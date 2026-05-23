# Mizer

Mizer is an R package for dynamic multi-species size-spectrum modelling of
fish communities. It tracks the full size distribution of each species and
the plankton resource, computing growth, predation, and mortality from
individual-level physiology.

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
Change species parameters with `given_species_params(params) <- value`, which
triggers recalculation of dependent quantities.

**`MizerSim`** — simulation output from `project()`. Arrays: `N(sim)` (time ×
species × size), `NResource(sim)`.

## Species parameters

The `species_params` data frame must have `species` (name) and `w_max`
(maximum weight in grams). Everything else has defaults.

| Column | Meaning |
|--------|---------|
| `w_mat` | Maturity weight (g) |
| `beta` | Preferred predator/prey mass ratio (default ~100) |
| `sigma` | S.d. of lognormal predation kernel (default ~1.3) |
| `h` | Max intake rate coefficient |
| `alpha` | Assimilation efficiency (default 0.6) |
| `erepro` | Reproductive efficiency |
| `R_max` | Beverton-Holt max recruitment |
| `biomass_observed` | Observed biomass for `calibrateBiomass()` |
| `yield_observed` | Observed yield for `matchYields()` |

## Units

Weights in grams, lengths in cm, time in years.

## Plotting

Mizer provides many built-in plotting functions. Always prefer these over
writing custom plotting code.

```r
plot(sim)              # overview of simulation
plotSpectra(sim)       # size spectra
plotBiomass(sim)       # biomass over time
plotYield(sim)         # yield over time
plotGrowthCurves(sim)  # growth curves
plotFMort(sim)         # fishing mortality
```

The return values of most `get...()` functions also have `plot()` methods,
so you can visualise any quantity directly without writing custom plotting code:

```r
plot(getSSB(sim))           # ArrayTimeBySpecies  → time series per species
plot(getTrophicLevel(params)) # ArraySpeciesBySize → curve per species
```

Grep for "plot" in `llms-full.txt` to discover the full list of available
plots before writing any custom code. Grep for a specific function name to
look up its documentation — do not read the whole file.

## Extending mizer

To replace a rate function: `params <- setRateFunction(params, "Encounter", myFun)`.
To add a new ecosystem component: `params <- setComponent(params, "detritus", ...)`.
See https://sizespectrum.org/mizer/articles/extending-mizer.html
