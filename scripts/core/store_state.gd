class_name StoreState
extends RefCounted
## Persistent state of one owned store location.

const RATING_MEMORY := 60.0   # how many reviews the rating "remembers"

var id: String = "main_street"
var equipment: Dictionary = {}   # station_id -> level index (0-based)
var items: Array = []            # owned one-off item ids
var inventory := Inventory.new()
var staff: Array = []            # Array[StaffData]
var par: Dictionary = {}         # donut_id -> par level
var rating: float = 3.0
var review_weight: float = 10.0
var loyalty_pool: float = 0.15   # share of returning customers (0..1)
var cleanliness: float = 80.0    # 0..100
var ledger := Ledger.new()
var days_open: int = 0


func setup_new(store_id: String, db) -> void:
	id = store_id
	for s in db.stations:
		equipment[s["id"]] = 0
	inventory.setup_defaults(db.ingredients)
	for d in db.donuts:
		par[d["id"]] = int(d.get("par", 6))


func level_of(station_id: String) -> int:
	return int(equipment.get(station_id, 0))


func has_item(item_id: String) -> bool:
	return item_id in items


func station_stat(db, station_id: String, key: String) -> float:
	var def: Dictionary = db.station(station_id)
	var arr: Array = def.get(key, [])
	if arr.is_empty():
		return 1.0 if key == "speed" else 0.0
	return float(arr[clampi(level_of(station_id), 0, arr.size() - 1)])


func add_review(score: float, weight: float) -> void:
	# score 0..5
	var w := clampf(review_weight, 0.0, RATING_MEMORY)
	rating = clampf((rating * w + score * weight) / (w + weight), 0.0, 5.0)
	review_weight = minf(review_weight + weight, RATING_MEMORY)


func daily_maintenance(db) -> float:
	var total := 0.0
	for s in db.stations:
		var arr: Array = s.get("maintenance", [0])
		total += float(arr[clampi(level_of(s["id"]), 0, arr.size() - 1)])
	for item_id in items:
		total += float(db.item(item_id).get("maintenance", 0))
	return total


func max_par() -> int:
	return 24 if has_item("big_case") else 14


func to_dict() -> Dictionary:
	var staff_arr: Array = []
	for s in staff:
		staff_arr.append(s.to_dict())
	return {
		"id": id, "equipment": equipment.duplicate(), "items": items.duplicate(),
		"inventory": inventory.to_dict(), "staff": staff_arr, "par": par.duplicate(),
		"rating": rating, "review_weight": review_weight, "loyalty_pool": loyalty_pool,
		"cleanliness": cleanliness, "ledger": ledger.to_dict(), "days_open": days_open,
	}


static func from_dict(d: Dictionary) -> StoreState:
	var s := StoreState.new()
	s.id = d.get("id", "main_street")
	for k in d.get("equipment", {}):
		s.equipment[k] = int(d["equipment"][k])
	s.items = d.get("items", [])
	s.inventory.from_dict(d.get("inventory", {}))
	for sd in d.get("staff", []):
		s.staff.append(StaffData.from_dict(sd))
	for k in d.get("par", {}):
		s.par[k] = int(d["par"][k])
	s.rating = float(d.get("rating", 3.0))
	s.review_weight = float(d.get("review_weight", 10.0))
	s.loyalty_pool = float(d.get("loyalty_pool", 0.15))
	s.cleanliness = float(d.get("cleanliness", 80.0))
	s.ledger.from_dict(d.get("ledger", {}))
	s.days_open = int(d.get("days_open", 0))
	return s
