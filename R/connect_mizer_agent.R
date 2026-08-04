# Handing the user's R session to the MCP server.
#
# The work is `btw::btw_mcp_session()`; this is a wrapper around it. Two things
# justify the wrapper rather than telling people to call btw directly. The first
# is that this is the one step of the whole setup you repeat every session, and
# it was the only one with no entry in this package's reference index - the user
# had to know the name of a second package to finish a job they started here.
#
# The second is that btw does not know about the project. It registers the
# session with whatever MCP server comes asking, which is the right scope for
# btw and leaves the question this package can answer unanswered: whether any
# agent in *this* project is configured to come asking at all. Handing over a
# session that nothing is set up to reach otherwise fails silently.

# Whether this session already holds a slot on the mcptools socket, and which
# one. `mcptools::mcp_session()` (which `btw::btw_mcp_session()` calls) is not
# idempotent and does not check: a second call opens a *second* socket on the
# next free slot without releasing the first, and reschedules the session's
# message handling onto it. The session then answers one probe and goes silent -
# it drops out of the agent's `list_r_sessions` while its orphaned slot still
# counts as a live session, which also defeats the "connect to the only running
# session" fallback for every other server on the machine. Only restarting R
# clears it. So the number is worth reading before connecting again.
#
# It lives in mcptools' internal state, with no accessor, so this reaches into
# the namespace and treats any surprise as "not connected": guessing wrong that
# way costs a duplicate session only if btw's internals have changed, whereas
# guessing wrong the other way would refuse to connect a session that is not.
# Internal helper.
.session_slot <- function() {
    if (!requireNamespace("mcptools", quietly = TRUE)) return(NULL)
    slot <- tryCatch(get("the", envir = asNamespace("mcptools"))$session,
                     error = function(e) NULL)
    if (length(slot) != 1 || !is.numeric(slot)) return(NULL)
    as.integer(slot)
}

# The pre-flight checks, kept apart from the btw call so that they can be
# tested without starting anything. Reports which agents can reach the session
# and what they will be allowed to do in it, and warns when the answer is none.
# Internal helper.
.connect_preflight <- function(path) {
    detected <- .detect_options(path)
    if (!isTRUE(detected$r_session)) {
        warning(
            "This project has no `", .mcp_server_name, "` MCP configuration, ",
            "so no agent is set up to reach the session you are handing over.",
            "\n  Run setup_mizer_agent() to configure one",
            if (isTRUE(detected$found)) {
                " (this project was set up with r_session = FALSE)"
            } else "",
            ", then restart your agent.",
            call. = FALSE
        )
        return(invisible(detected))
    }
    message(
        "Handing this session to the ", .mcp_server_name, " MCP server.",
        "\n  Agents configured to reach it: ",
        paste(vapply(.agent_configs[intersect(detected$agents,
                                              names(.agent_configs))],
                     `[[`, character(1), "label"), collapse = ", "),
        if (isTRUE(detected$run_r)) {
            paste0("\n  They may run R code here, in your global environment,",
                   "\n  which means they can overwrite your objects.")
        } else {
            paste0("\n  Read-only: documentation, your environment and the",
                   "\n  document open in the IDE, but no code execution.")
        },
        "\n  The connection lasts as long as this R session does."
    )
    invisible(detected)
}

#' Connect your R session to the agent
#'
#' Hands the R session you are working in to the `r-mizer` MCP server that
#' [setup_mizer_agent()] configured, so that your AI coding agent can read the
#' help pages of the mizer you actually have installed, see the objects in your
#' global environment and the document open in your IDE, and - unless the
#' project was set up with `run_r = FALSE` - run mizer code here and see the
#' plots that come back.
#'
#' Run it in your RStudio (or Positron) console at the start of a session, then
#' start your agent. Until you do, the server has no session to work in and the
#' agent's `btw_tool_*` tools will be missing or will run against an empty R
#' process of their own. The connection lasts as long as the R session does, so
#' it is needed once per session; `setup_mizer_agent(rprofile = TRUE)` puts the
#' call in the project `.Rprofile` so that it happens on startup instead.
#'
#' The work is done by `btw::btw_mcp_session()` from the
#' [btw](https://posit-dev.github.io/btw/) package, which provides the server
#' and which you install yourself. This function is a convenience wrapper: it
#' checks that btw is available, and, because btw has no knowledge of your
#' project, it also reports which agents are configured to reach this session
#' and what they are allowed to do in it, warning you if the answer is none -
#' handing over a session that nothing is set up to reach otherwise fails
#' silently.
#'
#' Call it once per session. A second call in the same session does not refresh
#' the connection but breaks it, so this function checks and refuses; see
#' "Connecting twice" below.
#'
#' @section Which session the agent connects to:
#'
#' Connected sessions are not private to a project: they are registered per
#' user, in a single machine-wide list, and every MCP server your agents start
#' can see all of them. Each server runs in the directory the agent was started
#' in, and picks a session on its *first tool call*, in this order:
#'
#' 1. The session it is already connected to, if there is one. That choice is
#'    then fixed for as long as the agent runs.
#' 2. The one connected session whose working directory is the server's own.
#'    This is what makes several projects, each with its own session and its own
#'    agent, sort themselves out.
#' 3. Failing that, the only connected session there is, whatever directory it
#'    is in - so an agent started in a project with no session of its own will
#'    reach for one belonging to another project.
#' 4. Failing that, no session at all: the agent's `btw_tool_*` calls run in the
#'    server's own throwaway R process, with an empty global environment. This
#'    is not reported as an error, and is the usual explanation for an agent
#'    that cannot see objects you can see.
#'
#' Two sessions in the same directory are ambiguous under rule 2 and, being two,
#' cannot be resolved by rule 3 either, so neither is picked. Every agent can
#' list the sessions and choose between them (`list_r_sessions` and
#' `select_r_session`); ask yours to do so when the automatic choice is wrong.
#' To check which session an agent is working in, have it evaluate
#' `Sys.getpid()` and compare that with `Sys.getpid()` in your console.
#'
#' @section Connecting twice:
#'
#' `btw::btw_mcp_session()` is not idempotent. A second call in the same session
#' opens a second connection without releasing the first, and the session then
#' stops responding: it disappears from the agent's `list_r_sessions`, while the
#' connection it abandoned still counts as a live session and so spoils rule 3
#' above for every other agent on the machine. Only restarting R clears it.
#'
#' This function therefore reports the connection this session already has and
#' does nothing else. The case worth knowing about is
#' `setup_mizer_agent(rprofile = TRUE)`, which connects each session as it
#' starts: there is then nothing left for you to call.
#'
#' @param path Project directory whose MCP configuration to report on. Defaults
#'   to the current working directory. It does not affect what is connected:
#'   the session is handed over whatever this says.
#'
#' @return Invisibly, the result of `btw::btw_mcp_session()`, or `NULL` if this
#'   session was already connected and nothing was done.
#' @export
#'
#' @seealso [setup_mizer_agent()], which configures the server this connects to.
#'
#' @examples
#' \dontrun{
#' # In the RStudio console, once per session
#' connect_mizer_agent()
#' }
connect_mizer_agent <- function(path = ".") {
    if (!dir.exists(path)) {
        stop("`path` does not exist: ", path, call. = FALSE)
    }
    if (!requireNamespace("btw", quietly = TRUE)) {
        # `requireNamespace()` also fails when btw is installed but cannot be
        # loaded, typically an out-of-date dependency, so do not claim it is
        # missing.
        stop("The btw package provides the MCP server, and is not available.",
             "\n  Install it with: install.packages(\"btw\")",
             "\n  (if it is already installed, `library(btw)` will show why ",
             "it fails)", call. = FALSE)
    }
    # Connecting twice breaks the session rather than refreshing it, so stop
    # here rather than passing the call on to btw. `.Rprofile` makes this easy
    # to hit: with `rprofile = TRUE` the session connected itself at startup.
    # Checked before anything else is said, since a session that is already
    # connected is not about to be handed over and none of it applies.
    slot <- .session_slot()
    if (!is.null(slot)) {
        message(
            "This session is already connected, as session ", slot, ".",
            "\n  Connecting again would break it rather than refresh it, so",
            "\n  nothing was done. If a session was connected at startup by",
            "\n  the project .Rprofile, you do not need to call this at all.",
            "\n  Agents see it as \"", slot, ": ", basename(getwd()),
            "\", and pick it by working",
            "\n  directory; ask yours to run `list_r_sessions` if it seems to",
            "\n  be working somewhere else."
        )
        return(invisible(NULL))
    }
    if (!interactive()) {
        warning("This is not an interactive session, so it will end - taking ",
                "the connection with it - as soon as this script does. Run ",
                "connect_mizer_agent() in the console you are working in.",
                call. = FALSE)
    }
    .connect_preflight(path)
    invisible(btw::btw_mcp_session())
}
