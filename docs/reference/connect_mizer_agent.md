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
[`btw::btw_mcp_session()`](https://posit-dev.github.io/btw/reference/mcp.html).

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
