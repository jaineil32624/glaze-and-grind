extends Node
## The player's persistent profile: money, career, owned stores, settings.

const START_MONEY := 600.0
const STARTING_CREW := 3

var money: float = START_MONEY
var day: int = 1
var lifetime_profit: float = 0.0
var career_rank: int = 0
var active_store: String = "main_street"
var stores: Dictionary = {}      # store_id -> StoreState
var candidates: Array = []       # StaffData available to hire today
var settings := {"music": 0.6, "sfx": 0.8, "show_tutorial": true, "cloud": "off", "cloud_url": ""}
var today_event: Dictionary = {}
var rng := RandomNumberGenerator.new()
var time_scale: float = 1.0
var started: bool = false


func _ready() -> void:
	rng.randomize()
	_setup_input()
	_setup_font_fallback()


## Web builds have no system fonts, so symbols like ★ ♥ → ✕ would render as
## boxes. Bundle DejaVu Sans as a fallback behind the default font.
func _setup_font_fallback() -> void:
	var fb: Font = load("res://assets/fonts/DejaVuSans-Bold.ttf")
	if fb == null:
		return
	var base: Font = ThemeDB.fallback_font
	if base != null and not base.fallbacks.has(fb):
		var list := base.fallbacks.duplicate()
		list.append(fb)
		base.fallbacks = list


# --- Profile lifecycle --------------------------------------------------------

func new_game(seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	money = START_MONEY
	day = 1
	lifetime_profit = 0.0
	career_rank = 0
	active_store = "main_street"
	stores.clear()
	var s := StoreState.new()
	s.setup_new(active_store, DB)
	# Starting crew: decent but unremarkable
	for i in STARTING_CREW:
		var st := StaffData.generate(rng, 0.3)
		s.staff.append(st)
	# Make sure at least one person can pull espresso on day 1
	s.staff[0].level = 2
	s.staff[0].xp = StaffData.XP_LEVELS[1]
	stores[active_store] = s
	today_event = {}
	refresh_candidates()
	started = true
	Bus.money_changed.emit(money)


func current() -> StoreState:
	return stores.get(active_store)


func store_def() -> Dictionary:
	return DB.store(active_store)


func rank_title(rank: int = -1) -> String:
	return str(DB.career_rank(career_rank if rank < 0 else rank).get("title", "Trainee"))


# --- Money --------------------------------------------------------------------

func earn(amount: float, category: String, hour: float = -1.0) -> void:
	money += amount
	current().ledger.add_revenue(category, amount, hour)
	Bus.money_changed.emit(money)


func spend(amount: float, category: String) -> bool:
	if amount > money + 0.001:
		return false
	money -= amount
	current().ledger.add_expense(category, amount)
	Bus.money_changed.emit(money)
	return true


## Charge even if it goes negative (wages, rent). Debt is allowed but hurts.
func charge(amount: float, category: String) -> void:
	money -= amount
	current().ledger.add_expense(category, amount)
	Bus.money_changed.emit(money)


# --- Menu availability --------------------------------------------------------

func is_unlocked(item_id: String) -> bool:
	var def: Dictionary = DB.menu_item(item_id)
	if def.is_empty():
		return false
	if career_rank < int(def.get("unlock_rank", 0)):
		return false
	var req: String = def.get("requires_equipment", "")
	if req != "" and not current().has_item(req):
		return false
	return true


# --- Hiring -------------------------------------------------------------------

func refresh_candidates() -> void:
	candidates.clear()
	var bias := career_rank * 0.35
	for i in 3:
		candidates.append(StaffData.generate(rng, bias))


func hire_cost(s: StaffData) -> float:
	return snappedf(25.0 + s.stat_total() * 2.0, 1.0)


func staff_slots() -> int:
	var base := int(store_def().get("staff_slots", 3))
	return base + (1 if career_rank >= 1 else 0)


# --- Career -------------------------------------------------------------------

func update_career() -> bool:
	var new_rank := Career.rank_for(DB.career, lifetime_profit, current().rating, career_rank)
	if new_rank > career_rank:
		career_rank = new_rank
		Bus.rank_up.emit(career_rank, rank_title())
		return true
	return false


## Passive income from owned stores the player isn't currently running.
func passive_income() -> float:
	var total := 0.0
	for id in stores:
		if id == active_store:
			continue
		var s: StoreState = stores[id]
		var def := DB.store(id)
		var base := 120.0 * float(def.get("traffic", 1.0)) * float(def.get("price", 1.0))
		total += base * (s.rating / 5.0) * clampf(s.staff.size() / 3.0, 0.3, 1.5) - float(def.get("rent", 0))
	return snappedf(total, 0.01)


# --- Serialization ------------------------------------------------------------

func to_dict() -> Dictionary:
	var st := {}
	for id in stores:
		st[id] = stores[id].to_dict()
	return {
		"money": money, "day": day, "lifetime_profit": lifetime_profit, "career_rank": career_rank,
		"active_store": active_store, "stores": st, "settings": settings.duplicate(),
	}


func from_dict(d: Dictionary) -> void:
	money = float(d.get("money", START_MONEY))
	day = int(d.get("day", 1))
	lifetime_profit = float(d.get("lifetime_profit", 0.0))
	career_rank = int(d.get("career_rank", 0))
	active_store = d.get("active_store", "main_street")
	stores.clear()
	for id in d.get("stores", {}):
		stores[id] = StoreState.from_dict(d["stores"][id])
	settings.merge(d.get("settings", {}), true)
	today_event = {}
	refresh_candidates()
	started = true
	Bus.money_changed.emit(money)


# --- Input --------------------------------------------------------------------

func _setup_input() -> void:
	_bind("pause", [KEY_SPACE, KEY_P], [JOY_BUTTON_START])
	_bind("speed_1", [KEY_1], [])
	_bind("speed_2", [KEY_2], [])
	_bind("speed_3", [KEY_3], [JOY_BUTTON_RIGHT_SHOULDER])
	_bind("toggle_dashboard", [KEY_D, KEY_TAB], [JOY_BUTTON_BACK])
	_bind("quick_save", [KEY_F5], [])
	_bind("fry_pull", [KEY_F], [JOY_BUTTON_X])
	_bind("menu", [KEY_ESCAPE], [JOY_BUTTON_GUIDE])


func _bind(action: String, keys: Array, buttons: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
	for b in buttons:
		var jb := InputEventJoypadButton.new()
		jb.button_index = b
		InputMap.action_add_event(action, jb)
