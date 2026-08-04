# Undo what `setup_mizer_agent()` did

Removes the mizer agent support that
[`setup_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/setup_mizer_agent.md)
installed in a project: the `MIZER-AGENTS.md` reference card, the mizer
block in the instruction files, the bundled skills in `.claude/skills/`,
the `r-mizer` MCP server in each agent's config, and the
[`btw::btw_mcp_session()`](https://posit-dev.github.io/btw/reference/mcp.html)
call in the project `.Rprofile`. Use it when you no longer want the
agent support in a project, or to get back to a clean slate before
setting it up differently.

## Usage

``` r
remove_mizer_agent(path = ".")
```

## Arguments

- path:

  Directory to clean up. Defaults to the current working directory,
  which should be your R project root.

## Value

Invisibly, a character vector of the paths that were removed or changed.

## Details

Only what this package wrote is removed, following the same boundary
[`setup_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/setup_mizer_agent.md)
respects when writing:

- `MIZER-AGENTS.md` is deleted. It is package-managed and rewritten on
  every setup, so there is nothing of yours in it.

- In `AGENTS.md`, `CLAUDE.md` and `GEMINI.md` only the block between the
  `<!-- mizerAgents: start -->` and `<!-- mizerAgents: end -->` markers
  is deleted; your own notes stay. A file that held nothing but the
  block is deleted with it. An `@AGENTS.md` import is never removed,
  just as it is never written: which of your instruction files import
  which is your business.

- Under `.claude/skills/`, a file is removed only if it still matches
  the hash recorded in `.claude/skills/.mizerAgents.json` when it was
  installed. One that has been edited here is kept and reported, as is
  any `NOTES.md`, which this package never writes. Directories left
  empty are removed. (In a project set up by version 0.3.2 or earlier
  there is no record, so files are identified by comparing them with
  what the installed mizer's skills would have produced; anything that
  does not match is kept.)

- In each agent's MCP config only the `r-mizer` entry is removed; other
  servers you configured there stay, and the file is deleted only if
  that entry was all it held. A config file that cannot be parsed is
  left alone with a warning rather than risking your other servers.

- In `.Rprofile` only the guarded
  [`btw::btw_mcp_session()`](https://posit-dev.github.io/btw/reference/mcp.html)
  call and its comment are removed.

The `btw` package is not touched: it is an ordinary R package you
installed, and other projects may be using it. Uninstall it yourself
with `remove.packages("btw")` if you want it gone.

## See also

[`setup_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/setup_mizer_agent.md),
which this undoes, and
[`update_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/update_mizer_agent.md)
if you only want to refresh the files.

## Examples

``` r
if (FALSE) { # \dontrun{
# Remove the mizer agent support from the current project
remove_mizer_agent()
} # }
```
