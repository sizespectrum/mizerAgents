# mizerAgents 0.1.0

## New features

* `setup_mizer_agent()` creates or updates agent context files
  (`MIZER-AGENTS.md`, `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`) in a mizer
  project directory so that AI coding agents pick up the mizer reference card
  and API documentation automatically on startup.

* `setup_mizer_agent()` also installs bundled Claude Code skills into
  `.claude/skills/` — `analyse-and-plot`, `build-multispecies-model`,
  `calibrate-model`, `run-simulation`, `set-up-fishing`, `change-parameters`,
  and `extend-mizer` — giving task-triggered, step-by-step guidance for common
  mizer workflows. The skills are refreshed on every call.

* Bundled `inst/skills/` — one sub-directory with a `SKILL.md` per skill,
  deployed by `setup_mizer_agent()`.

* Bundled `inst/AGENTS.md` — concise mizer reference card covering the core
  workflow, key objects, species parameters, plotting, and extending mizer.

* Bundled `inst/llms.txt` — concise index of the full mizer API, with links
  to online reference pages.

* Bundled `inst/llms-full.txt` — full prose documentation for every exported
  mizer function, intended for agent `grep` searches.
