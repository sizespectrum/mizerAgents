# Support for giving the agent access to the user's live R session, via the
# `btw` package's MCP server (<https://posit-dev.github.io/btw/>). `btw` is a
# pure-R, CRAN package from Posit built on `mcptools`/`ellmer`; the server runs
# as a separate `Rscript` process and gains access to the user's RStudio session
# only once `btw::btw_mcp_session()` has been called there.

# Name of the server entry written into the project's `.mcp.json`. Namespaced so
# that it does not collide with a `btw` server the user has configured
# themselves, and so that we only ever rewrite our own entry.
.mcp_server_name <- "r-mizer"

# `btw` tool groups to expose. Deliberately narrow: `files`, `git`, `github`,
# `web` and `cran` duplicate capabilities every coding agent already has. What
# is left is what the agent cannot get any other way — documentation for the
# *installed* mizer, the user's live objects, and the file they are looking at
# in the IDE. `pkg` is off unless asked for: it only makes sense when the
# project is itself a package, and `btw_tool_pkg_check()` on a project that is
# not one is a slow way to get an error.
.btw_groups <- function(run_r, pkg_dev) {
    c("docs", "env", "sessioninfo", "ide",
      if (run_r) "run", if (pkg_dev) "pkg")
}

# Build the `.mcp.json` server entry. `args` is a list rather than a character
# vector so that the value survives a round trip through `jsonlite` unchanged,
# which is what lets `.write_mcp_json()` recognise an up-to-date file and leave
# it alone.
.mcp_entry <- function(run_r, pkg_dev) {
    groups <- .btw_groups(run_r, pkg_dev)
    call <- sprintf("btw::btw_mcp_server(c(%s))",
                    paste0("'", groups, "'", collapse = ", "))
    entry <- list(type = "stdio",
                  command = "Rscript",
                  args = list("-e", call))
    # `btw_tool_run_r()` executes in the global environment with no sandboxing,
    # so `btw` requires it to be switched on explicitly.
    if (run_r) entry$env <- list(BTW_RUN_R_ENABLED = "true")
    entry
}

# Add (or refresh) our server in the project's `.mcp.json`, leaving any other
# servers the user has configured untouched. Returns TRUE if the file changed.
# Internal helper.
.write_mcp_json <- function(dest, run_r, pkg_dev) {
    entry <- .mcp_entry(run_r, pkg_dev)
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
    if (!is.list(cfg$mcpServers)) cfg$mcpServers <- list()
    if (identical(cfg$mcpServers[[.mcp_server_name]], entry)) return(FALSE)

    cfg$mcpServers[[.mcp_server_name]] <- entry
    writeLines(jsonlite::toJSON(cfg, auto_unbox = TRUE, pretty = TRUE), dest)
    TRUE
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
.r_session_message <- function(run_r, rprofile, pkg_dev) {
    paste0(
        "\n\nLive R session for the agent (MCP server `", .mcp_server_name, "`):",
        if (!requireNamespace("btw", quietly = TRUE)) {
            # `requireNamespace()` also fails when btw is installed but cannot
            # be loaded (typically an out-of-date dependency), so do not claim
            # it is missing.
            "\n  ! The btw package is not available. Run: install.packages(\"btw\")\n    (if it is already installed, `library(btw)` will show why it fails)"
        } else "",
        if (isTRUE(rprofile)) {
            "\n  Connects automatically: .Rprofile now calls btw::btw_mcp_session()\n  (restart R for this to take effect)"
        } else {
            "\n  Run btw::btw_mcp_session() in this console to connect it,\n  or re-run with rprofile = TRUE to do that on every startup"
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
        "\n\n## The user's live R session\n\n",
        "This project is configured with an MCP server named `r-mizer` (provided by\n",
        "the [btw](https://posit-dev.github.io/btw/) package) that connects you to the\n",
        "R session the user is working in. Use it:\n\n",
        "- **Look up mizer functions before calling them.** The docs tools\n",
        "  (`btw_tool_docs_help_page`, `btw_tool_docs_available_vignettes`,\n",
        "  `btw_tool_docs_vignette`, `btw_tool_docs_package_news`) read the *installed*\n",
        "  mizer. That is the authority on argument names and defaults — above this\n",
        "  card, and far above your own recollection, which is very likely stale.\n",
        "- **Inspect what the user already has.** `btw_tool_env_describe_environment`\n",
        "  lists the objects in their global environment; do not rebuild a\n",
        "  `MizerParams` or re-run a simulation that is already sitting there.\n",
        "- **Read what they are looking at.** `btw_tool_ide_read_current_editor`\n",
        "  returns the document open in RStudio, which is usually the thing a vague\n",
        "  request refers to.\n",
        if (run_r) paste0(
            "- **Run mizer code in their session, not in a scratch script.**\n",
            "  `btw_tool_run_r` evaluates in their global environment, so results\n",
            "  persist and the user can carry on with them. Plots come back to you as\n",
            "  images: after calibrating or projecting, plot the result and *look at it*\n",
            "  before reporting success.\n",
            "- **That session holds their work.** Assigning over an existing object\n",
            "  destroys it, and there is no undo. Assign to a new name, or say what you\n",
            "  are about to overwrite first. Long projections block their console, so\n",
            "  keep `t_max` modest unless asked otherwise.\n"
        ) else paste0(
            "- Running R code in the session is **not** enabled for this project. To use\n",
            "  the console yourself, write a script and run it with `Rscript`; it will not\n",
            "  see the user's objects. The user can enable in-session execution with\n",
            "  `setup_mizer_agent(run_r = TRUE)`.\n"
        ),
        if (pkg_dev) paste0(
            "- **This project is an R package** — most likely a mizer extension. Use the\n",
            "  package tools (`btw_tool_pkg_load_all`, `btw_tool_pkg_document`,\n",
            "  `btw_tool_pkg_test`, `btw_tool_pkg_check`, `btw_tool_pkg_coverage`) rather\n",
            "  than shelling out to `R CMD` or `devtools`: they run in the user's session,\n",
            "  so after `load_all` the new code is live and you can exercise it directly.\n",
            "  Read the `extend-mizer` skill before changing how a mizer rate is\n",
            "  calculated.\n"
        ) else "",
        "\nIf these tools are missing, the user has not run `btw::btw_mcp_session()` in\n",
        "their RStudio console — ask them to, rather than working around it.\n"
    )
}
