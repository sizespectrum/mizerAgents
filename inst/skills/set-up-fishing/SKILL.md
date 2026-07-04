---
name: set-up-fishing
description: >-
  Set up or change fishing in a mizer model — gears, selectivity curves,
  catchability, and effort. Use whenever the user wants to define fishing gears,
  choose or configure a selectivity function (knife_edge, sigmoid_length,
  double_sigmoid_length, sigmoid_weight), set which gear catches which species,
  change catchability, or set the baseline fishing effort with setFishing() and
  the gear_params data frame.
---

# Setting up fishing

Fishing mortality in mizer is `F[g,i](w) = S[g,i](w) * Q[g,i] * E[g]` — a gear's
**selectivity** at size, times its **catchability** for a species, times its
**effort**. You configure the first two through the `gear_params` data frame and
`setFishing()`; effort at run time is handled in the `run-simulation` skill.

Setter functions return a new `MizerParams` — always reassign.

## The `gear_params` data frame

One row per **gear–species combination** (a gear that catches three species
contributes three rows). Required columns:

| Column | Meaning |
|---|---|
| `gear` | gear name |
| `species` | species this row applies to |
| `sel_func` | name of the selectivity function (e.g. `"sigmoid_length"`) |
| `catchability` | scales `F` for this gear–species pair (default 1) |

Plus **one column per parameter of the chosen `sel_func`**, named exactly like
the function's argument (see below). Read/replace the table with
`gear_params(params)` / `gear_params(params) <- ...`.

```r
gp <- gear_params(params)
gp["Cod, Otter", "catchability"] <- 0.8   # row names are "species, gear"
gear_params(params) <- gp
```

If each species is caught by only one gear, you may instead put the gear columns
directly in `species_params` when building the model; mizer copies them into
`gear_params`. (Later edits to those `species_params` columns will **not**
propagate — edit `gear_params` after construction.)

## Selectivity functions

Every selectivity function takes `w` as its first argument and returns a value in
`[0, 1]` at each size. The other arguments must appear as columns in
`gear_params`:

| `sel_func` | Parameter column(s) | Shape |
|---|---|---|
| `knife_edge` (default) | `knife_edge_size` | 0 below the size, 1 above (default size = `w_mat`) |
| `sigmoid_length` | `l50`, `l25` | smooth; lengths (cm) at 50% and 25% selection |
| `double_sigmoid_length` | `l50`, `l25`, `l50_right`, `l25_right` | dome-shaped (selects a length band) |
| `sigmoid_weight` | `sigmoidal_weight`, `sigmoidal_sigma` | smooth transition in weight |

`sigmoid_length` is the most commonly used. You can also write your own function
(first argument `w`, returns selectivity at size) and name it in `sel_func`.

```r
gp <- gear_params(params)
gp$sel_func <- "sigmoid_length"
gp$l50 <- 25            # 50% selected at 25 cm
gp$l25 <- 20            # 25% selected at 20 cm
gear_params(params) <- gp
```

## `setFishing()`

`setFishing(params, selectivity = NULL, catchability = NULL, reset = FALSE,
initial_effort = NULL, ...)` recomputes the fishing setup after a change.
Assigning `gear_params(params) <- ...` already triggers recalculation, so you
usually only call `setFishing()` when supplying a `selectivity` or `catchability`
**array** directly, or to set a baseline effort:

```r
params <- setFishing(params, initial_effort = c(Otter = 1, Beam = 0.5))
```

Use `reset = TRUE` to rebuild the selectivity/catchability arrays from
`gear_params` from scratch.

## Baseline effort

The model stores a baseline effort per gear, read with `getInitialEffort(params)`
(a named vector) and set via `initial_effort(params) <- ...` or the
`initial_effort` argument of `setFishing()`. This is the effort used when
`project()` is called without an explicit `effort` argument.

```r
initial_effort(params) <- c(Industrial = 0, Pelagic = 1, Beam = 0.5, Otter = 0.5)
```

To vary effort **through time** in a run, pass a time × gear array to
`project()` — see the `run-simulation` skill.

## Checking the setup

```r
gear_params(params)                 # the gear table
getInitialEffort(params)            # baseline effort per gear
plotFMort(params)                   # realised fishing mortality at size
getFMortGear(params)                # F by gear × species × size
```
