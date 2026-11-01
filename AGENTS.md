# AI Agent Instructions for mizerAgents

`mizerAgents` is an R package that provides AI-agent support tooling for the
mizer size-spectrum modelling package.

## Package purpose

`setup_mizer_agent()` prepares a user's mizer project for AI agents: it writes
the reference card `MIZER-AGENTS.md` (from `inst/`), a marked block in the
instruction files, the task skills and the MCP configs for the live R session.
The skills and the API index come from the *installed mizer*, not from this
package. The other exports work on what setup wrote: `update_mizer_agent()`
re-runs it with the project's detected settings, `remove_mizer_agent()` undoes
it, and `connect_mizer_agent()` hands the user's R session to the MCP server
and says when the project is out of date.

## Common commands

```r
devtools::load_all()      # Load package for development
devtools::document()      # Regenerate NAMESPACE and man/ from roxygen2
devtools::test()          # Run all tests
devtools::check()         # Full R CMD check
```

## Architecture

- `R/setup_mizer_agent.R` — setup, and the helpers that decide what it writes.
  The skills are installed as copies in every directory in `.skill_dirs`
  (`.claude/skills/` for Claude Code, `.agents/skills/` for Codex and Gemini
  CLI); add a new location there. Copies, never links: on Windows a link is a
  junction, which fails on network drives and breaks under OneDrive and git.
  Each skill's footer names its `NOTES.md` under the *first* directory, so all
  copies share one set of notes. The card does not list the skills, since every
  agent lists them itself; do not add an index back.
- `R/update_mizer_agent.R`, `R/remove_mizer_agent.R`,
  `R/connect_mizer_agent.R` — the other exports. `.project_is_stale()` decides
  whether a project needs refreshing by comparing it with `.build_card()` and
  `.skill_content()`, so anything setup writes must be produced by a helper
  the check can call too; otherwise projects go stale without anyone being
  told. `remove_mizer_agent()` must remove whatever setup adds.
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
  are where `.build_card()` substitutes the generated sections, so the card
  controls their order; a new section needs a placeholder added here and a
  line in `.build_card()`.

## Code conventions

- **Indentation**: 4 spaces
- **Naming**: camelCase or snake_case for functions; PascalCase for classes
- **Language**: British English (en-GB)

## Before submitting

- Run `devtools::document()` after editing roxygen2 comments.
- Update `NEWS.md` when adding features or fixing bugs.
