---
name: run-simulation
description: >-
  Project a mizer model forward in time and set up fishing-effort scenarios. Use
  whenever the user wants to run a simulation with project(), specify constant or
  time-varying fishing effort, choose a projection method or time step, run to a
  new steady state after a change, continue an existing MizerSim, or set up
  scenario comparisons. For extracting and plotting the results, see the
  analyse-and-plot skill.
---

# Running a mizer simulation

`project()` advances a `MizerParams` object through time and returns a
`MizerSim`. The params object must already be set up and (usually) at steady
state — see the `build-multispecies-model` and `calibrate-model` skills.

```r
sim <- project(params, t_max = 20, effort = 1)
```

## Key `project()` arguments

| Argument | Meaning |
|---|---|
| `object` | a `MizerParams` (fresh run) or a `MizerSim` (continue from its end) |
| `effort` | fishing effort — see the four forms below |
| `t_max` | number of years to simulate (default 100) |
| `dt` | integration time step (default 0.1); reduce if the run is unstable |
| `t_save` | interval (years) at which output is stored (default 1) |
| `t_start` | initial time / calendar year for the output (default 0) |
| `method` | `"euler"` (default), `"predictor_corrector"`, or `"tr_bdf2"` |
| `callback` | a function called at each saved step (e.g. to log or intervene) |
| `progress_bar` | set `FALSE` to silence the progress bar |

## Specifying fishing effort

`effort` can be given four ways (if omitted, the model's stored
`initial_effort` is used):

```r
project(params, effort = 1)                          # 1. scalar: same for all gears, constant
project(params, effort = c(Otter = 0.5, Beam = 1))   # 2. named vector: per-gear, constant
project(params, effort = c(0.5, 1, 0))               # 3. vector in gear order, constant
project(params, effort = effort_array)               # 4. time × gear array: effort through time
```

For form 4, build a `time × gear` matrix with **numeric, increasing** row names
(times) and column names matching the gear names:

```r
gears <- names(getInitialEffort(params))             # gear names (a named vector)
years <- 2010:2030
effort_array <- array(1, dim = c(length(years), length(gears)),
                      dimnames = list(time = years, gear = gears))
effort_array[as.character(2020:2030), "Otter"] <- 1.5  # ramp one gear up from 2020
sim <- project(params, effort = effort_array)
```

Each effort value applies from its time until the next time in the array. With
an array, the simulation starts at the smallest time; use `t_max` to extend
beyond the last row.

## Common patterns

**Run to a new steady state after a change** — to get the equilibrium a change
implies (rather than a fixed number of years), use `steady()` / `projectToSteady()`
from the `calibrate-model` skill instead of a long `project()`.

**Continue a simulation** — pass a `MizerSim` back to `project()`; it resumes
from the final state:

```r
sim2 <- project(sim, t_max = 10, effort = 2)
```

**Scenario comparison** — project the same params under different efforts, then
compare with the plotting tools (`plotBiomass`, `plotYield`, `plotSpectra2`,
`plotCDF2`; see the `analyse-and-plot` skill):

```r
sim_low  <- project(params, t_max = 30, effort = 0.5)
sim_high <- project(params, t_max = 30, effort = 1.5)
plotSpectra2(sim_low, sim_high, "F = 0.5", "F = 1.5")
```

## Tips

- If a run blows up or oscillates unphysically, first reduce `dt` (e.g. `0.01`);
  a stiff model may also do better with `method = "tr_bdf2"`.
- `t_save` controls output resolution, not accuracy — the model always steps at
  `dt` internally.
- The `MizerSim` stores the `MizerParams` it used (`sim@params`), so a sim is
  self-contained for later analysis.
- To change *which* gears exist or their selectivity/catchability before running,
  see the `set-up-fishing` skill.
