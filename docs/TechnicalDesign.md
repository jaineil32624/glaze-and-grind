# Glaze & Grind — Technical Design Document

**Engine:** Godot 4.3+ (GDScript, typed) · **Renderer:** Compatibility (GL ES 3 / WebGL 2) so one build path covers desktop, Web and low-end Android.

---

## 1. Principles

1. **Data-driven.** Every recipe, customer type, equipment item, store and event lives in `data/*.json`. Mods in `user://mods/*.json` are merged on top using the same loader.
2. **Simulation is separate from presentation.** Business rules (ledger, inventory, orders, task board, staff stats, traffic, career) are plain `RefCounted` classes with no node dependencies, so they're unit-testable headlessly.
3. **Nodes are thin.** World nodes (`Employee`, `Customer`, `Station`) own movement, animation and drawing, and call into the core classes for decisions.
4. **Signals over references.** Cross-system communication goes through the `Bus` autoload.
5. **No external assets required.** Art is drawn procedurally (`_draw()`), audio is synthesised at boot. The game runs from a fresh clone.

## 2. Autoload singletons

| Name | Script | Responsibility |
|---|---|---|
| `Bus` | `scripts/autoload/event_bus.gd` | Global signals (order_completed, mistake, money_changed, toast, …) |
| `DB` | `scripts/autoload/data_registry.gd` | Loads and merges JSON content + mods; lookup by id |
| `Game` | `scripts/autoload/game_state.gd` | Persistent profile: money, day, career XP, owned stores, per-store state, settings |
| `Saves` | `scripts/autoload/save_system.gd` | Slot saves, autosave, versioned schema + migration, optional cloud provider |
| `Sfx` | `scripts/autoload/audio_manager.gd` | Procedural SFX/music generation and playback buses |

Load order matters: `Bus` → `DB` → `Game` → `Saves` → `Sfx`.

## 3. Core simulation classes (`scripts/core/`)

| Class | Purpose |
|---|---|
| `Ledger` | Daily revenue/expense categories, profit, history |
| `Inventory` | Ingredient counts, consume/can_afford checks, restock, shortage detection |
| `Order` | A customer order: lines (donuts from case, drinks to make), price, quality, accuracy |
| `WorkTask` | A unit of work for a station (kind, station type, duration, priority, claimant, progress) |
| `TaskBoard` | Holds open tasks; scoring/claiming; production tasks from par levels |
| `StaffData` | Employee stats, personality, stress/happiness, XP/levels, skill checks, mistake roll |
| `CustomerProfile` | Generated customer (type, patience, spend, favourites, loyalty) + order generation |
| `DayClock` | Game time, phases, traffic curve |
| `EventDirector` | Rolls and applies daily random events |
| `Career` | Rank thresholds and unlocks |
| `FryCurve` | Quality curve for fry timing (shared by AI and player minigame) |
| `BT` | Minimal behaviour-tree library: `Selector`, `Sequence`, `Condition`, `Action` |

## 4. Scene & node tree

All scenes are assembled in code from `scenes/main.tscn` so the project has no fragile scene dependencies.

```
Main (Node)                                   scripts/main.gd — app state machine
├── World (StoreWorld : Node2D)               scripts/world/store_world.gd
│   ├── Floor (Node2D, _draw)                 tiles, walls, windows (sky colour by time)
│   ├── Stations (Node2D)
│   │   ├── Mixer / Fryer / Glaze / CoffeeBar / ColdBar / Register×N / Pickup (Station)
│   │   └── DisplayCase (Station)
│   ├── Actors (Node2D, y_sort_enabled)
│   │   ├── Employee ×N (Node2D + BT)          scripts/world/employee.gd
│   │   └── Customer ×N (Node2D)               scripts/world/customer.gd
│   ├── Lamps (PointLight2D ×N)
│   ├── FX (Node2D)                            floating text, CPUParticles2D bursts
│   └── CanvasModulate                         day/night tint
└── UI (CanvasLayer)
    ├── HUD (Control)                          scripts/ui/hud.gd
    ├── Dashboard (PanelContainer)             scripts/ui/dashboard.gd + LineGraph
    ├── StaffCard (PanelContainer)             scripts/ui/staff_card.gd
    ├── FryOverlay (Control)                   scripts/ui/fry_overlay.gd
    ├── Toasts (VBoxContainer)
    ├── SummaryScreen / ManagementScreen / MainMenu / PauseMenu
```

## 5. Game states (`main.gd`)

```
BOOT → MAIN_MENU → (new/load) → SHIFT ⇄ PAUSED
                                  │ 20:00 and store empty
                                  ▼
                               SUMMARY → MANAGEMENT → (autosave) → SHIFT
```

## 6. Task system

Tasks are the contract between the store and the crew.

| Kind | Station | Created when |
|---|---|---|
| `take_order` | register | customer reaches register |
| `mix_dough` | mixer | dough < 12 and a fry task needs it |
| `fry_batch` | fryer | donut case count + in-progress < par |
| `finish_batch` | glaze | a fried batch is waiting |
| `make_drink` | coffee / cold | order placed with a drink line |
| `assemble` | pickup | all drink lines for an order are done |

**Priority score** (higher = sooner):
`base[kind] + urgency(customer mood) + age_seconds*0.5 + focus_bonus + skill_fit − distance*0.002`

Employees claim one task at a time. Claims are released if the employee goes on break, so another crew member can pick it up.

## 7. Employee behaviour tree

```
Selector
├── Sequence  "Break"
│   ├── Condition  needs_break()        stress > threshold or on_break
│   └── Action     do_break()           walk to break room, rest until stress < 25
├── Sequence  "Work"
│   ├── Condition  has_task()
│   └── Action     do_task()            walk → work (progress += dt * speed * station mult * assist)
├── Sequence  "Pick"
│   ├── Action     pick_task()          TaskBoard.best_for(self)
├── Sequence  "Assist"
│   ├── Condition  wants_assist()       teamwork roll vs. busy coworker
│   └── Action     do_assist()
└── Action    do_idle()                 clean or wander; raises cleanliness
```

Each node returns `SUCCESS`, `FAILURE` or `RUNNING`; the tree ticks every physics frame.

## 8. Mistake model

```
p_mistake = base[kind] * (11 - accuracy)/10 * stress_mult * personality_mult * (1 - 0.08*(level-1))
stress_mult = 1.0 (stress<50), 1.4 (<75), 2.0 (≥75)
```
Outcomes by kind: `fry_batch` → burned (waste 6 dough), `make_drink` → spilled (waste ingredients, redo), `finish_batch` → forgot topping (quality ×0.6), `assemble` → wrong order (mood −25, redo), shift start → late arrival (reliability roll).

## 9. Save system

- Location: `user://saves/slot_<n>.json` (slots 1–3) and `user://saves/autosave.json`.
- Format: JSON with `schema_version`. `Saves.migrate()` upgrades older versions step by step.
- Saved: profile (money, day, career XP, settings), owned stores and each store's equipment levels, inventory, staff, par levels, rating, stats history.
- **Not saved:** transient in-shift entities (customers, tasks). Saves happen at day boundaries; a mid-shift manual save stores the profile as of the start of the current day.
- **Cloud:** `Saves.cloud_provider` is an interface (`push(slot, json)`, `pull(slot)`). Ships with `LocalMirrorProvider` (copies to `user://cloud_mirror/`) and `HttpProvider` (POST/GET to a configurable endpoint). Disabled by default.

## 10. Modding

`DB` loads `res://data/{recipes,ingredients,customers,equipment,stores,events}.json`, then every `user://mods/*.json`. Each mod file can contain any of those keys; entries are merged by `id` (override or add). See `docs/MODDING.md`.

## 11. Input

Input actions are registered at boot by `Game._setup_input()` (keeps `project.godot` readable):
`pause` (Space/P / Start), `speed_1..3` (1/2/3, RB = 3×), `toggle_dashboard` (D/Tab / Back), `quick_save` (F5), `menu` (Esc / Guide), `fry_pull` (F / X / tap). All UI is focus-navigable for gamepads; everything tappable is ≥ 48 px on mobile.

## 12. Display

Base resolution 1280×720, `stretch_mode = canvas_items`, `aspect = expand`. The world is centred and scaled to fit; the HUD anchors to edges so ultrawide and tall phone screens both work.

## 13. Testing

`tests/run_tests.gd` (extends `SceneTree`) runs headless unit tests for the core classes:
ledger maths, inventory consume/shortage, order pricing, task scoring, mistake probability bounds, fry curve, career ranks, data registry + mod merge, save round-trip and migration.

CI command: `godot --headless --path . -s tests/run_tests.gd` (exit code = failures).

## 14. Build & CI

`.github/workflows/ci.yml`: import → tests → export Linux, Windows, Web, Android APK (debug-signed) on every push; on `v*` tags, a GitHub Release is created with all artifacts attached. macOS and iOS presets are included for local export (Apple signing can't be automated without your certificates).
