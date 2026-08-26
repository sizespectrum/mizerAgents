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

    # The report is wrapped to the width of its bullet, so match it against the
    # message with the line breaks and indents squeezed out
    flat <- function(msgs) gsub("\\s+", " ", paste(msgs, collapse = " "))

    # A first run has nothing to compare against, so it says nothing
    msgs <- capture_messages(setup_mizer_agent(path = tmp_dir, run_r = FALSE,
                                               agents = "claude"))
    expect_false(grepl("Changed from how this project was set up", flat(msgs)))

    # A plain re-run switches code execution back on, adds the other agents,
    # and now says so
    msgs <- flat(capture_messages(setup_mizer_agent(path = tmp_dir)))
    expect_true(grepl("Changed from how this project was set up", msgs))
    expect_true(grepl("code execution in your session off -> on", msgs,
                      fixed = TRUE))
    expect_true(grepl("now also configured for", msgs, fixed = TRUE))

    # And an update, which changes no setting, does not
    msgs <- capture_messages(update_mizer_agent(path = tmp_dir, check_version = FALSE))
    expect_false(grepl("Changed from how this project was set up", flat(msgs)))
})

test_that(".check_mizeragents_version reports when a newer version is available", {
    tmp_desc <- tempfile("DESCRIPTION_test")
    writeLines(c("Package: mizerAgents", "Version: 99.0.0"), tmp_desc)
    on.exit(unlink(tmp_desc))

    msgs <- capture_messages(
        .check_mizeragents_version(url = tmp_desc, local_version = "0.4.1")
    )
    expect_true(any(grepl("A newer version of mizerAgents is available", msgs)))
    expect_true(any(grepl("99.0.0 > 0.4.1", msgs, fixed = TRUE)))
    expect_true(any(grepl("pak::pak", msgs, fixed = TRUE)))

    # When local is up to date or newer, it says nothing
    msgs_ok <- capture_messages(
        .check_mizeragents_version(url = tmp_desc, local_version = "99.0.0")
    )
    expect_length(msgs_ok, 0)

    msgs_ahead <- capture_messages(
        .check_mizeragents_version(url = tmp_desc, local_version = "100.0.0")
    )
    expect_length(msgs_ahead, 0)
})

test_that(".check_mizeragents_version degrades gracefully on error or missing version", {
    # Non-existent or invalid URL
    expect_null(.check_mizeragents_version(url = "http://invalid.domain.example/DESCRIPTION"))

    # Malformed file without Version header
    tmp_empty <- tempfile("DESCRIPTION_empty")
    writeLines("Package: mizerAgents", tmp_empty)
    on.exit(unlink(tmp_empty), add = TRUE)
    expect_null(.check_mizeragents_version(url = tmp_empty))
})

test_that("the version check is made once by setup and once by an update", {
    tmp_dir <- tempfile("mizer_agent_test")
    dir.create(tmp_dir)
    on.exit(unlink(tmp_dir, recursive = TRUE))

    calls <- 0L
    local_mocked_bindings(
        .check_mizeragents_version = function(...) calls <<- calls + 1L
    )

    suppressMessages(setup_mizer_agent(path = tmp_dir))
    expect_identical(calls, 1L)

    suppressMessages(setup_mizer_agent(path = tmp_dir, check_version = FALSE))
    expect_identical(calls, 1L)

    # `update_mizer_agent()` leaves the check to the `setup_mizer_agent()` it
    # calls, so a refresh reaches GitHub once, not twice
    suppressMessages(update_mizer_agent(path = tmp_dir))
    expect_identical(calls, 2L)

    suppressMessages(update_mizer_agent(path = tmp_dir, check_version = FALSE))
    expect_identical(calls, 2L)
})
