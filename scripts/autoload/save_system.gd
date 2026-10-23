extends Node
## JSON save slots with schema versioning, autosave and optional cloud mirror.

const SCHEMA_VERSION := 2
const SAVE_DIR := "user://saves/"
const AUTOSAVE := "autosave"
const SLOTS := ["slot_1", "slot_2", "slot_3"]

var cloud_provider = null        # CloudProvider-like: has push(slot, json) / pull(slot)
var save_dir: String = SAVE_DIR


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(save_dir)
	configure_cloud()


func configure_cloud() -> void:
	match str(Game.settings.get("cloud", "off")):
		"mirror":
			cloud_provider = LocalMirrorProvider.new()
		"http":
			var p := HttpProvider.new()
			p.endpoint = str(Game.settings.get("cloud_url", ""))
			add_child(p)
			cloud_provider = p
		_:
			cloud_provider = null


func path_for(slot: String) -> String:
	return save_dir.path_join(slot + ".json")


func has_save(slot: String) -> bool:
	return FileAccess.file_exists(path_for(slot))


## Save the current profile, or `game_data` if given (e.g. a start-of-day snapshot).
func save(slot: String, game_data: Dictionary = {}) -> bool:
	DirAccess.make_dir_recursive_absolute(save_dir)
	var payload := {
		"schema_version": SCHEMA_VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"game": game_data if not game_data.is_empty() else Game.to_dict(),
	}
	var text := JSON.stringify(payload, "  ")
	# Write to a temp file first, then swap, so a crash never leaves a half-written save.
	var tmp := path_for(slot) + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Save failed: " + str(FileAccess.get_open_error()))
		return false
	f.store_string(text)
	f.close()
	if FileAccess.file_exists(path_for(slot)):
		DirAccess.remove_absolute(path_for(slot))
	DirAccess.rename_absolute(tmp, path_for(slot))
	if cloud_provider != null:
		cloud_provider.push(slot, text)
	return true


func load_slot(slot: String) -> bool:
	if not has_save(slot):
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path_for(slot)))
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var data := migrate(parsed)
	Game.from_dict(data.get("game", {}))
	return true


func summary(slot: String) -> String:
	if not has_save(slot):
		return "Empty"
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path_for(slot)))
	if typeof(parsed) != TYPE_DICTIONARY:
		return "Corrupt save"
	var g: Dictionary = migrate(parsed).get("game", {})
	return "Day %d · $%s · %s" % [int(g.get("day", 1)), _fmt(float(g.get("money", 0))),
		str(DB.store(str(g.get("active_store", "main_street"))).get("name", "Store"))]


func delete(slot: String) -> void:
	if has_save(slot):
		DirAccess.remove_absolute(path_for(slot))


## Bring older save data up to the current schema, one version at a time.
static func migrate(data: Dictionary) -> Dictionary:
	var v := int(data.get("schema_version", 1))
	if v < 2:
		# v1 stored a single store at the top level as "store"
		var g: Dictionary = data.get("game", {})
		if g.has("store") and not g.has("stores"):
			var st: Dictionary = g["store"]
			g["stores"] = {st.get("id", "main_street"): st}
			g["active_store"] = st.get("id", "main_street")
			g.erase("store")
		data["game"] = g
		v = 2
	data["schema_version"] = v
	return data


static func _fmt(n: float) -> String:
	var s := str(int(round(n)))
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0 and s[i - 1] != "-":
			out = "," + out
	return out


# --- Cloud providers ------------------------------------------------------------

class CloudProvider extends RefCounted:
	func push(_slot: String, _json: String) -> void:
		pass
	func pull(_slot: String) -> String:
		return ""


## Mirrors saves to a second folder. Point it at a synced folder (Dropbox, iCloud
## Drive, Steam Cloud's remote directory) to get cross-device saves.
class LocalMirrorProvider extends CloudProvider:
	var dir := "user://cloud_mirror/"
	func push(slot: String, json: String) -> void:
		DirAccess.make_dir_recursive_absolute(dir)
		var f := FileAccess.open(dir.path_join(slot + ".json"), FileAccess.WRITE)
		if f:
			f.store_string(json)
	func pull(slot: String) -> String:
		var p := dir.path_join(slot + ".json")
		return FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else ""


## POSTs saves to your own endpoint: POST {endpoint}/{slot} with the JSON body.
## Pulling is asynchronous; listen to `pulled`.
class HttpProvider extends Node:
	signal pulled(slot: String, json: String)
	var endpoint := ""
	func push(slot: String, json: String) -> void:
		if endpoint == "":
			return
		var req := HTTPRequest.new()
		add_child(req)
		req.request_completed.connect(func(_r, _c, _h, _b): req.queue_free())
		req.request(endpoint.path_join(slot), ["Content-Type: application/json"], HTTPClient.METHOD_POST, json)
	func pull(slot: String) -> String:
		if endpoint == "":
			return ""
		var req := HTTPRequest.new()
		add_child(req)
		req.request_completed.connect(func(_r, code, _h, body: PackedByteArray):
			if code == 200:
				pulled.emit(slot, body.get_string_from_utf8())
			req.queue_free())
		req.request(endpoint.path_join(slot))
		return ""
