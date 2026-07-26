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

    # MIZER-AGENTS.md should contain mizer documentation
    mizer_content <- readLines(mizer_dest)
    expect_true(any(grepl("Mizer", mizer_content)))
    expect_true(any(grepl("Full API documentation", mizer_content)))

    # AGENTS.md should contain the marked block: a note plus the `@` import
    agents_content <- readLines(agents_dest)
    expect_true("@MIZER-AGENTS.md" %in% agents_content)
    expect_true(any(grepl("Read `MIZER-AGENTS.md`", agents_content, fixed = TRUE)))
    expect_true(any(grepl("mizerAgents: start", agents_content, fixed = TRUE)))
    expect_true(any(grepl("mizerAgents: end", agents_content, fixed = TRUE)))

    # CLAUDE.md should point to @AGENTS.md
    claude_content <- readLines(claude_dest)
    expect_identical(claude_content[1], "@AGENTS.md")

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
        "<!-- mizerAgents: start — managed by setup_mizer_agent(), edits are overwritten -->",
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

test_that("unmarked shims from earlier versions are migrated", {
    tmp_dir <- tempfile("mizer_agent_legacy")
    dir.create(tmp_dir)
    on.exit(unlink(tmp_dir, recursive = TRUE))
    agents_dest <- file.path(tmp_dir, "AGENTS.md")

    # Pre-0.3.3 form: a bare import line above the user's own notes
    writeLines(c("@MIZER-AGENTS.md", "", "# My Model"), agents_dest)
    suppressMessages(setup_mizer_agent(path = tmp_dir))
    content <- readLines(agents_dest)

    expect_equal(sum(content == "@MIZER-AGENTS.md"), 1)
    expect_true(any(grepl("mizerAgents: start", content, fixed = TRUE)))
    expect_identical(tail(content, 1), "# My Model")

    # 0.3.2.9000 form: an unmarked note above the import, absorbed into the
    # block rather than left behind as a duplicate
    writeLines(c(
        "This project uses [mizer](https://sizespectrum.org/mizer/) for size-spectrum",
        "modelling. Read `MIZER-AGENTS.md` before writing or changing mizer code — it is",
        "imported below if your tool resolves `@` imports. It is generated by",
        "`mizerAgents::setup_mizer_agent()`; don't edit it by hand.",
        "",
        "@MIZER-AGENTS.md",
        "",
        "# My Model"
    ), agents_dest)
    suppressMessages(setup_mizer_agent(path = tmp_dir))
    content <- readLines(agents_dest)

    expect_identical(content[1],
                     grep("mizerAgents: start", content, value = TRUE)[1])
    expect_equal(sum(grepl("This project uses", content, fixed = TRUE)), 1)
    expect_identical(tail(content, 1), "# My Model")

    # A note the user has reworded is theirs, so it is left in place
    writeLines(c("My own wording about mizer.", "@MIZER-AGENTS.md"), agents_dest)
    suppressMessages(setup_mizer_agent(path = tmp_dir))
    content <- readLines(agents_dest)
    expect_identical(content[1], "My own wording about mizer.")
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
    # Execution is on by default, and needs btw's own opt-in to work
    expect_true(grepl("'run'", entry$args[[2]], fixed = TRUE))
    expect_identical(entry$env$BTW_RUN_R_ENABLED, "true")
    # Package development tools are not
    expect_false(grepl("'pkg'", entry$args[[2]], fixed = TRUE))

    # The live-session section reaches the always-loaded card
    mizer_content <- readLines(file.path(tmp_dir, "MIZER-AGENTS.md"))
    expect_true(any(grepl("live R session", mizer_content, ignore.case = TRUE)))

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
