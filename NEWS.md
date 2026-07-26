# mizerAgents 0.3.2

## New features

* The reference card (`inst/AGENTS.md`) opens with a "Do not write mizer code
  from memory" section: mizer's API has moved on, most mizer code in the
  training data predates the installed version, and outdated calls often still
  run and return plausible numbers. It names the parameters recollection is
  most often stale on (the `w_inf` / `w_repro_max` / `w_max` distinction, the
  `species_params(params) <-` setter, the `setBevertonHolt()` arguments) and
  tells agents to treat the installed mizer as authoritative over the card, and
  to report any discrepancy rather than work around it.

* The `AGENTS.md` shim written by `setup_mizer_agent()` is no longer a bare
  `@MIZER-AGENTS.md` line: it now carries a short note telling agents what the
  file is and to read it before touching mizer code. Codex and Copilot do not
  resolve `@` imports, so for them the note is what gets the card read; the
  import is kept for Claude Code and Gemini CLI, which inline it at startup
  whether or not the agent thinks it needs it.

* That block is now delimited by `<!-- mizerAgents: start -->` and
  `<!-- mizerAgents: end -->` comments and refreshed in place on every
  `setup_mizer_agent()` run, so later improvements to it reach projects that
  are already set up — previously it was written once and then frozen. It is
  refreshed wherever in the file it sits, and everything outside the markers is
  left alone, so your own project notes are preserved. Shims written by earlier
  versions have no markers and are migrated automatically; a note you have
  reworded yourself is treated as yours and left in place. The file is not
  touched at all when nothing would change, so re-running setup no longer
  dirties it.

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
