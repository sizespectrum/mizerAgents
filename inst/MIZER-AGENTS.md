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

Mizer's API has moved on, and most mizer code in your training data predates
the version installed here — recollection that feels solid is often a version
or two stale. Before calling any function you have not looked up in this
session, read its help page from the installed mizer and check the real
signature. This failure is quiet: outdated calls often still run and return
plausible numbers.

Nothing in this repository is a substitute for that. The bundled API index
tells you which functions exist, not how to call them, and the skills describe
workflows rather than signatures. Argument lists come from the installed
package or they come from a guess.

The one correction worth making before you read anything else: **`w_inf`,
`w_repro_max` and `w_max` are three distinct parameters**, not three names for
the maximum size. The `build-multispecies-model` skill has the difference.

If the installed mizer disagrees with this file, the installed mizer wins.
Check with `?name` and say so rather than quietly working around it.

## Key objects

**`MizerParams`** holds all model parameters; **`MizerSim`** is what `project()`
returns. Never modify slots directly. Every `new…`/`set…`/`match…`/`calibrate…`
function returns a *new* object, so always reassign — `params <- setFishing(params, ...)`.
A call whose result you drop on the floor does nothing, silently. This is the
one mizer idiom that applies to code in every skill below.

<!-- mizerAgents:skills -->

<!-- mizerAgents:r-session -->

<!-- mizerAgents:function-lookup -->
