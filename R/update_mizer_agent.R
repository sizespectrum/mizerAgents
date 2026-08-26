# Refreshing an existing setup without re-declaring how it was set up.
#
# `setup_mizer_agent()` is declarative: what you do not ask for, you do not get,
# and its defaults are the defaults for a *new* project. That is the right
# behaviour for setting a project up and the wrong one for refreshing it - the
# skills now come from the installed mizer, so "upgrade mizer, re-run setup" is
# the expected way to get new guidance, and a bare re-run would quietly switch
# code execution back on in a project that had turned it off, drop the package
# tools from a mizer extension, and write config files for agents the user had
# deliberately narrowed away from.
#
# So the options are read back off disk and replayed. Nothing needs to be
# remembered for this: every choice is visible in what the last run wrote, which
# also means it works for a project set up by an earlier version, and stays true
# if the user has since edited a config by hand.

# The `Rscript -e` argument our MCP entry carries in one agent's config, or `NA`
# if that agent has no entry of ours to read. The btw tool groups are in there,
# which is where `run_r` and `pkg_dev` are recoverable from. Internal helper.
.detected_call <- function(dest, agent) {
    if (!file.exists(dest)) return(NA_character_)
    if (identical(agent, "codex")) {
        lines <- readLines(dest, warn = FALSE)
        b <- which(lines == .codex_begin)
        e <- which(lines == .codex_end)
        if (!(length(b) && length(e) && e[1] > b[1])) return(NA_character_)
        arg <- grep("^args = ", lines[b[1]:e[1]], value = TRUE)
        return(if (length(arg)) arg[1] else "")
    }
    cfg <- tryCatch(jsonlite::fromJSON(dest, simplifyVector = FALSE),
                    error = function(e) NULL)
    if (is.null(cfg)) return(NA_character_)
    entry <- cfg[[.agent_configs[[agent]]$key]][[.mcp_server_name]]
    if (is.null(entry)) return(NA_character_)
    paste(unlist(entry$args), collapse = " ")
}

# What the last `setup_mizer_agent()` in this project asked for, read back from
# what it wrote. `found` says whether there is any sign of a previous run at
# all; when it is `FALSE` the rest are the defaults for a new project and mean
# nothing. Internal helper.
.detect_options <- function(path) {
    calls <- vapply(names(.agent_configs), function(a) {
        .detected_call(normalizePath(file.path(path, .agent_configs[[a]]$path),
                                     mustWork = FALSE), a)
    }, character(1))
    configured <- names(calls)[!is.na(calls)]

    # Any one entry answers `run_r` and `pkg_dev`, since one run writes them
    # all alike; the first is as good as any if a hand edit has made them
    # disagree.
    call <- if (length(configured)) calls[[configured[1]]] else NA_character_
    rprofile_dest <- normalizePath(file.path(path, ".Rprofile"),
                                   mustWork = FALSE)

    # A project may have been set up with `r_session = FALSE`, which writes no
    # config at all, so the presence of the files setup always writes is what
    # tells us it was set up.
    instruction_block <- any(vapply(.instruction_files, function(f) {
        dest <- file.path(path, f)
        file.exists(dest) &&
            !is.null(.shim_range(readLines(dest, warn = FALSE)))
    }, logical(1)))
    found <- length(configured) > 0 || instruction_block ||
        file.exists(file.path(path, "MIZER-AGENTS.md")) ||
        file.exists(file.path(path, ".claude", "skills", .skill_manifest))

    list(
        found     = found,
        r_session = length(configured) > 0,
        run_r     = if (is.na(call)) TRUE else grepl("'run'", call, fixed = TRUE),
        pkg_dev   = if (is.na(call)) FALSE else grepl("'pkg'", call, fixed = TRUE),
        agents    = if (length(configured)) configured else .agent_choices,
        rprofile  = file.exists(rprofile_dest) &&
            .rprofile_line %in% readLines(rprofile_dest, warn = FALSE)
    )
}

# Report the settings a run of `setup_mizer_agent()` is about to change relative
# to what the project already had, so that a re-run meant as a refresh does not
# silently re-declare them. Says nothing on a first run, or when nothing
# changes. Returns bullets to add to the summary. Internal helper.
.setting_changes <- function(before, r_session, run_r, pkg_dev, agents) {
    if (!isTRUE(before$found)) return(character(0))
    changes <- character(0)
    onoff <- function(x) if (isTRUE(x)) "on" else "off"

    if (!identical(isTRUE(before$r_session), isTRUE(r_session))) {
        changes <- c(changes, paste0(
            "live R session ", onoff(before$r_session), " -> ",
            onoff(r_session)))
    }
    if (isTRUE(r_session) && isTRUE(before$r_session)) {
        if (!identical(isTRUE(before$run_r), isTRUE(run_r))) {
            changes <- c(changes, paste0(
                "code execution in your session ", onoff(before$run_r),
                " -> ", onoff(run_r)))
        }
        if (!identical(isTRUE(before$pkg_dev), isTRUE(pkg_dev))) {
            changes <- c(changes, paste0(
                "package development tools ", onoff(before$pkg_dev),
                " -> ", onoff(pkg_dev)))
        }
    }
    if (isTRUE(r_session)) {
        label <- function(a) vapply(.agent_configs[a], `[[`, character(1),
                                    "label")
        added <- setdiff(intersect(agents, names(.agent_configs)),
                         before$agents)
        dropped <- setdiff(intersect(before$agents, names(.agent_configs)),
                           agents)
        if (length(added)) {
            changes <- c(changes, paste0("now also configured for ",
                                         paste(label(added), collapse = ", ")))
        }
        if (length(dropped)) {
            changes <- c(changes, paste0(
                "not requested this time but left in place: ",
                paste(label(dropped), collapse = ", "),
                " (remove_mizer_agent() takes those out again)"))
        }
    }
    if (!length(changes)) return(character(0))
    # Wrapped here rather than left to the terminal, so that the continuation
    # lines line up under the bullet.
    paste0(paste(strwrap(paste0(
        "Changed from how this project was set up: ",
        paste(changes, collapse = "; "), "."), width = 74), collapse = "\n  "),
        "\n  update_mizer_agent() refreshes the files while keeping a ",
        "project's settings")
}

# Check GitHub for a newer version of mizerAgents without blocking or failing on
# network errors. Internal helper.
.check_mizeragents_version <- function(
    timeout_sec = 2,
    url = "https://raw.githubusercontent.com/sizespectrum/mizerAgents/main/DESCRIPTION",
    package = "mizerAgents",
    local_version = NULL) {
    tryCatch({
        old_opt <- options(timeout = timeout_sec)
        on.exit(options(old_opt), add = TRUE)

        lines <- suppressWarnings(readLines(url, warn = FALSE))
        ver_line <- grep("^Version:\\s*", lines, value = TRUE)
        if (!length(ver_line)) return(invisible(NULL))

        remote_ver_str <- trimws(sub("^Version:\\s*", "", ver_line[1]))
        remote_ver <- package_version(remote_ver_str)
        local_ver <- if (is.null(local_version)) {
            utils::packageVersion(package)
        } else {
            package_version(local_version)
        }

        if (remote_ver > local_ver) {
            message(
                "\nA newer version of mizerAgents is available (", remote_ver,
                " > ", local_ver, ").\n",
                "  To update, run: pak::pak(\"sizespectrum/mizerAgents\")"
            )
        }
        invisible(remote_ver)
    }, error = function(e) invisible(NULL))
}

#' Refresh a project's mizer agent files, keeping its settings
#'
#' Re-runs [setup_mizer_agent()] with the options this project was set up with,
#' rather than with the defaults for a new one. Use it to pick up a new version
#' of the skills or of the reference card - after upgrading mizer, say, since
#' the skills come from the installed mizer - without having to remember how the
#' project was configured.
#'
#' The files themselves are refreshed exactly as `setup_mizer_agent()` refreshes
#' them, because that is what does the work: the reference card is rewritten,
#' the marked block in each instruction file is updated in place with your own
#' notes left alone, and the skills are refreshed file by file, keeping and
#' reporting any that have been edited here. What this function adds is that
#' your *settings* survive.
#'
#' `setup_mizer_agent()` is declarative: its arguments describe the setup you
#' want, and its defaults are the ones for a fresh project. Re-running it plainly
#' therefore re-declares them - switching code execution back on in a project
#' that had turned it off with `run_r = FALSE`, dropping the package tools from
#' one set up with `pkg_dev = TRUE`, and writing config files for agents you had
#' narrowed away from with `agents`. This function reads those choices back from
#' what the last run wrote and replays them, so a refresh changes only content.
#' (`setup_mizer_agent()` now reports any setting it changes, so a plain re-run
#' at least says what it did.)
#'
#' Nothing is stored to make this work: `r_session`, `run_r`, `pkg_dev` and
#' `agents` are read from the MCP configs, and `rprofile` from the project
#' `.Rprofile`, which means it works for projects set up by earlier versions of
#' this package too. The one choice that leaves no trace is `agents = "copilot"`,
#' which only prints a snippet; pass it through `...` if you want it again. Pass
#' any argument of `setup_mizer_agent()` through `...` to override what was
#' detected.
#'
#' @param path Directory to refresh. Defaults to the current working directory,
#'   which should be your R project root.
#' @param check_version Logical; whether to check if a newer version of
#'   `mizerAgents` is available on GitHub. Defaults to `TRUE`. Passed on to
#'   [setup_mizer_agent()], which makes the check.
#' @param ... Arguments passed on to [setup_mizer_agent()], overriding the
#'   detected settings. `path = "."`, for instance, is refreshed with
#'   `update_mizer_agent(run_r = FALSE)` if you want to turn code execution off
#'   while refreshing.
#'
#' @return Invisibly, the path to the `AGENTS.md` file, as
#'   [setup_mizer_agent()] returns.
#' @export
#'
#' @seealso [setup_mizer_agent()] to set a project up, and
#'   [remove_mizer_agent()] to undo it.
#'
#' @examples
#' \dontrun{
#' # After upgrading mizer, refresh the skills without changing the setup
#' update_mizer_agent()
#' }
update_mizer_agent <- function(path = ".", check_version = TRUE, ...) {
    if (!dir.exists(path)) {
        stop("`path` does not exist: ", path, call. = FALSE)
    }
    detected <- .detect_options(path)
    if (!isTRUE(detected$found)) {
        stop("No mizer agent files found in ",
             normalizePath(path, mustWork = FALSE),
             ".\n  There is nothing to update; run setup_mizer_agent() to set ",
             "the project up first.", call. = FALSE)
    }

    detected_opts <- list(
        path = path, overwrite = FALSE,
        r_session = detected$r_session, run_r = detected$run_r,
        pkg_dev = detected$pkg_dev, rprofile = detected$rprofile,
        agents = detected$agents, check_version = check_version)
    opts <- list(...)
    opts <- c(opts, detected_opts[setdiff(names(detected_opts), names(opts))])

    # The settings themselves are not listed here: the summary that
    # `setup_mizer_agent()` prints at the end says what they are.
    message("Refreshing with the settings this project already has.")

    # `setup_mizer_agent()` does the version check itself, at the end.
    result <- do.call(setup_mizer_agent, opts)

    invisible(result)
}
