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
