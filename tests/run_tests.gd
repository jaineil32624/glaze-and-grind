extends SceneTree
## Headless unit tests for the simulation core.
## Run: godot --headless --path . -s tests/run_tests.gd   (exit code = number of failures)

var _failures := 0
var _passes := 0
var _current := ""
var DB
var Game
var Saves


func _initialize() -> void:
	pass


func _process(_d: float) -> bool:
	DB = root.get_node("DB")
	Game = root.get_node("Game")
	Saves = root.get_node("Saves")
	for m in get_method_list():
		var n: String = m["name"]
		if n.begins_with("test_"):
			_current = n
			call(n)
	print("\n%d passed, %d failed" % [_passes, _failures])
	quit(_failures)
	return true


func check(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures += 1
		printerr("FAIL [%s] %s" % [_current, msg])


func near(a: float, b: float, msg: String, eps: float = 0.001) -> void:
	check(absf(a - b) <= eps, "%s (got %s, expected %s)" % [msg, a, b])


# --- Ledger -----------------------------------------------------------------

func test_ledger_math() -> void:
	var l := Ledger.new()
	l.add_revenue("sales", 100.0, 7.5)
	l.add_revenue("tips", 12.5, 8.0)
	l.add_expense("wages", 60.0)
	l.add_expense("rent", 40.0)
	near(l.revenue(), 112.5, "revenue")
	near(l.expenses(), 100.0, "expenses")
	near(l.profit(), 12.5, "profit")
	near(l.hourly_revenue[1], 100.0, "7am bucket")
	near(l.hourly_revenue[2], 12.5, "8am bucket")
	var rec := l.close_day(3, 4.1, 20, 2)
	check(rec["day"] == 3 and rec["served"] == 20, "close_day record")
	check(l.history.size() == 1, "history grows")


# --- Inventory ---------------------------------------------------------------

func test_inventory_consume_and_case() -> void:
	var inv := Inventory.new()
	inv.stock = {"sugar": 3, "flour": 1}
	check(inv.has_all({"sugar": 1, "flour": 1}), "has_all true")
	check(not inv.has_all({"sugar": 2}, 2), "has_all with times")
	check(inv.missing({"sugar": 1, "milk": 1}) == "milk", "missing ingredient")
	check(inv.consume({"sugar": 2}), "consume ok")
	check(inv.count("sugar") == 1, "consumed")
	check(not inv.consume({"sugar": 5}), "consume fails when short")
	check(inv.count("sugar") == 1, "failed consume leaves stock")
	inv.add_to_case("glazed", [0.5, 0.9, 1.0])
	var taken := inv.take_from_case("glazed", 2)
	check(taken == [0.5, 0.9], "case is FIFO")
	check(inv.case_count("glazed") == 1, "case count after take")
	var n := inv.spoil_case(func(_id): return 2.0)
	check(n == 1 and inv.case_total() == 0, "spoil empties case")
	check(inv.wasted_value > 0.0, "spoilage counted as waste")


# --- Orders -----------------------------------------------------------------

func test_order_pricing() -> void:
	var o := Order.new()
	o.donuts = {"glazed": 2}
	o.drinks = [{"id": "latte", "flavor": true, "done": false, "quality": 0.0}]
	var expected := float(DB.donut("glazed")["price"]) * 2 + float(DB.drink("latte")["price"]) + float(DB.flavor_shot["price"])
	near(o.subtotal(DB), snappedf(expected, 0.01), "subtotal")
	o.price_mult = 1.5
	near(o.subtotal(DB), snappedf(expected * 1.5, 0.01), "store price multiplier")
	check(o.donut_count() == 2, "donut count")
	check(not o.drinks_done(), "drinks not done")
	o.drinks[0]["done"] = true
	check(o.drinks_done(), "drinks done")


func test_customer_order_respects_menu() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var allowed := ["hot_coffee", "glazed"]
	for i in 30:
		var def: Dictionary = DB.customers[i % DB.customers.size()]
		var prof := CustomerProfile.create(rng, def, 1.0, 0.2)
		var o := CustomerProfile.build_order(rng, prof, def, DB, func(id): return id in allowed, 0.5, 0.0)
		for id in o.all_item_ids():
			check(id in allowed, "ordered only available items (%s)" % id)
		check(not o.is_empty(), "order not empty")
		check(prof.patience > 0.0, "patience positive")


# --- Tasks ------------------------------------------------------------------

func test_task_scoring() -> void:
	var t := WorkTask.new("make_drink", "coffee", 4.0, {}, 2)
	check(WorkTask.score(t, 0.0, 0.0, 0.0, "", 1) == -INF, "skill gate")
	var calm := WorkTask.score(t, 0.0, 0.0, 0.0, "", 2)
	var urgent := WorkTask.score(t, 0.0, 1.0, 0.0, "", 2)
	check(urgent > calm, "urgency raises priority")
	var focused := WorkTask.score(t, 0.0, 0.0, 0.0, "coffee", 2)
	var unfocused := WorkTask.score(t, 0.0, 0.0, 0.0, "fryer", 2)
	check(focused > calm and unfocused < calm, "focus bonus / penalty")
	var far := WorkTask.score(t, 0.0, 0.0, 800.0, "", 2)
	check(far < calm, "distance penalty")


func test_task_board_picks_best() -> void:
	var b := TaskBoard.new()
	var a := b.post(WorkTask.new("mix_dough", "mixer", 5.0))
	var c := b.post(WorkTask.new("assemble", "pickup", 2.0))
	var blocked := b.post(WorkTask.new("take_order", "register", 2.0))
	var st_ok := Node2D.new()
	var station_for := func(t): return null if t == blocked else st_ok
	var res := b.best_for(1, "", Vector2.ZERO, 0.0, station_for, func(_s): return Vector2.ZERO,
		func(_t): return 0.0, func(_t): return true)
	check(res["task"] == c, "highest base priority wins when station free")
	c.claimant = st_ok
	res = b.best_for(1, "", Vector2.ZERO, 0.0, station_for, func(_s): return Vector2.ZERO,
		func(_t): return 0.0, func(t): return t != a)
	check(res["task"] == null, "claimed / unstartable / no-station tasks are skipped")
	b.release(c)
	check(c.claimant == null, "release clears claim")
	st_ok.free()


# --- Staff -------------------------------------------------------------------

func test_staff_mistakes_and_xp() -> void:
	var careful := StaffData.new()
	careful.accuracy = 10
	var sloppy := StaffData.new()
	sloppy.accuracy = 1
	check(careful.mistake_chance("make_drink") < sloppy.mistake_chance("make_drink"), "accuracy lowers mistakes")
	var calm_p := sloppy.mistake_chance("make_drink")
	sloppy.stress = 90.0
	check(sloppy.mistake_chance("make_drink") > calm_p, "stress raises mistakes")
	check(sloppy.mistake_chance("make_drink") <= 0.6, "mistake chance capped")
	var s := StaffData.new()
	s.intelligence = 10
	var leveled := false
	for i in 40:
		if s.gain_xp(5.0):
			leveled = true
	check(leveled and s.level >= 2, "xp levels up")
	var copy := StaffData.from_dict(s.to_dict())
	check(copy.level == s.level and copy.name == s.name and is_equal_approx(copy.xp, s.xp), "staff round trip")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 20:
		var g := StaffData.generate(rng)
		check(g.speed >= 1 and g.speed <= 10 and g.wage > 0.0, "generated stats in range")


# --- Fry curve -----------------------------------------------------------------

func test_fry_curve() -> void:
	near(FryCurve.quality(0.62, 0.62, 0.12), 1.0, "perfect pull")
	check(FryCurve.quality(1.0, 0.62, 0.12) == 0.0, "burned")
	check(FryCurve.is_burned(1.05), "burn point")
	check(FryCurve.quality(0.3, 0.62, 0.12) < FryCurve.quality(0.55, 0.62, 0.12), "underdone is worse")
	check(FryCurve.quality(0.85, 0.62, 0.12, 0.1) >= FryCurve.quality(0.85, 0.62, 0.12, 0.0), "fryer bonus widens window")
	check(FryCurve.grade(1.0) == "PERFECT!" and FryCurve.grade(0.0) == "BURNED", "grades")


# --- Career / clock / events ---------------------------------------------------

func test_career() -> void:
	check(Career.rank_for(DB.career, 0.0, 5.0) == 0, "start rank")
	check(Career.rank_for(DB.career, 1e9, 2.0) == 0, "rating gate")
	check(Career.rank_for(DB.career, 1e9, 5.0) == 5, "top rank")
	check(Career.rank_for(DB.career, 0.0, 0.0, 3) == 3, "rank never decreases")


func test_day_clock() -> void:
	var c := DayClock.new()
	check(c.clock_text() == "6:00 AM", "opening time text")
	check(c.phase_name() == "Morning Rush", "opening phase")
	near(DayClock.traffic_at(8.0), 1.0, "morning rush peak")
	check(DayClock.traffic_at(15.0) < DayClock.traffic_at(12.5), "afternoon slower than lunch")
	c.advance(DayClock.REAL_SECONDS_PER_DAY)
	check(c.is_closed(), "closes after a full day")
	check(not c.is_open_for_entry(), "no entry after close")


func test_events() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	check(EventDirector.roll(rng, 1, DB.events, 1.0).is_empty(), "no events on day 1")
	for i in 50:
		var e := EventDirector.roll(rng, 3, DB.events, 1.0)
		check(e.is_empty() or int(e.get("min_day", 1)) <= 3, "respects min_day")
	var m := EventDirector.merged_mix({"student": 1.0}, {"mix": {"student": 3.0}})
	near(m["student"], 3.0, "event mix boost")


# --- Behaviour tree --------------------------------------------------------------

class MockActor:
	var log: Array = []
	func yes() -> bool: return true
	func no() -> bool: return false
	func act_ok(_d) -> int:
		log.append("ok")
		return BT.Status.SUCCESS
	func act_run(_d) -> int:
		log.append("run")
		return BT.Status.RUNNING


func test_behaviour_tree() -> void:
	var a := MockActor.new()
	var tree := BT.Selector.new("root", [
		BT.Sequence.new("never", [BT.Condition.new(&"no"), BT.Action.new(&"act_ok")]),
		BT.Sequence.new("this", [BT.Condition.new(&"yes"), BT.Action.new(&"act_run")]),
		BT.Action.new(&"act_ok"),
	])
	check(tree.tick(a, 0.1) == BT.Status.RUNNING, "selector returns running child")
	check(a.log == ["run"], "earlier failing branch skipped, later branch not reached")


# --- Data & mods ---------------------------------------------------------------

func test_data_registry_and_mods() -> void:
	check(DB.donuts.size() >= 5 and DB.drinks.size() >= 8, "base content loaded")
	check(DB.customers.size() == 6 and DB.stores.size() == 6, "customers and stores")
	check(DB.load_errors.is_empty(), "no load errors: %s" % str(DB.load_errors))
	var price_before := float(DB.donut("glazed")["price"])
	DB.apply_mod({"donuts": [{"id": "glazed", "price": 9.99}, {"id": "test_cruller", "name": "Cruller", "price": 2.5}]})
	near(float(DB.donut("glazed")["price"]), 9.99, "mod overrides by id")
	check(not DB.donut("test_cruller").is_empty(), "mod adds new item")
	DB.load_all("user://__no_mods__/")
	near(float(DB.donut("glazed")["price"]), price_before, "reload restores base data")


# --- Save system ------------------------------------------------------------------

func test_save_round_trip() -> void:
	Saves.save_dir = "user://test_saves/"
	Game.new_game(99)
	Game.money = 1234.5
	Game.day = 7
	Game.current().par["glazed"] = 14
	var first_name: String = Game.current().staff[0].name
	check(Saves.save("slot_3"), "save succeeds")
	Game.money = 0.0
	Game.day = 1
	check(Saves.load_slot("slot_3"), "load succeeds")
	near(Game.money, 1234.5, "money restored")
	check(Game.day == 7, "day restored")
	check(int(Game.current().par["glazed"]) == 14, "store state restored")
	check(Game.current().staff[0].name == first_name, "staff restored")
	Saves.delete("slot_3")
	check(not Saves.has_save("slot_3"), "delete")
	var v1 := {"schema_version": 1, "game": {"money": 5.0, "store": {"id": "mall", "rating": 4.0}}}
	var migrated: Dictionary = Saves.migrate(v1)
	check(migrated["schema_version"] == 2, "migrated version")
	check(migrated["game"]["stores"].has("mall") and migrated["game"]["active_store"] == "mall", "v1 store moved")


func test_store_state_economy() -> void:
	var s := StoreState.new()
	s.setup_new("main_street", DB)
	check(s.inventory.count("flour") > 0, "starting stock")
	var before := s.rating
	for i in 20:
		s.add_review(5.0, 1.0)
	check(s.rating > before and s.rating <= 5.0, "good reviews raise rating")
	check(s.daily_maintenance(DB) > 0.0, "maintenance cost")
	near(s.station_stat(DB, "fryer", "speed"), 1.0, "base fryer speed")
	s.equipment["fryer"] = 2
	check(s.station_stat(DB, "fryer", "speed") > 1.0, "upgraded fryer faster")
	var copy := StoreState.from_dict(s.to_dict())
	near(copy.rating, s.rating, "store round trip rating")
	check(copy.level_of("fryer") == 2, "store round trip equipment")
