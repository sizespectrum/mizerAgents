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

Then open a terminal in your project directory and start your favourite
coding agent CLI, for example:

```
claude    # Claude Code (Anthropic)
codex     # Codex CLI (OpenAI)
agy       # Antigravity CLI (Google)
copilot   # GitHub Copilot CLI
```

The agent will immediately have the mizer context it needs.

## What's included

| File | Description |
|------|-------------|
| `inst/AGENTS.md` | Mizer reference card deployed by `setup_mizer_agent()` |
| `inst/llms.txt` | Concise mizer API overview (start here) |
| `inst/llms-full.txt` | Full documentation for every mizer function |
| `inst/skills/` | Claude Code skills deployed to `.claude/skills/` |

## Documentation

<https://sizespectrum.github.io/mizerAgents/>
