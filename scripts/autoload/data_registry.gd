extends Node
## Loads all game content from JSON, then merges mods on top.
## Base content and mods go through the exact same path, so anything the base
## game can define, a mod can add or override.

const DATA_DIR := "res://data/"
const MOD_DIR := "user://mods/"
const LIST_KEYS := ["donuts", "drinks", "ingredients", "customers", "stations", "items", "stores", "events", "career"]

var donuts: Array = []
var drinks: Array = []
var ingredients: Array = []
var customers: Array = []
var stations: Array = []
var items: Array = []
var stores: Array = []
var events: Array = []
var career: Array = []
var dough: Dictionary = {}
var fry: Dictionary = {}
var flavor_shot: Dictionary = {}
var daily_event_chance: float = 0.45
var loaded_mods: PackedStringArray = []
var load_errors: PackedStringArray = []

var _index: Dictionary = {}  # "<list>:<id>" -> Dictionary


func _ready() -> void:
	load_all()


func load_all(mod_dir: String = MOD_DIR) -> void:
	for k in LIST_KEYS:
		set(k, [])
	loaded_mods.clear()
	load_errors.clear()

	var recipes := _read_json(DATA_DIR + "recipes.json")
	donuts = recipes.get("donuts", [])
	drinks = recipes.get("drinks", [])
	dough = recipes.get("dough", {})
	fry = recipes.get("fry", {})
	flavor_shot = recipes.get("flavor_shot", {})
	ingredients = _read_json(DATA_DIR + "ingredients.json").get("ingredients", [])
	customers = _read_json(DATA_DIR + "customers.json").get("customers", [])
	var equip := _read_json(DATA_DIR + "equipment.json")
	stations = equip.get("stations", [])
	items = equip.get("items", [])
	var st := _read_json(DATA_DIR + "stores.json")
	stores = st.get("stores", [])
	career = st.get("career", [])
	var ev := _read_json(DATA_DIR + "events.json")
	events = ev.get("events", [])
	daily_event_chance = float(ev.get("daily_event_chance", 0.45))

	_load_mods(mod_dir)
	_rebuild_index()


func _load_mods(dir_path: String) -> void:
	if not DirAccess.dir_exists_absolute(dir_path):
		return
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	var files: Array = []
	for f in dir.get_files():
		if f.get_extension().to_lower() == "json":
			files.append(f)
	files.sort()  # deterministic load order: alphabetical
	for f in files:
		var data := _read_json(dir_path.path_join(f))
		if data.is_empty():
			continue
		apply_mod(data)
		loaded_mods.append(str(data.get("name", f)))


## Merge one mod dictionary into the registry. Entries with an existing id are
## shallow-merged (mod keys win); new ids are appended.
func apply_mod(mod: Dictionary) -> void:
	for key in LIST_KEYS:
		if not mod.has(key) or typeof(mod[key]) != TYPE_ARRAY:
			continue
		var base: Array = get(key)
		for entry in mod[key]:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var id_field := "rank" if key == "career" else "id"
			if not entry.has(id_field):
				load_errors.append("Mod entry in '%s' missing '%s'" % [key, id_field])
				continue
			var found := false
			for existing in base:
				if existing.get(id_field) == entry[id_field]:
					existing.merge(entry, true)
					found = true
					break
			if not found:
				base.append(entry.duplicate(true))
	for key in ["dough", "fry", "flavor_shot"]:
		if mod.has(key) and typeof(mod[key]) == TYPE_DICTIONARY:
			(get(key) as Dictionary).merge(mod[key], true)
	_rebuild_index()


func _rebuild_index() -> void:
	_index.clear()
	for key in LIST_KEYS:
		for e in get(key):
			if e.has("id"):
				_index["%s:%s" % [key, e["id"]]] = e


func find(list_key: String, id: String) -> Dictionary:
	return _index.get("%s:%s" % [list_key, id], {})


func donut(id: String) -> Dictionary: return find("donuts", id)
func drink(id: String) -> Dictionary: return find("drinks", id)
func ingredient(id: String) -> Dictionary: return find("ingredients", id)
func customer_type(id: String) -> Dictionary: return find("customers", id)
func station(id: String) -> Dictionary: return find("stations", id)
func item(id: String) -> Dictionary: return find("items", id)
func store(id: String) -> Dictionary: return find("stores", id)
func event(id: String) -> Dictionary: return find("events", id)


## Any menu item (donut or drink) by id.
func menu_item(id: String) -> Dictionary:
	var d := donut(id)
	return d if not d.is_empty() else drink(id)


func career_rank(rank: int) -> Dictionary:
	for c in career:
		if int(c.get("rank", -1)) == rank:
			return c
	return {}


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		load_errors.append("Missing data file: " + path)
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		load_errors.append("Invalid JSON: " + path)
		push_warning("Glaze & Grind: could not parse " + path)
		return {}
	return parsed
