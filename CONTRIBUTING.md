# Contributing

Thanks for helping make Glaze & Grind better!

## Setup
1. Install [Godot 4.3+](https://godotengine.org/download) (standard build, not .NET).
2. Clone the repo and open `project.godot`.
3. Press F5 to play.

## Before you open a PR
Run both checks from the project folder:

```bash
godot --headless --path . -s tests/run_tests.gd                      # unit tests
godot --headless --fixed-fps 60 --path . -s tests/smoke_sim.gd       # 3 simulated days
```

CI runs the same commands and will block merges that fail.

## Code style
- Typed GDScript (`var x: int`, `func f() -> void`), tabs for indentation.
- Simulation rules go in `scripts/core/` as `RefCounted` classes with no node dependencies, so they can be unit tested. Pass `DB` in as a parameter instead of reaching for the autoload.
- World nodes (`scripts/world/`) handle movement, drawing and calling into core rules.
- Cross-system communication goes through `Bus` signals.
- New content belongs in `data/*.json`, not in code, whenever possible.

## Balancing changes
If you change prices, timings or traffic, include before/after output from `tests/smoke_sim.gd` in your PR so reviewers can see the effect on profit, walk-outs and rating.

## Reporting bugs
Open an issue with your platform, the day number, what happened, and what you expected. Attaching your save (`user://saves/`) helps a lot.
