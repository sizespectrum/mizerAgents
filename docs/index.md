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

If you are running the development version of mizer from GitHub instead
of the version from CRAN then you need the alternative

    pak::pak("sizespectrum/mizerAgents@dev")

## Usage

Run once in the root of your mizer project:

``` r

mizerAgents::setup_mizer_agent()
```

This creates:

- **`MIZER-AGENTS.md`** — a concise mizer reference card that AI agents
  read automatically on startup, including key objects, the core
  workflow, and links to the bundled API documentation.
- **`AGENTS.md`**, **`CLAUDE.md`** and **`GEMINI.md`** — your project
  instruction files, each updated to include a short package-managed
  block pointing agents at `MIZER-AGENTS.md`. All three are handled the
  same way, since Claude Code reads `CLAUDE.md` and Gemini CLI reads
  `GEMINI.md` rather than falling back to `AGENTS.md`. Only the block
  between the `<!-- mizerAgents: start -->` and
  `<!-- mizerAgents: end -->` markers is refreshed on each run; anything
  you add outside it is preserved, and no `@AGENTS.md` import is ever
  written or removed.
- **`.claude/skills/`** — bundled Claude Code skills
  (`analyse-and-plot`, `build-multispecies-model`, `calibrate-model`,
  `run-simulation`, `set-up-fishing`, `change-parameters`,
  `extend-mizer`) that agents read automatically when a task matches,
  giving step-by-step guidance for common mizer workflows. They are
  refreshed on each run, but only file by file and only where nothing
  has edited them: see [What your project
  learns](#what-your-project-learns).
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
`~/.copilot/mcp-config.json`, so nothing is written for it;
[`setup_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/setup_mizer_agent.md)
prints the JSON snippet to paste there. Use the `agents` argument if you
want fewer files, e.g. `setup_mizer_agent(agents = "claude")`.

Then, in your RStudio console, hand your session to the server:

``` r

btw::btw_mcp_session()
```

The agent can now read help pages, vignettes and NEWS for your installed
mizer, list the objects in your global environment, read the document
you have open in RStudio, and run mizer code in your session —
projecting or calibrating a model, plotting the result, and seeing that
plot as an image. Use `setup_mizer_agent(rprofile = TRUE)` to add the
`btw_mcp_session()` call to the project `.Rprofile` so that it happens
on every startup.

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

## What your project learns

The files this package installs are refreshed on every run, so nothing
you or your agent writes into them survives. But an agent that discovers
something about your model wants to write it down, and it writes it
where it was reading: in the skill it was following. So each skill has a
home for that which the package never touches.

- **`.claude/skills/<name>/NOTES.md`** — findings about *this* project.
  Every bundled `SKILL.md` ends by telling agents to read this file
  alongside it, to treat it as taking precedence, and to record what
  they learn there rather than in `SKILL.md`. Nothing in this package
  ever writes it. Commit it: it is project knowledge, and your
  collaborators’ agents get it too.
- **`AGENTS.md` / `CLAUDE.md` / `GEMINI.md`, outside the markers** —
  project notes that belong to no single skill.
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
| `inst/llms.txt` | Curated index of the mizer API, grouped by workflow stage |
| `inst/skills/` | Claude Code skills deployed to `.claude/skills/` |

Argument lists are deliberately not bundled. A snapshot of them goes
stale as soon as mizer moves on, and it fails quietly — an outdated call
often still runs and returns plausible numbers. The index tells an agent
*which* function it needs; *how to call it* comes from the help page of
the mizer you have installed, which is what the R session connection
above is for.

## Documentation

<https://sizespectrum.github.io/mizerAgents/>
