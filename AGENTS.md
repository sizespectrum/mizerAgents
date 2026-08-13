# AI Agent Instructions for mizerAgents

`mizerAgents` is an R package that provides AI-agent support tooling for the
mizer size-spectrum modelling package.

## Package purpose

This package has one primary exported function: `setup_mizer_agent()`. It
copies agent context files (a mizer reference card + API docs) from the
package's `inst/` directory into a user's mizer project directory.

## Common commands

```r
devtools::load_all()      # Load package for development
devtools::document()      # Regenerate NAMESPACE and man/ from roxygen2
devtools::test()          # Run all tests
devtools::check()         # Full R CMD check
```

## Architecture

- `R/setup_mizer_agent.R` — the sole exported function
- `R/r_session.R` — per-agent MCP config writers and the `.Rprofile` hook, for
  the `btw` MCP server that connects the agent to the user's live R session.
  `.agent_configs` is the table of paths and schema quirks (which top-level
  key, whether a `type` field is documented); add new agents there, and extend
  the shape test in `tests/testthat/test-setup_mizer_agent.R` — a config with
  the wrong key parses fine and silently does nothing.
- `inst/MIZER-AGENTS.md` — the routing card deployed to user projects as
  `MIZER-AGENTS.md`. Keep it a routing card: it is loaded on every request, and
  anything it explains well enough to act on is something an agent will act on
  instead of opening the skill that owns it. Mizer facts belong in a mizer skill
  (`inst/skills/` in mizer), not here. Its `<!-- mizerAgents:<name> -->` lines
  are where `setup_mizer_agent()` substitutes the generated sections, so the
  card controls their order; a new section needs a placeholder added here.
- `inst/llms.txt` — curated mizer API index, grouped by workflow stage
  (deployed path written into `MIZER-AGENTS.md`). Names and descriptions only:
  argument lists are intentionally not bundled, because they go stale silently.

## Code conventions

- **Indentation**: 4 spaces
- **Naming**: camelCase or snake_case for functions; PascalCase for classes
- **Language**: British English (en-GB)

## Before submitting

- Run `devtools::document()` after editing roxygen2 comments.
- Update `NEWS.md` when adding features or fixing bugs.
