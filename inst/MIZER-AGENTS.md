# Mizer

Mizer is an R package for dynamic multi-species size-spectrum modelling of
fish communities. It tracks the full size distribution of each species and
the plankton resource, computing growth, predation, and mortality from
individual-level physiology.

This card is a routing table, not a reference. It says where the answer lives —
in a task skill, or in the installed mizer's help pages — and deliberately does
not restate the answer, because a summary you can act on without opening the
skill is a summary you will act on while it is out of date.

## Do not write mizer code from memory

Mizer's API has evolved, and outdated calls often still run and return
plausible results. Before calling a mizer function, inspect the version installed
in this project rather than relying on memory or online documentation.

For the full help page, use
`Rscript -e 'help("functionName", package = "mizer", help_type = "text")'`.
Run it from the project directory without --vanilla, so project library
settings such as renv apply.
For a quick signature check, use `args(mizer::functionName)`. The
mizer API index names functions and the task skills describe workflows, but
neither provides argument lists.

If the installed mizer disagrees with this card or any skill, the installed
package wins. Report any discrepancy to the user rather than quietly working
around it.

## Reporting bugs in mizer

If a mizer function behaves differently from what its installed help page led
you to expect, treat it as a bug in mizer rather than quietly working around it:

1. **Do not silently patch or work around the discrepancy.**
2. **Create a minimal reproducible example (reprex)** isolating the unexpected
   behaviour, noting the installed mizer version (`packageVersion("mizer")`).
3. **File an issue on the mizer issue tracker** at
   <https://github.com/sizespectrum/mizer/issues>. If the GitHub CLI (`gh`) is
   available and authenticated, you may offer to run:
   ```bash
   gh issue create --repo sizespectrum/mizer --title "..." --body "..."
   ```
   Otherwise, present the ready-to-paste title, description, and reprex to the
   user with the link.

*(Note: Issues with this agent card, skills, or `mizerAgents` tooling belong on
<https://github.com/sizespectrum/mizerAgents/issues> instead.)*

## Key objects

**`MizerParams`** holds all model parameters; **`MizerSim`** is what `project()`
returns. Never modify slots directly. Every `new…`/`set…`/`match…`/`calibrate…`
function returns a *new* object, so always reassign — `params <- setFishing(params, ...)`.

<!-- mizerAgents:skills -->

<!-- mizerAgents:r-session -->

<!-- mizerAgents:function-lookup -->
