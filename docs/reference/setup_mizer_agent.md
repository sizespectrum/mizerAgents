# Set up an AI agent to help with your mizer project

Creates (or updates) a `MIZER-AGENTS.md` file in your project directory
containing a concise mizer reference that AI coding agents read
automatically on startup. The file includes the core mizer workflow, key
object descriptions, and the path to the full mizer API documentation
bundled with the package.

## Usage

``` r
setup_mizer_agent(path = ".", overwrite = FALSE)
```

## Arguments

- path:

  Directory in which to create or update the agent files. Defaults to
  the current working directory, which should be your R project root.

- overwrite:

  If `TRUE`, replace an existing `AGENTS.md` entirely with a clean shim.
  If `FALSE` (the default), preserve any custom content in `AGENTS.md`
  while prepending the `@MIZER-AGENTS.md` shim if not already present.
  `MIZER-AGENTS.md` is always overwritten to ensure it stays up-to-date.

## Value

Invisibly returns the path to the `AGENTS.md` file.

## Details

It also creates (or updates) an `AGENTS.md` file with a
`@MIZER-AGENTS.md` shim so that agents read both the project-specific
instructions and the mizer reference. It also creates `CLAUDE.md` and
`GEMINI.md` shim files (each containing just `@AGENTS.md`) so that
agent-specific tools that look for their own named file also pick up the
shared context. These shims are only created if the files do not already
exist.

After running this function, start your AI coding agent (e.g. `claude`,
`codex`, `copilot` or `gemini`) from the RStudio Terminal and it will
immediately have the mizer context it needs.

## Examples

``` r
if (FALSE) { # \dontrun{
# Run once in your mizer project to set up AI agent support
setup_mizer_agent()
} # }
```
