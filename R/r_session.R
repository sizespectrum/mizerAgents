# Support for giving the agent access to the user's live R session, via the
# `btw` package's MCP server (<https://posit-dev.github.io/btw/>). `btw` is a
# pure-R, CRAN package from Posit built on `mcptools`/`ellmer`; the server runs
# as a separate `Rscript` process and gains access to the user's R session only
# once `btw::btw_mcp_session()` has been called there. That call, and every tool
# group below except `ide`, works in any R session - a terminal, ESS, the VS
# Code R extension - not just RStudio and Positron.

# Name of the server entry written into the project's `.mcp.json`. Namespaced so
# that it does not collide with a `btw` server the user has configured
# themselves, and so that we only ever rewrite our own entry.
.mcp_server_name <- "r-mizer"

# `btw` tool groups to expose. Deliberately narrow: `files`, `git`, `github`,
# `web` and `cran` duplicate capabilities every coding agent already has. What
# is left is what the agent cannot get any other way: documentation for the
# *installed* mizer, the user's live objects, and the file they are looking at
# in the IDE. `pkg` is off unless asked for: it only makes sense when the
# project is itself a package, and `btw_tool_pkg_check()` on a project that is
# not one is a slow way to get an error.
#
# `ide` is the one group that needs a particular editor: it is a single tool,
# `btw_tool_ide_read_current_editor`, which requires `rstudioapi` and so errors
# anywhere but RStudio and Positron. It is still requested unconditionally,
# because these config files are committed and shared, and the editor a
# collaborator uses is not knowable when they are written. The card tells the
# agent when to expect the failure and what it does and does not mean.
.btw_groups <- function(run_r, pkg_dev) {
    c("docs", "env", "sessioninfo", "ide",
      if (run_r) "run", if (pkg_dev) "pkg")
}

# The `Rscript -e` invocation that starts the server. Every agent's config
# format ultimately wraps this same command.
#
# Linux desktop sessions normally advertise their per-user runtime directory
# through `XDG_RUNTIME_DIR`, which is where `mcptools` puts the sockets that
# connect an MCP server to an interactive R session. Some agents sanitise the
# environment of MCP subprocesses, however. The user's R session then registers
# under `/run/user/<uid>/mcptools`, while the server falls back to
# `/tmp/mcptools-<user>` and silently sees no sessions.
#
# Recover the standard Linux location in the server process when neither the
# explicit mcptools override nor XDG itself survived. The expression has to be
# self-contained because the generated config depends only on btw/mcptools,
# not on mizerAgents remaining installed. It deliberately leaves explicit and
# inherited settings alone, and is a no-op on systems without `/run/user`.
.mcp_socket_prelude <- paste0(
    "if (.Platform$OS.type == 'unix' && ",
    "!nzchar(Sys.getenv('MCPTOOLS_SOCKET_DIR')) && ",
    "!nzchar(Sys.getenv('XDG_RUNTIME_DIR'))) { ",
    "uid <- file.info(path.expand('~'))$uid; ",
    "runtime <- file.path('/run/user', uid); ",
    "if (!is.na(uid) && dir.exists(runtime)) ",
    "Sys.setenv(MCPTOOLS_SOCKET_DIR = file.path(runtime, 'mcptools')) }"
)

# The groups go through `btw_tools()` rather than being handed to
# `btw_mcp_server()` as a bare character vector. `btw_mcp_server()` starts by
# testing whether its argument names an R file, with
# `is.character(tools) && file.exists(tools) && ...`; since R 4.3 an `&&` whose
# operand has length > 1 is an error, so a vector of two or more group names
# kills the server process at startup. The agent then sees only a closed pipe
# and reports a transport error, with the R message going nowhere. Passing a
# list of tool objects makes `is.character()` FALSE and short-circuits the test
# before `file.exists()` is reached.
.btw_call <- function(run_r, pkg_dev) {
    sprintf("local({ %s; btw::btw_mcp_server(btw::btw_tools(%s)) })",
            .mcp_socket_prelude,
            paste0("'", .btw_groups(run_r, pkg_dev), "'", collapse = ", "))
}

# Build the server entry for a JSON-based config. `args` is a list rather than a
# character vector so that the value survives a round trip through `jsonlite`
# unchanged, which is what lets `.write_mcp_json()` recognise an up-to-date file
# and leave it alone. `type` varies by agent: Claude Code labels stdio servers
# `"stdio"`, Copilot CLI calls them `"local"`, and Gemini CLI and Antigravity
# document no `type` field at all, so it is omitted for them rather than
# guessed at.
.mcp_entry <- function(run_r, pkg_dev, type = "stdio") {
    entry <- list(type = type,
                  command = "Rscript",
                  args = list("-e", .btw_call(run_r, pkg_dev)))
    entry <- entry[!vapply(entry, is.null, logical(1))]
    # `btw_tool_run_r()` executes in the global environment with no sandboxing,
    # so `btw` requires it to be switched on explicitly.
    if (run_r) entry$env <- list(BTW_RUN_R_ENABLED = "true")
    entry
}

# Add (or refresh) our server in a JSON config file, leaving any other servers
# the user has configured untouched. Most agents nest servers under
# `mcpServers`, but VS Code uses `servers` instead, so the key is a parameter:
# writing the wrong one leaves a file that parses cleanly and does nothing.
# Returns TRUE if the file changed. Internal helper.
.write_mcp_json <- function(dest, run_r, pkg_dev, type = "stdio",
                            key = "mcpServers") {
    entry <- .mcp_entry(run_r, pkg_dev, type)
    cfg <- list()
    if (file.exists(dest)) {
        cfg <- tryCatch(
            jsonlite::fromJSON(dest, simplifyVector = FALSE),
            error = function(e) NULL
        )
        # Refuse to touch a file we cannot parse: overwriting it would silently
        # discard the user's other MCP servers.
        if (is.null(cfg)) {
            warning("Could not parse ", dest, ", so it was left unchanged. ",
                    "Add the `", .mcp_server_name, "` server by hand, or fix ",
                    "the file and re-run setup_mizer_agent().", call. = FALSE)
            return(FALSE)
        }
    }
    if (!is.list(cfg[[key]])) cfg[[key]] <- list()
    if (identical(cfg[[key]][[.mcp_server_name]], entry)) return(FALSE)

    cfg[[key]][[.mcp_server_name]] <- entry
    dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
    writeLines(jsonlite::toJSON(cfg, auto_unbox = TRUE, pretty = TRUE), dest)
    TRUE
}

# Codex is the one agent whose project config is TOML rather than JSON. Rather
# than take on a TOML parser to merge into it, manage a marked block, as
# `AGENTS.md` does. The block goes at the *end* of the file because a TOML table
# header claims every key below it until the next header: anywhere else, config
# the user has written afterwards would silently be absorbed into our table.
.codex_begin <- "# mizerAgents: start - managed by setup_mizer_agent(), edits are overwritten"
.codex_end   <- "# mizerAgents: end - add your own config above this block, not below"

.codex_block <- function(run_r, pkg_dev) {
    c(.codex_begin,
      sprintf('[mcp_servers."%s"]', .mcp_server_name),
      'command = "Rscript"',
      sprintf('args = ["-e", "%s"]', .btw_call(run_r, pkg_dev)),
      if (run_r) 'env = { BTW_RUN_R_ENABLED = "true" }',
      .codex_end)
}

# Write (or refresh in place) our block in `.codex/config.toml`. Returns TRUE if
# the file changed. Internal helper.
.write_codex_toml <- function(dest, run_r, pkg_dev) {
    block <- .codex_block(run_r, pkg_dev)
    existing <- if (file.exists(dest)) readLines(dest, warn = FALSE) else character(0)
    b <- which(existing == .codex_begin)
    e <- which(existing == .codex_end)
    if (length(b) && length(e) && e[1] > b[1]) {
        updated <- c(existing[seq_len(b[1] - 1)], block, existing[-seq_len(e[1])])
    } else {
        updated <- c(existing, if (length(existing)) "", block)
    }
    if (identical(updated, existing)) return(FALSE)
    dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
    writeLines(updated, dest)
    TRUE
}

# Where each agent keeps its project-level MCP config, and the schema quirks it
# expects. `type` is the transport label: Claude Code and VS Code want
# `"stdio"`, the rest document no such field, so it is omitted rather than
# guessed at. `key` is the top-level JSON key holding the servers: `mcpServers`
# everywhere except VS Code, which uses `servers`.
#
# Copilot CLI and Windsurf are absent because they have no project scope at all
# (`~/.copilot/mcp-config.json`, `~/.codeium/windsurf/mcp_config.json` are
# user-wide, and a project setup function has no business writing there);
# Copilot gets printed instructions instead. Zed is absent because it uses a
# `context_servers` schema of its own.
.agent_configs <- list(
    claude      = list(path = ".mcp.json",
                       type = "stdio", key = "mcpServers",
                       label = "Claude Code"),
    codex       = list(path = file.path(".codex", "config.toml"),
                       type = NULL,    key = NULL,
                       label = "Codex CLI"),
    gemini      = list(path = file.path(".gemini", "settings.json"),
                       type = NULL,    key = "mcpServers",
                       label = "Gemini CLI"),
    antigravity = list(path = file.path(".agents", "mcp_config.json"),
                       type = NULL,    key = "mcpServers",
                       label = "Antigravity CLI"),
    cursor      = list(path = file.path(".cursor", "mcp.json"),
                       type = NULL,    key = "mcpServers",
                       label = "Cursor"),
    vscode      = list(path = file.path(".vscode", "mcp.json"),
                       type = "stdio", key = "servers",
                       label = "VS Code / Copilot"),
    posit       = list(path = file.path(".posit", "assistant", "settings.json"),
                       type = NULL,    key = "mcpServers",
                       label = "Posit Assistant")
)

# Every agent `setup_mizer_agent()` knows about. `copilot` is a valid choice
# even though it has no entry above; asking for it gets you the snippet to
# paste into your user config.
.agent_choices <- c(names(.agent_configs), "copilot")

# Write the project-level MCP config for each requested agent. Returns the
# paths actually written, so that the caller can report them. Internal helper.
.write_agent_configs <- function(path, agents, run_r, pkg_dev) {
    written <- character(0)
    for (agent in intersect(agents, names(.agent_configs))) {
        spec <- .agent_configs[[agent]]
        dest <- normalizePath(file.path(path, spec$path), mustWork = FALSE)
        changed <- if (identical(agent, "codex")) {
            .write_codex_toml(dest, run_r, pkg_dev)
        } else {
            .write_mcp_json(dest, run_r, pkg_dev, spec$type, spec$key)
        }
        if (changed) written <- c(written, stats::setNames(dest, spec$label))
    }
    written
}

# Copilot CLI reads MCP config only from `~/.copilot/mcp-config.json`, which is
# user-wide rather than per-project, so we print the snippet instead of writing
# it. Internal helper.
.copilot_snippet <- function(run_r, pkg_dev) {
    entry <- .mcp_entry(run_r, pkg_dev, type = "local")
    entry$tools <- list("*")
    json <- jsonlite::toJSON(list(mcpServers = stats::setNames(
        list(entry), .mcp_server_name)), auto_unbox = TRUE, pretty = TRUE)
    paste0(
        "\n\nCopilot CLI has no per-project MCP config, so add this to\n",
        "~/.copilot/mcp-config.json yourself (merge into any `mcpServers` you\n",
        "already have):\n\n",
        paste0("  ", strsplit(as.character(json), "\n")[[1]], collapse = "\n")
    )
}

# The line added to the project `.Rprofile` to hand the running session to the
# MCP server. Guarded so that a project that is opened without `btw` installed,
# or non-interactively (R CMD check, knitting, CI), still starts cleanly.
.rprofile_marker <- "# mizerAgents: expose this session to the r-mizer MCP server"
.rprofile_line <-
    'if (interactive() && requireNamespace("btw", quietly = TRUE)) btw::btw_mcp_session()'

# Append the session hook to the project `.Rprofile` if it is not already there.
# Returns TRUE if the file changed. Internal helper.
.write_rprofile <- function(dest) {
    existing <- if (file.exists(dest)) readLines(dest, warn = FALSE) else character(0)
    if (.rprofile_line %in% existing) return(FALSE)
    writeLines(c(existing, if (length(existing)) "",
                 .rprofile_marker, .rprofile_line), dest)
    TRUE
}

# The part of the setup summary covering the live session. Spells out the two
# things that are easy to miss: `btw` is not installed for you, and the server
# sees nothing until the session registers itself. Internal helper.
.r_session_message <- function(run_r, rprofile, pkg_dev, agents) {
    paste0(
        "\n\nLive R session for the agent (MCP server `", .mcp_server_name, "`):",
        {
            configured <- intersect(agents, names(.agent_configs))
            if (length(configured)) {
                paste0("\n  Configured for: ",
                       paste(vapply(.agent_configs[configured], `[[`,
                                    character(1), "label"), collapse = ", "))
            } else ""
        },
        if (!requireNamespace("btw", quietly = TRUE)) {
            # `requireNamespace()` also fails when btw is installed but cannot
            # be loaded (typically an out-of-date dependency), so do not claim
            # it is missing.
            "\n  ! The btw package is not available. Run: install.packages(\"btw\")\n    (if it is already installed, `library(btw)` will show why it fails)"
        } else "",
        if (isTRUE(rprofile)) {
            "\n  Connects automatically: .Rprofile now calls btw::btw_mcp_session()\n  (restart R for this to take effect)"
        } else {
            "\n  Run connect_mizer_agent() in this console to connect it\n  (a wrapper around btw::btw_mcp_session()), or re-run with\n  rprofile = TRUE to do that on every startup"
        },
        if (run_r) {
            "\n  Code execution in your session is ENABLED: the agent can overwrite\n  your objects. Re-run with run_r = FALSE to make it read-only."
        } else {
            "\n  Read-only: docs, your environment and the open document. Use\n  run_r = TRUE to also let the agent run mizer code and see the plots."
        },
        if (pkg_dev) {
            "\n  Package tools enabled: the agent can run load_all(), document(),\n  test(), check() and coverage on this project."
        } else ""
    )
}

# The section added to `MIZER-AGENTS.md` describing the live session. The MCP
# server alone changes nothing: without these instructions an agent will still
# reach for its recollection of the mizer API and write throwaway scripts
# instead of using the session the user is sitting in front of. Tool names are
# given as `btw` function names rather than as the agent's own MCP tool names,
# which vary between clients.
.r_session_section <- function(run_r, pkg_dev) {
    paste0(
        "## The user's live R session\n\n",
        "This project is configured with an MCP server named `r-mizer` (provided by\n",
        "the [btw](https://posit-dev.github.io/btw/) package) that connects you to the\n",
        "R session the user is working in. Use it:\n\n",
        "- **Look up mizer functions before calling them.** The docs tools\n",
        "  (`btw_tool_docs_help_page`, `btw_tool_docs_available_vignettes`,\n",
        "  `btw_tool_docs_vignette`, `btw_tool_docs_package_news`) read the *installed*\n",
        "  mizer. That is the authority on argument names and defaults, above this\n",
        "  card, and far above your own recollection, which is very likely stale.\n",
        "- **Inspect what the user already has.** `btw_tool_env_describe_environment`\n",
        "  lists the objects in their global environment; do not rebuild a\n",
        "  `MizerParams` or re-run a simulation that is already sitting there.\n",
        "- **Read what they are looking at.** `btw_tool_ide_read_current_editor`\n",
        "  returns the document open in the editor, which is usually the thing a\n",
        "  vague request refers to. It works only when the user is in RStudio or\n",
        "  Positron; in any other editor it errors, which tells you nothing about\n",
        "  the rest of the session. Ask them which file they mean instead.\n",
        if (run_r) paste0(
            "- **Run mizer code in their session, not in a scratch script.**\n",
            "  `btw_tool_run_r` evaluates in their global environment, so results\n",
            "  persist and the user can carry on with them. Plots come back to you as\n",
            "  images: after calibrating or projecting, plot the result and *look at it*\n",
            "  before reporting success.\n",
            "- **That session holds their work.** You are in *their* global\n",
            "  environment: assigning over an existing object destroys it, and `load()`\n",
            "  and `rm()` reach everything they have open. There is no undo and nothing\n",
            "  warns you. Assign to a new name, or say what you are about to overwrite\n",
            "  first, and do exploratory work in a throwaway environment or a separate\n",
            "  `Rscript` — keep the session itself for the steps whose result the user\n",
            "  wants to keep. Say so whenever you do change a global. Long projections\n",
            "  block their console, so keep `t_max` modest unless asked otherwise.\n"
        ) else paste0(
            "- Running R code in the session is **not** enabled for this project. To use\n",
            "  the console yourself, write a script and run it with `Rscript`; it will not\n",
            "  see the user's objects. The user can enable in-session execution with\n",
            "  `setup_mizer_agent(run_r = TRUE)`.\n"
        ),
        if (pkg_dev) paste0(
            "- **This project is an R package**, most likely a mizer extension. Use the\n",
            "  package tools (`btw_tool_pkg_load_all`, `btw_tool_pkg_document`,\n",
            "  `btw_tool_pkg_test`, `btw_tool_pkg_check`, `btw_tool_pkg_coverage`) rather\n",
            "  than shelling out to `R CMD` or `devtools`: they run in the user's session,\n",
            "  so after `load_all` the new code is live and you can exercise it directly.\n",
            "  Read the `extend-mizer` skill before changing how a mizer rate is\n",
            "  calculated.\n"
        ) else "",
        "\nIf these tools are missing, the user has not connected their session; ask\n",
        "them to run `mizerAgents::connect_mizer_agent()` in their R console, rather\n",
        "than working around it."
    )
}
