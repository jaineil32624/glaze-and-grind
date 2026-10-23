class_name Inventory
extends RefCounted
## Ingredient stock, prepared dough, and the donut display case.

var stock: Dictionary = {}      # ingredient_id -> int
var targets: Dictionary = {}    # ingredient_id -> int (Smart Inventory restock target)
var dough: int = 0
var case_items: Dictionary = {} # donut_id -> Array[float] qualities (oldest first)
var wasted_value: float = 0.0   # $ of food wasted today


func setup_defaults(ingredient_defs: Array) -> void:
	for ing in ingredient_defs:
		stock[ing["id"]] = int(ing.get("start", 0))
		targets[ing["id"]] = int(ing.get("start", 0))


func count(id: String) -> int:
	return int(stock.get(id, 0))


func has_all(req: Dictionary, times: int = 1) -> bool:
	for id in req:
		if count(id) < int(req[id]) * times:
			return false
	return true


## Returns the first missing ingredient id for a requirement, or "".
func missing(req: Dictionary, times: int = 1) -> String:
	for id in req:
		if count(id) < int(req[id]) * times:
			return id
	return ""


func consume(req: Dictionary, times: int = 1) -> bool:
	if not has_all(req, times):
		return false
	for id in req:
		stock[id] = count(id) - int(req[id]) * times
	return true


func add(id: String, amount: int) -> void:
	stock[id] = count(id) + amount


## Cost estimate of a requirement set given pack pricing (for waste accounting).
static func unit_cost(ingredient_defs: Array, req: Dictionary, times: int = 1) -> float:
	var total := 0.0
	for ing in ingredient_defs:
		if req.has(ing["id"]):
			total += float(ing["pack_cost"]) / float(ing["pack"]) * int(req[ing["id"]]) * times
	return total


# --- Display case -----------------------------------------------------------

func case_count(donut_id: String) -> int:
	return (case_items.get(donut_id, []) as Array).size()


func case_total() -> int:
	var t := 0
	for k in case_items:
		t += (case_items[k] as Array).size()
	return t


func add_to_case(donut_id: String, qualities: Array) -> void:
	if not case_items.has(donut_id):
		case_items[donut_id] = []
	(case_items[donut_id] as Array).append_array(qualities)


## Take n donuts (oldest first). Returns the qualities taken; may be shorter than n.
func take_from_case(donut_id: String, n: int) -> Array:
	var arr: Array = case_items.get(donut_id, [])
	var taken := arr.slice(0, mini(n, arr.size()))
	case_items[donut_id] = arr.slice(taken.size())
	return taken


## End of day: donuts left in the case go stale and are wasted.
func spoil_case(donut_value: Callable) -> int:
	var n := 0
	for id in case_items:
		var c := (case_items[id] as Array).size()
		n += c
		wasted_value += float(donut_value.call(id)) * 0.35 * c  # ingredient cost ≈ 35% of price
	case_items.clear()
	return n


func to_dict() -> Dictionary:
	return {"stock": stock.duplicate(), "targets": targets.duplicate(), "dough": dough}


func from_dict(d: Dictionary) -> void:
	stock = {}
	for k in d.get("stock", {}):
		stock[k] = int(d["stock"][k])
	targets = {}
	for k in d.get("targets", {}):
		targets[k] = int(d["targets"][k])
	dough = int(d.get("dough", 0))
