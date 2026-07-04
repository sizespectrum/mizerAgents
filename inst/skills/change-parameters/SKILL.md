---
name: change-parameters
description: >-
  Change parameters of an existing mizer model correctly. Use whenever the user
  wants to modify species parameters, size-dependent rates, fishing, the
  resource, or interactions — and especially when unsure which accessor to use:
  given_species_params() vs species_params(), changing a species parameter vs
  setting a rate array directly (setSearchVolume, setPredKernel, setParams…), or
  gear_params() vs the resource setters. Follow these rules to avoid changes
  that silently fail to propagate or get overwritten.
---

# Changing model parameters

Guiding principle: **change the model at the highest level that expresses the
intent, and let mizer propagate the change downwards.** Drop to a lower level
only to deliberately override mizer's calculation. Every setter returns a **new**
`MizerParams` — always reassign (`params <- setResource(params, ...)`).

There are three levels:

1. **Species parameters** — per-species scalars (`w_inf`, `beta`, `gamma`, `h`,
   `erepro`, …). Most are used to *calculate* the size-dependent rate arrays.
2. **Size-dependent rates** — arrays over size (search volume, metabolic rate,
   predation kernel, …), built from the species parameters by `set…()` functions.
3. **Other groups** — fishing (`gear_params`), resource (`setResource`),
   interaction (`setInteraction`).

## Species parameters: which accessor

| Accessor | Returns |
|---|---|
| `given_species_params(params)` | only the parameters the user supplied |
| `calculated_species_params(params)` | parameters mizer derived or defaulted |
| `species_params(params)` | everything (given, with calculated filling gaps) |

**Rule: change species parameters with `given_species_params(params) <-`.** It
records the value as *given* and triggers recalculation of the derived scalars
**and** the size-dependent rate arrays that depend on it.

```r
given_species_params(params)$beta <- 150   # also rebuilds the predation kernel
```

Do **not** use `species_params(params) <-` for edits: it writes into the combined
table without recalculating derived scalars, and the value can be **silently
overwritten** the next time a recalculation is triggered.

Columns come back as named vectors: `species_params(params)$w_mat` is named by
species; `given_species_params(params)$gamma` is `NA` where the user never set it.

## How a species-parameter change propagates

Many species parameters exist only to set up a rate array; changing one re-runs
the relevant setter automatically:

| Species parameter(s) | Sets up | via |
|---|---|---|
| `gamma`, `q` | search volume | `setSearchVolume()` |
| `h`, `n` | maximum intake rate | `setMaxIntakeRate()` |
| `k`, `ks`, `p` | metabolic rate | `setMetabolicRate()` |
| `z0`, `z_ext`, `d` | external mortality | `setExtMort()` |
| `beta`, `sigma`, `pred_kernel_type` | predation kernel | `setPredKernel()` |
| `w_mat`, `w_mat25`, `w_repro_max`, `m` | reproduction allocation | `setReproduction()` |

Other species parameters are used **directly** and build no array (changing them
just changes the model): `alpha`, `w_min` (egg size), `erepro`, `R_max`,
`interaction_resource`, and the length–weight parameters `a`, `b`.

## Setting a rate array directly — and the freeze trap

Each rate has a setter. Called with only `params`, it **recomputes** the array
from the current species parameters:

```r
params <- setMetabolicRate(params)         # recompute from k, ks, p
params <- setParams(params)                # rebuild ALL rate arrays at once
```

**Trap:** passing an array to a setter **freezes** it. mizer marks it "set
manually" and will no longer update it from species parameters. After this,
changing the feeding species parameter has *no effect* on that rate:

```r
params <- setSearchVolume(params, search_vol = my_array)  # frozen
given_species_params(params)$gamma <- 2 * gamma           # search volume UNCHANGED now
params <- setSearchVolume(params)          # recompute to hand control back
```

If a user reports "I changed `gamma`/`h`/`beta` but nothing happened," suspect a
manually-set (frozen) rate array — recompute it with its bare `set…(params)`.

## Fishing

Gears, selectivity, and catchability live in `gear_params(params)`, one row per
gear–species pair (row names `"species, gear"`). Assigning to it **does**
recompute the fishing arrays.

```r
gp <- gear_params(params)
gp["Cod, Otter", "catchability"] <- 0.8
gear_params(params) <- gp                  # rebuilds fishing mortality
```

Use `setFishing()` for supplying selectivity/catchability arrays directly or
setting baseline effort. See the `set-up-fishing` skill.

## Resource — NOT parallel to gear_params

**Trap:** `resource_params(params)` returns scalars (`kappa`, `lambda`, `r_pp`,
`n`, `w_pp_cutoff`), but assigning to it **does not rebuild the resource arrays**
(not even followed by `setResource()`). These are essentially set-up metadata,
and the scalar `kappa`/`r_pp` arguments are deprecated.

```r
resource_params(params)$kappa <- 1e11      # stored, but resource is UNCHANGED
```

Change the resource through `setResource()` or the array replacement functions,
which take effect immediately:

```r
params <- setResource(params, resource_capacity = my_capacity)  # array over size
resource_rate(params)     <- my_rate       # array over size
resource_capacity(params) <- my_capacity
resource_level(params)    <- my_level
```

## Interaction matrix

```r
inter <- getInteraction(params)
inter["Cod", "Herring"] <- 0.5
params <- setInteraction(params, inter)
```

The resource interaction is the `interaction_resource` species-parameter column
instead.

## Which to use

| To change… | Use |
|---|---|
| a per-species value | `given_species_params(params) <- …` |
| a rate, keeping it tied to the parameters | change the underlying species parameter |
| a rate to a bespoke array (freezing it) | the matching `set…(params, array)` |
| everything after several edits | `setParams(params)` |
| fishing gears / selectivity / catchability | `gear_params(params) <- …` |
| baseline effort or selectivity arrays | `setFishing(params, …)` |
| the resource | `setResource(params, …)` or `resource_capacity(params) <- …` (**not** `resource_params(params) <-`) |
| species interactions | `setInteraction(params, …)` |
