class_name CustomerProfile
extends RefCounted
## A generated customer: personality numbers and what they want.

var type_id: String = "student"
var type_name: String = "Student"
var patience: float = 80.0        # seconds of waiting before mood hits zero
var mood: float = 1.0             # 0..1
var spend: float = 1.0
var tip: float = 1.0
var rating_weight: float = 1.0
var loyalty: float = 0.5
var favorites: Array = []
var special: String = ""
var body: Color = Color.WHITE
var accent: Color = Color.WHITE
var returning: bool = false
var box_chance: float = 0.0


static func pick_type(rng: RandomNumberGenerator, customer_defs: Array, mix: Dictionary) -> Dictionary:
	var total := 0.0
	var weights: Array = []
	for c in customer_defs:
		var w := float(c.get("weight", 1.0)) * float(mix.get(c["id"], 0.5))
		weights.append(w)
		total += w
	var r := rng.randf() * total
	for i in customer_defs.size():
		r -= weights[i]
		if r <= 0.0:
			return customer_defs[i]
	return customer_defs[0]


static func create(rng: RandomNumberGenerator, def: Dictionary, patience_mult: float, loyalty_pool: float) -> CustomerProfile:
	var p := CustomerProfile.new()
	p.type_id = def["id"]
	p.type_name = def.get("name", def["id"])
	p.patience = float(def.get("patience", 80)) * patience_mult * rng.randf_range(0.85, 1.15)
	p.spend = float(def.get("spend", 1.0))
	p.tip = float(def.get("tip", 1.0))
	p.rating_weight = float(def.get("rating_weight", 1.0))
	p.loyalty = float(def.get("loyalty", 0.5))
	p.favorites = def.get("favorites", [])
	p.special = def.get("special", "")
	p.body = Color(def.get("body", "#888888"))
	p.accent = Color(def.get("accent", "#ffffff"))
	p.box_chance = float(def.get("box_chance", 0.0))
	p.returning = rng.randf() < loyalty_pool * p.loyalty
	if p.returning:
		p.patience *= 1.15
		p.spend *= 1.1
	return p


## Build an order from what is on the menu. `available` = Callable(id) -> bool.
static func build_order(rng: RandomNumberGenerator, prof: CustomerProfile, def: Dictionary, db,
		available: Callable, hot_bias: float, drink_bias: float) -> Order:
	var o := Order.new()
	o.customer_type = prof.type_id
	var drink_range: Array = def.get("drinks", [1, 1])
	var donut_range: Array = def.get("donuts", [0, 2])
	var n_drinks := rng.randi_range(int(drink_range[0]), int(drink_range[1]))
	var n_donuts := rng.randi_range(int(donut_range[0]), int(donut_range[1]))
	if drink_bias > 0.0 and rng.randf() < drink_bias:
		n_donuts = maxi(0, n_donuts - 1)
	if n_drinks == 0 and n_donuts == 0:
		n_drinks = 1

	var drink_pool: Array = db.drinks.filter(func(d): return available.call(d["id"]))
	var donut_pool: Array = db.donuts.filter(func(d): return available.call(d["id"]))
	var fav_drinks: Array = prof.favorites.filter(func(id): return not db.drink(id).is_empty() and available.call(id))
	var fav_donuts: Array = prof.favorites.filter(func(id): return not db.donut(id).is_empty() and available.call(id))

	var shot_chance := float(db.flavor_shot.get("chance", 0.25))
	for i in n_drinks:
		if drink_pool.is_empty():
			break
		var id: String
		if not fav_drinks.is_empty() and rng.randf() < 0.55:
			id = fav_drinks[rng.randi() % fav_drinks.size()]
		else:
			# Hot/cold preference
			var want_hot := rng.randf() < hot_bias
			var pool := drink_pool.filter(func(d): return bool(d.get("hot", true)) == want_hot)
			if pool.is_empty():
				pool = drink_pool
			id = pool[rng.randi() % pool.size()]["id"]
		o.drinks.append({"id": id, "flavor": rng.randf() < shot_chance * prof.spend, "done": false, "quality": 0.0})

	for i in n_donuts:
		if donut_pool.is_empty():
			break
		var did: String
		if not fav_donuts.is_empty() and rng.randf() < 0.5:
			did = fav_donuts[rng.randi() % fav_donuts.size()]
		else:
			did = donut_pool[rng.randi() % donut_pool.size()]["id"]
		o.donuts[did] = int(o.donuts.get(did, 0)) + 1

	o.boxed = o.donut_count() >= 3 or (o.donut_count() > 0 and rng.randf() < prof.box_chance)
	return o
