# Changelog

## mizerAgents 0.3.2.2

### New features

- **New
  [`connect_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/connect_mizer_agent.md)
  hands your R session to the agent.** This is the one step of the setup
  you repeat every session, and it was the only one with no entry in
  this package’s reference index: you had to know the name of a second
  package to finish a job you started here. It wraps
  [`btw::btw_mcp_session()`](https://posit-dev.github.io/btw/reference/mcp.html),
  which still does the work, and adds what btw cannot know because it
  knows nothing about your project — which agents are configured to
  reach the session you are handing over, and whether they may run code
  in it. If none are, it says so rather than connecting silently to
  nothing. btw stays in `Suggests`; you get an actionable error if it is
  not installed.

  The `.Rprofile` line written by `rprofile = TRUE` still calls
  [`btw::btw_mcp_session()`](https://posit-dev.github.io/btw/reference/mcp.html)
  directly, so that a project starts cleanly for someone who does not
  have mizerAgents installed.

- **New
  [`update_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/update_mizer_agent.md)
  refreshes a project while keeping the settings it was set up with.**
  Since the skills now come from the installed mizer, “upgrade mizer,
  then refresh” is the normal way to get new guidance — but
  [`setup_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/setup_mizer_agent.md)
  is declarative, so a bare re-run re-declares its arguments from the
  defaults for a *new* project: it would switch code execution back on
  in a project set up with `run_r = FALSE`, drop the package tools from
  one set up with `pkg_dev = TRUE`, and write config files for agents
  you had narrowed away from with `agents`.
  [`update_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/update_mizer_agent.md)
  reads those choices back from what the last run wrote and replays
  them, so a refresh changes content and nothing else. Nothing had to be
  stored to make that work, so it works for projects set up by earlier
  versions too. Pass any argument of
  [`setup_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/setup_mizer_agent.md)
  through `...` to override what was detected.

- [`setup_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/setup_mizer_agent.md)
  now **reports any setting it changes** relative to how the project was
  already set up, so that a plain re-run meant as a refresh at least
  says what it did rather than switching things over silently. A first
  run has nothing to compare against and says nothing.

- **New
  [`remove_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/remove_mizer_agent.md)
  undoes everything
  [`setup_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/setup_mizer_agent.md)
  did.** It deletes `MIZER-AGENTS.md`, the marked block in `AGENTS.md`,
  `CLAUDE.md` and `GEMINI.md`, the bundled skills in `.claude/skills/`,
  the `r-mizer` entry in each agent’s MCP config, and the
  [`btw::btw_mcp_session()`](https://posit-dev.github.io/btw/reference/mcp.html)
  call in the project `.Rprofile`, and cleans up the directories those
  left empty.

  It removes only what this package wrote, following the same boundary
  setup respects: your notes outside the markers stay, other MCP servers
  in those config files stay, and a file that held nothing but our block
  is deleted with it. A skill file that has been edited in the project
  is no longer ours to delete, so it is kept and reported, as is any
  `NOTES.md`. The `btw` package itself is left installed.

- **The skills now come from the installed mizer, not from this
  package.**
  [`setup_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/setup_mizer_agent.md)
  reads them from `system.file("skills", package = "mizer")`, so the
  guidance an agent follows always describes the version of mizer the
  project actually runs. Previously this package shipped its own copy,
  which had to be kept in step with mizer by hand — the reason for the
  separate `@dev` branch — and could describe functions the user’s mizer
  did not have.

  In mizer each `SKILL.md` is now also the source of the matching
  `cheatsheet-*` article on the mizer website, so the agent-facing and
  human-facing documentation are one document rather than two that drift
  apart.

  Skills arrived in mizer 3.2.2. Against an older mizer,
  [`setup_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/setup_mizer_agent.md)
  still writes everything else and reports that it installed no skills.

## mizerAgents 0.3.2

### New features

- **What a project learns about mizer now has somewhere to go.**
  Previously
  [`setup_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/setup_mizer_agent.md)
  deleted each bundled skill’s directory and copied a fresh one over it,
  so anything an agent had added there — the very thing it had just
  learned about your model — vanished on the next run, silently.

  Three changes, one per kind of finding:

  - Every deployed `SKILL.md` now ends by pointing at a `NOTES.md`
    beside it: read it too, treat it as taking precedence, and record
    what you learn about *this* project there rather than in `SKILL.md`.
    That file is never written by this package. The same pointer goes
    into the skills index in `MIZER-AGENTS.md`, for agents that do not
    discover `.claude/skills/` themselves.
  - Skills are refreshed **file by file**, so a `NOTES.md` — or a skill
    of your own — is left alone. The MD5 sums of the files installed are
    recorded in `.claude/skills/.mizerAgents.json`, which is what makes
    a file you have edited distinguishable from one an older version of
    the package installed. An edited file is kept and reported, with the
    new version written beside it as `<file>.new` to merge by hand;
    delete the `.new` file and the skill goes back under package
    management. Without the record, the choice would be between
    clobbering your edits and freezing the skills at whatever shipped
    first. A project set up by 0.3.2 or earlier has no record, so the
    first run after upgrading refreshes the skills as it always did, and
    starts keeping one. Skills that later versions stop shipping are now
    removed rather than lingering, unless they have been edited here.
  - A lesson that is true of mizer in general rather than of one project
    belongs upstream, where every project gets it in the next release,
    so the skills tell agents to say so and offer to report it at
    <https://github.com/sizespectrum/mizerAgents/issues>.

- `AGENTS.md`, `CLAUDE.md` and `GEMINI.md` are now all handled the same
  way: each gets the package-managed mizer block, refreshed in place on
  every run with your own notes around it left alone. Previously only
  `AGENTS.md` was managed, and `CLAUDE.md`/`GEMINI.md` were written as
  one-line `@AGENTS.md` shims only when they did not already exist — so
  a project that already had a `CLAUDE.md` got no mizer context in
  Claude Code at all. Neither tool falls back to `AGENTS.md`: Claude
  Code reads `CLAUDE.md`, and Gemini CLI reads `GEMINI.md` unless its
  `context.fileName` setting says otherwise.

  The block is the only thing added. No `@AGENTS.md` import is written
  or removed, so which of your own instructions reach which agent is
  unchanged: a `CLAUDE.md` that did not import `AGENTS.md` still does
  not, and one that did — including the one-line shims written by
  earlier versions — is left exactly as it was, since the block reaches
  the agent through the import.

- [`setup_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/setup_mizer_agent.md)
  now connects the agent to your live R session, by configuring an MCP
  server named `r-mizer`. The server comes from the
  [btw](https://posit-dev.github.io/btw/) package (CRAN, from Posit),
  which you install yourself; it is listed in `Suggests`. Its docs tools
  read the mizer that is actually installed, so the agent can check a
  signature rather than recall it, and it also gains a view of the
  objects in your global environment and of the document open in
  RStudio.

- The server is registered for **every agent that supports project-level
  MCP configuration**, each of which uses a different file: `.mcp.json`
  (Claude Code), `.codex/config.toml` (Codex), `.gemini/settings.json`
  (Gemini CLI), `.agents/mcp_config.json` (Antigravity),
  `.cursor/mcp.json` (Cursor), `.vscode/mcp.json` (VS Code and Copilot
  in the editor) and `.posit/assistant/settings.json` (Posit Assistant,
  which runs in RStudio as well as Positron). All seven are written by
  default — they are small, they sit in different places, and each agent
  ignores the others’ — so a project set up on your machine works for a
  collaborator using a different agent. The new `agents` argument
  narrows this, e.g. `agents = c("claude", "posit")`.

  The schemas are not interchangeable: VS Code nests servers under
  `servers` where everyone else uses `mcpServers`, and only Claude Code
  and VS Code document a `type` field, so it is omitted for the rest
  rather than guessed at. A config with the wrong top-level key parses
  cleanly and silently does nothing, so there is a test pinning the
  shape of each generated file.

  GitHub Copilot CLI is the exception: it reads MCP servers only from
  the user-wide `~/.copilot/mcp-config.json`, which a project setup
  function has no business editing, so the snippet to paste there is
  printed instead.

  Only the `r-mizer` entry of each file is package-managed, so other
  servers you have configured survive. The JSON files are parsed and
  merged; an unparseable one is left untouched with a warning rather
  than overwritten. Codex’s TOML is managed as a marked block instead,
  to avoid taking on a TOML parser, and that block is always written at
  the end of the file — a TOML table header claims every key below it,
  so anywhere else it would swallow config written after it.

- **`inst/llms-full.txt` has been removed** (173 KB of the package’s 227
  KB of bundled documentation). Its reference pages and articles were a
  snapshot of what [`?help`](https://rdrr.io/r/utils/help.html) and
  [`vignette()`](https://rdrr.io/r/utils/vignette.html) already return
  from the installed mizer, so they duplicated btw’s docs tools while
  being pinned to whatever mizer was current when this package was last
  built. That is the same failure the reference card warns about: an
  argument list that has moved on does not announce itself, it just
  produces a call that runs and returns plausible numbers.

  `inst/llms.txt` stays. It is a curated index — every exported function
  with a one-line description, grouped by workflow stage — which no tool
  can regenerate, and it carries no argument lists, so it ages
  gracefully: a renamed function shows up as a lookup that fails rather
  than a call that quietly does the wrong thing.

  `MIZER-AGENTS.md` now sets the two apart explicitly, under a “Finding
  the right mizer function” heading: grep the index for *which* function
  you need, then read the installed help page for *how to call it* — via
  `btw_tool_docs_help_page` when the R session is connected, and
  `Rscript -e 'help(...)'` when it is not.

- For the server to see your session you must run
  [`btw::btw_mcp_session()`](https://posit-dev.github.io/btw/reference/mcp.html)
  in the RStudio console. The new `rprofile = TRUE` argument appends a
  guarded call to the project `.Rprofile` so that this happens on every
  startup.

- The agent can evaluate R code in that session, which is what allows it
  to project or calibrate a model and then *see* the resulting plots as
  images — the mode in which it is most useful for calibration work. The
  code runs in your global environment with no sandboxing and can
  overwrite your objects, so keep your work under version control;
  `run_r = FALSE` gives a read-only connection instead, and
  `r_session = FALSE` skips the MCP setup altogether.

- New `pkg_dev = TRUE` argument for projects that are themselves R
  packages, such as mizer extensions. It adds btw’s package development
  tools, so the agent can run `load_all()`, `document()`, `test()`,
  `check()` and test coverage in your session rather than shelling out
  to `devtools`. Because `load_all()` then leaves the new code live in
  the same session, the agent can immediately exercise the rate function
  it has just written, closing the write–load–test loop by itself. Off
  by default, as these tools do nothing useful in an ordinary modelling
  project.

- `MIZER-AGENTS.md` gains a “The user’s live R session” section telling
  the agent to look mizer functions up in the installed help pages
  before calling them, to check what objects the user already has before
  rebuilding them, and — when execution is enabled — to look at the
  plots it produces before reporting success, and to avoid assigning
  over the user’s work.

- The reference card (`inst/AGENTS.md`) opens with a “Do not write mizer
  code from memory” section: mizer’s API has moved on, most mizer code
  in the training data predates the installed version, and outdated
  calls often still run and return plausible numbers. It names the
  parameters recollection is most often stale on (the `w_inf` /
  `w_repro_max` / `w_max` distinction, the `species_params(params) <-`
  setter, the `setBevertonHolt()` arguments) and tells agents to treat
  the installed mizer as authoritative over the card, and to report any
  discrepancy rather than work around it.

- The `AGENTS.md` shim written by
  [`setup_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/setup_mizer_agent.md)
  is no longer a bare `@MIZER-AGENTS.md` line: it now carries a short
  note telling agents what the file is and to read it before touching
  mizer code. Codex and Copilot do not resolve `@` imports, so for them
  the note is what gets the card read; the import is kept for Claude
  Code and Gemini CLI, which inline it at startup whether or not the
  agent thinks it needs it.

- That block is now delimited by `<!-- mizerAgents: start -->` and
  `<!-- mizerAgents: end -->` comments and refreshed in place on every
  [`setup_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/setup_mizer_agent.md)
  run, so later improvements to it reach projects that are already set
  up — previously it was written once and then frozen. It is refreshed
  wherever in the file it sits, and everything outside the markers is
  left alone, so your own project notes are preserved. Shims written by
  earlier versions have no markers and are migrated automatically; a
  note you have reworded yourself is treated as yours and left in place.
  The file is not touched at all when nothing would change, so
  re-running setup no longer dirties it.

- [`setup_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/setup_mizer_agent.md)
  now adds a “Task skills” index to `MIZER-AGENTS.md`, generated from
  the bundled skills’ own frontmatter (name, one-line description, and
  path). This makes the skills usable by agents other than Claude Code,
  which do not discover `.claude/skills/` natively: they read the index
  from the always-loaded reference card and open the relevant `SKILL.md`
  on demand, mirroring Claude Code’s lazy loading. No skill content is
  duplicated, so the index cannot drift from the skills.

### Updated for mizer 3.2

- The reference card (`inst/AGENTS.md`) and the `change-parameters`
  skill now recommend `species_params(params) <-` as the setter for
  scripts. As of mizer 3.2 it records the change in
  `given_species_params` and triggers recalculation of dependent rates,
  so the old advice to avoid it (and use only
  `given_species_params(params) <-`) no longer applies;
  `given_species_params()` is now framed as the interactive alternative
  that warns about overrides. A version note points users on mizer \<
  3.2 back to the old rule.

- Species-parameter documentation now distinguishes `w_max` (the purely
  computational size-grid boundary) from `w_repro_max` (mizer 3.2’s name
  for the asymptotic size, i.e. the old `w_inf`).

- Replaced the stale `matchYields()` reference with `calibrateYield()`.

### Skills

- Captured lessons from dynamics/limit-cycle work: `inst/AGENTS.md`
  gains “Numerical scheme for dynamics” and “Gotchas” sections;
  `run-simulation` gains a “Numerical scheme: watch for numerical
  diffusion” section (upwind scheme silently damping real oscillations,
  the `second_order_w` / `tr_bdf2` fix, and freezing the resource to
  isolate the phantom-jam feedback); `change-parameters` gains “The
  feeding level is set by `f0`, not `h`”.

## mizerAgents 0.1.0

### New features

- [`setup_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/setup_mizer_agent.md)
  creates or updates agent context files (`MIZER-AGENTS.md`,
  `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`) in a mizer project directory so
  that AI coding agents pick up the mizer reference card and API
  documentation automatically on startup.

- [`setup_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/setup_mizer_agent.md)
  also installs bundled Claude Code skills into `.claude/skills/` —
  `analyse-and-plot`, `build-multispecies-model`, `calibrate-model`,
  `run-simulation`, `set-up-fishing`, `change-parameters`, and
  `extend-mizer` — giving task-triggered, step-by-step guidance for
  common mizer workflows. The skills are refreshed on every call.

- Bundled `inst/skills/` — one sub-directory with a `SKILL.md` per
  skill, deployed by
  [`setup_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/setup_mizer_agent.md).

- Bundled `inst/AGENTS.md` — concise mizer reference card covering the
  core workflow, key objects, species parameters, plotting, and
  extending mizer.

- Bundled `inst/llms.txt` — concise index of the full mizer API, with
  links to online reference pages.

- Bundled `inst/llms-full.txt` — full prose documentation for every
  exported mizer function, intended for agent `grep` searches.
