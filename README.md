# mizerAgents

<!-- badges: start -->
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

`mizerAgents` is an R package that makes it easy to set up AI coding agents
(such as Claude Code, GitHub Copilot, Codex, or Gemini) to work with the
[mizer](https://sizespectrum.org/mizer/) package for dynamic multi-species
size-spectrum modelling.

The package bundles a curated mizer reference card and full API documentation
optimised for large language models, and deploys them into any mizer project
with a single function call.

## Installation

```r
# install.packages("pak")
pak::pak("sizespectrum/mizerAgents")
```

If you are running the development version of mizer from GitHub instead of the
version from CRAN then you need the alternative
```
pak::pak("sizespectrum/mizerAgents@dev")
```

## Usage

Run once in the root of your mizer project:

```r
mizerAgents::setup_mizer_agent()
```

This creates:

- **`MIZER-AGENTS.md`** — a concise mizer reference card that AI agents read
  automatically on startup, including key objects, the core workflow, and links
  to the bundled API documentation.
- **`AGENTS.md`** — your project instruction file, updated to include a short
  package-managed block pointing agents at `MIZER-AGENTS.md`. Only the block
  between the `<!-- mizerAgents: start -->` and `<!-- mizerAgents: end -->`
  markers is refreshed on each run; anything you add outside it is preserved.
- **`CLAUDE.md`** / **`GEMINI.md`** — agent-specific shims pointing to
  `AGENTS.md` (only created if they do not already exist).
- **`.claude/skills/`** — bundled skills (`analyse-and-plot`,
  `build-multispecies-model`, `calibrate-model`, `run-simulation`,
  `set-up-fishing`, `change-parameters`, `extend-mizer`) that agents read
  automatically when a task matches, giving step-by-step guidance for common
  mizer workflows.
- **`.mcp.json`** — an MCP server named `r-mizer` that connects the agent to
  your live R session (see below). Only this entry is package-managed; other
  servers you configure there are left alone.

Then open a terminal in your project directory and start your favourite
coding agent CLI, for example:

```
claude    # Claude Code (Anthropic)
codex     # Codex CLI (OpenAI)
agy       # Antigravity CLI (Google)
copilot   # GitHub Copilot CLI
```

The agent will immediately have the mizer context it needs.

## Connecting the agent to your R session

The bundled documentation is a snapshot taken when this package was built, and
it will drift from whatever mizer version you have installed. To let the agent
read the *installed* mizer instead, install the
[btw](https://posit-dev.github.io/btw/) package:

```r
install.packages("btw")
```

`setup_mizer_agent()` configures btw's MCP server in your project's `.mcp.json`
under the name `r-mizer`. Then, in your RStudio console, hand your session to
it:

```r
btw::btw_mcp_session()
```

The agent can now read help pages, vignettes and NEWS for your installed mizer,
list the objects in your global environment, read the document you have open in
RStudio, and run mizer code in your session — projecting or calibrating a
model, plotting the result, and seeing that plot as an image. Use
`setup_mizer_agent(rprofile = TRUE)` to add the `btw_mcp_session()` call to the
project `.Rprofile` so that it happens on every startup.

That code is evaluated in your global environment with no sandboxing, so the
agent can overwrite your objects. Keep your work under version control. For a
read-only connection — documentation and inspection, but no execution — use
`setup_mizer_agent(run_r = FALSE)`, and `setup_mizer_agent(r_session = FALSE)`
to skip the MCP setup entirely.

### If your project is a mizer extension package

```r
setup_mizer_agent(pkg_dev = TRUE)
```

adds btw's package development tools, so the agent can run `load_all()`,
`document()`, `test()`, `check()` and test coverage in your session rather than
shelling out to `devtools`. After `load_all()` the new code is live in the
session, so the agent can exercise it immediately. Off by default, since these
tools do nothing useful in an ordinary modelling project.

## What's included

| File | Description |
|------|-------------|
| `inst/AGENTS.md` | Mizer reference card deployed by `setup_mizer_agent()` |
| `inst/llms.txt` | Concise mizer API overview (start here) |
| `inst/llms-full.txt` | Full documentation for every mizer function |
| `inst/skills/` | Claude Code skills deployed to `.claude/skills/` |

## Documentation

<https://sizespectrum.github.io/mizerAgents/>
