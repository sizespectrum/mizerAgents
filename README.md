# mizerAgents

<!-- badges: start -->
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![R-CMD-check](https://github.com/sizespectrum/mizerAgents/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/sizespectrum/mizerAgents/actions/workflows/R-CMD-check.yaml)
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

## Usage

Run once in the root of your mizer project:

```r
library(mizerAgents)
setup_mizer_agent()
```

This creates:

- **`MIZER-AGENTS.md`** — a concise mizer reference card that AI agents read
  automatically on startup, including key objects, the core workflow, and links
  to the bundled API documentation.
- **`AGENTS.md`** — updated to include `@MIZER-AGENTS.md` (created fresh, or
  the shim is prepended to any existing content).
- **`CLAUDE.md`** / **`GEMINI.md`** — agent-specific shims pointing to
  `AGENTS.md` (only created if they do not already exist).

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

## Documentation

<https://sizespectrum.github.io/mizerAgents/>
