# Using AI Agents with Mizer

## Overview

AI coding agents can be surprisingly effective at helping you build,
calibrate, analyse and extend mizer models. Unlike a web search or a
static manual, an agent can read your actual data and scripts, suggest
specific parameter changes, write R snippets for your situation, and
explain what functions do in plain language.

This article explains how to get an agent working inside RStudio and
shows a range of example tasks where one can save you significant time.

## Quick start: one-line setup

mizerAgents bundles everything an AI agent needs to understand the mizer
API. You only need to run this once in your R project:

``` r

pak::pak("sizespectrum/mizerAgents")
mizerAgents::setup_mizer_agent()
```

This creates the following files in your working directory:

- **`MIZER-AGENTS.md`** — a concise mizer reference: core workflow, key
  object descriptions, a species parameter table, and the path to the
  bundled API index. This file is package-managed and can be updated
  when mizer is upgraded.
- **`AGENTS.md`**, **`CLAUDE.md`** and **`GEMINI.md`** — your
  project-specific instruction files. Each is created with a short
  package-managed block at the top that points agents at
  `MIZER-AGENTS.md`; the rest of each file is yours. All three carry the
  same block, because none of them is a fallback for another: Claude
  Code reads `CLAUDE.md` and not `AGENTS.md`, and Gemini CLI reads
  `GEMINI.md`, so an agent that looks only for its own named file should
  still find the mizer context. The block is the only thing added to
  these files: no `@AGENTS.md` import is written or removed, so which of
  your own instructions reach which agent stays exactly as you had it.
- **MCP configuration** for a server named `r-mizer` that connects the
  agent to your R session, described in the next section. Every agent
  uses a different file for this, so all of them are written:
  `.mcp.json`, `.codex/config.toml`, `.gemini/settings.json`,
  `.agents/mcp_config.json`, `.cursor/mcp.json`, `.vscode/mcp.json` and
  `.posit/assistant/settings.json`.

`MIZER-AGENTS.md` is always updated when you run
[`setup_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/setup_mizer_agent.md).
In the three instruction files only the block between the
`<!-- mizerAgents: start -->` and `<!-- mizerAgents: end -->` comments
is package-managed: it is refreshed each time you run
[`setup_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/setup_mizer_agent.md),
so improvements to it reach existing projects, while everything you
write outside those markers is preserved. If a `CLAUDE.md` or
`GEMINI.md` of yours already contains `@AGENTS.md`, it is left
untouched, since the block reaches the agent through that import.

## Connecting the agent to your R session

`mizerAgents` bundles an index of the mizer API — every exported
function with a one-line description, grouped by workflow stage — but
deliberately not the argument lists. A snapshot of those would drift
from the mizer you have installed, and it would drift *quietly*: a call
written against last year’s signature usually still runs and returns
plausible numbers, which is the hardest kind of error to notice in a
model.

So the index tells the agent which function it needs, and the installed
package tells it how to call that function. The
[btw](https://posit-dev.github.io/btw/) package supplies the second
half: an MCP server that lets the agent read the documentation of your
*installed* packages, along with your R session. Install it once:

``` r

install.packages("btw")
```

[`setup_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/setup_mizer_agent.md)
has already registered that server under the name `r-mizer`. Agents have
not converged on a single place to configure MCP servers, nor even on a
single schema, so it writes all of them:

| Agent             | File                             |
|-------------------|----------------------------------|
| Claude Code       | `.mcp.json`                      |
| Codex CLI         | `.codex/config.toml`             |
| Gemini CLI        | `.gemini/settings.json`          |
| Antigravity CLI   | `.agents/mcp_config.json`        |
| Cursor            | `.cursor/mcp.json`               |
| VS Code / Copilot | `.vscode/mcp.json`               |
| Posit Assistant   | `.posit/assistant/settings.json` |

The files are small, they sit in different places, and each agent
ignores the others’, so the effect is that whichever agent you or a
collaborator reaches for, the connection is already there. Commit them
along with `AGENTS.md`. If you would rather have fewer files, name the
ones you use:

``` r

mizerAgents::setup_mizer_agent(agents = c("claude", "posit"))
```

`"posit"` is worth knowing about if you would rather not leave the IDE
at all: [Posit Assistant](https://assistant.posit.co/) runs inside
RStudio as well as Positron, and connects to the same R session this
whole mechanism is built around.

GitHub Copilot CLI is the exception: it reads MCP servers only from the
user-wide `~/.copilot/mcp-config.json`, which is not a file a project
setup function should be editing, so
[`setup_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/setup_mizer_agent.md)
prints the snippet to paste there instead.

The server runs as its own R process, so it does not see your session
until you hand it over. In the RStudio console, run:

``` r

btw::btw_mcp_session()
```

The agent can now read help pages, vignettes and release notes for your
installed mizer, list the objects in your global environment, and read
the document you have open in the editor. That means it can *check* the
argument names of `newMultispeciesParams()` or `setBevertonHolt()`
instead of recalling them, which is the single most common source of
mizer code that looks right and is not.

To have every new session connect itself, run

``` r

mizerAgents::setup_mizer_agent(rprofile = TRUE)
```

which adds the `btw_mcp_session()` call to your project’s `.Rprofile`.

### Letting the agent run mizer code

The agent can also evaluate R code in your session, and does so by
default. It can call `project()` or `steady()` on your `params` object
and plot the result, and the plot comes back to it as an image — so it
can look at a spectrum or a biomass trajectory and judge whether the
model is behaving, rather than guessing from numbers. This is the mode
in which an agent is most useful for calibration work.

The trade-off is real: that code runs in your global environment with no
sandboxing, so a careless assignment can overwrite an object you spent
an hour building. `MIZER-AGENTS.md` tells the agent to assign to new
names and to announce overwrites, but the safeguard you should rely on
is version control. Commit your work before turning the agent loose on
it. If you would rather have a read-only connection — documentation and
inspection, but no execution — use

``` r

mizerAgents::setup_mizer_agent(run_r = FALSE)
```

and `setup_mizer_agent(r_session = FALSE)` skips the MCP setup
altogether.

### If your project is a mizer extension package

When you are writing an extension package rather than a model, add btw’s
package development tools:

``` r

mizerAgents::setup_mizer_agent(pkg_dev = TRUE)
```

The agent can then run `load_all()`, `document()`, `test()`, `check()`
and test coverage in your session instead of shelling out to `devtools`
in a terminal. The gain is not just tidiness: after `load_all()` your
new code is live in the same session, so the agent can immediately build
a `MizerParams` object and try the rate function it has just written.
Combined with the `extend-mizer` skill, this makes the write–load–test
loop something the agent can close on its own. These tools are off by
default, as they do nothing useful in an ordinary modelling project.

## Running an AI agent in the terminal

The **Terminal** tab in RStudio (open it with **Tools → Terminal → New
Terminal**) runs a real shell in your project directory. AI coding
agents can run here alongside your normal R session and can read and
edit the same files.

Alternatively, you may want to open a terminal in a separate window from
the RStudio window, for example if you work with multiple monitors. Then
start the agent there in the working directory of your project.

## What an AI agent can help with

- **Building a model** — translating a species parameter spreadsheet
  into a working `newMultispeciesParams()` call, identifying missing
  columns and suggesting sensible defaults.
- **Calibration** — diagnosing why a species is not converging in
  `steady()`, or suggesting which parameters to adjust when biomasses
  are off.
- **Writing analysis code** — producing R code to compare scenarios,
  extract rates, or reshape output for plotting.
- **Explaining functions** — describing what a function does and when to
  use it, especially for less familiar parts of the API such as
  `setRateFunction()` or `setComponent()`.
- **Extending mizer** — scaffolding a custom rate function or a new
  ecosystem component.
- **Debugging** — reading an error message or a suspicious plot
  alongside your code and suggesting fixes.

An agent is not infallible. Always verify R code it produces actually
runs and gives sensible results, especially for anything involving
numerical tuning.

## Giving the agent context about your project

After running
[`setup_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/setup_mizer_agent.md)
you will have an `AGENTS.md` in your project directory. It begins with a
short block, marked off by `<!-- mizerAgents: start -->` and
`<!-- mizerAgents: end -->` comments, that shims in the mizer package
reference. Open `AGENTS.md` and add a short description of your own
project *below* the closing marker — that part of the file is yours and
is never overwritten, whereas anything you change inside the markers is
replaced the next time you run
[`setup_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/setup_mizer_agent.md).
For example:

``` markdown
<!-- mizerAgents: start — managed by setup_mizer_agent(), edits are overwritten -->
This project uses [mizer](https://sizespectrum.org/mizer/) for size-spectrum
modelling. Read `MIZER-AGENTS.md` before writing or changing mizer code — it is
imported below if your tool resolves `@` imports. It is generated by
`mizerAgents::setup_mizer_agent()`; don't edit it by hand.

@MIZER-AGENTS.md
<!-- mizerAgents: end -->

# Celtic Sea mizer model

This project builds and analyses a mizer model for the Celtic Sea,
calibrated to ICES survey data for 2010–2020.

## Species
Cod, Haddock, Whiting, Herring, Sprat, Mackerel — 6 species.

## Key files
- `species_params.csv` — species parameter table
- `celtic_model.R` — builds and saves the MizerParams object
- `scenarios.R` — runs and compares fishing scenarios

## Workflow
1. Build: `celtic_model.R`, saves `celtic_params.rds`
2. Load: `params <- readRDS("celtic_params.rds")`
3. Project and analyse in `scenarios.R`
```

This project-specific context costs ten minutes to write and saves
re-explaining your setup at the start of every session.

### What the agent works out for itself

Most of what an agent learns about your model, it learns while working:
that this model only settles with a smaller `steady()` tolerance, that
one species’ `beta` is doing something odd, that a scenario has to be
run a particular way. It will want to write that down, and it writes
where it was reading — in the skill it was following, under
`.claude/skills/`. Those skill files are installed by
[`setup_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/setup_mizer_agent.md)
and refreshed when you run it again, so that is the wrong place for it.

Each skill therefore has a `NOTES.md` beside it that this package never
writes. The skills tell agents to read it alongside the `SKILL.md`, to
treat it as taking precedence where the two disagree, and to record
project-specific findings there:

    .claude/skills/calibrate-model/SKILL.md    # ours, refreshed
    .claude/skills/calibrate-model/NOTES.md    # yours, never touched

Commit those files. They are as much a part of the project as the code,
and a collaborator’s agent picks them up too. If you or your agent do
edit a `SKILL.md` directly, the edit is not lost either:
[`setup_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/setup_mizer_agent.md)
notices, keeps your version, and writes the new one beside it as
`SKILL.md.new` for you to merge.

Some of what an agent discovers is not about your project at all — a
mizer function that behaves differently from how the skill describes it,
a workflow that would work anywhere. That belongs upstream, in an [issue
on the mizerAgents
repository](https://github.com/sizespectrum/mizerAgents/issues), so that
the next release carries it to every project instead of leaving it in
yours. The skills tell agents to offer this, so you may find yourself
asked.

## Example prompts

The examples below illustrate the kinds of request that work well. Type
them directly into the agent’s terminal session, or into a browser-based
AI assistant.

### Getting a model started

> “I have a CSV of species parameters for the Celtic Sea at
> `data/celtic_species_params.csv`. Read it and help me set up a mizer
> model. Tell me which required columns are missing and what sensible
> defaults I could use.”

The agent will inspect the file, identify missing columns such as
`w_max` or `beta`, suggest defaults, and produce a
`newMultispeciesParams()` call ready to run.

### Diagnosing calibration problems

> “I’ve run `steady(params)` and biomass of Whiting is about 4× too high
> compared to the `biomass_observed` column. What’s the most likely
> cause and what should I try first?”

A good response will walk through the relevant parameters (`gamma`,
`beta`, `sigma`, `z0`) and suggest targeted changes rather than blind
adjustments.

### Writing scenario code

> “Write R code that runs three fishing scenarios — status quo, 50%
> effort reduction, and effort doubled — for 50 years each, then plots
> yield through time for all three on the same axes with a legend.”

The agent will produce a self-contained snippet using `project()` and
`plotYield()`. Check it, run it, and ask for tweaks.

### Understanding a function

> “What does `setBevertonHolt()` actually do? I’m confused about the
> `reproduction_level` argument and when I should change it during
> calibration.”

You will get a plain-language explanation of the Beverton-Holt
stock–recruitment relationship in mizer, what `reproduction_level`
represents ecologically, and guidance on when to adjust it.

### Adding custom biology

> “I want growth rates to scale with water temperature following a Q10
> relationship. Show me how to use `setRateFunction()` to replace the
> encounter rate so that `params@other_params$temp` is used.”

The agent will produce a custom encounter function and the
`setRateFunction()` call to register it — the kind of task that would
otherwise require careful reading of the [extending
mizer](https://sizespectrum.github.io/mizerAgents/articles/extending-mizer.md)
article.

### Debugging an error

> “Running `project(params, t_max = 50)` throws this warning repeatedly:
> \[paste warning text\]. What does it mean and how do I fix it?”

Share the exact text of the warning. The agent will usually identify the
cause (e.g. a species going near-extinct, a numerical instability from
too large a time step) and suggest a remedy.

## Tips for effective use

**Be specific.** “My model doesn’t work” is hard to help with. “Cod
biomass is 10× too high after `steady()` and I’ve already tried reducing
`gamma`” is much easier.

**Share actual files.** CLI agents can read your `.rds` files, CSVs and
R scripts. Give them your real data and they produce targeted
suggestions rather than generic advice.

**Iterate.** If the first response misses the mark, say so and explain
what you expected. Agents improve substantially with clarifying feedback
within a session.

**Verify numerical results.** An agent knows the mizer API well but may
not know whether a particular parameter value is ecologically plausible
for your system. Apply your domain knowledge.

**Teach the agent** After you have had to explain something to the agent
to make the agent’s answers more useful to you, tell the agent to “Add
what I just told you to AGENTS.md so that you know this in future
sessions.”

**Keep sessions focused.** One task per session tends to produce better
results than a long chain of unrelated questions.
