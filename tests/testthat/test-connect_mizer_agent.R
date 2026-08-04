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

test_that(".session_slot() reports no slot for an unconnected session", {
    # The testing session has not called `btw::btw_mcp_session()`, and must not
    expect_null(.session_slot())
})

test_that("connect_mizer_agent does not connect an already connected session", {
    skip_if_not_installed("btw")
    tmp_dir <- tempfile("mizer_agent_connect_twice")
    dir.create(tmp_dir)
    on.exit(unlink(tmp_dir, recursive = TRUE))
    suppressMessages(setup_mizer_agent(path = tmp_dir))

    # Stand in for a session that has already been handed over, so that the
    # guard can be exercised without handing over the testing session
    local_mocked_bindings(.session_slot = function() 3L)
    msgs <- capture_messages(res <- connect_mizer_agent(tmp_dir))
    expect_null(res)
    expect_true(any(grepl("already connected", msgs, fixed = TRUE)))
    # The pre-flight belongs to a connection that is being made, not to one
    # that already exists
    expect_false(any(grepl("Handing this session", msgs, fixed = TRUE)))
})
