# Connect your R session to the agent

Hands the R session you are working in to the `r-mizer` MCP server that
[`setup_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/setup_mizer_agent.md)
configured, so that your AI coding agent can read the help pages of the
mizer you actually have installed, see the objects in your global
environment and the document open in your IDE, and - unless the project
was set up with `run_r = FALSE` - run mizer code here and see the plots
that come back.

## Usage

``` r
connect_mizer_agent(path = ".")
```

## Arguments

- path:

  Project directory whose MCP configuration to report on. Defaults to
  the current working directory. It does not affect what is connected:
  the session is handed over whatever this says.

## Value

Invisibly, the result of
[`btw::btw_mcp_session()`](https://posit-dev.github.io/btw/reference/mcp.html),
or `NULL` if this session was already connected and nothing was done.

## Details

Run it in your RStudio (or Positron) console at the start of a session,
then start your agent. Until you do, the server has no session to work
in and the agent's `btw_tool_*` tools will be missing or will run
against an empty R process of their own. The connection lasts as long as
the R session does, so it is needed once per session;
`setup_mizer_agent(rprofile = TRUE)` puts the call in the project
`.Rprofile` so that it happens on startup instead.

The work is done by
[`btw::btw_mcp_session()`](https://posit-dev.github.io/btw/reference/mcp.html)
from the [btw](https://posit-dev.github.io/btw/) package, which provides
the server and which you install yourself. This function is a
convenience wrapper: it checks that btw is available, and, because btw
has no knowledge of your project, it also reports which agents are
configured to reach this session and what they are allowed to do in it,
warning you if the answer is none - handing over a session that nothing
is set up to reach otherwise fails silently.

Call it once per session. A second call in the same session does not
refresh the connection but breaks it, so this function checks and
refuses; see "Connecting twice" below.

## Which session the agent connects to

Connected sessions are not private to a project: they are registered per
user, in a single machine-wide list, and every MCP server your agents
start can see all of them. Each server runs in the directory the agent
was started in, and picks a session on its *first tool call*, in this
order:

1.  The session it is already connected to, if there is one. That choice
    is then fixed for as long as the agent runs.

2.  The one connected session whose working directory is the server's
    own. This is what makes several projects, each with its own session
    and its own agent, sort themselves out.

3.  Failing that, the only connected session there is, whatever
    directory it is in - so an agent started in a project with no
    session of its own will reach for one belonging to another project.

4.  Failing that, no session at all: the agent's `btw_tool_*` calls run
    in the server's own throwaway R process, with an empty global
    environment. This is not reported as an error, and is the usual
    explanation for an agent that cannot see objects you can see.

Two sessions in the same directory are ambiguous under rule 2 and, being
two, cannot be resolved by rule 3 either, so neither is picked. Every
agent can list the sessions and choose between them (`list_r_sessions`
and `select_r_session`); ask yours to do so when the automatic choice is
wrong. To check which session an agent is working in, have it evaluate
[`Sys.getpid()`](https://rdrr.io/r/base/Sys.getpid.html) and compare
that with [`Sys.getpid()`](https://rdrr.io/r/base/Sys.getpid.html) in
your console.

## Connecting twice

[`btw::btw_mcp_session()`](https://posit-dev.github.io/btw/reference/mcp.html)
is not idempotent. A second call in the same session opens a second
connection without releasing the first, and the session then stops
responding: it disappears from the agent's `list_r_sessions`, while the
connection it abandoned still counts as a live session and so spoils
rule 3 above for every other agent on the machine. Only restarting R
clears it.

This function therefore reports the connection this session already has
and does nothing else. The case worth knowing about is
`setup_mizer_agent(rprofile = TRUE)`, which connects each session as it
starts: there is then nothing left for you to call.

## See also

[`setup_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/setup_mizer_agent.md),
which configures the server this connects to.

## Examples

``` r
if (FALSE) { # \dontrun{
# In the RStudio console, once per session
connect_mizer_agent()
} # }
```
