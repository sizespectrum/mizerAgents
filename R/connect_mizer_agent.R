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
#' @param path Project directory whose MCP configuration to report on. Defaults
#'   to the current working directory. It does not affect what is connected:
#'   the session is handed over whatever this says.
#'
#' @return Invisibly, the result of `btw::btw_mcp_session()`.
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
    if (!interactive()) {
        warning("This is not an interactive session, so it will end - taking ",
                "the connection with it - as soon as this script does. Run ",
                "connect_mizer_agent() in the console you are working in.",
                call. = FALSE)
    }
    .connect_preflight(path)
    invisible(btw::btw_mcp_session())
}
