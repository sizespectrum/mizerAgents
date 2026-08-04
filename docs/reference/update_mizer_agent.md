# Refresh a project's mizer agent files, keeping its settings

Re-runs
[`setup_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/setup_mizer_agent.md)
with the options this project was set up with, rather than with the
defaults for a new one. Use it to pick up a new version of the skills or
of the reference card - after upgrading mizer, say, since the skills
come from the installed mizer - without having to remember how the
project was configured.

## Usage

``` r
update_mizer_agent(path = ".", ...)
```

## Arguments

- path:

  Directory to refresh. Defaults to the current working directory, which
  should be your R project root.

- ...:

  Arguments passed on to
  [`setup_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/setup_mizer_agent.md),
  overriding the detected settings. `path = "."`, for instance, is
  refreshed with `update_mizer_agent(run_r = FALSE)` if you want to turn
  code execution off while refreshing.

## Value

Invisibly, the path to the `AGENTS.md` file, as
[`setup_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/setup_mizer_agent.md)
returns.

## Details

The files themselves are refreshed exactly as
[`setup_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/setup_mizer_agent.md)
refreshes them, because that is what does the work: the reference card
is rewritten, the marked block in each instruction file is updated in
place with your own notes left alone, and the skills are refreshed file
by file, keeping and reporting any that have been edited here. What this
function adds is that your *settings* survive.

[`setup_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/setup_mizer_agent.md)
is declarative: its arguments describe the setup you want, and its
defaults are the ones for a fresh project. Re-running it plainly
therefore re-declares them - switching code execution back on in a
project that had turned it off with `run_r = FALSE`, dropping the
package tools from one set up with `pkg_dev = TRUE`, and writing config
files for agents you had narrowed away from with `agents`. This function
reads those choices back from what the last run wrote and replays them,
so a refresh changes only content.
([`setup_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/setup_mizer_agent.md)
now reports any setting it changes, so a plain re-run at least says what
it did.)

Nothing is stored to make this work: `r_session`, `run_r`, `pkg_dev` and
`agents` are read from the MCP configs, and `rprofile` from the project
`.Rprofile`, which means it works for projects set up by earlier
versions of this package too. The one choice that leaves no trace is
`agents = "copilot"`, which only prints a snippet; pass it again
yourself if you want it. Pass any argument of
[`setup_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/setup_mizer_agent.md)
through `...` to override what was detected.

## See also

[`setup_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/setup_mizer_agent.md)
to set a project up, and
[`remove_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/remove_mizer_agent.md)
to undo it.

## Examples

``` r
if (FALSE) { # \dontrun{
# After upgrading mizer, refresh the skills without changing the setup
update_mizer_agent()
} # }
```
