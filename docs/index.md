# mizerAgents

`mizerAgents` is an R package that makes it easy to set up AI coding
agents (such as Claude Code, GitHub Copilot, Codex, or Gemini) to work
with the [mizer](https://sizespectrum.org/mizer/) package for dynamic
multi-species size-spectrum modelling.

The package bundles a curated mizer reference card and full API
documentation optimised for large language models, and deploys them into
any mizer project with a single function call.

## Installation

``` r

# install.packages("pak")
pak::pak("sizespectrum/mizerAgents")
```

You also need **mizer 3.3.0 or newer**, which is where the skills and
the API index deployed into your project are maintained.

The same install works whichever mizer you run. The skills and the API
index are read from the mizer you have installed rather than bundled
here, so the CRAN version and the development version from GitHub each
get guidance matching themselves. (Earlier releases needed a separate
`@dev` branch for this; it has been retired.)

## Usage

Run once in the root of your mizer project:

``` r

mizerAgents::setup_mizer_agent()
```

This creates:

- **`MIZER-AGENTS.md`** — a short routing card that AI agents read
  automatically on startup. It does not try to teach mizer: it warns the
  agent that its recollection of the mizer API is probably stale, and
  points it at the skills below and at mizer’s API index for anything it
  actually needs to know.

- **`AGENTS.md`** — your project instruction file, updated to include a
  short package-managed block pointing agents at `MIZER-AGENTS.md`. Only
  the block between the `<!-- mizerAgents: start -->` and
  `<!-- mizerAgents: end -->` markers is refreshed on each run; anything
  you add outside it is preserved.

- **`CLAUDE.md`** and **`GEMINI.md`** — created, if you do not have
  them, with the single line `@AGENTS.md`, so that Claude Code and
  Gemini CLI read your `AGENTS.md`, which neither of them falls back to
  on its own. Your project instructions then live in one file rather
  than three. If you already have either file it is treated exactly like
  `AGENTS.md` instead: it gets its own copy of the marked block, the
  rest is left alone, and no `@AGENTS.md` import is written into it or
  removed from it.

- **`.claude/skills/`** — Claude Code skills (`analyse-and-plot`,
  `analyse-stability`, `build-model`, `calibrate-model`,
  `run-simulation`, `set-up-fishing`, `change-parameters`,
  `extend-mizer`) that agents read automatically when a task matches,
  giving step-by-step guidance for common mizer workflows. They are
  refreshed on each run, but only file by file and only where nothing
  has edited them: see [What your project
  learns](#what-your-project-learns).

  The skills come from the **installed mizer** (`inst/skills/`), not
  from this package, so they always describe the version of mizer your
  project actually runs. Each is also the source of the matching
  `guide-*` article on the mizer website, so the agent and the human
  documentation are one document. Skills arrived in mizer 3.3.0; against
  an older mizer everything else is still set up and
  [`setup_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/setup_mizer_agent.md)
  reports that it installed none.

- **MCP configuration** for an `r-mizer` server that connects the agent
  to your live R session (see below), written in each agent’s own format
  — Claude Code, Codex, Gemini CLI, Antigravity, Cursor, VS Code and
  Posit Assistant all keep it somewhere different. Only the `r-mizer`
  entry is package-managed; other servers you configure in those files
  are left alone. Commit them, and a collaborator using a different
  agent gets the same setup.

Then open a terminal in your project directory and start your favourite
coding agent CLI, for example:

    claude    # Claude Code (Anthropic)
    codex     # Codex CLI (OpenAI)
    agy       # Antigravity CLI (Google)
    copilot   # GitHub Copilot CLI

The agent will immediately have the mizer context it needs.

## Which editor you use

Any. The agent runs in a terminal and reads files in your project
directory, and it reaches your R session over a socket, so this works
the same from RStudio, Positron, a bare R console, Emacs/ESS, the VS
Code R extension, or R over SSH on a server. The examples say “RStudio”
because something has to be named.

The single exception is the agent’s ability to read the document you
have open in the editor: that goes through the `rstudioapi` package and
so works only in RStudio and Positron. Everywhere else the agent is told
to ask you which file you mean. Nothing else — the reference card, the
skills, documentation lookups against your installed mizer, your global
environment, running mizer code and seeing the plots — depends on the
editor.

## Connecting the agent to your R session

The package bundles an index of the mizer API, but not the argument
lists — for those the agent needs the mizer you actually have installed.
To give it that, install the [btw](https://posit-dev.github.io/btw/)
package:

``` r

install.packages("btw")
```

[`setup_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/setup_mizer_agent.md)
has already registered btw’s MCP server under the name `r-mizer` — in
every agent’s config format, so it does not matter which one you use:

| Agent              | File                                  |
|--------------------|---------------------------------------|
| Claude Code        | `.mcp.json`                           |
| Codex CLI          | `.codex/config.toml`                  |
| Gemini CLI         | `.gemini/settings.json`               |
| Antigravity CLI    | `.agents/mcp_config.json`             |
| Cursor             | `.cursor/mcp.json`                    |
| VS Code / Copilot  | `.vscode/mcp.json`                    |
| Posit Assistant    | `.posit/assistant/settings.json`      |
| GitHub Copilot CLI | *no project-level config* — see below |

Posit Assistant runs in RStudio as well as Positron, so you do not have
to leave the IDE to use this.

Copilot CLI reads MCP servers only from the user-wide
`~/.copilot/mcp-config.json`, so nothing is written for it. Ask for it
by name, with `setup_mizer_agent(agents = "copilot")`, and the JSON
snippet to paste there is printed. Use the `agents` argument if you want
fewer files, e.g. `setup_mizer_agent(agents = "claude")`.

Then, in your R console, hand your session to the server:

``` r

mizerAgents::connect_mizer_agent()
```

Once per session, before you start the agent. It wraps
[`btw::btw_mcp_session()`](https://posit-dev.github.io/btw/reference/mcp.html),
which does the work, and tells you which agents are configured to reach
the session and whether they may run code in it — warning you if none
are, since connecting to nothing otherwise looks exactly like connecting
to something.

The agent can now read help pages, vignettes and NEWS for your installed
mizer, list the objects in your global environment, and run mizer code
in your session — projecting or calibrating a model, plotting the
result, and seeing that plot as an image. In RStudio and Positron it can
also read the document you have open. Use
`setup_mizer_agent(rprofile = TRUE)` to add the `btw_mcp_session()` call
to the project `.Rprofile` so that it happens on every startup — R reads
that file only when it starts in the project directory, which RStudio
and Positron do for you and a shell does not.

That code is evaluated in your global environment with no sandboxing, so
the agent can overwrite your objects. Keep your work under version
control. For a read-only connection — documentation and inspection, but
no execution — use `setup_mizer_agent(run_r = FALSE)`, and
`setup_mizer_agent(r_session = FALSE)` to skip the MCP setup entirely.

### If your project is a mizer extension package

``` r

setup_mizer_agent(pkg_dev = TRUE)
```

adds btw’s package development tools, so the agent can run `load_all()`,
`document()`, `test()`, `check()` and test coverage in your session
rather than shelling out to `devtools`. After `load_all()` the new code
is live in the session, so the agent can exercise it immediately. Off by
default, since these tools do nothing useful in an ordinary modelling
project.

### Keeping it up to date

``` r

mizerAgents::update_mizer_agent()
```

refreshes everything the setup installed — most usefully after upgrading
mizer, since that is where the skills now come from — **keeping the
settings this project was set up with**.

Use it rather than re-running
[`setup_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/setup_mizer_agent.md).
That function is declarative: its arguments describe the setup you want,
and its defaults are the ones for a new project. So a bare re-run
switches code execution back on in a project set up with
`run_r = FALSE`, drops the package tools from one set up with
`pkg_dev = TRUE`, and writes config files for the agents you narrowed
away from.
[`update_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/update_mizer_agent.md)
reads those choices back off disk and replays them, so only the content
changes.
([`setup_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/setup_mizer_agent.md)
reports any setting it changes, so a plain re-run at least tells you.)
Pass any of its arguments to override what was detected,
e.g. `update_mizer_agent(run_r = FALSE)`.

### Undoing the setup

``` r

mizerAgents::remove_mizer_agent()
```

removes everything
[`setup_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/setup_mizer_agent.md)
installed: `MIZER-AGENTS.md`, the marked block in the instruction files,
the bundled skills, the `r-mizer` entry in each agent’s MCP config, and
the `btw_mcp_session()` call in `.Rprofile`. Only what this package
wrote comes out. Your own notes outside the markers stay, as do other
MCP servers you configured in those files; a file that held nothing but
our block — or nothing but the `@AGENTS.md` import we wrote into a
`CLAUDE.md` or `GEMINI.md` we created — is deleted with it, and
directories left empty are removed. A skill file you have edited, and
any `NOTES.md`, are kept and reported rather than deleted — see below.

## What your project learns

The files this package installs are refreshed on every update, so
nothing you or your agent writes into them survives. But an agent that
discovers something about your model wants to write it down, and it
writes it where it was reading: in the skill it was following. So each
skill has a home for that which the package never touches.

- **`.claude/skills/<name>/NOTES.md`** — findings about *this* project.
  Every bundled `SKILL.md` ends by telling agents to read this file
  alongside it, to treat it as taking precedence, and to record what
  they learn there rather than in `SKILL.md`. Nothing in this package
  ever writes it. Commit it: it is project knowledge, and your
  collaborators’ agents get it too.
- **`AGENTS.md`, outside the markers** (or `CLAUDE.md` / `GEMINI.md`, if
  you keep separate instructions for those agents) — project notes that
  belong to no single skill.
- **[An issue on this
  repo](https://github.com/sizespectrum/mizerAgents/issues)** — for a
  lesson that is true of mizer in general rather than of your project.
  The skills tell agents to offer this, so that the next release carries
  it to everyone rather than leaving it buried in one project.

Skills are refreshed file by file, never by replacing whole directories,
so a `NOTES.md` — or a skill of your own invention — is left alone. The
hashes of the files installed are recorded in
`.claude/skills/.mizerAgents.json`. If a `SKILL.md` has been edited
since, it is recognised, kept, and reported, with the new version
written beside it as `SKILL.md.new` for you to merge:

    These skill files have been edited in this project, so they
    were kept and the new version of each was written beside it:
      run-simulation/SKILL.md  ->  SKILL.md.new

Delete the `.new` file when you are done and the skill goes back under
package management. Skills that later versions stop shipping are
removed, unless they were edited here.

## What’s included

| File | Description |
|----|----|
| `inst/MIZER-AGENTS.md` | Mizer reference card deployed by [`setup_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/setup_mizer_agent.md) |

Everything that describes mizer rather than the agent setup is
maintained in mizer and read from the installed copy, so it always
matches the version your project runs. The skills come from
`system.file("skills", package = "mizer")`, and the API index — every
exported function with a one-line description, grouped by workflow stage
— from `system.file("llms.txt", package = "mizer")`, where it is
generated from the website by `dev_scripts/build_llms.R`. Both arrived
in mizer 3.3.0, which is the oldest mizer this package is designed
against; against anything older it writes everything else and reports
what the installed mizer does not ship.

Argument lists are deliberately not bundled anywhere. A snapshot of them
goes stale as soon as mizer moves on, and it fails quietly — an outdated
call often still runs and returns plausible numbers. The index tells an
agent *which* function it needs; *how to call it* comes from the help
page of the mizer you have installed, which is what the R session
connection above is for.

## Documentation

<https://sizespectrum.github.io/mizerAgents/>
