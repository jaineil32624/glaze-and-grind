<p align="center"><img src="assets/marketing/github_social_preview.png" alt="Glaze & Grind — Donut & Coffee Shop Tycoon"></p>

<p align="center">
  <a href="https://jaineil32624.github.io/glaze-and-grind/play/"><b>▶ Play in your browser</b></a> ·
  <a href="https://github.com/jaineil32624/glaze-and-grind/releases/latest/download/GlazeAndGrind.apk"><b>📱 Android APK</b></a> ·
  <a href="https://github.com/jaineil32624/glaze-and-grind/releases/latest/download/GlazeAndGrind.exe"><b>🪟 Windows</b></a> ·
  <a href="https://github.com/jaineil32624/glaze-and-grind/releases/latest/download/GlazeAndGrind.x86_64"><b>🐧 Linux</b></a> ·
  <a href="https://jaineil32624.github.io/glaze-and-grind/"><b>🌐 Website</b></a>
</p>

<p align="center">
  <a href="../../actions/workflows/ci.yml"><img src="../../actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <img src="https://img.shields.io/badge/Godot-4.3-478cbf?logo=godotengine&logoColor=white" alt="Godot 4.3">
  <img src="https://img.shields.io/badge/platforms-Windows%20%7C%20Linux%20%7C%20macOS%20%7C%20Web%20%7C%20Android-ff6f91" alt="Platforms">
  <img src="https://img.shields.io/badge/license-MIT-2fae6b" alt="MIT">
</p>

Run a bustling donut shop through the morning rush. Your crew fries, glazes, brews and steams **on their own** — you're the manager deciding who works where, what to stock, which machines to buy, and when to jump in and pull a batch out of the fryer yourself. Build a five-star reputation, open new locations, and climb from **Trainee** to **CEO**.

> Inspired by Papa's Donuteria, Diner Dash and Two Point Hospital. An original brand — not affiliated with any real coffee or donut chain.

---

## Features

**Restaurant management**
- Customers queue, order at the register, wait at pickup and pay — with tips based on speed and quality
- Donuts are made the way real shops do it: **mix dough → fry a batch of 6 → glaze & top → display case**
- **Fryer minigame**: tap the fryer and stop the needle in the green zone for a *PERFECT* batch (or burn it)
- 8 made-to-order drinks: hot coffee, tea, espresso, latte, cappuccino, iced coffee, berry refresher, frozen coffee, plus flavour shots

**Autonomous crew (behaviour trees)**
- Every employee has Speed, Accuracy, Intelligence, Teamwork, Reliability, Stress, Happiness and XP
- They pick the most urgent task themselves, help busy coworkers, clean when idle and take breaks when stressed
- Personalities: Steady, Cheerful, Perfectionist, Speedy, Chatty
- Real mistakes: burned batches, spilled drinks, wrong orders, forgotten toppings, bad dough, late arrivals
- Level up to unlock espresso and blended drinks; set a **focus station** per employee

**Customers**
- Students, business workers, families, tourists, **influencers** (can go viral) and **food critics** (reviews count ×5)
- Patience, mood, loyalty, spending level and favourite items; regulars come back and spend more

**Tycoon layer**
- 13 tracked ingredients — run out and items vanish from the menu; rush deliveries cost 1.5×
- Upgrade 7 stations through 3–4 levels, plus a 2nd register, blender, comfy break room, Auto-Glazer, Smart Inventory and bigger display case
- Full ledger: sales, tips, ingredients, wages, rent, maintenance, repairs, fines
- **6 locations** (Main Street → Mall → Highway → Airport → City Center → Mega Flagship) with their own traffic, prices, rent and customer mix; stores you're not running earn passive income
- Career: Trainee → Shift Manager → Store Manager → District Manager → Regional Director → CEO

**Days & events**
- Morning rush, lunch rush, afternoon slowdown, evening rush, with dawn-to-night lighting and lamps
- Random events: Snow Day, Holiday Rush, School Opening, Championship Night, Equipment Breakdown, Power Outage, Health Inspection, Sick Day, Viral Post

**Everything else**
- Live dashboard with real-time graphs (revenue, profit, happiness, crew efficiency, rating, waste, revenue by hour)
- 3 save slots + autosave, versioned save schema with migration, optional cloud mirror / HTTP sync
- **JSON modding** — recipes, customers, stores, equipment, events ([guide](docs/MODDING.md))
- All sound and music is synthesised at runtime — no licensed assets
- Responsive layout from phones to ultrawide; mouse, touch, keyboard and gamepad

## Screenshots

| Morning rush | Crew stats & focus |
|---|---|
| ![Morning rush](docs/screenshots/02_morning_rush.png) | ![Staff card](docs/screenshots/03_staff_card.png) |
| **Fryer minigame** | **Live dashboard** |
| ![Fryer minigame](docs/screenshots/05_fryer_minigame.png) | ![Dashboard](docs/screenshots/04_dashboard.png) |
| **Evening lights** | **End-of-day ledger** |
| ![Evening](docs/screenshots/07_evening.png) | ![Summary](docs/screenshots/08_day_summary.png) |
| **Upgrades** | **Expand to new stores** |
| ![Upgrades](docs/screenshots/11_management_upgrades.png) | ![Stores](docs/screenshots/12_management_stores.png) |

<details><summary>More screenshots</summary>

| | |
|---|---|
| ![Main menu](docs/screenshots/01_main_menu.png) | ![Rush restock](docs/screenshots/06_rush_restock.png) |
| ![Restock](docs/screenshots/09_management_restock.png) | ![Staff](docs/screenshots/10_management_staff.png) |

</details>

## Concept art

| | |
|---|---|
| ![Store exterior](assets/concept/store_exterior.png) | ![Store interior](assets/concept/store_interior.png) |
| ![Production line](assets/concept/donut_production_line.png) | ![Customer types](assets/concept/customer_types.png) |
| ![Workstation](assets/concept/employee_workstation.png) | ![Coffee machines](assets/concept/coffee_machines.png) |
| ![Upgrade shop](assets/concept/upgrade_shop.png) | ![Dashboard UI](assets/concept/dashboard_ui.png) |

Every piece ships as **SVG (source) + PNG** in [`assets/concept/`](assets/concept). Store/marketing graphics (app icons 512/1024, Play Store feature graphic, Steam capsule, social preview) are in [`assets/marketing/`](assets/marketing). Regenerate with `python3 tools/make_concept_art.py && python3 tools/svg_to_png.py`.

## Brand colors

| Swatch | Name | Hex | Used for |
|---|---|---|---|
| ![](https://img.shields.io/badge/-%20%20%20%20-ff6f91?style=flat-square) | Glaze Pink | `#ff6f91` | Brand, uniforms, primary buttons |
| ![](https://img.shields.io/badge/-%20%20%20%20-e8457a?style=flat-square) | Deep Pink | `#e8457a` | Headings, visors, accents |
| ![](https://img.shields.io/badge/-%20%20%20%20-fff8ec?style=flat-square) | Cream | `#fff8ec` | Panels, aprons |
| ![](https://img.shields.io/badge/-%20%20%20%20-3a2a22?style=flat-square) | Espresso Ink | `#3a2a22` | Text |
| ![](https://img.shields.io/badge/-%20%20%20%20-4f8cff?style=flat-square) | Sky Blue | `#4f8cff` | Info, speed controls, staff levels |
| ![](https://img.shields.io/badge/-%20%20%20%20-2fae6b?style=flat-square) | Mint Green | `#2fae6b` | Money, success, perfect fry zone |
| ![](https://img.shields.io/badge/-%20%20%20%20-ffd23f?style=flat-square) | Sprinkle Yellow | `#ffd23f` | Highlights, focus rings |
| ![](https://img.shields.io/badge/-%20%20%20%20-ff8a3d?style=flat-square) | Maple Orange | `#ff8a3d` | Warnings, fryer, stock |
| ![](https://img.shields.io/badge/-%20%20%20%20-c45bff?style=flat-square) | Berry Purple | `#c45bff` | Influencers, events |

### Regenerating screenshots

Screenshots are captured straight from the game (no editor needed):

```bash
xvfb-run -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --fixed-fps 60 \
  --resolution 1280x720 --path . -s tests/screenshots.gd
```

They're written to `docs/screenshots/` (main menu, morning rush, staff card, dashboard, fryer minigame, restock, evening, day summary, management tabs).

## Play it

**From source (any OS):**
1. Install [Godot 4.3+](https://godotengine.org/download) (standard, not .NET)
2. Clone this repo and open `project.godot` in Godot
3. Press **F5**

**In your browser:** [jaineil32624.github.io/glaze-and-grind/play](https://jaineil32624.github.io/glaze-and-grind/play/) — no install, works on desktop and mobile browsers.

**Downloads** (latest release):

| Platform | Download | Notes |
|---|---|---|
| 📱 Android | [GlazeAndGrind.apk](https://github.com/jaineil32624/glaze-and-grind/releases/latest/download/GlazeAndGrind.apk) | Allow "install unknown apps" |
| 🪟 Windows | [GlazeAndGrind.exe](https://github.com/jaineil32624/glaze-and-grind/releases/latest/download/GlazeAndGrind.exe) | Single file, just run it |
| 🐧 Linux | [GlazeAndGrind.x86_64](https://github.com/jaineil32624/glaze-and-grind/releases/latest/download/GlazeAndGrind.x86_64) | `chmod +x` then run |
| 🌐 Web | [GlazeAndGrind-web.zip](https://github.com/jaineil32624/glaze-and-grind/releases/latest/download/GlazeAndGrind-web.zip) | Host on any static server |
| 📦 Source | [main.zip](https://github.com/jaineil32624/glaze-and-grind/archive/refs/heads/main.zip) | Open in Godot 4.3 |

## Controls

| Action | Keyboard / Mouse | Touch | Gamepad |
|---|---|---|---|
| Select crew / customer / station | Left click | Tap | — |
| Pause / resume | Space or P | ⏸ button | Start |
| Speed 1× / 2× / 3× | 1 / 2 / 3 | buttons | RB = 3× |
| Pull the fryer batch | F | PULL button | X |
| Dashboard | D or Tab | Stats button | Back/Select |
| Quick save (slot 1) | F5 | — | — |
| Pause menu | Esc | ☰ button | Guide |

## How to play
1. **Shift:** customers arrive in waves. Watch the order tickets (top right) and the crew strip (bottom left). Tap a stressed employee to send them on a break, or give someone a focus station during a rush.
2. **Frying:** when a batch is in the oil, tap the Fryer and hit **PULL** in the green zone.
3. **Low stock?** Hit **Stock** for a rush delivery.
4. **After closing:** review the ledger, then restock, hire, upgrade, tweak par levels and expand.

## Build & export

Export presets are included for **Windows, Linux, Web, Android APK, Android AAB (Play Store), macOS and iOS**.

```bash
# one-time: install export templates from the Godot editor (Editor → Manage Export Templates)
godot --headless --path . --export-release "Linux"           builds/linux/GlazeAndGrind.x86_64
godot --headless --path . --export-release "Windows Desktop" builds/windows/GlazeAndGrind.exe
godot --headless --path . --export-release "Web"             builds/web/index.html
godot --headless --path . --export-release "Android"         builds/android/GlazeAndGrind.apk
```

- **Android:** set your Android SDK path and keystore in *Editor Settings → Export → Android*. For the Play Store, use the **Android AAB** preset (needs *Project → Install Android Build Template*) and a release keystore.
- **macOS / iOS:** export from a Mac; iOS needs Xcode and your Apple Team ID in the preset.

### CI/CD
Every push runs [`.github/workflows/ci.yml`](.github/workflows/ci.yml):
1. Unit tests (`tests/run_tests.gd`)
2. A headless 3-day gameplay simulation (`tests/smoke_sim.gd`)
3. Exports for Linux, Windows, Web and Android (debug-signed APK) uploaded as artifacts

Push a tag like `v0.1.0-alpha` and the builds are attached to a GitHub Release automatically.

## Run the tests

```bash
godot --headless --path . -s tests/run_tests.gd                   # unit tests
godot --headless --fixed-fps 60 --path . -s tests/smoke_sim.gd    # plays 3 days, prints the ledger
```

## Project structure

```
├── data/                  game content (JSON): recipes, ingredients, customers, equipment, stores, events
├── scenes/main.tscn       entry scene (everything else is built in code)
├── scripts/
│   ├── autoload/          Bus (signals), DB (data + mods), Game (profile), Saves, Sfx
│   ├── core/              pure simulation: ledger, inventory, orders, tasks, staff, behaviour trees, clock…
│   ├── world/             store layout, stations, employees, customers, FX
│   └── ui/                HUD, dashboard graphs, management, summary, menus, theme
├── tests/                 unit tests, gameplay simulation, screenshot capture
├── docs/                  Game Design Document, Technical Design, Modding guide, Roadmap
├── mods_example/          a sample mod (Pumpkin Season)
└── .github/workflows/     CI + exports + releases
```

Read the [Game Design Document](docs/GameDesignDocument.md) and [Technical Design](docs/TechnicalDesign.md) for the full breakdown.

## Roadmap
See [docs/Roadmap.md](docs/Roadmap.md) — next up: drive-thru, delivery orders, sprite art pass, Steam/Play achievements, leaderboards and co-op.

## License
[MIT](LICENSE) © 2026 Jaineil Rana
