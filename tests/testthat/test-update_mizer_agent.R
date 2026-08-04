test_that("update_mizer_agent replays the settings the project was set up with", {
    tmp_dir <- tempfile("mizer_agent_update")
    dir.create(tmp_dir)
    on.exit(unlink(tmp_dir, recursive = TRUE))

    suppressMessages(setup_mizer_agent(
        path = tmp_dir, run_r = FALSE, pkg_dev = TRUE, rprofile = TRUE,
        agents = c("claude", "codex")))
    before <- list.files(tmp_dir, recursive = TRUE, all.files = TRUE,
                         no.. = TRUE)

    suppressMessages(update_mizer_agent(path = tmp_dir))

    # Nothing about the setup changed: the same files, and the same options
    # recorded in them
    expect_identical(list.files(tmp_dir, recursive = TRUE, all.files = TRUE,
                                no.. = TRUE), before)
    detected <- .detect_options(tmp_dir)
    expect_false(detected$run_r)
    expect_true(detected$pkg_dev)
    expect_true(detected$rprofile)
    expect_identical(detected$agents, c("claude", "codex"))

    # ... whereas a plain re-run of setup re-declares them from its defaults,
    # which is the whole reason this function exists
    suppressMessages(setup_mizer_agent(path = tmp_dir))
    detected <- .detect_options(tmp_dir)
    expect_true(detected$run_r)
    expect_false(detected$pkg_dev)
    expect_true(all(names(.agent_configs) %in% detected$agents))
})

test_that("update_mizer_agent detects a project set up without a session", {
    tmp_dir <- tempfile("mizer_agent_update_nosession")
    dir.create(tmp_dir)
    on.exit(unlink(tmp_dir, recursive = TRUE))

    suppressMessages(setup_mizer_agent(path = tmp_dir, r_session = FALSE))
    expect_false(.detect_options(tmp_dir)$r_session)

    suppressMessages(update_mizer_agent(path = tmp_dir))
    expect_false(file.exists(file.path(tmp_dir, ".mcp.json")))
    expect_false(.detect_options(tmp_dir)$r_session)
})

test_that("update_mizer_agent takes overrides through ...", {
    tmp_dir <- tempfile("mizer_agent_update_override")
    dir.create(tmp_dir)
    on.exit(unlink(tmp_dir, recursive = TRUE))

    suppressMessages(setup_mizer_agent(path = tmp_dir, run_r = FALSE,
                                       agents = "claude"))
    suppressMessages(update_mizer_agent(path = tmp_dir, run_r = TRUE))

    detected <- .detect_options(tmp_dir)
    expect_true(detected$run_r)
    # What was not overridden is still what the project had
    expect_identical(detected$agents, "claude")
})

test_that("update_mizer_agent refuses a project that was never set up", {
    tmp_dir <- tempfile("mizer_agent_update_fresh")
    dir.create(tmp_dir)
    on.exit(unlink(tmp_dir, recursive = TRUE))

    expect_error(update_mizer_agent(path = tmp_dir), "nothing to update")
    expect_error(update_mizer_agent(tempfile("no_such_dir")), "does not exist")

    # A project set up without any MCP config is still recognised as set up
    suppressMessages(setup_mizer_agent(path = tmp_dir, r_session = FALSE))
    expect_true(.detect_options(tmp_dir)$found)
})

test_that("setup_mizer_agent reports the settings a re-run changes", {
    tmp_dir <- tempfile("mizer_agent_report")
    dir.create(tmp_dir)
    on.exit(unlink(tmp_dir, recursive = TRUE))

    # A first run has nothing to compare against, so it says nothing
    msgs <- capture_messages(setup_mizer_agent(path = tmp_dir, run_r = FALSE,
                                               agents = "claude"))
    expect_false(any(grepl("Settings changed", msgs)))

    # A plain re-run switches code execution back on, adds the other agents,
    # and now says so
    msgs <- capture_messages(setup_mizer_agent(path = tmp_dir))
    expect_true(any(grepl("Settings changed", msgs)))
    expect_true(any(grepl("Code execution in your session: off -> on", msgs,
                          fixed = TRUE)))
    expect_true(any(grepl("Now also configured for", msgs, fixed = TRUE)))

    # And an update, which changes no setting, does not
    msgs <- capture_messages(update_mizer_agent(path = tmp_dir))
    expect_false(any(grepl("Settings changed", msgs)))
})
