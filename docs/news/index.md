# Changelog

## mizerAgents (development version)

### New features

- [`setup_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/setup_mizer_agent.md)
  creates or updates agent context files (`MIZER-AGENTS.md`,
  `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`) in a mizer project directory so
  that AI coding agents pick up the mizer reference card and API
  documentation automatically on startup.

- Bundled `inst/AGENTS.md` — concise mizer reference card covering the
  core workflow, key objects, species parameters, plotting, and
  extending mizer.

- Bundled `inst/llms.txt` — concise index of the full mizer API, with
  links to online reference pages.

- Bundled `inst/llms-full.txt` — full prose documentation for every
  exported mizer function, intended for agent `grep` searches.
