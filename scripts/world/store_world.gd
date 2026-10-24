class_name StoreWorld
extends Node2D
## The running store during a shift: layout, customers, crew, tasks and the
## rules that connect them.

const W := 1280.0
const H := 720.0
const DOOR := Vector2(1185, 735)
const ENTRANCE := Vector2(1120, 650)
const MAX_CUSTOMERS := 16
const OVERTIME_LIMIT := 30.0     # real seconds after close before everyone is ushered out

var rng := RandomNumberGenerator.new()
var clock := DayClock.new()
var board := TaskBoard.new()
var running := false
var stations: Array = []
var by_type: Dictionary = {}       # type -> Array[Station]
var employees: Array = []
var customers: Array = []
var queue: Array = []
var pending_orders: Array = []
var register_customer: Dictionary = {}   # Station -> Customer
var wait_spots: Array = []
var case_station: Station
var break_station: Station

# Today's modifiers
var event: Dictionary = {}
var traffic_mult := 1.0
var hot_bias := 0.55
var drink_bias := 0.0
var evening_surge := 1.0
var mix: Dictionary = {}
var viral_until := -1.0
var broken_station: Station = null
var breakdown_hour := -1.0
var inspection_done := false

# Stats for the dashboard & summary
var stats := {}
var samples: Array = []
var _sample_next := 6.5
var _spawn_acc := 0.0
var _prod_timer := 0.0
var _overtime := 0.0
var _deliveries: Array = []
var _auto_task: WorkTask = null
var _late: Array = []              # [{emp, hour}]

var _actors: Node2D
var _fx: Node2D
var _modulate: CanvasModulate
var _lamps: Array = []
var _snow: Array = []


func _ready() -> void:
	rng.randomize()
	_modulate = CanvasModulate.new()
	add_child(_modulate)
	_actors = Node2D.new()
	_actors.name = "Actors"
	_fx = Node2D.new()
	_fx.name = "FX"
	_fx.z_index = 2000
	Bus.float_text.connect(_on_float_text)
	Bus.burst.connect(_on_burst)
	for i in 60:
		_snow.append(Vector2(randf() * W, randf() * 40.0))
	for y in [470, 540, 610]:
		for x in [600, 680, 760, 840]:
			wait_spots.append(Vector2(x, y))


# =============================================================================
# Layout
# =============================================================================

func build_layout() -> void:
	for c in get_children():
		if c is Station or c == _actors or c == _fx or c is PointLight2D:
			remove_child(c)
			c.queue_free()
	_actors = Node2D.new()
	_actors.name = "Actors"
	_fx = Node2D.new()
	_fx.name = "FX"
	_fx.z_index = 2000
	stations.clear()
	by_type.clear()
	_lamps.clear()
	var s := Game.current()
	_add_station("mixer", Vector2(110, 168), Vector2(120, 70), "Mixer")
	_add_station("fryer", Vector2(265, 168), Vector2(140, 74), "Fryer")
	_add_station("glaze", Vector2(430, 168), Vector2(130, 70), "Glaze & Top")
	_add_station("coffee", Vector2(610, 168), Vector2(150, 70), "Coffee Bar")
	_add_station("cold", Vector2(790, 168), Vector2(130, 70), "Cold Bar")
	var r1 := _add_station("register", Vector2(170, 352), Vector2(110, 60), "Register")
	r1.stand_offset = Vector2(0, -50)
	if s.has_item("register2"):
		var r2 := _add_station("register", Vector2(320, 352), Vector2(110, 60), "Register 2")
		r2.stand_offset = Vector2(0, -50)
		r2.level = s.level_of("register")
	case_station = _add_station("case", Vector2(490, 352), Vector2(150, 64), "Display Case")
	var pk := _add_station("pickup", Vector2(700, 352), Vector2(150, 60), "Pickup")
	pk.stand_offset = Vector2(0, -50)
	break_station = _add_station("break", Vector2(1110, 222), Vector2(230, 190), "")
	for st in stations:
		if st.type in ["mixer", "fryer", "glaze", "coffee", "cold", "register", "pickup"]:
			st.level = s.level_of(st.type)
	add_child(_actors)
	add_child(_fx)
	# Lamps
	var tex := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(1, 0.9, 0.7, 1))
	g.set_color(1, Color(1, 0.9, 0.7, 0))
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	for p in [Vector2(300, 520), Vector2(700, 520), Vector2(1050, 560), Vector2(450, 220), Vector2(950, 240)]:
		var l := PointLight2D.new()
		l.texture = tex
		l.position = p
		l.texture_scale = 2.4
		l.energy = 0.0
		l.blend_mode = Light2D.BLEND_MODE_ADD
		add_child(l)
		_lamps.append(l)


func _add_station(type: String, pos: Vector2, sz: Vector2, label: String) -> Station:
	var st := Station.new()
	st.type = type
	st.position = pos
	st.size = sz
	st.label = label
	st.world = self
	st.z_index = int(pos.y)
	add_child(st)
	stations.append(st)
	if not by_type.has(type):
		by_type[type] = []
	by_type[type].append(st)
	return st


# =============================================================================
# Shift lifecycle
# =============================================================================

func start_shift() -> void:
	build_layout()
	clock.reset()
	board.clear()
	queue.clear()
	pending_orders.clear()
	register_customer.clear()
	customers.clear()
	employees.clear()
	_deliveries.clear()
	_late.clear()
	samples.clear()
	_sample_next = 6.5
	_spawn_acc = 0.6
	_overtime = 0.0
	_auto_task = null
	inspection_done = false
	viral_until = -1.0
	broken_station = null
	breakdown_hour = -1.0
	stats = {"served": 0, "lost": 0, "orders": 0, "accurate": 0, "satisfaction": 0.0,
		"mistakes": {}, "mistake_count": 0, "perfect_fries": 0, "burned": 0, "critic": "", "viral": false,
		"inspection": "", "late": [], "sick": "", "rating_start": Game.current().rating, "donuts_sold": 0, "drinks_sold": 0}
	var s := Game.current()
	s.inventory.wasted_value = 0.0
	for st in s.staff:
		st.mistakes_today = 0
		st.tasks_today = 0
	_apply_event(Game.today_event)

	# Crew
	var crew: Array = s.staff.duplicate()
	if event.get("sick", false) and crew.size() > 1:
		var sick: StaffData = crew[rng.randi() % crew.size()]
		crew.erase(sick)
		stats["sick"] = sick.name
	var i := 0
	for sd in crew:
		var e := Employee.new()
		e.data = sd
		e.world = self
		e.position = Vector2(140 + i * 110, 260)
		_actors.add_child(e)
		employees.append(e)
		if rng.randf() < sd.late_chance():
			e.present = false
			e.visible = false
			_late.append({"emp": e, "hour": rng.randf_range(6.5, 8.0)})
			stats["late"].append(sd.name)
		i += 1
	_prod_timer = 0.0
	_produce()
	running = true
	Sfx.start_shift_ambience()
	Bus.day_phase_changed.emit(clock.phase_name())


func _apply_event(e: Dictionary) -> void:
	event = e
	var sd := Game.store_def()
	traffic_mult = float(e.get("traffic", 1.0))
	hot_bias = float(e.get("hot_bias", 0.55))
	drink_bias = float(sd.get("drink_bias", 0.0))
	evening_surge = float(e.get("evening_surge", 1.0))
	mix = EventDirector.merged_mix(sd.get("mix", {}), e)
	if e.get("breakdown", false):
		breakdown_hour = rng.randf_range(8.0, 13.0)
	if not e.is_empty():
		Bus.event_started.emit(e)


func stop() -> void:
	running = false
	Sfx.stop_shift_ambience()


# =============================================================================
# Main loop
# =============================================================================

func _process(delta: float) -> void:
	_update_lighting()
	queue_redraw()
	if not running:
		return
	var d := delta * Game.time_scale
	if d <= 0.0:
		return
	var prev_phase := clock.phase_name()
	clock.advance(d)
	if clock.phase_name() != prev_phase:
		Bus.day_phase_changed.emit(clock.phase_name())

	_update_power_and_breakdowns()
	_update_late_arrivals()
	_update_deliveries()
	_spawn(d)
	_assign_registers()
	_prod_timer -= d
	if _prod_timer <= 0.0:
		_prod_timer = 0.5
		_produce()
	for e in employees:
		e.tick(d)
	for c in customers.duplicate():
		c.tick(d)
	_check_assembly()
	_tick_auto_glazer(d)
	_check_inspection()
	_sample_stats()
	var cs := Game.current()
	cs.cleanliness = maxf(0.0, cs.cleanliness - d * 0.05 * (1.0 + customers.size() * 0.05))

	var frying := 0
	for st in by_type.get("fryer", []):
		if st.current_task != null:
			frying += 1
	Sfx.set_activity(customers.size(), frying)

	if clock.is_closed():
		_overtime += d
		if _overtime > OVERTIME_LIMIT:
			for c in customers.duplicate():
				if c.state != Customer.State.LEAVING:
					_send_away(c, false)
		if customers.is_empty():
			running = false
			Sfx.stop_shift_ambience()
			Bus.shift_ended.emit()


func _update_lighting() -> void:
	if _modulate:
		_modulate.color = clock.light_color()
	var on := clock.lamps_on()
	for l in _lamps:
		l.energy = lerpf(l.energy, 0.35 if on else 0.0, 0.05)


func _update_power_and_breakdowns() -> void:
	var outage: Dictionary = event.get("outage", {})
	if not outage.is_empty():
		var off: bool = clock.hour >= float(outage["start"]) and clock.hour < float(outage["end"])
		for t in outage.get("stations", []):
			for st in by_type.get(t, []):
				if st.powered == off:
					st.powered = not off
					if off:
						Bus.toast.emit("Power's out at the %s!" % st.label, Color("#555555"))
					else:
						Bus.toast.emit("%s is back online" % st.label, Color("#2fae6b"))
	if breakdown_hour > 0.0 and clock.hour >= breakdown_hour and broken_station == null:
		var options: Array = []
		for t in ["fryer", "coffee", "cold", "mixer"]:
			options.append_array(by_type.get(t, []))
		broken_station = options[rng.randi() % options.size()]
		broken_station.broken = true
		breakdown_hour = -1.0
		Bus.toast.emit("The %s broke down! Tap it to repair." % broken_station.label, Color("#ff8a3d"))
		Sfx.play("mistake")


func repair_cost() -> float:
	return float(event.get("repair_cost", 120.0))


func repair(st: Station) -> bool:
	if not st.broken:
		return false
	if not Game.spend(repair_cost(), "repairs"):
		Bus.toast.emit("Not enough cash to repair", Color("#e5383b"))
		return false
	st.broken = false
	Bus.toast.emit("%s repaired" % st.label, Color("#2fae6b"))
	Sfx.play("pop")
	return true


func _update_late_arrivals() -> void:
	for l in _late.duplicate():
		if clock.hour >= l["hour"]:
			var e: Employee = l["emp"]
			e.present = true
			e.visible = true
			e.position = ENTRANCE
			e.data.happiness -= 3.0
			Bus.toast.emit("%s showed up late" % e.data.name, Color("#ffb020"))
			Bus.mistake.emit("late", e.data.name)
			_count_mistake("late")
			_late.erase(l)


func _update_deliveries() -> void:
	for dv in _deliveries.duplicate():
		if clock.hour >= dv["hour"]:
			Game.current().inventory.add(dv["id"], dv["amount"])
			Bus.toast.emit("Delivery arrived: +%d %s" % [dv["amount"], DB.ingredient(dv["id"]).get("name", dv["id"])], Color("#4f8cff"))
			Sfx.play("bell")
			_deliveries.erase(dv)


func emergency_order(ingredient_id: String) -> bool:
	var def := DB.ingredient(ingredient_id)
	var cost := float(def.get("pack_cost", 10.0)) * 1.5
	if not Game.spend(cost, "delivery"):
		Bus.toast.emit("Not enough cash", Color("#e5383b"))
		return false
	_deliveries.append({"id": ingredient_id, "amount": int(def.get("pack", 10)), "hour": clock.hour + 0.75})
	Bus.toast.emit("Rush delivery of %s on the way (45 min)" % def.get("name", ingredient_id), Color("#4f8cff"))
	return true


func pending_delivery(ingredient_id: String) -> bool:
	for dv in _deliveries:
		if dv["id"] == ingredient_id:
			return true
	return false


# =============================================================================
# Customers
# =============================================================================

func _spawn(d: float) -> void:
	if not clock.is_open_for_entry():
		return
	var game_hours := d * (DayClock.CLOSE_HOUR - DayClock.OPEN_HOUR) / DayClock.REAL_SECONDS_PER_DAY
	var viral := 1.35 if clock.hour < viral_until else 1.0
	var rate := clock.arrival_rate(float(Game.store_def().get("traffic", 1.0)), traffic_mult * viral,
		Game.current().rating, evening_surge)
	_spawn_acc += rate * game_hours
	while _spawn_acc >= 1.0:
		_spawn_acc -= 1.0
		if customers.size() < MAX_CUSTOMERS:
			spawn_customer()


func spawn_customer(type_id: String = "") -> Customer:
	var def: Dictionary = DB.customer_type(type_id) if type_id != "" else CustomerProfile.pick_type(rng, DB.customers, mix)
	var patience_mult := float(Game.store_def().get("patience", 1.0))
	var prof := CustomerProfile.create(rng, def, patience_mult, Game.current().loyalty_pool)
	var bias := hot_bias
	if def.has("hot_bias"):
		bias = (bias + float(def["hot_bias"])) * 0.5
	var order := CustomerProfile.build_order(rng, prof, def, DB, is_orderable, bias, drink_bias)
	if order.is_empty():
		return null
	order.price_mult = float(Game.store_def().get("price", 1.0))
	var c := Customer.new()
	c.setup(prof, order, self, rng)
	c.position = DOOR
	c.target = ENTRANCE + Vector2(rng.randf_range(-20, 20), 0)
	_actors.add_child(c)
	customers.append(c)
	Sfx.play("bell", 0.02)
	return c


## Can this menu item be ordered right now? (unlocked, station working, ingredients exist)
func is_orderable(id: String) -> bool:
	if not Game.is_unlocked(id):
		return false
	var inv: Inventory = Game.current().inventory
	var dn := DB.donut(id)
	if not dn.is_empty():
		if inv.case_count(id) > 0:
			return true
		return inv.has_all(dn.get("finish", {}), 1) and (inv.dough >= 6 or inv.has_all(DB.dough.get("ingredients", {})))
	var dr := DB.drink(id)
	if dr.is_empty():
		return false
	var any_station := false
	for st in by_type.get(dr["station"], []):
		if st.usable():
			any_station = true
	return any_station and inv.has_all(dr.get("ingredients", {}))


func customer_reached_door(c: Customer) -> void:
	c.state = Customer.State.QUEUE
	queue.append(c)
	_layout_queue()


func _queue_pos(i: int) -> Vector2:
	var col := i / 6
	var row := i % 6
	return Vector2(250 + col * 46, 460 + row * 42)


func _layout_queue() -> void:
	for i in queue.size():
		queue[i].target = _queue_pos(i)


func _assign_registers() -> void:
	if queue.is_empty():
		return
	for reg in by_type.get("register", []):
		if queue.is_empty():
			return
		if register_customer.has(reg):
			continue
		var c: Customer = queue.pop_front()
		register_customer[reg] = c
		c.register_station = reg
		c.state = Customer.State.TO_REGISTER
		c.target = reg.global_position + Vector2(0, 62)
		_layout_queue()


func customer_at_register(c: Customer) -> void:
	var reg = c.register_station
	var dur := 1.8
	var t := WorkTask.new("take_order", "register", dur, {"customer": c, "station": reg, "order": c.order})
	t.created_at = clock.hour * 10.0
	board.post(t)


func _finalize_order(c: Customer) -> void:
	var o := c.order
	var inv: Inventory = Game.current().inventory
	# Substitute unavailable items
	for i in range(o.drinks.size() - 1, -1, -1):
		var dr: Dictionary = o.drinks[i]
		if not is_orderable(dr["id"]):
			var alts := DB.drinks.filter(func(x): return is_orderable(x["id"]))
			c.profile.mood = maxf(0.05, c.profile.mood - 0.1)
			if alts.is_empty():
				o.drinks.remove_at(i)
			else:
				dr["id"] = alts[rng.randi() % alts.size()]["id"]
		if i < o.drinks.size() and o.drinks[i].get("flavor", false) and inv.count("syrup") < 1:
			o.drinks[i]["flavor"] = false
	for k in o.donuts.keys():
		if not is_orderable(k):
			o.donuts.erase(k)
			c.profile.mood = maxf(0.05, c.profile.mood - 0.1)
	if o.donut_count() < 3 and o.boxed and not c.profile.type_id == "family":
		o.boxed = false


func _order_taken(task: WorkTask, emp: Employee) -> void:
	var c: Customer = task.payload["customer"]
	var reg = task.payload["station"]
	register_customer.erase(reg)
	if not is_instance_valid(c) or c.state != Customer.State.ORDERING:
		return
	_finalize_order(c)
	if c.order.is_empty():
		Bus.float_text.emit(c.global_position + Vector2(0, -70), "Sold out!", Color("#e5383b"))
		_send_away(c, true)
		return
	if emp.data.personality == "chatty":
		c.profile.mood = minf(1.0, c.profile.mood + 0.1)
	var o := c.order
	o.placed_at = clock.hour
	pending_orders.append(o)
	stats["orders"] += 1
	for i in o.drinks.size():
		var dd := DB.drink(o.drinks[i]["id"])
		var dt := WorkTask.new("make_drink", dd["station"], float(dd.get("time", 4.0)),
			{"order": o, "index": i, "drink": dd["id"], "customer": c}, int(dd.get("skill", 1)))
		dt.created_at = clock.hour * 10.0
		board.post(dt)
	c.state = Customer.State.WAITING
	c.target = _free_wait_spot()
	Bus.order_placed.emit(o)
	Sfx.play("click")


func _free_wait_spot() -> Vector2:
	var taken: Array = []
	for c in customers:
		if c.state == Customer.State.WAITING:
			taken.append(c.target)
	var free := wait_spots.filter(func(p): return not taken.has(p))
	if free.is_empty():
		return Vector2(rng.randf_range(560, 880), rng.randf_range(450, 640))
	return free[rng.randi() % free.size()]


func _check_assembly() -> void:
	for o in pending_orders:
		if o.get_meta("assemble_posted", false):
			continue
		if o.drinks_done():
			o.set_meta("assemble_posted", true)
			var t := WorkTask.new("assemble", "pickup", 2.4 + o.donut_count() * 0.25, {"order": o, "customer": o.customer})
			t.created_at = clock.hour * 10.0
			board.post(t)


func customer_pay(c: Customer) -> void:
	var o := c.order
	var s := Game.current()
	var quality := o.quality
	var satisfaction := clampf(c.profile.mood * 0.5 + quality * 0.42 + (0.0 if o.wrong else 0.08), 0.0, 1.0)
	if o.wrong:
		satisfaction *= 0.75
	var subtotal := o.subtotal(DB)
	var tip := subtotal * 0.2 * satisfaction * satisfaction * c.profile.tip
	Game.earn(subtotal, "sales", clock.hour)
	if tip >= 0.05:
		Game.earn(snappedf(tip, 0.01), "tips", clock.hour)
	var stars := 1.0 + 4.0 * satisfaction
	s.add_review(stars, c.profile.rating_weight)
	s.loyalty_pool = clampf(s.loyalty_pool + (satisfaction - 0.55) * 0.01, 0.05, 0.6)
	s.cleanliness = maxf(0.0, s.cleanliness - 0.5)
	stats["served"] += 1
	stats["satisfaction"] += satisfaction
	stats["donuts_sold"] += o.donut_count()
	stats["drinks_sold"] += o.drinks.size()
	if not o.wrong:
		stats["accurate"] += 1
	c.happy_result = satisfaction
	c.react(satisfaction >= 0.5)
	Bus.float_text.emit(c.global_position + Vector2(-10, -80), "+$%.2f" % (subtotal + tip), Color("#2fae6b"))
	Sfx.play("cash")
	Sfx.play("happy" if satisfaction >= 0.5 else "angry")
	# Specials
	if c.profile.special == "critic":
		var st := "★".repeat(int(round(stars)))
		stats["critic"] = st
		Bus.toast.emit("Food critic review: %s" % st, Color("#c9a227"))
	elif c.profile.special == "viral":
		if satisfaction > 0.82 and rng.randf() < 0.5:
			viral_until = clock.hour + 2.0
			stats["viral"] = true
			Bus.toast.emit("An influencer's post is going viral! Traffic up!", Color("#c45bff"))
			Bus.burst.emit(c.global_position, "confetti")
		elif satisfaction < 0.4:
			s.add_review(1.0, 3.0)
			Bus.toast.emit("An influencer posted a bad review...", Color("#e5383b"))
	pending_orders.erase(o)
	Bus.order_completed.emit(o, satisfaction)
	Bus.customer_left.emit(c.profile.type_id, satisfaction >= 0.5, satisfaction)
	c.state = Customer.State.LEAVING
	c.target = DOOR


func customer_gave_up(c: Customer) -> void:
	Game.current().add_review(1.0, c.profile.rating_weight)
	stats["lost"] += 1
	Bus.float_text.emit(c.global_position + Vector2(0, -70), "Too slow!", Color("#e5383b"))
	Sfx.play("angry")
	Bus.customer_left.emit(c.profile.type_id, false, 0.0)
	_send_away(c, false)


func _send_away(c: Customer, polite: bool) -> void:
	queue.erase(c)
	_layout_queue()
	for reg in register_customer.keys():
		if register_customer[reg] == c:
			register_customer.erase(reg)
	pending_orders.erase(c.order)
	for t in board.tasks.duplicate():
		if t.payload.get("customer") == c or t.payload.get("order") == c.order:
			if t.claimant == null:
				board.remove(t)
			t.cancelled = true
	c.react(polite)
	c.state = Customer.State.LEAVING
	c.target = DOOR


func customer_exit(c: Customer) -> void:
	customers.erase(c)
	if c.selected:
		Bus.employee_selected.emit(null)
	c.queue_free()


# =============================================================================
# Production planning
# =============================================================================

func _produce() -> void:
	var s := Game.current()
	var inv := s.inventory
	var fry_size := int(DB.fry.get("batch_size", 6))
	var open_fry := board.count("fry_batch")
	var fryers: int = by_type.get("fryer", []).size()
	for d in DB.donuts:
		var id: String = d["id"]
		if not Game.is_unlocked(id):
			continue
		var planned := inv.case_count(id)
		planned += fry_size * board.count("fry_batch", func(t): return t.payload.get("donut") == id)
		planned += fry_size * board.count("finish_batch", func(t): return t.payload.get("donut") == id)
		var par := int(s.par.get(id, 6))
		if clock.hour > 19.0:
			par = mini(par, 3)   # don't bake a full case right before closing
		if planned < par and open_fry < 1 + fryers and inv.has_all(d.get("finish", {})):
			var fry_time := float(DB.fry.get("time", 7.0))
			var t := WorkTask.new("fry_batch", "fryer", fry_time, {"donut": id})
			t.created_at = clock.hour * 10.0
			board.post(t)
			open_fry += 1
	# Dough
	var need := fry_size * board.count("fry_batch", func(t): return not t.is_claimed())
	if inv.dough < need and board.count("mix_dough") == 0:
		var mt := WorkTask.new("mix_dough", "mixer", float(DB.dough.get("time", 6.0)), {})
		mt.created_at = clock.hour * 10.0
		board.post(mt)


func _tick_auto_glazer(d: float) -> void:
	if not Game.current().has_item("auto_glazer"):
		return
	if _auto_task == null:
		for t in board.tasks:
			if t.kind == "finish_batch" and t.claimant == null and can_start(t):
				_auto_task = t
				t.claimant = self
				_consume_for(t)
				break
		if _auto_task == null:
			return
	var glaze: Station = by_type["glaze"][0]
	if glaze.user == null:
		glaze.current_task = _auto_task
	_auto_task.progress += d * 0.8 * station_speed(glaze)
	if _auto_task.progress >= _auto_task.duration:
		_finish_batch(_auto_task, null)
		board.remove(_auto_task)
		if glaze.current_task == _auto_task:
			glaze.current_task = null
		_auto_task = null


# =============================================================================
# Task API used by Employee
# =============================================================================

func queue_pressure() -> float:
	return clampf((queue.size() + pending_orders.size() * 0.5) / 8.0, 0.0, 1.5)


func can_take_break(emp: Employee) -> bool:
	if emp.data.stress >= 98.0:
		return true
	var working := 0
	for e in employees:
		if e != emp and e.present and not e.on_break:
			working += 1
	return working >= 1


func break_point(emp: Employee) -> Vector2:
	var idx := employees.find(emp)
	return break_station.global_position + Vector2(-70 + (idx % 4) * 45, 50)


func idle_point(_emp: Employee) -> Vector2:
	return Vector2(rng.randf_range(80, 860), rng.randf_range(222, 296))


func station_for_task(t: WorkTask):
	var specific = t.payload.get("station")
	if specific != null:
		return specific if specific.is_available() else null
	for st in by_type.get(t.station_type, []):
		if st.is_available():
			return st
	return null


func station_speed(st: Station) -> float:
	return Game.current().station_stat(DB, st.type, "speed")


func urgency_of(t: WorkTask) -> float:
	var c = t.payload.get("customer")
	if c != null and is_instance_valid(c):
		return 1.0 - c.profile.mood
	if t.kind in ["fry_batch", "finish_batch"]:
		var id: String = t.payload.get("donut", "")
		if Game.current().inventory.case_count(id) == 0:
			for o in pending_orders:
				if o.donuts.has(id):
					return 0.8
			return 0.35
	if t.kind == "mix_dough" and Game.current().inventory.dough < 6:
		return 0.5
	return 0.0


func can_start(t: WorkTask) -> bool:
	var inv: Inventory = Game.current().inventory
	match t.kind:
		"mix_dough":
			return inv.has_all(DB.dough.get("ingredients", {}))
		"fry_batch":
			return inv.dough >= int(DB.fry.get("batch_size", 6))
		"finish_batch":
			return inv.has_all(DB.donut(t.payload["donut"]).get("finish", {}), int(DB.fry.get("batch_size", 6)))
		"make_drink":
			var o: Order = t.payload["order"]
			var dr: Dictionary = o.drinks[t.payload["index"]]
			if dr.get("flavor", false) and inv.count("syrup") < 1:
				dr["flavor"] = false
			return inv.has_all(DB.drink(dr["id"]).get("ingredients", {}))
		"assemble":
			var o: Order = t.payload["order"]
			for k in o.donuts:
				if inv.case_count(k) < int(o.donuts[k]):
					return false
			return not o.boxed or inv.count("boxes") >= 1
	return true


func assign_task(emp: Employee) -> bool:
	var res := board.best_for(emp.data.level, emp.data.focus, emp.position, clock.hour * 10.0,
		station_for_task, func(st): return st.stand_point(), urgency_of, can_start)
	var t: WorkTask = res["task"]
	if t == null:
		return false
	t.claimant = emp
	t.station = res["station"]
	res["station"].reserve(emp)
	emp.task = t
	emp.station = res["station"]
	emp.started = false
	return true


func abandon_task(emp: Employee) -> void:
	var t: WorkTask = emp.task
	if emp.station != null:
		emp.station.free_up()
	if t != null:
		if t.cancelled:
			board.remove(t)
		else:
			board.release(t)
			t.progress = 0.0
	emp.task = null
	emp.station = null
	emp.started = false


func _consume_for(t: WorkTask) -> bool:
	var inv: Inventory = Game.current().inventory
	match t.kind:
		"mix_dough":
			return inv.consume(DB.dough.get("ingredients", {}))
		"fry_batch":
			var n := int(DB.fry.get("batch_size", 6))
			if inv.dough < n:
				return false
			inv.dough -= n
			return true
		"finish_batch":
			return inv.consume(DB.donut(t.payload["donut"]).get("finish", {}), int(DB.fry.get("batch_size", 6)))
		"make_drink":
			var o: Order = t.payload["order"]
			var dr: Dictionary = o.drinks[t.payload["index"]]
			if not inv.consume(DB.drink(dr["id"]).get("ingredients", {})):
				return false
			if dr.get("flavor", false):
				inv.consume(DB.flavor_shot.get("ingredients", {"syrup": 1}))
			return true
		"assemble":
			var o: Order = t.payload["order"]
			if not can_start(t):
				return false
			var qs: Array = []
			for k in o.donuts:
				qs.append_array(inv.take_from_case(k, int(o.donuts[k])))
			if o.boxed:
				inv.consume({"boxes": 1})
			t.payload["donut_qualities"] = qs
			return true
	return true


func start_task(t: WorkTask, emp: Employee) -> bool:
	if not can_start(t):
		return false
	if not _consume_for(t):
		return false
	emp.station.current_task = t
	if t.kind == "fry_batch":
		Bus.fry_started.emit(emp.station)
	elif t.kind == "make_drink" and t.station_type == "coffee":
		Sfx.play("steam", 0.1)
	return true


func complete_task(t: WorkTask, emp: Employee) -> void:
	var sd := emp.data
	var st: Station = emp.station
	var mistake := rng.randf() < sd.mistake_chance(t.kind)
	var xp := 2.0
	match t.kind:
		"take_order":
			_order_taken(t, emp)
		"mix_dough":
			if mistake:
				_mistake("bad_dough", emp, "Bad dough!")
				Game.current().inventory.wasted_value += Inventory.unit_cost(DB.ingredients, DB.dough.get("ingredients", {}))
			else:
				Game.current().inventory.dough += int(DB.dough.get("batch_size", 12))
				Bus.float_text.emit(st.global_position + Vector2(0, -50), "+12 dough", Color("#8a5a36"))
		"fry_batch":
			xp = 3.0
			_fry_done(t, emp, t.ratio())
		"finish_batch":
			if mistake:
				_mistake("forgot_topping", emp, "Forgot toppings!")
				var qs: Array = t.payload.get("qualities", [])
				for i in qs.size():
					qs[i] = qs[i] * 0.6
			_finish_batch(t, emp)
		"make_drink":
			xp = 3.0
			if mistake:
				_mistake("spill", emp, "Spilled!")
				var dr0: Dictionary = t.payload["order"].drinks[t.payload["index"]]
				Game.current().inventory.wasted_value += Inventory.unit_cost(DB.ingredients, DB.drink(dr0["id"]).get("ingredients", {}))
				# Redo: keep the task, start over (ingredients are consumed again)
				t.progress = 0.0
				emp.started = false
				st.current_task = null
				sd.tasks_today += 1
				return
			var o: Order = t.payload["order"]
			var dr: Dictionary = o.drinks[t.payload["index"]]
			var q := 0.72 + Game.current().station_stat(DB, st.type, "quality") + sd.accuracy * 0.015 \
				+ (sd.level - 1) * 0.03 - sd.stress / 500.0
			dr["quality"] = clampf(q + rng.randf_range(-0.05, 0.05), 0.3, 1.0)
			dr["done"] = true
		"assemble":
			var o: Order = t.payload["order"]
			if mistake:
				_mistake("wrong_order", emp, "Wrong order!")
				o.wrong = true
			var qs: Array = t.payload.get("donut_qualities", [])
			for d in o.drinks:
				qs.append(d["quality"])
			var sum := 0.0
			for q in qs:
				sum += float(q)
			o.quality = sum / maxf(qs.size(), 1.0)
			o.assembled = true
			var c = o.customer
			if c != null and is_instance_valid(c) and c.state == Customer.State.WAITING:
				c.state = Customer.State.TO_PICKUP
				c.target = st.global_position + Vector2(rng.randf_range(-30, 30), 62)
			Sfx.play("pop")
	sd.tasks_today += 1
	if sd.gain_xp(xp):
		emp.level_up_fx()
		Sfx.play("levelup")
		Bus.toast.emit("%s reached level %d!" % [sd.name, sd.level], Color("#4f8cff"))
	board.remove(t)
	st.free_up()
	emp.task = null
	emp.station = null
	emp.started = false


func _fry_done(t: WorkTask, emp, pull_t: float) -> void:
	var st: Station = t.station
	var bonus := Game.current().station_stat(DB, "fryer", "quality")
	var q := FryCurve.quality(pull_t, float(DB.fry.get("perfect", 0.62)), float(DB.fry.get("window", 0.12)), bonus)
	var label := FryCurve.grade(q)
	var by_player: bool = t.payload.get("player", false)
	var pos: Vector2 = st.global_position + Vector2(0, -60)
	if FryCurve.is_burned(pull_t):
		stats["burned"] += 1
		Game.current().inventory.wasted_value += Inventory.unit_cost(DB.ingredients, DB.dough.get("ingredients", {})) * 0.5
		Bus.float_text.emit(pos, "BURNED!", Color("#e5383b"))
		Bus.burst.emit(st.global_position, "smoke")
		Sfx.play("burn")
		if emp != null and not by_player:
			_mistake("burned", emp, "")
		return
	if q >= 0.95:
		stats["perfect_fries"] += 1
		Bus.burst.emit(st.global_position, "sparkle")
	Bus.float_text.emit(pos, label, Color("#ffd23f") if q >= 0.85 else Color("#ffffff"))
	var qs: Array = []
	for i in int(DB.fry.get("batch_size", 6)):
		qs.append(clampf(q + rng.randf_range(-0.04, 0.03), 0.2, 1.0))
	var ft := WorkTask.new("finish_batch", "glaze", 4.5, {"donut": t.payload["donut"], "qualities": qs})
	ft.created_at = clock.hour * 10.0
	board.post(ft)


func _finish_batch(t: WorkTask, emp) -> void:
	var qs: Array = t.payload.get("qualities", [])
	var bonus := Game.current().station_stat(DB, "glaze", "quality")
	var out: Array = []
	for q in qs:
		out.append(clampf(float(q) + bonus, 0.0, 1.0))
	Game.current().inventory.add_to_case(t.payload["donut"], out)
	var pos: Vector2 = by_type["glaze"][0].global_position + Vector2(0, -50)
	Bus.float_text.emit(pos, "+%d %s" % [out.size(), DB.donut(t.payload["donut"]).get("name", "")], Color("#ff6f91"))


## Player takes over the fryer pull for the batch currently frying there.
func player_take_fryer(st: Station) -> bool:
	if st.current_task == null or st.current_task.kind != "fry_batch":
		return false
	st.current_task.payload["player"] = true
	return true


func player_pull(st: Station) -> String:
	var t: WorkTask = st.current_task
	if t == null or t.kind != "fry_batch" or t.claimant == null:
		return ""
	var pull_t := t.ratio()
	var q := FryCurve.quality(pull_t, float(DB.fry.get("perfect", 0.62)), float(DB.fry.get("window", 0.12)),
		Game.current().station_stat(DB, "fryer", "quality"))
	complete_task(t, t.claimant)
	return FryCurve.grade(q)


func find_assist_target(emp: Employee) -> WorkTask:
	var best: WorkTask = null
	var best_rem := 2.5
	for t in board.tasks:
		if not (t.claimant is Employee) or t.claimant == emp or t.assist > 0.0:
			continue
		if not t.claimant.started or t.kind in ["take_order", "fry_batch"]:
			continue
		if emp.data.level < t.skill:
			continue
		var rem: float = t.duration - t.progress
		if rem > best_rem:
			best_rem = rem
			best = t
	return best


func _mistake(kind: String, emp: Employee, text: String) -> void:
	emp.data.mistakes_today += 1
	emp.data.add_stress(6.0)
	Game.current().cleanliness = maxf(0.0, Game.current().cleanliness - 2.0)
	_count_mistake(kind)
	if text != "":
		Bus.float_text.emit(emp.global_position + Vector2(0, -80), text, Color("#e5383b"))
		Sfx.play("mistake")
	Bus.mistake.emit(kind, emp.data.name)


func _count_mistake(kind: String) -> void:
	stats["mistakes"][kind] = int(stats["mistakes"].get(kind, 0)) + 1
	stats["mistake_count"] += 1


# =============================================================================
# Events: inspection
# =============================================================================

func _check_inspection() -> void:
	if not event.get("inspection", false) or inspection_done or clock.hour < 14.0:
		return
	inspection_done = true
	var s := Game.current()
	var waste_pen := clampf(s.inventory.wasted_value / 40.0, 0.0, 1.0)
	var score := clampf(s.cleanliness / 100.0 * 0.7 + (1.0 - waste_pen) * 0.3, 0.0, 1.0)
	var grade := "A" if score > 0.85 else ("B" if score > 0.7 else ("C" if score > 0.5 else "F"))
	stats["inspection"] = grade
	s.add_review(1.0 + 4.0 * score, 4.0)
	if grade == "F":
		Game.charge(150.0, "fines")
		Bus.toast.emit("Health inspection: F. Fined $150.", Color("#e5383b"))
	else:
		Bus.toast.emit("Health inspection grade: %s" % grade, Color("#2fae6b") if grade == "A" else Color("#ffb020"))


# =============================================================================
# Stats & end of day
# =============================================================================

func efficiency() -> float:
	var busy := 0.0
	var total := 0.0
	for e in employees:
		busy += e.busy_time
		total += e.shift_time
	return busy / total if total > 0.0 else 0.0


func avg_satisfaction() -> float:
	return stats["satisfaction"] / stats["served"] if stats.get("served", 0) > 0 else 0.0


func accuracy() -> float:
	return float(stats["accurate"]) / stats["served"] if stats.get("served", 0) > 0 else 1.0


func _sample_stats() -> void:
	if clock.hour < _sample_next:
		return
	_sample_next += 0.5
	var s := Game.current()
	samples.append({
		"hour": clock.hour,
		"revenue": s.ledger.revenue(),
		"profit": s.ledger.profit(),
		"happiness": avg_satisfaction(),
		"efficiency": efficiency(),
		"waste": s.inventory.wasted_value,
		"rating": s.rating,
		"accuracy": accuracy(),
		"customers": customers.size(),
	})


## Settle the day: wages, rent, maintenance, spoilage, staff morale, career.
func close_day() -> Dictionary:
	var s := Game.current()
	var sd := Game.store_def()
	var spoiled := s.inventory.spoil_case(func(id): return float(DB.donut(id).get("price", 2.0)))
	var wages := 0.0
	var worked: Array = []
	for e in employees:
		worked.append(e.data)
	for st in s.staff:
		var pay: float = st.wage if st in worked else st.wage * 0.5  # sick pay
		wages += pay
	Game.charge(snappedf(wages, 0.01), "wages")
	Game.charge(float(sd.get("rent", 40)), "rent")
	Game.charge(s.daily_maintenance(DB), "maintenance")

	# Staff morale and quitting
	var quit: Array = []
	for st in s.staff:
		st.days_worked += 1
		var tired: float = st.stress
		st.happiness = clampf(st.happiness + (45.0 - tired) * 0.15 + (st.wage - st.fair_wage()) * 0.6, 0.0, 100.0)
		st.stress = tired * 0.25
		if st.happiness < 18.0 and rng.randf() < 0.4 and s.staff.size() > 1:
			quit.append(st)
	for q in quit:
		s.staff.erase(q)

	var revenue := s.ledger.revenue()
	var profit := s.ledger.profit()
	var record := s.ledger.close_day(Game.day, s.rating, stats["served"], stats["lost"])
	var passive := Game.passive_income()
	if absf(passive) > 0.01:
		Game.money += passive
		Bus.money_changed.emit(Game.money)
	Game.lifetime_profit += profit + passive
	s.days_open += 1
	var old_rank := Game.career_rank
	var ranked := Game.update_career()

	# Smart inventory restocks for tomorrow
	var restock_cost := 0.0
	s.ledger.reset_day()
	if s.has_item("smart_inventory"):
		restock_cost = auto_restock(s)

	var summary := {
		"day": Game.day, "revenue": revenue, "profit": profit, "record": record,
		"served": stats["served"], "lost": stats["lost"], "satisfaction": avg_satisfaction(),
		"accuracy": accuracy(), "efficiency": efficiency(), "mistakes": stats["mistakes"],
		"mistake_count": stats["mistake_count"], "waste": s.inventory.wasted_value, "spoiled": spoiled,
		"rating": s.rating, "rating_delta": s.rating - float(stats["rating_start"]),
		"quit": quit.map(func(q): return q.name), "passive": passive, "ranked_up": ranked,
		"old_rank": old_rank, "rank": Game.career_rank, "event": event.get("name", ""),
		"critic": stats["critic"], "viral": stats["viral"], "inspection": stats["inspection"],
		"late": stats["late"], "sick": stats["sick"], "perfect_fries": stats["perfect_fries"],
		"burned": stats["burned"], "restock": restock_cost, "breakdown": record.get("breakdown", {}),
		"donuts_sold": stats["donuts_sold"], "drinks_sold": stats["drinks_sold"],
	}
	Game.day += 1
	Game.refresh_candidates()
	Game.today_event = EventDirector.roll(rng, Game.day, DB.events, DB.daily_event_chance)
	return summary


## Buy packs until every ingredient reaches its target. Returns $ spent.
static func auto_restock(s: StoreState) -> float:
	var spent := 0.0
	for ing in DB.ingredients:
		var id: String = ing["id"]
		var target := int(s.inventory.targets.get(id, ing.get("start", 0)))
		while s.inventory.count(id) < target:
			if not Game.spend(float(ing["pack_cost"]), "ingredients"):
				return spent
			s.inventory.add(id, int(ing["pack"]))
			spent += float(ing["pack_cost"])
	return spent


# =============================================================================
# Input (tap/click selection)
# =============================================================================

func _unhandled_input(ev: InputEvent) -> void:
	var pressed := false
	var screen_pos := Vector2.ZERO
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		pressed = true
		screen_pos = ev.position
	elif ev is InputEventScreenTouch and ev.pressed:
		pressed = true
		screen_pos = ev.position
	if not pressed:
		return
	var p := get_global_transform_with_canvas().affine_inverse() * screen_pos
	select_at(p)


func select_at(p: Vector2) -> void:
	_clear_selection()
	for e in employees:
		if e.present and e.hit_test(p):
			e.selected = true
			Bus.employee_selected.emit(e)
			Sfx.play("click")
			return
	for c in customers:
		if c.hit_test(p):
			c.selected = true
			Bus.employee_selected.emit(c)
			Sfx.play("click")
			return
	for st in stations:
		if st.hit_test(p):
			Bus.station_selected.emit(st)
			Sfx.play("click")
			return
	Bus.employee_selected.emit(null)


func _clear_selection() -> void:
	for e in employees:
		e.selected = false
	for c in customers:
		c.selected = false


# =============================================================================
# FX
# =============================================================================

func _on_float_text(pos: Vector2, text: String, color: Color) -> void:
	if not is_inside_tree():
		return
	var ft := FloatText.new()
	ft.text = text
	ft.color = color
	ft.position = pos
	_fx.add_child(ft)


func _on_burst(pos: Vector2, kind: String) -> void:
	if not is_inside_tree():
		return
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 24
	p.lifetime = 1.0
	p.spread = 180.0
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 160.0
	p.gravity = Vector2(0, 240)
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	match kind:
		"sparkle":
			p.color = Color("#ffd23f")
			p.gravity = Vector2(0, -40)
		"smoke":
			p.color = Color(0.25, 0.25, 0.25, 0.7)
			p.gravity = Vector2(0, -80)
			p.scale_amount_max = 12.0
			p.initial_velocity_max = 50.0
		"confetti":
			var g := Gradient.new()
			g.offsets = PackedFloat32Array([0.0, 0.33, 0.66, 1.0])
			g.colors = PackedColorArray([Color("#ff6f91"), Color("#4f8cff"), Color("#ffd23f"), Color("#2fae6b")])
			p.color_initial_ramp = g
			p.amount = 60
			p.lifetime = 1.8
	_fx.add_child(p)
	p.emitting = true
	get_tree().create_timer(2.5).timeout.connect(p.queue_free)


# =============================================================================
# Drawing the building
# =============================================================================

func _draw() -> void:
	var sd := Game.store_def() if Game.started else {}
	var wall := Color(sd.get("wall", "#ffe3c2"))
	var fa := Color(sd.get("floor_a", "#f4d8b4"))
	var fb := Color(sd.get("floor_b", "#ecc99f"))
	# Outside / sky band
	draw_rect(Rect2(-400, -200, W + 800, H + 400), clock.sky_color().darkened(0.15))
	# Kitchen floor (white tile)
	var tile := 40.0
	for y in range(100, 330, int(tile)):
		for x in range(20, 1260, int(tile)):
			var c := Color("#f4f6f8") if ((x + y) / int(tile)) % 2 == 0 else Color("#e6eaee")
			draw_rect(Rect2(x, y, tile, tile), c)
	# Customer floor (checker)
	for y in range(384, 720, int(tile)):
		for x in range(20, 1260, int(tile)):
			draw_rect(Rect2(x, y, tile, tile), fa if ((x + y) / int(tile)) % 2 == 0 else fb)
	# Back wall with windows
	draw_rect(Rect2(20, 52, 1240, 60), wall)
	for i in 6:
		var wr := Rect2(60 + i * 140, 62, 90, 36)
		draw_rect(wr, clock.sky_color())
		if event.get("id", "") == "snow_day":
			for sn in _snow:
				var sp := Vector2(fmod(sn.x + i * 13.0, wr.size.x), fmod(sn.y + clock.hour * 60.0, wr.size.y))
				draw_circle(wr.position + sp, 1.5, Color(1, 1, 1, 0.9))
		draw_rect(wr, Color(1, 1, 1, 0.6), false, 3.0)
	# Brand sign
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(960, 58, 240, 46), Color("#ff6f91"))
	draw_string(font, Vector2(978, 90), "GLAZE & GRIND", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	# Side walls
	draw_rect(Rect2(0, 52, 20, H), wall.darkened(0.1))
	draw_rect(Rect2(1260, 52, 20, H), wall.darkened(0.1))
	# Counter band
	draw_rect(Rect2(20, 322, 880, 62), Color("#c98a5a"))
	draw_rect(Rect2(20, 322, 880, 10), Color("#e2a878"))
	# Kitchen partition by break room
	draw_rect(Rect2(990, 112, 8, 210), wall.darkened(0.15))
	# Tables (decor)
	for tp in [Vector2(1000, 470), Vector2(1140, 470), Vector2(1000, 590), Vector2(1140, 590)]:
		draw_circle(tp + Vector2(4, 6), 30, Color(0, 0, 0, 0.1))
		draw_circle(tp, 30, Color("#ffffff"))
		draw_circle(tp, 26, Color("#ffd6e0"))
		for a in 4:
			draw_circle(tp + Vector2.from_angle(a * PI * 0.5 + 0.6) * 44, 11, Color("#4f8cff"))
	# Front windows + door
	draw_rect(Rect2(20, 700, 1130, 20), wall.darkened(0.05))
	for i in 7:
		draw_rect(Rect2(40 + i * 160, 703, 130, 14), clock.sky_color())
	draw_rect(Rect2(1150, 700, 72, 20), Color("#8a5a36"))
	# Queue rope
	draw_line(Vector2(222, 440), Vector2(222, 690), Color("#c0392b"), 3.0)
	for y in [440, 520, 600, 690]:
		draw_circle(Vector2(222, y), 5, Color("#c9a227"))
