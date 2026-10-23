# Modding Glaze & Grind

All game content is JSON. The base game in `data/` is loaded exactly the same way as mods, so a mod can add or change anything the base game defines.

## Where mods go

Put `.json` files in the game's user folder under `mods/`:

| Platform | Folder |
|---|---|
| Windows | `%APPDATA%\Godot\app_userdata\Glaze & Grind\mods\` |
| macOS | `~/Library/Application Support/Godot/app_userdata/Glaze & Grind/mods/` |
| Linux | `~/.local/share/godot/app_userdata/Glaze & Grind/mods/` |
| Android | the app's internal storage (`user://mods/`) |

Mods load alphabetically, after the base data. Loaded mods are listed on the main menu.

## How merging works

A mod file can contain any of these lists: `donuts`, `drinks`, `ingredients`, `customers`, `stations`, `items`, `stores`, `events`, `career`. Each entry is matched by `id` (`rank` for career):

- **Existing id** → the mod's keys are merged over the original. You only need the keys you're changing.
- **New id** → the entry is added.

You can also override single keys of `dough`, `fry` and `flavor_shot`.

## Example

See [`mods_example/pumpkin_season.json`](../mods_example/pumpkin_season.json). It adds a donut, a drink and an event, and changes what students like. Copy it into your `mods/` folder to try it.

## Field reference

### Donut
| Key | Type | Notes |
|---|---|---|
| `id` | string | unique |
| `name` | string | shown in UI |
| `price` | number | before the store's price multiplier |
| `color`, `topping` | hex colour | used to draw it |
| `finish` | {ingredient: qty} | used **per donut** at the glaze station |
| `par` | int | default case par level |
| `unlock_rank` | int | career rank needed (0–5) |
| `filled` | hex colour | optional |

### Drink
| Key | Type | Notes |
|---|---|---|
| `station` | `"coffee"` or `"cold"` | where it's made |
| `time` | seconds | base make time |
| `skill` | int 1–5 | employee level needed |
| `ingredients` | {ingredient: qty} | per drink |
| `hot` | bool | used for hot/cold preference and snow days |
| `requires_equipment` | item id | optional, e.g. `"blender"` |

### Customer type
`patience` (seconds), `spend`, `drinks` [min,max], `donuts` [min,max], `box_chance`, `favorites` [ids], `tip`, `rating_weight`, `loyalty`, `weight`, optional `hot_bias`, `special` (`"viral"` or `"critic"`), `body`/`accent` colours.

### Store
`traffic`, `price`, `rent`, `cost`, `min_rank`, `mix` {customer_id: weight}, `patience`, `staff_slots`, `wall`/`floor_a`/`floor_b` colours, optional `drink_bias`.

### Event
`weight`, `min_day`, and any of: `traffic`, `hot_bias`, `mix`, `evening_surge`, `breakdown` + `repair_cost`, `outage` {start, end, stations}, `inspection`, `sick`.

### Station upgrade / item
Stations: `costs`, `speed`, `quality`, `maintenance` arrays (one entry per level), optional `min_rank` array.
Items: `cost`, `maintenance`, `min_rank`, `desc`. Item effects are coded by id (`register2`, `blender`, `break_room`, `auto_glazer`, `smart_inventory`, `big_case`); new item ids can be used as `requires_equipment` for drinks.
