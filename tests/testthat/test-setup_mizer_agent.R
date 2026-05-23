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

    # AGENTS.md should contain just the shim pointing to MIZER-AGENTS.md
    agents_content <- readLines(agents_dest)
    expect_identical(agents_content[1], "@MIZER-AGENTS.md")

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
    expect_identical(agents_content[1], "@MIZER-AGENTS.md")
    expect_identical(agents_content[2], "# My Custom Notes")

    # Run setup again: since shim is present, it shouldn't prepend it again
    # and shouldn't output any "Prepended" message.
    # Note: MIZER-AGENTS.md gets overwritten each time.
    expect_message(
        setup_mizer_agent(path = tmp_dir, overwrite = FALSE),
        "Created"
    ) |> suppressMessages()
    agents_content <- readLines(agents_dest)
    expect_identical(agents_content[1], "@MIZER-AGENTS.md")
    expect_identical(agents_content[2], "# My Custom Notes")
    expect_equal(length(agents_content), 4)

    # 3. Existing AGENTS.md with custom content and overwrite = TRUE
    # Run setup with overwrite = TRUE
    suppressMessages(setup_mizer_agent(path = tmp_dir, overwrite = TRUE))
    agents_content <- readLines(agents_dest)
    expect_identical(agents_content[1], "@MIZER-AGENTS.md")
    expect_equal(length(agents_content), 1)
})
