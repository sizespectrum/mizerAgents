# mizerAgents 0.3.2

## New features

* `setup_mizer_agent()` now adds a "Task skills" index to `MIZER-AGENTS.md`,
  generated from the bundled skills' own frontmatter (name, one-line
  description, and path). This makes the skills usable by agents other than
  Claude Code, which do not discover `.claude/skills/` natively: they read the
  index from the always-loaded reference card and open the relevant `SKILL.md`
  on demand, mirroring Claude Code's lazy loading. No skill content is
  duplicated, so the index cannot drift from the skills.

## Updated for mizer 3.2

* The reference card (`inst/AGENTS.md`) and the `change-parameters` skill now
  recommend `species_params(params) <-` as the setter for scripts. As of mizer
  3.2 it records the change in `given_species_params` and triggers recalculation
  of dependent rates, so the old advice to avoid it (and use only
  `given_species_params(params) <-`) no longer applies; `given_species_params()`
  is now framed as the interactive alternative that warns about overrides. A
  version note points users on mizer < 3.2 back to the old rule.

* Species-parameter documentation now distinguishes `w_max` (the purely
  computational size-grid boundary) from `w_repro_max` (mizer 3.2's name for the
  asymptotic size, i.e. the old `w_inf`).

* Replaced the stale `matchYields()` reference with `calibrateYield()`.

## Skills

* Captured lessons from dynamics/limit-cycle work: `inst/AGENTS.md` gains
  "Numerical scheme for dynamics" and "Gotchas" sections; `run-simulation` gains
  a "Numerical scheme: watch for numerical diffusion" section (upwind scheme
  silently damping real oscillations, the `second_order_w` / `tr_bdf2` fix, and
  freezing the resource to isolate the phantom-jam feedback); `change-parameters`
  gains "The feeding level is set by `f0`, not `h`".

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
