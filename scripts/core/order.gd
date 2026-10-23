class_name Order
extends RefCounted
## One customer's order. Donuts come from the display case at assembly time;
## drinks are made to order, each as its own task.

static var _next_id: int = 1

var id: int
var customer = null              # Customer node (untyped to keep core node-free)
var customer_type: String = ""
var donuts: Dictionary = {}      # donut_id -> qty
var drinks: Array = []           # [{id, flavor:bool, done:bool, quality:float}]
var boxed: bool = false
var placed_at: float = 0.0
var assembled: bool = false
var wrong: bool = false          # set by an "assemble" mistake
var quality: float = 0.0
var price_mult: float = 1.0


func _init() -> void:
	id = _next_id
	_next_id += 1


func donut_count() -> int:
	var n := 0
	for k in donuts:
		n += int(donuts[k])
	return n


func drinks_done() -> bool:
	for d in drinks:
		if not d["done"]:
			return false
	return true


func is_empty() -> bool:
	return donuts.is_empty() and drinks.is_empty()


## Total price before tips, given the registry for item prices.
func subtotal(db) -> float:
	var t := 0.0
	for k in donuts:
		t += float(db.donut(k).get("price", 0.0)) * int(donuts[k])
	for d in drinks:
		t += float(db.drink(d["id"]).get("price", 0.0))
		if d.get("flavor", false):
			t += float(db.flavor_shot.get("price", 0.5))
	return snappedf(t * price_mult, 0.01)


## Short human-readable summary, e.g. "2× Glazed, Latte+".
func describe(db) -> String:
	var parts: PackedStringArray = []
	for k in donuts:
		var n := int(donuts[k])
		parts.append(("%d× " % n if n > 1 else "") + str(db.donut(k).get("name", k)))
	for d in drinks:
		parts.append(str(db.drink(d["id"]).get("name", d["id"])) + ("+" if d.get("flavor", false) else ""))
	return ", ".join(parts)


func all_item_ids() -> Array:
	var ids: Array = donuts.keys()
	for d in drinks:
		ids.append(d["id"])
	return ids
