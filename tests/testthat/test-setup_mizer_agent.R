test_that("setup_mizer_agent works as expected", {
    # Create a temporary directory for setup
    tmp_dir <- tempfile("mizer_agent_test")
    dir.create(tmp_dir)
    on.exit(unlink(tmp_dir, recursive = TRUE))

    # 1. Clean run: files should be created
    expect_message(
        setup_mizer_agent(path = tmp_dir),
        "Created"
    ) |> suppressMessages()

    mizer_dest  <- file.path(tmp_dir, "MIZER-AGENTS.md")
    agents_dest <- file.path(tmp_dir, "AGENTS.md")
    claude_dest <- file.path(tmp_dir, "CLAUDE.md")
    gemini_dest <- file.path(tmp_dir, "GEMINI.md")

    expect_true(file.exists(mizer_dest))
    expect_true(file.exists(agents_dest))
    expect_true(file.exists(claude_dest))
    expect_true(file.exists(gemini_dest))

    # MIZER-AGENTS.md should contain mizer documentation and point at the
    # bundled API index, but never at a bundled argument reference
    mizer_content <- readLines(mizer_dest)
    expect_true(any(grepl("Mizer", mizer_content)))
    expect_true(any(grepl("Finding the right mizer function", mizer_content,
                          fixed = TRUE)))
    expect_true(any(grepl("llms.txt", mizer_content, fixed = TRUE)))
    expect_false(any(grepl("llms-full", mizer_content, fixed = TRUE)))

    # Every generated section was substituted into its placeholder, and the
    # routing sections come before the reference the card is not: the skills
    # index has to be reachable for an agent that stops reading part-way.
    expect_false(any(grepl("^<!-- mizerAgents:[a-z-]+ -->$", mizer_content)))
    expect_lt(grep("^## Task skills", mizer_content),
              grep("^## Finding the right", mizer_content))

    # The card routes rather than duplicating: the workflow, plotting and
    # species-parameter sections it used to carry are the skills' job now, and
    # restating them here is how they went stale.
    expect_false(any(grepl("plotSpectra", mizer_content, fixed = TRUE)))
    expect_false(any(grepl("Numerical scheme for dynamics", mizer_content,
                           fixed = TRUE)))

    # Each instruction file should contain the marked block: a note plus the
    # `@` import. All three carry it, so an agent that reads only its own named
    # file still gets the mizer context.
    for (dest in c(agents_dest, claude_dest, gemini_dest)) {
        content <- readLines(dest)
        expect_true("@MIZER-AGENTS.md" %in% content, info = dest)
        expect_true(any(grepl("Read `MIZER-AGENTS.md`", content, fixed = TRUE)),
                    info = dest)
        expect_true(any(grepl("mizerAgents: start", content, fixed = TRUE)),
                    info = dest)
        expect_true(any(grepl("mizerAgents: end", content, fixed = TRUE)),
                    info = dest)
    }
    agents_content <- readLines(agents_dest)

    # 2. Existing AGENTS.md with custom content and overwrite = FALSE
    # Overwrite AGENTS.md with custom notes
    custom_notes <- c("# My Custom Notes", "", "Some projects details")
    writeLines(custom_notes, agents_dest)

    # Run setup again
    expect_message(
        setup_mizer_agent(path = tmp_dir, overwrite = FALSE),
        "Prepended @MIZER-AGENTS.md shim"
    ) |> suppressMessages()

    # Custom notes should be preserved below the shim
    agents_content <- readLines(agents_dest)
    expect_true("@MIZER-AGENTS.md" %in% agents_content)
    expect_identical(tail(agents_content, 3), custom_notes)

    # Run setup again: the block is already present and up to date, so the file
    # should be left byte-identical rather than prepended to a second time.
    # Note: MIZER-AGENTS.md gets overwritten each time.
    before <- agents_content
    expect_message(
        setup_mizer_agent(path = tmp_dir, overwrite = FALSE),
        "Created"
    ) |> suppressMessages()
    agents_content <- readLines(agents_dest)
    expect_identical(agents_content, before)
    expect_equal(sum(agents_content == "@MIZER-AGENTS.md"), 1)

    # 3. Existing AGENTS.md with custom content and overwrite = TRUE
    # Run setup with overwrite = TRUE: custom notes are dropped, leaving the
    # shim on its own
    suppressMessages(setup_mizer_agent(path = tmp_dir, overwrite = TRUE))
    agents_content <- readLines(agents_dest)
    expect_true("@MIZER-AGENTS.md" %in% agents_content)
    expect_false(any(grepl("My Custom Notes", agents_content, fixed = TRUE)))
})

test_that("the managed block is refreshed in place", {
    tmp_dir <- tempfile("mizer_agent_block")
    dir.create(tmp_dir)
    on.exit(unlink(tmp_dir, recursive = TRUE))
    agents_dest <- file.path(tmp_dir, "AGENTS.md")

    # A user file with the block below their own notes, and stale content in it
    writeLines(c(
        "# My Model",
        "",
        "Project notes.",
        "",
        .shim_begin,
        "Something out of date.",
        "@MIZER-AGENTS.md",
        "<!-- mizerAgents: end -->",
        "",
        "## Notes below the block"
    ), agents_dest)

    suppressMessages(setup_mizer_agent(path = tmp_dir))
    content <- readLines(agents_dest)

    # Stale content replaced, block stays where the user had it, and text on
    # both sides survives
    expect_false(any(grepl("out of date", content, fixed = TRUE)))
    expect_true(any(grepl("Read `MIZER-AGENTS.md`", content, fixed = TRUE)))
    expect_identical(content[1:3], c("# My Model", "", "Project notes."))
    expect_identical(tail(content, 1), "## Notes below the block")
    expect_equal(sum(grepl("mizerAgents: start", content, fixed = TRUE)), 1)
})

test_that("the unmarked shim written by 0.3.2 and earlier is upgraded", {
    tmp_dir <- tempfile("mizer_agent_legacy")
    dir.create(tmp_dir)
    on.exit(unlink(tmp_dir, recursive = TRUE))
    agents_dest <- file.path(tmp_dir, "AGENTS.md")

    # 0.3.2 form: a bare import line above the user's own notes
    writeLines(c("@MIZER-AGENTS.md", "", "# My Model"), agents_dest)
    suppressMessages(setup_mizer_agent(path = tmp_dir))
    content <- readLines(agents_dest)

    expect_equal(sum(content == "@MIZER-AGENTS.md"), 1)
    expect_true(any(grepl("mizerAgents: start", content, fixed = TRUE)))
    expect_identical(tail(content, 1), "# My Model")

    # Only the import line is ours: prose the user wrote around it stays put
    writeLines(c("My own wording about mizer.", "@MIZER-AGENTS.md"), agents_dest)
    suppressMessages(setup_mizer_agent(path = tmp_dir))
    content <- readLines(agents_dest)
    expect_identical(content[1], "My own wording about mizer.")
    expect_equal(sum(content == "@MIZER-AGENTS.md"), 1)
})

test_that("existing CLAUDE.md and GEMINI.md are updated like AGENTS.md", {
    tmp_dir <- tempfile("mizer_agent_shims")
    dir.create(tmp_dir)
    on.exit(unlink(tmp_dir, recursive = TRUE))
    claude_dest <- file.path(tmp_dir, "CLAUDE.md")
    gemini_dest <- file.path(tmp_dir, "GEMINI.md")

    # A user file that predates mizerAgents keeps its content and gains the
    # block, rather than being skipped for existing
    writeLines(c("# House rules", "", "Use tidyverse style."), claude_dest)
    suppressMessages(setup_mizer_agent(path = tmp_dir))

    claude_content <- readLines(claude_dest)
    expect_true(any(grepl("mizerAgents: start", claude_content, fixed = TRUE)))
    expect_true("@MIZER-AGENTS.md" %in% claude_content)
    expect_identical(tail(claude_content, 3),
                     c("# House rules", "", "Use tidyverse style."))
    # No import of AGENTS.md is invented: what non-mizer context reaches Claude
    # Code is exactly what it was before we ran
    expect_false("@AGENTS.md" %in% claude_content)

    # Re-running leaves the file byte-identical
    before <- readLines(claude_dest)
    suppressMessages(setup_mizer_agent(path = tmp_dir))
    expect_identical(readLines(claude_dest), before)

    # overwrite = TRUE discards the user's content in these files too
    suppressMessages(setup_mizer_agent(path = tmp_dir, overwrite = TRUE))
    claude_content <- readLines(claude_dest)
    expect_false(any(grepl("House rules", claude_content, fixed = TRUE)))
    expect_true("@MIZER-AGENTS.md" %in% claude_content)
})

test_that("a file that imports AGENTS.md is left alone", {
    tmp_dir <- tempfile("mizer_agent_imports")
    dir.create(tmp_dir)
    on.exit(unlink(tmp_dir, recursive = TRUE))
    claude_dest <- file.path(tmp_dir, "CLAUDE.md")
    gemini_dest <- file.path(tmp_dir, "GEMINI.md")

    # The one-line shim written by 0.3.2 and earlier, and a user file with the
    # same import among their own notes. Removing that import would cut off
    # instructions the agent was seeing, so both are left exactly as they are:
    # the block reaches the agent through AGENTS.md.
    writeLines("@AGENTS.md", gemini_dest)
    writeLines(c("# House rules", "", "@AGENTS.md"), claude_dest)

    suppressMessages(setup_mizer_agent(path = tmp_dir))

    expect_identical(readLines(gemini_dest), "@AGENTS.md")
    expect_identical(readLines(claude_dest), c("# House rules", "", "@AGENTS.md"))
    # AGENTS.md itself carries the block, so the context still arrives
    expect_true(any(grepl("mizerAgents: start",
                          readLines(file.path(tmp_dir, "AGENTS.md")),
                          fixed = TRUE)))
})

test_that("skills are installed with a manifest and a NOTES.md pointer", {
    tmp_dir <- tempfile("mizer_agent_skills")
    dir.create(tmp_dir)
    on.exit(unlink(tmp_dir, recursive = TRUE))
    skills_dest <- file.path(tmp_dir, ".claude", "skills")

    suppressMessages(setup_mizer_agent(path = tmp_dir))
    skill <- file.path(skills_dest, "calibrate-model", "SKILL.md")
    expect_true(file.exists(skill))

    # Every SKILL.md carries the footer sending project-specific findings to
    # NOTES.md and general ones upstream
    content <- readLines(skill)
    expect_true(any(grepl("`NOTES.md`", content, fixed = TRUE)))
    expect_true(any(grepl("sizespectrum/mizerAgents/issues", content,
                          fixed = TRUE)))

    # ... and so does the index in the always-loaded card, for agents that do
    # not discover .claude/skills/ themselves
    mizer_content <- readLines(file.path(tmp_dir, "MIZER-AGENTS.md"))
    expect_true(any(grepl("NOTES.md", mizer_content, fixed = TRUE)))
    expect_true(any(grepl("sizespectrum/mizerAgents/issues", mizer_content,
                          fixed = TRUE)))

    # The manifest records what was installed, keyed by relative path
    manifest <- file.path(skills_dest, .skill_manifest)
    expect_true(file.exists(manifest))
    hashes <- .read_skill_manifest(manifest)
    expect_true("calibrate-model/SKILL.md" %in% names(hashes))
    expect_identical(unname(hashes["calibrate-model/SKILL.md"]),
                     unname(tools::md5sum(skill)))

    # Re-running leaves an up-to-date file untouched, mtime included
    before <- file.mtime(skill)
    suppressMessages(setup_mizer_agent(path = tmp_dir))
    expect_identical(file.mtime(skill), before)
})

test_that("local edits inside .claude/skills/ survive a re-run", {
    tmp_dir <- tempfile("mizer_agent_skill_edits")
    dir.create(tmp_dir)
    on.exit(unlink(tmp_dir, recursive = TRUE))
    skills_dest <- file.path(tmp_dir, ".claude", "skills")
    suppressMessages(setup_mizer_agent(path = tmp_dir))

    # Notes an agent wrote next to a bundled skill, and a skill of the user's own
    notes <- file.path(skills_dest, "calibrate-model", "NOTES.md")
    writeLines(c("# Notes", "", "This model needs steady(tol = 1e-4)."), notes)
    own <- file.path(skills_dest, "my-own-skill")
    dir.create(own)
    writeLines("# Mine", file.path(own, "SKILL.md"))

    # An edit to a bundled SKILL.md itself
    skill <- file.path(skills_dest, "run-simulation", "SKILL.md")
    edited <- c(readLines(skill), "", "A hard-won lesson.")
    writeLines(edited, skill)

    expect_message(setup_mizer_agent(path = tmp_dir),
                   "run-simulation/SKILL.md") |> suppressMessages()

    # Nothing of the project's is lost
    expect_identical(readLines(notes)[3], "This model needs steady(tol = 1e-4).")
    expect_identical(readLines(file.path(own, "SKILL.md")), "# Mine")
    # The edited skill is kept, with the new version alongside for merging
    expect_identical(readLines(skill), edited)
    side <- paste0(skill, ".new")
    expect_true(file.exists(side))
    expect_false(any(grepl("hard-won", readLines(side), fixed = TRUE)))

    # The edit is still recognised as an edit on the next run, rather than
    # adopted and then overwritten
    suppressMessages(setup_mizer_agent(path = tmp_dir))
    expect_identical(readLines(skill), edited)

    # Reverting it puts the file back under package management, and the .new
    # copy is cleared away
    unlink(skill)
    suppressMessages(setup_mizer_agent(path = tmp_dir))
    expect_false(any(grepl("hard-won", readLines(skill), fixed = TRUE)))
    expect_false(file.exists(side))
})

test_that("a project set up before the manifest existed is refreshed once", {
    tmp_dir <- tempfile("mizer_agent_skill_legacy")
    dir.create(tmp_dir)
    on.exit(unlink(tmp_dir, recursive = TRUE))
    skills_dest <- file.path(tmp_dir, ".claude", "skills")
    suppressMessages(setup_mizer_agent(path = tmp_dir))

    # 0.3.2 and earlier kept no record of what they installed, so a stale skill
    # is indistinguishable from an edited one and must be refreshed, as it was
    # then. Simulate that: stale content, no manifest.
    skill <- file.path(skills_dest, "calibrate-model", "SKILL.md")
    writeLines("stale", skill)
    unlink(file.path(skills_dest, .skill_manifest))

    suppressMessages(setup_mizer_agent(path = tmp_dir))
    expect_false(identical(readLines(skill), "stale"))
    expect_true(file.exists(file.path(skills_dest, .skill_manifest)))
})

test_that("a skill that is no longer bundled is removed unless edited", {
    tmp_dir <- tempfile("mizer_agent_skill_dropped")
    dir.create(tmp_dir)
    on.exit(unlink(tmp_dir, recursive = TRUE))
    skills_dest <- file.path(tmp_dir, ".claude", "skills")
    suppressMessages(setup_mizer_agent(path = tmp_dir))

    # Two skills a previous version shipped and this one does not: one
    # untouched since, one edited here
    manifest <- file.path(skills_dest, .skill_manifest)
    hashes <- .read_skill_manifest(manifest)
    for (name in c("dropped-skill", "dropped-edited")) {
        dir.create(file.path(skills_dest, name))
        f <- file.path(skills_dest, name, "SKILL.md")
        writeLines("# Was bundled once", f)
        hashes[paste0(name, "/SKILL.md")] <- unname(tools::md5sum(f))
    }
    writeLines("# Edited here", file.path(skills_dest, "dropped-edited",
                                          "SKILL.md"))
    .write_skill_manifest(manifest, hashes)

    suppressMessages(setup_mizer_agent(path = tmp_dir))
    expect_false(dir.exists(file.path(skills_dest, "dropped-skill")))
    expect_identical(readLines(file.path(skills_dest, "dropped-edited",
                                         "SKILL.md")), "# Edited here")
})

test_that("the website-only files in a skill directory are not installed", {
    tmp_dir <- tempfile("mizer_agent_skill_payload")
    dir.create(tmp_dir)
    on.exit(unlink(tmp_dir, recursive = TRUE))
    skills_dest <- file.path(tmp_dir, ".claude", "skills")

    src <- .skills_source()
    skip_if(!nzchar(src), "the installed mizer ships no skills")
    rels <- sort(list.files(src, recursive = TRUE))
    excluded <- setdiff(rels, .skill_payload(rels))
    skip_if(length(excluded) == 0,
            "the installed mizer ships no quick-reference.md")
    qr_rel <- excluded[1]

    suppressMessages(setup_mizer_agent(path = tmp_dir))
    # The skill itself is installed; its quick reference - which belongs to the
    # mizer website, and which no SKILL.md points at - is not
    expect_true(file.exists(file.path(skills_dest, dirname(qr_rel),
                                      "SKILL.md")))
    expect_false(file.exists(file.path(skills_dest, qr_rel)))
    expect_length(list.files(skills_dest, pattern = "^quick-reference\\.md$",
                             recursive = TRUE), 0)
    expect_false(qr_rel %in% names(.read_skill_manifest(
        file.path(skills_dest, .skill_manifest))))

    # A copy left behind by a version that did install it is swept away, even
    # with no manifest entry to recognise it by ...
    dest <- file.path(skills_dest, qr_rel)
    writeLines(readLines(file.path(src, qr_rel), warn = FALSE), dest)
    suppressMessages(setup_mizer_agent(path = tmp_dir))
    expect_false(file.exists(dest))

    # ... but one that has been edited here is not ours to remove
    edited <- c(readLines(file.path(src, qr_rel), warn = FALSE),
                "A note of my own.")
    writeLines(edited, dest)
    suppressMessages(setup_mizer_agent(path = tmp_dir))
    expect_identical(readLines(dest), edited)
})

test_that("the r-mizer MCP server is configured in .mcp.json", {
    tmp_dir <- tempfile("mizer_agent_mcp")
    dir.create(tmp_dir)
    on.exit(unlink(tmp_dir, recursive = TRUE))
    mcp_dest <- file.path(tmp_dir, ".mcp.json")

    suppressMessages(setup_mizer_agent(path = tmp_dir))
    expect_true(file.exists(mcp_dest))

    cfg <- jsonlite::fromJSON(mcp_dest, simplifyVector = FALSE)
    entry <- cfg$mcpServers[["r-mizer"]]
    expect_identical(entry$command, "Rscript")
    expect_match(entry$args[[2]], "btw::btw_mcp_server", fixed = TRUE)
    # Agent launchers may strip XDG_RUNTIME_DIR. The shared R command recovers
    # Linux's per-user socket directory so that the MCP server still sees the
    # RStudio/Positron session registered there.
    expect_match(entry$args[[2]], "MCPTOOLS_SOCKET_DIR", fixed = TRUE)
    expect_match(entry$args[[2]], "/run/user", fixed = TRUE)
    # Execution is on by default, and needs btw's own opt-in to work
    expect_true(grepl("'run'", entry$args[[2]], fixed = TRUE))
    expect_identical(entry$env$BTW_RUN_R_ENABLED, "true")
    # Package development tools are not
    expect_false(grepl("'pkg'", entry$args[[2]], fixed = TRUE))

    # The live-session section reaches the always-loaded card, and the
    # "how do I call it?" step routes through btw rather than a shell
    mizer_content <- readLines(file.path(tmp_dir, "MIZER-AGENTS.md"))
    expect_true(any(grepl("live R session", mizer_content, ignore.case = TRUE)))
    expect_true(any(grepl("btw_tool_docs_help_page", mizer_content,
                          fixed = TRUE)))

    # run_r = FALSE drops the group and the opt-in environment variable
    suppressMessages(setup_mizer_agent(path = tmp_dir, run_r = FALSE))
    cfg <- jsonlite::fromJSON(mcp_dest, simplifyVector = FALSE)
    entry <- cfg$mcpServers[["r-mizer"]]
    expect_false(grepl("'run'", entry$args[[2]], fixed = TRUE))
    expect_null(entry$env)

    # r_session = FALSE leaves .mcp.json alone and drops the section
    unlink(mcp_dest)
    suppressMessages(setup_mizer_agent(path = tmp_dir, r_session = FALSE))
    expect_false(file.exists(mcp_dest))
    mizer_content <- readLines(file.path(tmp_dir, "MIZER-AGENTS.md"))
    expect_false(any(grepl("r-mizer", mizer_content, fixed = TRUE)))
    # Without the session, the lookup step falls back to a shell command, but
    # still sends the agent to the installed mizer rather than to a snapshot
    expect_false(any(grepl("btw_tool_docs_help_page", mizer_content,
                           fixed = TRUE)))
    expect_true(any(grepl("help(name, package = \"mizer\")", mizer_content,
                          fixed = TRUE)))
})

test_that("every agent with a project-level config gets one", {
    tmp_dir <- tempfile("mizer_agent_agents")
    dir.create(tmp_dir)
    on.exit(unlink(tmp_dir, recursive = TRUE))

    suppressMessages(setup_mizer_agent(path = tmp_dir))
    for (f in c(".mcp.json", ".codex/config.toml", ".gemini/settings.json",
                ".agents/mcp_config.json", ".cursor/mcp.json",
                ".vscode/mcp.json", ".posit/assistant/settings.json")) {
        expect_true(file.exists(file.path(tmp_dir, f)), info = f)
    }

    # Claude labels stdio servers; Gemini and Antigravity document no `type`
    # field, so we must not invent one for them
    claude <- jsonlite::fromJSON(file.path(tmp_dir, ".mcp.json"),
                                 simplifyVector = FALSE)
    expect_identical(claude$mcpServers[["r-mizer"]]$type, "stdio")
    gemini <- jsonlite::fromJSON(file.path(tmp_dir, ".gemini/settings.json"),
                                 simplifyVector = FALSE)
    expect_null(gemini$mcpServers[["r-mizer"]]$type)
    expect_identical(gemini$mcpServers[["r-mizer"]]$command, "Rscript")

    # Narrowing the selection writes only what was asked for
    unlink(list.files(tmp_dir, all.files = TRUE, full.names = TRUE,
                      pattern = "^[.](mcp|codex|gemini|agents|cursor|vscode|posit)"),
           recursive = TRUE)
    suppressMessages(setup_mizer_agent(path = tmp_dir, agents = "claude"))
    expect_true(file.exists(file.path(tmp_dir, ".mcp.json")))
    expect_false(file.exists(file.path(tmp_dir, ".gemini/settings.json")))

    # Copilot has no project scope, so it is reported rather than written
    expect_message(
        setup_mizer_agent(path = tmp_dir, agents = "copilot"),
        "~/.copilot/mcp-config.json", fixed = TRUE
    ) |> suppressMessages()
    expect_false(dir.exists(file.path(tmp_dir, ".copilot")))

    # An unknown agent is rejected rather than silently ignored
    expect_error(setup_mizer_agent(path = tmp_dir, agents = "emacs"))
})

test_that("each agent's config matches the shape its schema documents", {
    # Seven formats is seven things that can change under us, and a config with
    # the wrong top-level key parses cleanly and silently does nothing. Pin the
    # shape of each so that a drifting format fails here rather than in a user's
    # project.
    tmp_dir <- tempfile("mizer_agent_shapes")
    dir.create(tmp_dir)
    on.exit(unlink(tmp_dir, recursive = TRUE))
    suppressMessages(setup_mizer_agent(path = tmp_dir))

    read_key <- function(file, key) {
        cfg <- jsonlite::fromJSON(file.path(tmp_dir, file),
                                  simplifyVector = FALSE)
        expect_named(cfg, key)
        cfg[[key]][["r-mizer"]]
    }

    # VS Code is the odd one out: `servers`, not `mcpServers`, and it wants an
    # explicit transport
    vscode <- read_key(".vscode/mcp.json", "servers")
    expect_identical(vscode$type, "stdio")
    expect_identical(vscode$command, "Rscript")

    # Cursor and Posit Assistant take the common shape, with no `type`
    for (f in c(".cursor/mcp.json", ".posit/assistant/settings.json")) {
        entry <- read_key(f, "mcpServers")
        expect_null(entry$type)
        expect_identical(entry$command, "Rscript")
        expect_match(entry$args[[2]], "btw::btw_mcp_server", fixed = TRUE)
    }

    # Every agent must end up invoking the same server, whatever the wrapper
    calls <- vapply(names(.agent_configs), function(a) {
        spec <- .agent_configs[[a]]
        txt <- readLines(file.path(tmp_dir, spec$path), warn = FALSE)
        grep("btw_mcp_server", txt, value = TRUE)[1]
    }, character(1))
    expect_true(all(grepl("'docs', 'env', 'sessioninfo', 'ide', 'run'",
                          calls, fixed = TRUE)))
})

test_that("the groups reach btw_mcp_server() as tools, not a character vector", {
    # A bare vector of group names makes `btw_mcp_server()` fail at startup:
    # its `is.character(tools) && file.exists(tools)` guard is an error for
    # length > 1 under R >= 4.3, and the agent sees only a dead pipe. The
    # wrapper is what keeps `is.character()` FALSE, so it is load-bearing.
    call <- .btw_call(run_r = TRUE, pkg_dev = TRUE)
    expect_match(call, "btw::btw_mcp_server(btw::btw_tools(", fixed = TRUE)
    expect_false(grepl("btw_mcp_server(c(", call, fixed = TRUE))

    # The call must be valid R, with the groups inside the wrapper rather than
    # alongside it. The outer local() also contains the socket-directory
    # recovery prelude, so validate the group names independently instead of
    # evaluating the full expression (whose final call starts the server).
    parsed <- parse(text = call)[[1]]
    expect_length(parsed, 2L)
    expect_identical(as.character(parsed[[1]]), "local")
    groups <- .btw_groups(run_r = TRUE, pkg_dev = TRUE)
    for (group in groups) {
        expect_match(call, paste0("'", group, "'"), fixed = TRUE)
    }

    # ...and the group names must be ones this btw actually knows
    skip_if_not_installed("btw")
    expect_no_error(do.call(btw::btw_tools, as.list(groups)))
})

test_that("the MCP launcher preserves and recovers socket configuration", {
    call <- .btw_call(run_r = FALSE, pkg_dev = FALSE)

    # Never override a socket directory supplied deliberately by the user or
    # an XDG runtime directory inherited from the agent.
    expect_match(call, "!nzchar(Sys.getenv('MCPTOOLS_SOCKET_DIR'))",
                 fixed = TRUE)
    expect_match(call, "!nzchar(Sys.getenv('XDG_RUNTIME_DIR'))", fixed = TRUE)

    # If both are absent, derive the standard Linux path from the current
    # user's numeric uid. This stays portable across users instead of baking
    # the uid of the person who ran setup into a committed config file.
    expect_match(call, "file.info(path.expand('~'))$uid", fixed = TRUE)
    expect_match(call, "file.path('/run/user', uid)", fixed = TRUE)
    expect_match(call, "file.path(runtime, 'mcptools')", fixed = TRUE)
    expect_no_error(parse(text = call))
})

test_that("the Codex TOML block is merged and refreshed in place", {
    tmp_dir <- tempfile("mizer_agent_codex")
    dir.create(tmp_dir)
    on.exit(unlink(tmp_dir, recursive = TRUE))
    dir.create(file.path(tmp_dir, ".codex"))
    codex_dest <- file.path(tmp_dir, ".codex", "config.toml")

    # Config the user wrote themselves, including their own MCP server
    user_config <- c('model = "gpt-5"', '',
                     '[mcp_servers.other]', 'command = "other-server"')
    writeLines(user_config, codex_dest)

    suppressMessages(setup_mizer_agent(path = tmp_dir, agents = "codex"))
    content <- readLines(codex_dest)
    # Their config survives, and ours goes below it: a TOML table header claims
    # every key beneath it, so our block must come last
    expect_identical(content[seq_along(user_config)], user_config)
    expect_true(any(grepl('[mcp_servers."r-mizer"]', content, fixed = TRUE)))
    expect_identical(tail(content, 1), .codex_end)

    # Re-running leaves the file byte-identical rather than appending again
    before <- content
    suppressMessages(setup_mizer_agent(path = tmp_dir, agents = "codex"))
    expect_identical(readLines(codex_dest), before)

    # A changed option refreshes the block in place without duplicating it
    suppressMessages(setup_mizer_agent(path = tmp_dir, agents = "codex",
                                       run_r = FALSE))
    content <- readLines(codex_dest)
    expect_equal(sum(content == .codex_begin), 1)
    expect_identical(content[seq_along(user_config)], user_config)
    expect_false(any(grepl("BTW_RUN_R_ENABLED", content, fixed = TRUE)))
})

test_that("pkg_dev = TRUE exposes the package development tools", {
    tmp_dir <- tempfile("mizer_agent_pkgdev")
    dir.create(tmp_dir)
    on.exit(unlink(tmp_dir, recursive = TRUE))
    mcp_dest <- file.path(tmp_dir, ".mcp.json")

    suppressMessages(setup_mizer_agent(path = tmp_dir, pkg_dev = TRUE))
    entry <- jsonlite::fromJSON(mcp_dest,
                                simplifyVector = FALSE)$mcpServers[["r-mizer"]]
    expect_true(grepl("'pkg'", entry$args[[2]], fixed = TRUE))

    # ... and tells the agent to prefer them over shelling out to devtools
    mizer_content <- readLines(file.path(tmp_dir, "MIZER-AGENTS.md"))
    expect_true(any(grepl("btw_tool_pkg_load_all", mizer_content, fixed = TRUE)))

    # Turning it back off removes both again
    suppressMessages(setup_mizer_agent(path = tmp_dir))
    entry <- jsonlite::fromJSON(mcp_dest,
                                simplifyVector = FALSE)$mcpServers[["r-mizer"]]
    expect_false(grepl("'pkg'", entry$args[[2]], fixed = TRUE))
    mizer_content <- readLines(file.path(tmp_dir, "MIZER-AGENTS.md"))
    expect_false(any(grepl("btw_tool_pkg_load_all", mizer_content, fixed = TRUE)))
})

test_that("other MCP servers survive and an up-to-date file is not rewritten", {
    tmp_dir <- tempfile("mizer_agent_mcp_merge")
    dir.create(tmp_dir)
    on.exit(unlink(tmp_dir, recursive = TRUE))
    mcp_dest <- file.path(tmp_dir, ".mcp.json")

    # A server the user configured themselves, plus a stale entry of ours
    writeLines(jsonlite::toJSON(list(mcpServers = list(
        mine = list(type = "stdio", command = "my-server"),
        "r-mizer" = list(type = "stdio", command = "old")
    )), auto_unbox = TRUE, pretty = TRUE), mcp_dest)

    suppressMessages(setup_mizer_agent(path = tmp_dir))
    cfg <- jsonlite::fromJSON(mcp_dest, simplifyVector = FALSE)
    expect_identical(cfg$mcpServers$mine$command, "my-server")
    expect_identical(cfg$mcpServers[["r-mizer"]]$command, "Rscript")

    # Re-running changes nothing, so the file is left byte-identical
    before <- readLines(mcp_dest)
    suppressMessages(setup_mizer_agent(path = tmp_dir))
    expect_identical(readLines(mcp_dest), before)

    # An unparseable file is left alone rather than clobbered
    writeLines("{ not json", mcp_dest)
    expect_warning(suppressMessages(setup_mizer_agent(path = tmp_dir)),
                   "Could not parse")
    expect_identical(readLines(mcp_dest), "{ not json")
})

test_that("rprofile = TRUE adds the session hook exactly once", {
    tmp_dir <- tempfile("mizer_agent_rprofile")
    dir.create(tmp_dir)
    on.exit(unlink(tmp_dir, recursive = TRUE))
    rprofile_dest <- file.path(tmp_dir, ".Rprofile")

    # Not written unless asked for
    suppressMessages(setup_mizer_agent(path = tmp_dir))
    expect_false(file.exists(rprofile_dest))

    # An existing .Rprofile is appended to, not replaced
    writeLines("options(stringsAsFactors = FALSE)", rprofile_dest)
    suppressMessages(setup_mizer_agent(path = tmp_dir, rprofile = TRUE))
    content <- readLines(rprofile_dest)
    expect_identical(content[1], "options(stringsAsFactors = FALSE)")
    expect_equal(sum(grepl("btw_mcp_session", content)), 1)

    # Re-running does not add it a second time
    suppressMessages(setup_mizer_agent(path = tmp_dir, rprofile = TRUE))
    expect_equal(sum(grepl("btw_mcp_session", readLines(rprofile_dest))), 1)
})

test_that("the API index is taken from the installed mizer when it ships one", {
    # llms.txt describes one version of the mizer API, so it is maintained and
    # installed in mizer for the same reason the skills are: the index an agent
    # greps should list the functions the project's own mizer actually has.
    fake <- tempfile(fileext = ".txt")
    writeLines("# Mizer", fake)
    on.exit(unlink(fake))

    local_mocked_bindings(
        system.file = function(..., package = "base") {
            if (identical(package, "mizer")) fake else ""
        },
        .package = "base"
    )
    expect_identical(.llms_source(), fake)
})

test_that("the bundled API index is used against a mizer that predates the move", {
    # mizer only began installing llms.txt in 3.2.2. Against an older one the
    # copy shipped here is still a usable index, so unlike the skills there is
    # no degraded mode to report: a source is always found.
    # Captured before the mock is installed: inside it, `base::system.file`
    # resolves to the mock itself and would recurse. Unqualified, so that under
    # `load_all()` this is devtools' shim, which finds `inst/` in the source
    # tree - the same function `.llms_source()` is calling.
    real_system_file <- system.file
    bundled <- real_system_file("llms.txt", package = "mizerAgents")

    local_mocked_bindings(
        system.file = function(..., package = "base") {
            if (identical(package, "mizer")) "" else real_system_file(..., package = package)
        },
        .package = "base"
    )
    src <- .llms_source()
    expect_identical(src, bundled)
    expect_true(nzchar(src) && file.exists(src))
})

test_that("article-only blocks are stripped from an installed SKILL.md", {
    skill <- c(
        "# A skill",
        "",
        "Body the agent needs.",
        "",
        "<!-- article-only -->",
        "",
        "## Worked example",
        "",
        "```{r label}",
        "plot(1)",
        "```",
        "",
        "<!-- /article-only -->",
        "",
        "The end."
    )
    expect_identical(.strip_article_only(skill),
                     c("# A skill", "", "Body the agent needs.", "",
                       "", "The end."))

    # Two blocks, and one that runs to the end of the file
    expect_identical(
        .strip_article_only(c("a", "<!-- article-only -->", "x",
                              "<!-- /article-only -->", "b",
                              "<!-- article-only -->", "y")),
        c("a", "b"))

    # A skill from a mizer that does not use them is returned untouched, and an
    # `agent-only` block - which is mizer's to drop, not ours - is left alone.
    plain <- c("# A skill", "", "<!-- agent-only -->", "Symptom table.",
               "<!-- /agent-only -->")
    expect_identical(.strip_article_only(plain), plain)
})

test_that("no installed skill carries article-only material", {
    tmp_dir <- tempfile("mizer_agent_article_only")
    dir.create(tmp_dir)
    on.exit(unlink(tmp_dir, recursive = TRUE))

    src <- .skills_source()
    skip_if(!nzchar(src), "the installed mizer ships no skills")
    marked <- Filter(function(f) {
        any(grepl("^\\s*<!--\\s*article-only\\s*-->\\s*$",
                  readLines(f, warn = FALSE)))
    }, list.files(src, pattern = "^SKILL\\.md$", recursive = TRUE,
                  full.names = TRUE))
    skip_if(length(marked) == 0,
            "the installed mizer ships no article-only blocks")

    suppressMessages(setup_mizer_agent(path = tmp_dir))
    installed <- list.files(file.path(tmp_dir, ".claude", "skills"),
                            pattern = "^SKILL\\.md$", recursive = TRUE,
                            full.names = TRUE)
    expect_gt(length(installed), 0)
    for (f in installed) {
        lines <- readLines(f, warn = FALSE)
        expect_false(any(grepl("article-only", lines)), label = f)
    }
    # Not asserted: that no evaluated ```{r} chunk survives. A skill may define
    # one in its own body, so that a demonstration inside an article-only block
    # has something to run without the definition being duplicated into it.
})
