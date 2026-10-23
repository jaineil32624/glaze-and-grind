class_name ManagementScreen
extends Control
## Between-shift management: restock, staff, upgrades, menu, stores, career.

signal start_day
signal save_requested
signal menu_requested

var _tabs: TabContainer
var _money: Label
var _title: Label
var _forecast: Label
var _pages: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("#ffe9d6")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	var v := UIKit.vbox([], 10)
	margin.add_child(v)
	_title = UIKit.label("", 28, UIKit.INK, true)
	_money = UIKit.label("", 26, UIKit.GREEN, true)
	v.add_child(UIKit.hbox([UIKit.label("🍩", 30), _title, UIKit.spacer(), _money]))
	_forecast = UIKit.label("", 15, UIKit.MUTED)
	v.add_child(_forecast)
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_tabs)
	for name in ["Restock", "Staff", "Upgrades", "Menu", "Stores", "Career"]:
		var page := UIKit.vbox([], 8)
		var sc := UIKit.scroll(page)
		sc.name = name
		_tabs.add_child(sc)
		_pages[name] = page
	var start := UIKit.button("Open the store  ▶", func(): start_day.emit(), UIKit.GREEN, 260)
	start.custom_minimum_size = Vector2(260, 58)
	start.add_theme_font_size_override("font_size", 22)
	v.add_child(UIKit.hbox([UIKit.button("Save", func(): save_requested.emit(), UIKit.BLUE),
		UIKit.button("Main menu", func(): menu_requested.emit(), UIKit.MUTED), UIKit.spacer(), start]))
	Bus.money_changed.connect(func(_m): _update_header())


func open() -> void:
	refresh()
	visible = true


func refresh() -> void:
	_update_header()
	_build_restock()
	_build_staff()
	_build_upgrades()
	_build_menu()
	_build_stores()
	_build_career()


func _update_header() -> void:
	if not Game.started:
		return
	_title.text = "%s · Day %d" % [Game.store_def().get("name", "Store"), Game.day]
	_money.text = UIKit.money(Game.money)
	_money.add_theme_color_override("font_color", UIKit.GREEN if Game.money >= 0 else UIKit.RED)
	var e := Game.today_event
	_forecast.text = ("Forecast for today: %s — %s" % [e.get("name", ""), e.get("desc", "")]) if not e.is_empty() \
		else "Forecast for today: a normal day. %s · Rating %.2f" % [Game.rank_title(), Game.current().rating]


func _section(page: VBoxContainer, title: String, sub: String = "") -> void:
	page.add_child(UIKit.label(title, 20, UIKit.PINK_DARK, true))
	if sub != "":
		var l := UIKit.label(sub, 14, UIKit.MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		page.add_child(l)


func _card(content: Control) -> PanelContainer:
	var p := UIKit.panel(content, Color.WHITE)
	return p


# --- Restock -------------------------------------------------------------------

func _build_restock() -> void:
	var page: VBoxContainer = _pages["Restock"]
	UIKit.clear(page)
	var s := Game.current()
	_section(page, "Ingredients", "Buy packs before opening. Running out mid-shift means menu items disappear and customers leave. Targets are what Smart Inventory restocks to.")
	page.add_child(UIKit.hbox([UIKit.button("Fill everything to target", func():
		StoreWorld.auto_restock(s)
		refresh(), UIKit.GREEN)]))
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 6)
	for h in ["Ingredient", "In stock", "Target", "", "", ""]:
		grid.add_child(UIKit.label(h, 13, UIKit.MUTED))
	for ing in DB.ingredients:
		var id: String = ing["id"]
		var n := s.inventory.count(id)
		var target := int(s.inventory.targets.get(id, ing.get("start", 0)))
		var swatch := ColorRect.new()
		swatch.color = Color(ing.get("icon", "#ffffff"))
		swatch.custom_minimum_size = Vector2(14, 14)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(UIKit.hbox([swatch, UIKit.label(ing["name"], 16)], 6))
		grid.add_child(UIKit.label(str(n), 16, UIKit.RED if n < target * 0.5 else UIKit.INK))
		var spin := SpinBox.new()
		spin.min_value = 0
		spin.max_value = 400
		spin.step = 5
		spin.value = target
		spin.custom_minimum_size = Vector2(110, 40)
		spin.value_changed.connect(func(v): s.inventory.targets[id] = int(v))
		grid.add_child(spin)
		var pack := int(ing["pack"])
		var cost := float(ing["pack_cost"])
		grid.add_child(UIKit.button("+%d  %s" % [pack, UIKit.money(cost)], func(): _buy(id, 1), UIKit.BLUE, 140))
		grid.add_child(UIKit.button("+%d  %s" % [pack * 5, UIKit.money(cost * 5)], func(): _buy(id, 5), UIKit.BLUE, 150))
		grid.add_child(UIKit.label("", 12))
	page.add_child(_card(grid))


func _buy(id: String, packs: int) -> void:
	var ing := DB.ingredient(id)
	if Game.spend(float(ing["pack_cost"]) * packs, "ingredients"):
		Game.current().inventory.add(id, int(ing["pack"]) * packs)
		Sfx.play("cash")
	else:
		Sfx.play("mistake")
	refresh()


# --- Staff -----------------------------------------------------------------------

func _build_staff() -> void:
	var page: VBoxContainer = _pages["Staff"]
	UIKit.clear(page)
	var s := Game.current()
	_section(page, "Your crew (%d / %d)" % [s.staff.size(), Game.staff_slots()],
		"Wages are per day. Raises make people happier; unhappy staff quit. Training gives XP toward new skills.")
	for sd in s.staff:
		page.add_child(_staff_card(sd, true))
	_section(page, "Applicants", "New applicants every day. Better candidates show up as your career grows.")
	for sd in Game.candidates:
		page.add_child(_staff_card(sd, false))


func _staff_card(sd: StaffData, hired: bool) -> PanelContainer:
	var h := UIKit.hbox([], 16)
	var left := UIKit.vbox([], 2)
	left.custom_minimum_size = Vector2(220, 0)
	left.add_child(UIKit.label("%s  · Lv %d" % [sd.name, sd.level], 20, UIKit.INK, true))
	left.add_child(UIKit.label("%s — %s" % [sd.pers()["label"], sd.pers()["desc"]], 13, UIKit.MUTED))
	left.add_child(UIKit.label("Wage %s/day" % UIKit.money(sd.wage), 15, UIKit.INK))
	if hired:
		left.add_child(UIKit.label("Happiness %d · Days %d" % [int(sd.happiness), sd.days_worked], 13, UIKit.MUTED))
	h.add_child(left)
	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 8)
	for row in [["Speed", sd.speed], ["Accuracy", sd.accuracy], ["Smarts", sd.intelligence], ["Teamwork", sd.teamwork], ["Reliability", sd.reliability]]:
		var l := UIKit.label(row[0], 13, UIKit.MUTED)
		l.custom_minimum_size = Vector2(80, 0)
		stats.add_child(l)
		var b := UIKit.bar(row[1], 10, UIKit.BLUE, 140)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		stats.add_child(b)
	h.add_child(stats)
	h.add_child(UIKit.spacer())
	var actions := UIKit.vbox([], 6)
	var s := Game.current()
	if hired:
		actions.add_child(UIKit.button("Raise +$5", func():
			sd.wage += 5.0
			sd.happiness = minf(100.0, sd.happiness + 12.0)
			refresh(), UIKit.GREEN, 150))
		var train := UIKit.button("Train $60 (+30 XP)", func():
			if Game.spend(60.0, "hiring"):
				sd.xp = maxf(sd.xp, 0.0)
				if sd.gain_xp(30.0 / (0.7 + sd.intelligence * 0.06)):
					Bus.toast.emit("%s reached level %d" % [sd.name, sd.level], UIKit.BLUE)
			refresh(), UIKit.BLUE, 150)
		train.disabled = sd.level >= StaffData.XP_LEVELS.size()
		actions.add_child(train)
		var fire := UIKit.button("Let go", func():
			if s.staff.size() > 1:
				s.staff.erase(sd)
			refresh(), UIKit.RED, 150)
		fire.disabled = s.staff.size() <= 1
		actions.add_child(fire)
	else:
		var cost := Game.hire_cost(sd)
		var hire := UIKit.button("Hire (%s)" % UIKit.money(cost), func():
			if s.staff.size() < Game.staff_slots() and Game.spend(cost, "hiring"):
				s.staff.append(sd)
				Game.candidates.erase(sd)
				Sfx.play("happy")
			refresh(), UIKit.GREEN, 150)
		hire.disabled = s.staff.size() >= Game.staff_slots() or Game.money < cost
		actions.add_child(hire)
		if s.staff.size() >= Game.staff_slots():
			actions.add_child(UIKit.label("No open slots", 12, UIKit.MUTED))
	h.add_child(actions)
	return _card(h)


# --- Upgrades ---------------------------------------------------------------------

func _build_upgrades() -> void:
	var page: VBoxContainer = _pages["Upgrades"]
	UIKit.clear(page)
	var s := Game.current()
	_section(page, "Equipment", "Faster stations serve more customers; better stations make higher-quality food. Upgrades raise daily maintenance.")
	for def in DB.stations:
		var id: String = def["id"]
		var lv := s.level_of(id)
		var costs: Array = def.get("costs", [0])
		var h := UIKit.hbox([], 14)
		var info := UIKit.vbox([], 2)
		info.add_child(UIKit.label("%s  ·  Level %d / %d" % [def["name"], lv + 1, costs.size()], 18, UIKit.INK, true))
		info.add_child(UIKit.label(def.get("desc", ""), 13, UIKit.MUTED))
		info.add_child(UIKit.label("Speed ×%.2f   Quality +%d%%   Upkeep $%d/day" % [s.station_stat(DB, id, "speed"),
			int(s.station_stat(DB, id, "quality") * 100), int(s.station_stat(DB, id, "maintenance"))], 13))
		h.add_child(info)
		h.add_child(UIKit.spacer())
		if lv + 1 < costs.size():
			var next_cost := float(costs[lv + 1])
			var min_ranks: Array = def.get("min_rank", [])
			var need_rank := int(min_ranks[lv + 1]) if lv + 1 < min_ranks.size() else 0
			var b := UIKit.button("Upgrade  %s" % UIKit.money(next_cost), func():
				if Game.spend(next_cost, "equipment"):
					s.equipment[id] = lv + 1
					Sfx.play("levelup")
				refresh(), UIKit.GREEN, 200)
			b.disabled = Game.money < next_cost or Game.career_rank < need_rank
			if Game.career_rank < need_rank:
				b.text = "Needs " + Game.rank_title(need_rank)
			h.add_child(b)
		else:
			h.add_child(UIKit.label("MAXED", 16, UIKit.GREEN, true))
		page.add_child(_card(h))
	_section(page, "Store improvements")
	for it in DB.items:
		var id: String = it["id"]
		var h := UIKit.hbox([], 14)
		var info := UIKit.vbox([], 2)
		info.add_child(UIKit.label(it["name"], 18, UIKit.INK, true))
		info.add_child(UIKit.label(it.get("desc", ""), 13, UIKit.MUTED))
		h.add_child(info)
		h.add_child(UIKit.spacer())
		if s.has_item(id):
			h.add_child(UIKit.label("OWNED", 16, UIKit.GREEN, true))
		else:
			var cost := float(it.get("cost", 0))
			var need := int(it.get("min_rank", 0))
			var b := UIKit.button("Buy  %s" % UIKit.money(cost), func():
				if Game.spend(cost, "equipment"):
					s.items.append(id)
					Sfx.play("levelup")
				refresh(), UIKit.GREEN, 200)
			b.disabled = Game.money < cost or Game.career_rank < need
			if Game.career_rank < need:
				b.text = "Needs " + Game.rank_title(need)
			h.add_child(b)
		page.add_child(_card(h))


# --- Menu / par levels --------------------------------------------------------------

func _build_menu() -> void:
	var page: VBoxContainer = _pages["Menu"]
	UIKit.clear(page)
	var s := Game.current()
	_section(page, "Donut par levels", "The crew fries a new batch (6) whenever the case drops below par. Higher par = shorter waits but more stale donuts at closing.")
	for d in DB.donuts:
		var id: String = d["id"]
		var h := UIKit.hbox([], 12)
		var sw := ColorRect.new()
		sw.color = Color(d.get("topping", "#fff"))
		sw.custom_minimum_size = Vector2(22, 22)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(sw)
		var nm := UIKit.label("%s  ·  %s" % [d["name"], UIKit.money(float(d["price"]) * float(Game.store_def().get("price", 1.0)))], 17)
		nm.custom_minimum_size = Vector2(300, 0)
		h.add_child(nm)
		if Game.is_unlocked(id):
			var par := int(s.par.get(id, 6))
			h.add_child(UIKit.button("−", func():
				s.par[id] = maxi(0, par - 2)
				refresh(), UIKit.BLUE, 48))
			h.add_child(UIKit.label("Par %d" % par, 17, UIKit.INK, true))
			h.add_child(UIKit.button("+", func():
				s.par[id] = mini(s.max_par(), par + 2)
				refresh(), UIKit.BLUE, 48))
		else:
			h.add_child(UIKit.label("Unlocks at " + Game.rank_title(int(d.get("unlock_rank", 0))), 14, UIKit.MUTED))
		page.add_child(_card(h))
	_section(page, "Drinks")
	for d in DB.drinks:
		var id: String = d["id"]
		var status := "On the menu"
		var col := UIKit.GREEN
		if not Game.is_unlocked(id):
			col = UIKit.MUTED
			if int(d.get("unlock_rank", 0)) > Game.career_rank:
				status = "Unlocks at " + Game.rank_title(int(d.get("unlock_rank", 0)))
			else:
				status = "Needs " + str(DB.item(d.get("requires_equipment", "")).get("name", "equipment"))
		var station_name := "Coffee Bar" if d["station"] == "coffee" else "Cold Bar"
		page.add_child(_card(UIKit.hbox([
			UIKit.label("%s  ·  %s" % [d["name"], UIKit.money(float(d["price"]) * float(Game.store_def().get("price", 1.0)))], 17),
			UIKit.label("%s · skill Lv %d" % [station_name, int(d.get("skill", 1))], 13, UIKit.MUTED), UIKit.spacer(),
			UIKit.label(status, 14, col)])))


# --- Stores -----------------------------------------------------------------------

func _build_stores() -> void:
	var page: VBoxContainer = _pages["Stores"]
	UIKit.clear(page)
	_section(page, "Locations", "Stores you own but aren't running still earn passive income based on their rating and crew. Each location has its own crew, stock and equipment.")
	for def in DB.stores:
		var id: String = def["id"]
		var owned := Game.stores.has(id)
		var h := UIKit.hbox([], 14)
		var info := UIKit.vbox([], 2)
		info.add_child(UIKit.label(def["name"] + ("  (managing)" if id == Game.active_store else ""), 19, UIKit.INK, true))
		info.add_child(UIKit.label("Traffic ×%.1f · Prices ×%.2f · Rent $%d/day · Crew slots %d" % [def["traffic"], def["price"], int(def["rent"]), int(def.get("staff_slots", 3))], 13, UIKit.MUTED))
		if owned:
			info.add_child(UIKit.label("Rating %.2f · %d crew" % [Game.stores[id].rating, Game.stores[id].staff.size()], 13))
		h.add_child(info)
		h.add_child(UIKit.spacer())
		if owned:
			if id != Game.active_store:
				h.add_child(UIKit.button("Manage this store", func():
					Game.active_store = id
					Game.refresh_candidates()
					refresh(), UIKit.BLUE, 200))
		else:
			var cost := float(def.get("cost", 0))
			var need := int(def.get("min_rank", 0))
			var b := UIKit.button("Open  %s" % UIKit.money(cost), func():
				if Game.spend(cost, "equipment"):
					var ns := StoreState.new()
					ns.setup_new(id, DB)
					for i in 2:
						ns.staff.append(StaffData.generate(Game.rng, Game.career_rank * 0.3))
					Game.stores[id] = ns
					Bus.toast.emit("Opened %s!" % def["name"], UIKit.GREEN)
					Sfx.play("levelup")
				refresh(), UIKit.GREEN, 200)
			b.disabled = Game.money < cost or Game.career_rank < need
			if Game.career_rank < need:
				b.text = "Needs " + Game.rank_title(need)
			h.add_child(b)
		page.add_child(_card(h))


# --- Career -----------------------------------------------------------------------

func _build_career() -> void:
	var page: VBoxContainer = _pages["Career"]
	UIKit.clear(page)
	_section(page, "Career: %s" % Game.rank_title(),
		"Lifetime profit %s · Current store rating %.2f" % [UIKit.money(Game.lifetime_profit), Game.current().rating])
	for c in DB.career:
		var r := int(c["rank"])
		var done := Game.career_rank >= r
		var h := UIKit.hbox([], 12)
		h.add_child(UIKit.label("✔" if done else "○", 20, UIKit.GREEN if done else UIKit.MUTED))
		var t := UIKit.label(c["title"], 18, UIKit.INK if done else UIKit.MUTED, done)
		t.custom_minimum_size = Vector2(220, 0)
		h.add_child(t)
		if r > 0:
			var pv := clampf(Game.lifetime_profit / float(c["profit"]), 0.0, 1.0)
			h.add_child(UIKit.label("Profit %s" % UIKit.money(float(c["profit"])), 13, UIKit.MUTED))
			h.add_child(UIKit.bar(pv * 100.0, 100.0, UIKit.GREEN, 160))
			h.add_child(UIKit.label("Rating %.1f★" % float(c["rating"]), 13, UIKit.GREEN if Game.current().rating >= float(c["rating"]) else UIKit.MUTED))
		page.add_child(_card(h))
	var hist: Array = Game.current().ledger.history
	if hist.size() > 0:
		_section(page, "Profit history (this store)")
		var lg := LineGraph.new()
		lg.title = "Daily profit"
		lg.color = UIKit.GREEN
		lg.fmt = "$%.0f"
		lg.bars = true
		var vals := PackedFloat32Array()
		var lo := 0.0
		for rec in hist:
			vals.append(float(rec["profit"]))
			lo = minf(lo, float(rec["profit"]))
		lg.fixed_min = lo
		lg.custom_minimum_size = Vector2(600, 150)
		lg.set_data(vals)
		page.add_child(lg)
