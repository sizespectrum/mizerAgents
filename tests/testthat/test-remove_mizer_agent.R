test_that("remove_mizer_agent undoes a plain setup completely", {
    tmp_dir <- tempfile("mizer_agent_remove")
    dir.create(tmp_dir)
    on.exit(unlink(tmp_dir, recursive = TRUE))

    suppressMessages(setup_mizer_agent(path = tmp_dir, rprofile = TRUE))
    expect_true(length(list.files(tmp_dir, all.files = TRUE, no.. = TRUE)) > 0)

    expect_message(remove_mizer_agent(path = tmp_dir),
                   "Removed") |> suppressMessages()

    # A project that had nothing of its own is left with nothing of ours,
    # including the directories the config files sat in
    expect_identical(
        list.files(tmp_dir, recursive = TRUE, all.files = TRUE, no.. = TRUE),
        character(0)
    )

    # And running it again on the clean directory is a no-op, not an error
    expect_message(remove_mizer_agent(path = tmp_dir), "Nothing to remove")
})

test_that("remove_mizer_agent keeps what belongs to the user", {
    tmp_dir <- tempfile("mizer_agent_remove_user")
    dir.create(tmp_dir)
    on.exit(unlink(tmp_dir, recursive = TRUE))

    # Notes of the user's own, and an MCP server they configured themselves
    user_notes <- c("# My project", "", "Some details worth keeping")
    writeLines(user_notes, file.path(tmp_dir, "AGENTS.md"))
    writeLines(jsonlite::toJSON(list(mcpServers = list(
        mine = list(type = "stdio", command = "my-server")
    )), auto_unbox = TRUE, pretty = TRUE), file.path(tmp_dir, ".mcp.json"))
    writeLines("options(stringsAsFactors = FALSE)",
               file.path(tmp_dir, ".Rprofile"))
    user_codex <- c('model = "gpt-5"', '', '[mcp_servers.other]',
                    'command = "other-server"')
    dir.create(file.path(tmp_dir, ".codex"))
    writeLines(user_codex, file.path(tmp_dir, ".codex", "config.toml"))

    suppressMessages(setup_mizer_agent(path = tmp_dir, rprofile = TRUE))

    # A skill edited here, and a NOTES.md we never wrote
    skill_dirs <- sort(list.dirs(file.path(tmp_dir, ".claude", "skills"),
                                 recursive = FALSE))
    skip_if(length(skill_dirs) < 2, "installed mizer ships no skills")
    edited <- file.path(skill_dirs[1], "SKILL.md")
    cat("\nA note added by hand.\n", file = edited, append = TRUE)
    notes <- file.path(skill_dirs[2], "NOTES.md")
    writeLines("What this project learned", notes)

    suppressMessages(remove_mizer_agent(path = tmp_dir))

    # The user's own content survives, ours does not
    expect_identical(readLines(file.path(tmp_dir, "AGENTS.md")), user_notes)
    expect_false(file.exists(file.path(tmp_dir, "MIZER-AGENTS.md")))
    expect_false(file.exists(file.path(tmp_dir, "CLAUDE.md")))
    expect_false(file.exists(file.path(tmp_dir, "GEMINI.md")))

    cfg <- jsonlite::fromJSON(file.path(tmp_dir, ".mcp.json"),
                              simplifyVector = FALSE)
    expect_identical(cfg$mcpServers$mine$command, "my-server")
    expect_null(cfg$mcpServers[["r-mizer"]])

    expect_identical(readLines(file.path(tmp_dir, ".codex", "config.toml")),
                     user_codex)

    expect_identical(readLines(file.path(tmp_dir, ".Rprofile")),
                     "options(stringsAsFactors = FALSE)")

    # An edited skill and a NOTES.md are not ours to delete
    expect_true(file.exists(edited))
    expect_true(file.exists(notes))
    # ... but the manifest and the untouched skills are gone
    expect_false(file.exists(file.path(tmp_dir, ".claude", "skills",
                                       ".mizerAgents.json")))
    expect_false(file.exists(file.path(skill_dirs[2], "SKILL.md")))
    expect_true(length(list.dirs(file.path(tmp_dir, ".claude", "skills"),
                                 recursive = FALSE)) == 2)
})

test_that("remove_mizer_agent handles a project set up before the manifest", {
    tmp_dir <- tempfile("mizer_agent_remove_legacy")
    dir.create(tmp_dir)
    on.exit(unlink(tmp_dir, recursive = TRUE))

    suppressMessages(setup_mizer_agent(path = tmp_dir, r_session = FALSE))
    manifest <- file.path(tmp_dir, ".claude", "skills", ".mizerAgents.json")
    skip_if_not(file.exists(manifest), "installed mizer ships no skills")

    # 0.3.2 and earlier kept no record of what they installed; the files are
    # then identified by comparing them with what the bundle would have written
    unlink(manifest)
    suppressMessages(remove_mizer_agent(path = tmp_dir))
    expect_false(dir.exists(file.path(tmp_dir, ".claude")))
})

test_that("remove_mizer_agent removes the pre-marker bare import", {
    tmp_dir <- tempfile("mizer_agent_remove_bare")
    dir.create(tmp_dir)
    on.exit(unlink(tmp_dir, recursive = TRUE))

    # The form written by versions before the markers existed
    writeLines(c("@MIZER-AGENTS.md", "", "# My project"),
               file.path(tmp_dir, "AGENTS.md"))
    suppressMessages(remove_mizer_agent(path = tmp_dir))
    expect_identical(readLines(file.path(tmp_dir, "AGENTS.md")), "# My project")
})

test_that("remove_mizer_agent takes the @AGENTS.md shim but not the user's", {
    tmp_dir <- tempfile("mizer_agent_remove_import")
    dir.create(tmp_dir)
    on.exit(unlink(tmp_dir, recursive = TRUE))

    # The whole of CLAUDE.md is the import setup writes into a file it creates
    # itself, so it goes; the same import among the user's own notes stays,
    # since wiring GEMINI.md to AGENTS.md was their decision, not ours
    writeLines("@AGENTS.md", file.path(tmp_dir, "CLAUDE.md"))
    user_gemini <- c("# House rules", "", "@AGENTS.md")
    writeLines(user_gemini, file.path(tmp_dir, "GEMINI.md"))
    writeLines("# My project", file.path(tmp_dir, "AGENTS.md"))

    suppressMessages(remove_mizer_agent(path = tmp_dir))

    expect_false(file.exists(file.path(tmp_dir, "CLAUDE.md")))
    expect_identical(readLines(file.path(tmp_dir, "GEMINI.md")), user_gemini)
    expect_identical(readLines(file.path(tmp_dir, "AGENTS.md")), "# My project")
})

test_that("remove_mizer_agent leaves an unparseable config alone", {
    tmp_dir <- tempfile("mizer_agent_remove_bad_json")
    dir.create(tmp_dir)
    on.exit(unlink(tmp_dir, recursive = TRUE))

    writeLines("{ not json", file.path(tmp_dir, ".mcp.json"))
    expect_warning(suppressMessages(remove_mizer_agent(path = tmp_dir)),
                   "Could not parse")
    expect_identical(readLines(file.path(tmp_dir, ".mcp.json")), "{ not json")
})

test_that("remove_mizer_agent rejects a path that does not exist", {
    expect_error(remove_mizer_agent(tempfile("no_such_dir")),
                 "does not exist")
})
