# Mizer

Mizer is an R package for dynamic multi-species size-spectrum modelling of
fish communities. It tracks the full size distribution of each species and
the plankton resource, computing growth, predation, and mortality from
individual-level physiology.

## Do not write mizer code from memory

Mizer's API has moved on, and most mizer code in your training data predates
the version installed here — recollection that feels solid is often a version
or two stale. Before calling any function you have not looked up in this
session, read its help page from the installed mizer and check the real
signature. This failure is quiet: outdated calls often still run and return
plausible numbers.

Nothing in this repository is a substitute for that. The bundled API index
(path at the end of this file) tells you which functions exist, not how to call
them, and this card is a summary rather than a reference. Argument lists come
from the installed package or they come from a guess.

Memory is most often stale on:

- **maximum size** — `w_inf`, `w_repro_max` and `w_max` are three distinct
  parameters (see below), not one
- **setting species parameters** — use `species_params(params) <- value`, which
  records the change and recalculates dependent quantities
- **reproduction** — `setBevertonHolt()` takes `erepro`, `R_max` *or*
  `reproduction_level`; check which the task calls for

If the installed mizer disagrees with this file, the installed mizer wins.
Check with `?name` and say so rather than quietly working around it.

## Core workflow

```r
library(mizer)

# 1. Create model parameters from a species data frame
params <- newMultispeciesParams(species_params, interaction)

# 2. Find the steady state (sets initial values)
params <- steady(params)

# 3. Calibrate to observed biomasses / yields
params <- calibrateBiomass(params)  # adjusts kappa
params <- matchBiomasses(params)    # adjusts R_max per species
params <- matchGrowth(params)       # adjusts h per species

# 4. Tune density-dependent reproduction
params <- setBevertonHolt(params, reproduction_level = 0.25)

# 5. Project forward in time
sim <- project(params, t_max = 20, effort = 1)

# 6. Analyse results
plot(sim)
getBiomass(sim)
getYield(sim)
plotSpectra(sim)
```

## Key objects

**`MizerParams`** — holds all model parameters. Never modify slots directly.
All setter functions return a new copy: `params <- setFishing(params, ...)`.

**`MizerSim`** — simulation output from `project()`. Arrays: `N(sim)` (time ×
species × size), `NResource(sim)`.

## Species parameters

The `species_params` data frame must have `species` (name) and the
von Bertalanffy asymptotic weight `w_inf`. Everything else has defaults.
Change species parameters with `species_params(params) <- value`, which records
the change and triggers recalculation of dependent quantities. See the
`change-parameters` skill.

| Column | Meaning |
|--------|---------|
| `w_inf` | Von Bertalanffy asymptotic weight (g); accepted maximum-size input, sets `w_repro_max` |
| `w_max` | Computational upper size-grid boundary (g) — purely numerical; defaults to `1.5 * w_inf` |
| `w_repro_max` | Weight beyond which no growth/reproduction |
| `w_mat` | Maturity weight (g) |
| `beta` | Preferred predator/prey mass ratio (default ~100) |
| `sigma` | S.d. of lognormal predation kernel (default ~1.3) |
| `h` | Max intake rate coefficient |
| `alpha` | Assimilation efficiency (default 0.6) |
| `erepro` | Reproductive efficiency |
| `R_max` | Beverton-Holt max recruitment |
| `biomass_observed` | Observed biomass for `calibrateBiomass()` |

## Units

Weights in grams, lengths in cm, time in years.

## Numerical scheme for dynamics

The default `project()` flux scheme (first-order upwind) carries substantial
*numerical* diffusion that silently smears cohorts and travelling waves and can
completely damp real oscillations / limit cycles — a correctness issue, not just
accuracy. For any study of dynamics (oscillations, cohort waves, diffusion),
build the model with `second_order_w = TRUE` (van Leer flux) and project with
`method = "tr_bdf2"` (second order in time). See the `run-simulation` skill.

## Gotchas

- `w_max` defaults to `1.5 * w_inf`. Passing `max_w = w_inf` to
  `newMultispeciesParams()` then errors — set a `w_max` column equal to `w_inf`
  as well.
- The steady-state feeding level is set by the `f0` species parameter (from which
  the default `gamma` is derived), **not** by `h`; `h = Inf` makes `gamma`
  non-finite. See the `change-parameters` skill.
- With growth diffusion on (`D_ext > 0`), set `w_max` well above the sizes you
  analyse so abundance at the boundary stays negligible; the default
  `1.5 * w_inf` is usually enough, raise it if `D_ext` is large.

## Plotting

The return values of most `get...()` functions also have `plot()` methods,
so you can visualise any quantity directly.
Always prefer this over writing custom plotting code.

```r
plot(getSSB(sim))           # ArrayTimeBySpecies  → time series per species
plot(getTrophicLevel(params)) # ArraySpeciesBySize → curve per species
```

In addition, Mizer provides many custom plotting functions. 

```r
plot(sim)              # overview of simulation
plotSpectra(sim)       # size spectra
plotBiomass(sim)       # biomass over time
plotYield(sim)         # yield over time
plotGrowthCurves(sim)  # growth curves
plotFMort(sim)         # fishing mortality
```

Grep for "plot" in the bundled API index (path at the end of this file) to
discover the full list of available plots before writing any custom code, then
read the help page of the one you pick for its arguments.

## Extending mizer

To replace a rate function: `params <- setRateFunction(params, "Encounter", myFun)`.
To add a new ecosystem component: `params <- setComponent(params, "detritus", ...)`.
See https://sizespectrum.org/mizer/articles/extending-mizer.html
