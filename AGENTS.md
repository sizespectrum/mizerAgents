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
- `inst/AGENTS.md` — mizer reference card (deployed to user projects)
- `inst/llms.txt` — concise mizer API index (deployed path appended to `MIZER-AGENTS.md`)
- `inst/llms-full.txt` — full mizer API docs (deployed path appended to `MIZER-AGENTS.md`)

## Code conventions

- **Indentation**: 4 spaces
- **Naming**: camelCase or snake_case for functions; PascalCase for classes
- **Language**: British English (en-GB)

## Before submitting

- Run `devtools::document()` after editing roxygen2 comments.
- Update `NEWS.md` when adding features or fixing bugs.
