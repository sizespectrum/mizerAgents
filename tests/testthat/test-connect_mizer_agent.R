# The pre-flight checks are tested on their own: calling
# `connect_mizer_agent()` itself would hand the testing session to an MCP
# server, which is not something a test suite should do.

test_that("the connect pre-flight reports which agents can reach the session", {
    tmp_dir <- tempfile("mizer_agent_connect")
    dir.create(tmp_dir)
    on.exit(unlink(tmp_dir, recursive = TRUE))

    suppressMessages(setup_mizer_agent(path = tmp_dir,
                                       agents = c("claude", "posit")))
    msgs <- capture_messages(.connect_preflight(tmp_dir))
    expect_true(any(grepl("Claude Code", msgs, fixed = TRUE)))
    expect_true(any(grepl("Posit Assistant", msgs, fixed = TRUE)))
    expect_false(any(grepl("Cursor", msgs, fixed = TRUE)))
    # Code execution is on by default, and the user is told so
    expect_true(any(grepl("overwrite your objects", msgs, fixed = TRUE)))
})

test_that("the connect pre-flight reports a read-only connection as such", {
    tmp_dir <- tempfile("mizer_agent_connect_ro")
    dir.create(tmp_dir)
    on.exit(unlink(tmp_dir, recursive = TRUE))

    suppressMessages(setup_mizer_agent(path = tmp_dir, run_r = FALSE))
    msgs <- capture_messages(.connect_preflight(tmp_dir))
    expect_true(any(grepl("Read-only", msgs, fixed = TRUE)))
    expect_false(any(grepl("overwrite your objects", msgs, fixed = TRUE)))
})

test_that("the connect pre-flight warns when no agent is configured", {
    tmp_dir <- tempfile("mizer_agent_connect_none")
    dir.create(tmp_dir)
    on.exit(unlink(tmp_dir, recursive = TRUE))

    # Never set up at all
    expect_warning(.connect_preflight(tmp_dir), "no `r-mizer` MCP configuration")

    # Set up, but deliberately without a session: worth saying so, since the
    # fix is different
    suppressMessages(setup_mizer_agent(path = tmp_dir, r_session = FALSE))
    expect_warning(.connect_preflight(tmp_dir), "r_session = FALSE")
})

test_that("connect_mizer_agent rejects a path that does not exist", {
    expect_error(connect_mizer_agent(tempfile("no_such_dir")),
                 "does not exist")
})
