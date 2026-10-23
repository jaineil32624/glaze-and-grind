class_name HUD
extends Control
## In-shift interface: top bar, crew strip, order tickets, selection card,
## dashboard, rush-restock panel, fryer minigame and toasts.

signal menu_requested

const FOCUS_OPTIONS := [["", "Anywhere"], ["register", "Register"], ["mixer", "Mixer"], ["fryer", "Fryer"],
	["glaze", "Glaze"], ["coffee", "Coffee Bar"], ["cold", "Cold Bar"], ["pickup", "Pickup"]]

var world: StoreWorld
var _money: Label
var _clock: Label
var _phase: Label
var _rating: Label
var _event_chip: Label
var _speed_btns: Array = []
var _toasts: VBoxContainer
var _card: PanelContainer
var _card_box: VBoxContainer
var _selected = null              # Employee / Customer / Station
var _crew: HBoxContainer
var _tickets: VBoxContainer
var _dash: PanelContainer
var _graphs: Dictionary = {}
var _kpis: Dictionary = {}
var _restock: PanelContainer
var _restock_box: VBoxContainer
var _fry: PanelContainer
var _fry_bar: Control
var _fry_station: Station
var _hint: Label
var _refresh := 0.0
var _slow_refresh := 0
var _last_speed := 1.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_top_bar()
	_build_toasts()
	_build_card()
	_build_crew()
	_build_tickets()
	_build_dashboard()
	_build_restock()
	_build_fry()
	_hint = UIKit.label("", 15, Color.WHITE)
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.position = Vector2(-300, -150)
	_hint.custom_minimum_size = Vector2(600, 0)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(_hint)
	Bus.toast.connect(show_toast)
	Bus.employee_selected.connect(_on_select)
	Bus.station_selected.connect(_on_select)
	Bus.money_changed.connect(func(_m): _update_top())
	Bus.fry_started.connect(_on_fry_started)
	Bus.event_started.connect(_on_event)
	Bus.rank_up.connect(func(_r, title): show_toast("Promoted to %s!" % title, Color("#c9a227")))


func bind(w: StoreWorld) -> void:
	world = w
	_on_select(null)
	_fry.visible = false
	_restock.visible = false
	_rebuild_crew()
	_set_speed(1.0)
	if Game.day == 1 and Game.settings.get("show_tutorial", true):
		_hint.text = "Your crew works on their own. Tap a crew member to set their focus, tap a frying Fryer to pull the batch yourself, and keep an eye on stock!"
		get_tree().create_timer(14.0).timeout.connect(func(): _hint.text = "")
	else:
		_hint.text = ""


# --- Top bar -----------------------------------------------------------------

func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	var sb := UIKit._box(Color(1, 0.97, 0.93, 0.94), 0, Color(0, 0, 0, 0.1), 0)
	sb.border_width_bottom = 2
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	bar.add_theme_stylebox_override("panel", sb)
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.custom_minimum_size = Vector2(0, 52)
	add_child(bar)
	var h := UIKit.hbox([], 14)
	bar.add_child(h)
	var logo := UIKit.label("🍩", 26)
	h.add_child(logo)
	_money = UIKit.label("$0", 22, UIKit.GREEN, true)
	_money.custom_minimum_size = Vector2(130, 0)
	h.add_child(_money)
	var clock_box := UIKit.vbox([], 0)
	_clock = UIKit.label("6:00 AM", 18, UIKit.INK, true)
	_phase = UIKit.label("Morning Rush", 12, UIKit.MUTED)
	clock_box.add_child(_clock)
	clock_box.add_child(_phase)
	h.add_child(clock_box)
	_rating = UIKit.label("★★★☆☆", 20, Color("#c9a227"))
	h.add_child(_rating)
	_event_chip = UIKit.label("", 14, Color.WHITE)
	var chip_bg := UIKit._box(Color("#c45bff"), 10, Color(0, 0, 0, 0), 0)
	chip_bg.content_margin_left = 10
	chip_bg.content_margin_right = 10
	_event_chip.add_theme_stylebox_override("normal", chip_bg)
	_event_chip.visible = false
	h.add_child(_event_chip)
	h.add_child(UIKit.spacer())
	for s in [[0.0, "⏸"], [1.0, "1×"], [2.0, "2×"], [3.0, "3×"]]:
		var spd: float = s[0]
		var b := UIKit.button(s[1], func(): _set_speed(spd), UIKit.BLUE, 48)
		b.toggle_mode = false
		_speed_btns.append([spd, b])
		h.add_child(b)
	h.add_child(UIKit.button("Stock", _toggle_restock, Color("#ff8a3d")))
	h.add_child(UIKit.button("Stats", toggle_dashboard, Color("#6c5ce7")))
	h.add_child(UIKit.button("☰", func(): menu_requested.emit(), UIKit.INK, 48))


func _set_speed(s: float) -> void:
	if s > 0.0:
		_last_speed = s
	Game.time_scale = s
	for pair in _speed_btns:
		pair[1].modulate = Color(1, 1, 1, 1) if is_equal_approx(pair[0], s) else Color(1, 1, 1, 0.55)


func toggle_pause() -> void:
	_set_speed(_last_speed if Game.time_scale == 0.0 else 0.0)


func set_speed(s: float) -> void:
	_set_speed(s)


func _update_top() -> void:
	if _money == null:
		return
	_money.text = UIKit.money(Game.money)
	_money.add_theme_color_override("font_color", UIKit.GREEN if Game.money >= 0 else UIKit.RED)
	if world:
		_clock.text = world.clock.clock_text()
		_phase.text = world.clock.phase_name() + " · Day %d" % Game.day
	if Game.started:
		var r: float = Game.current().rating
		_rating.text = "%s %.1f" % [UIKit.stars(r), r]


func _on_event(e: Dictionary) -> void:
	_event_chip.text = "  %s  " % e.get("name", "")
	var sb: StyleBoxFlat = _event_chip.get_theme_stylebox("normal").duplicate()
	sb.bg_color = Color(e.get("color", "#c45bff"))
	_event_chip.add_theme_stylebox_override("normal", sb)
	_event_chip.visible = true
	show_toast("%s — %s" % [e.get("name", ""), e.get("desc", "")], Color(e.get("color", "#c45bff")))


func clear_event() -> void:
	_event_chip.visible = false


# --- Toasts ------------------------------------------------------------------

func _build_toasts() -> void:
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toasts.position = Vector2(-260, 62)
	_toasts.custom_minimum_size = Vector2(520, 0)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toasts)


func show_toast(text: String, color: Color) -> void:
	var l := UIKit.label(text, 16, Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	var sb := UIKit._box(Color(color, 0.92), 12, Color(0, 0, 0, 0), 0)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	l.add_theme_stylebox_override("normal", sb)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.35))
	l.add_theme_constant_override("outline_size", 3)
	_toasts.add_child(l)
	while _toasts.get_child_count() > 4:
		_toasts.get_child(0).queue_free()
		_toasts.remove_child(_toasts.get_child(0))
	var tw := create_tween()
	tw.tween_interval(3.2)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


# --- Selection card ----------------------------------------------------------

func _build_card() -> void:
	_card = PanelContainer.new()
	_card.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_card.position = Vector2(12, -420)
	_card.custom_minimum_size = Vector2(300, 0)
	_card_box = UIKit.vbox([], 6)
	_card.add_child(_card_box)
	_card.visible = false
	add_child(_card)


func _on_select(obj) -> void:
	_selected = obj
	if obj == null:
		_card.visible = false
		return
	if obj is Station and obj.type == "fryer" and obj.current_task != null and obj.current_task.kind == "fry_batch":
		open_fry(obj)
	_card.visible = true
	_rebuild_card()


func _rebuild_card() -> void:
	UIKit.clear(_card_box)
	var o = _selected
	if o == null or not is_instance_valid(o):
		_card.visible = false
		return
	var close := UIKit.button("✕", func(): _on_select(null), UIKit.MUTED, 40)
	close.custom_minimum_size = Vector2(40, 36)
	if o is Employee:
		var sd: StaffData = o.data
		_card_box.add_child(UIKit.hbox([UIKit.label(sd.name, 22, UIKit.INK, true), UIKit.label("Lv %d" % sd.level, 15, UIKit.BLUE), UIKit.spacer(), close]))
		_card_box.add_child(UIKit.label("%s · %s" % [sd.pers()["label"], o.status], 14, UIKit.MUTED))
		for row in [["Speed", sd.speed], ["Accuracy", sd.accuracy], ["Smarts", sd.intelligence], ["Teamwork", sd.teamwork], ["Reliability", sd.reliability]]:
			_card_box.add_child(_stat_row(row[0], float(row[1]), 10.0, UIKit.BLUE))
		_card_box.add_child(_stat_row("Stress", sd.stress, 100.0, UIKit.RED if sd.stress > 70 else UIKit.AMBER))
		_card_box.add_child(_stat_row("Happiness", sd.happiness, 100.0, UIKit.GREEN))
		_card_box.add_child(_stat_row("XP", sd.xp, sd.next_level_xp(), Color("#6c5ce7")))
		var opt := OptionButton.new()
		for i in FOCUS_OPTIONS.size():
			opt.add_item("Focus: " + FOCUS_OPTIONS[i][1], i)
			if FOCUS_OPTIONS[i][0] == sd.focus:
				opt.select(i)
		opt.custom_minimum_size = Vector2(0, 44)
		opt.item_selected.connect(func(i): sd.focus = FOCUS_OPTIONS[i][0])
		_card_box.add_child(opt)
		_card_box.add_child(UIKit.label("Skills: " + sd.skill_label(), 12, UIKit.MUTED))
		if sd.stress > 50 and not o.on_break:
			_card_box.add_child(UIKit.button("Send on break", func():
				o.on_break = true
				if o.task != null:
					world.abandon_task(o), Color("#6c5ce7")))
	elif o is Customer:
		var p: CustomerProfile = o.profile
		_card_box.add_child(UIKit.hbox([UIKit.label(p.type_name, 20, UIKit.INK, true), UIKit.spacer(), close]))
		if p.returning:
			_card_box.add_child(UIKit.label("♥ Returning regular", 13, UIKit.PINK))
		_card_box.add_child(_stat_row("Mood", p.mood * 100.0, 100.0, o.mood_color()))
		_card_box.add_child(UIKit.label("Wants: " + o.order.describe(DB), 14))
		_card_box.add_child(UIKit.label("Waited %ds · Patience %ds" % [int(o.waited), int(p.patience)], 13, UIKit.MUTED))
		if p.special == "critic":
			_card_box.add_child(UIKit.label("Their review counts ×5!", 13, Color("#c9a227")))
		elif p.special == "viral":
			_card_box.add_child(UIKit.label("Delight them and they might go viral.", 13, Color("#c45bff")))
	elif o is Station:
		var st: Station = o
		var title := st.label if st.label != "" else "Break Room"
		_card_box.add_child(UIKit.hbox([UIKit.label(title, 20, UIKit.INK, true), UIKit.spacer(), close]))
		if st.type == "case":
			var inv: Inventory = Game.current().inventory
			for d in DB.donuts:
				if Game.is_unlocked(d["id"]):
					_card_box.add_child(UIKit.label("%s: %d (par %d)" % [d["name"], inv.case_count(d["id"]), int(Game.current().par.get(d["id"], 0))], 14))
			_card_box.add_child(UIKit.label("Dough ready: %d" % inv.dough, 14, UIKit.MUTED))
		elif st.type == "break":
			_card_box.add_child(UIKit.label("Stressed staff rest here automatically.", 14, UIKit.MUTED))
		else:
			var def := DB.station(st.type)
			_card_box.add_child(UIKit.label("Level %d · Speed ×%.2f" % [st.level + 1, world.station_speed(st)], 14))
			_card_box.add_child(UIKit.label(str(def.get("desc", "")), 13, UIKit.MUTED))
			if st.user != null:
				_card_box.add_child(UIKit.label("In use by " + st.user.data.name, 13))
			if st.broken:
				_card_box.add_child(UIKit.button("Repair (%s)" % UIKit.money(world.repair_cost()), func():
					world.repair(st)
					_rebuild_card(), UIKit.RED))
			if not st.powered:
				_card_box.add_child(UIKit.label("No power — waiting for it to come back.", 13, UIKit.RED))
			if st.type == "fryer" and st.current_task != null and st.current_task.kind == "fry_batch":
				_card_box.add_child(UIKit.button("Pull this batch yourself", func(): open_fry(st), Color("#ff8a3d")))
			var open := world.board.tasks.filter(func(t): return t.station_type == st.type and t.claimant == null).size()
			_card_box.add_child(UIKit.label("Waiting tasks: %d" % open, 13, UIKit.MUTED))


func _stat_row(name: String, v: float, max_v: float, c: Color) -> HBoxContainer:
	var l := UIKit.label(name, 13, UIKit.MUTED)
	l.custom_minimum_size = Vector2(84, 0)
	var b := UIKit.bar(v, max_v, c, 150)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return UIKit.hbox([l, b, UIKit.label(str(int(v)), 13)], 6)


# --- Crew strip --------------------------------------------------------------

func _build_crew() -> void:
	var p := PanelContainer.new()
	var sb := UIKit._box(Color(1, 0.97, 0.93, 0.9), 12, Color(0, 0, 0, 0.1), 1)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", sb)
	p.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	p.position = Vector2(12, -86)
	_crew = UIKit.hbox([], 8)
	p.add_child(_crew)
	add_child(p)


func _rebuild_crew() -> void:
	UIKit.clear(_crew)
	if world == null:
		return
	for e in world.employees:
		var b := Button.new()
		b.custom_minimum_size = Vector2(116, 64)
		b.focus_mode = Control.FOCUS_ALL
		var sb := UIKit._box(Color.WHITE, 10, Color(0, 0, 0, 0.1), 1)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
		var v := UIKit.vbox([], 1)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.position = Vector2(8, 4)
		var nl := UIKit.label(e.data.name, 14, UIKit.INK, true)
		var stl := UIKit.label("", 11, UIKit.MUTED)
		stl.clip_text = true
		stl.custom_minimum_size = Vector2(100, 0)
		var sbar := UIKit.bar(e.data.stress, 100, UIKit.AMBER, 100)
		sbar.custom_minimum_size = Vector2(100, 7)
		for c in [nl, stl, sbar]:
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v.add_child(c)
		b.add_child(v)
		b.set_meta("emp", e)
		b.set_meta("status", stl)
		b.set_meta("stress", sbar)
		b.pressed.connect(func():
			for x in world.employees:
				x.selected = false
			e.selected = true
			Bus.employee_selected.emit(e))
		_crew.add_child(b)


func _update_crew() -> void:
	for b in _crew.get_children():
		var e: Employee = b.get_meta("emp")
		if not is_instance_valid(e):
			continue
		var st := "Not here yet" if not e.present else e.status
		(b.get_meta("status") as Label).text = st
		var sb: ProgressBar = b.get_meta("stress")
		sb.value = e.data.stress
		var col := UIKit.RED if e.data.stress > 75 else (UIKit.AMBER if e.data.stress > 45 else UIKit.GREEN)
		(sb.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = col


# --- Order tickets -----------------------------------------------------------

func _build_tickets() -> void:
	_tickets = UIKit.vbox([], 4)
	_tickets.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_tickets.position = Vector2(-236, 64)
	_tickets.custom_minimum_size = Vector2(224, 0)
	_tickets.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tickets)


func _update_tickets() -> void:
	UIKit.clear(_tickets)
	if world == null or _dash.visible:
		return
	var shown := 0
	for o in world.pending_orders:
		if shown >= 6:
			_tickets.add_child(UIKit.label("+%d more" % (world.pending_orders.size() - shown), 12, UIKit.MUTED))
			break
		var c = o.customer
		var mood: float = c.profile.mood if (c != null and is_instance_valid(c)) else 0.0
		var col := UIKit.GREEN if mood > 0.6 else (UIKit.AMBER if mood > 0.3 else UIKit.RED)
		var sb := UIKit._box(Color.WHITE, 8, col, 0)
		sb.border_width_left = 6
		sb.content_margin_left = 10
		sb.content_margin_right = 8
		sb.content_margin_top = 3
		sb.content_margin_bottom = 3
		var done := 0
		for d in o.drinks:
			if d["done"]:
				done += 1
		var l := UIKit.label("#%d  %s\n%d/%d drinks%s" % [o.id, o.describe(DB), done, o.drinks.size(), "  · packing" if o.get_meta("assemble_posted", false) else ""], 12)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		l.add_theme_stylebox_override("normal", sb)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tickets.add_child(l)
		shown += 1


# --- Dashboard ---------------------------------------------------------------

func _build_dashboard() -> void:
	_dash = PanelContainer.new()
	_dash.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_dash.offset_left = -300
	_dash.offset_top = 60
	_dash.offset_bottom = -10
	_dash.offset_right = -8
	var v := UIKit.vbox([], 6)
	v.add_child(UIKit.label("Live Dashboard", 20, UIKit.INK, true))
	var kp := GridContainer.new()
	kp.columns = 2
	kp.add_theme_constant_override("h_separation", 12)
	for k in [["served", "Served"], ["lost", "Walked out"], ["accuracy", "Accuracy"], ["waste", "Food waste"], ["clean", "Cleanliness"], ["mistakes", "Mistakes"]]:
		var l := UIKit.label(k[1] + ": —", 13)
		_kpis[k[0]] = [l, k[1]]
		kp.add_child(l)
	v.add_child(kp)
	var gbox := UIKit.vbox([], 6)
	for g in [["revenue", "Revenue today", Color("#2fae6b"), "$%.0f"], ["profit", "Profit today", Color("#4f8cff"), "$%.0f"],
			["happiness", "Customer happiness", Color("#ff6f91"), "%.0f%%"], ["efficiency", "Crew efficiency", Color("#6c5ce7"), "%.0f%%"],
			["rating", "Store rating", Color("#c9a227"), "%.2f★"], ["waste", "Food waste", Color("#e5383b"), "$%.1f"],
			["hourly", "Revenue by hour", Color("#ff8a3d"), "$%.0f"]]:
		var lg := LineGraph.new()
		lg.title = g[1]
		lg.color = g[2]
		lg.fmt = g[3]
		if g[0] in ["happiness", "efficiency"]:
			lg.fixed_min = 0.0
			lg.fixed_max = 100.0
		if g[0] == "rating":
			lg.fixed_min = 0.0
			lg.fixed_max = 5.0
		if g[0] == "hourly":
			lg.bars = true
			lg.fixed_min = 0.0
		_graphs[g[0]] = lg
		gbox.add_child(lg)
	v.add_child(UIKit.scroll(gbox))
	_dash.add_child(v)
	_dash.visible = false
	add_child(_dash)


func toggle_dashboard() -> void:
	_dash.visible = not _dash.visible
	if _dash.visible:
		_restock.visible = false
		_update_dashboard()


func _update_dashboard() -> void:
	if world == null or not _dash.visible:
		return
	var series := {"revenue": PackedFloat32Array(), "profit": PackedFloat32Array(), "happiness": PackedFloat32Array(),
		"efficiency": PackedFloat32Array(), "rating": PackedFloat32Array(), "waste": PackedFloat32Array()}
	for s in world.samples:
		series["revenue"].append(s["revenue"])
		series["profit"].append(s["profit"])
		series["happiness"].append(s["happiness"] * 100.0)
		series["efficiency"].append(s["efficiency"] * 100.0)
		series["rating"].append(s["rating"])
		series["waste"].append(s["waste"])
	# Live point for "now"
	var cs := Game.current()
	series["revenue"].append(cs.ledger.revenue())
	series["profit"].append(cs.ledger.profit())
	series["happiness"].append(world.avg_satisfaction() * 100.0)
	series["efficiency"].append(world.efficiency() * 100.0)
	series["rating"].append(cs.rating)
	series["waste"].append(cs.inventory.wasted_value)
	for k in series:
		_graphs[k].set_data(series[k])
	var hr := cs.ledger.hourly_revenue
	var upto := clampi(int(world.clock.hour) - 5, 1, hr.size())
	_graphs["hourly"].set_data(hr.slice(0, upto))
	var st := world.stats
	_kpis["served"][0].text = "Served: %d" % st.get("served", 0)
	_kpis["lost"][0].text = "Walked out: %d" % st.get("lost", 0)
	_kpis["accuracy"][0].text = "Accuracy: %.0f%%" % (world.accuracy() * 100.0)
	_kpis["waste"][0].text = "Waste: %s" % UIKit.money(cs.inventory.wasted_value)
	_kpis["clean"][0].text = "Clean: %.0f%%" % cs.cleanliness
	_kpis["mistakes"][0].text = "Mistakes: %d" % st.get("mistake_count", 0)


# --- Rush restock ------------------------------------------------------------

func _build_restock() -> void:
	_restock = PanelContainer.new()
	_restock.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_restock.position = Vector2(-430, 62)
	_restock.custom_minimum_size = Vector2(420, 0)
	_restock_box = UIKit.vbox([], 4)
	_restock.add_child(_restock_box)
	_restock.visible = false
	add_child(_restock)


func _toggle_restock() -> void:
	_restock.visible = not _restock.visible
	if _restock.visible:
		_dash.visible = false
		_rebuild_restock()


func _rebuild_restock() -> void:
	UIKit.clear(_restock_box)
	_restock_box.add_child(UIKit.hbox([UIKit.label("Stock room", 20, UIKit.INK, true), UIKit.spacer(),
		UIKit.button("✕", func(): _restock.visible = false, UIKit.MUTED, 40)]))
	_restock_box.add_child(UIKit.label("Rush deliveries cost 1.5× and take 45 minutes.", 12, UIKit.MUTED))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 4)
	var inv: Inventory = Game.current().inventory
	for ing in DB.ingredients:
		var id: String = ing["id"]
		var n := inv.count(id)
		var low := n < int(ing["pack"]) * 0.3
		var name_l := UIKit.label(ing["name"], 14, UIKit.RED if low else UIKit.INK)
		name_l.custom_minimum_size = Vector2(120, 0)
		grid.add_child(name_l)
		grid.add_child(UIKit.label(str(n), 14, UIKit.RED if low else UIKit.INK))
		var pending := world.pending_delivery(id)
		var b := UIKit.button("On the way" if pending else "+%d  %s" % [int(ing["pack"]), UIKit.money(float(ing["pack_cost"]) * 1.5)],
			func():
				world.emergency_order(id)
				_rebuild_restock(), Color("#ff8a3d"))
		b.custom_minimum_size = Vector2(150, 38)
		b.disabled = pending
		grid.add_child(b)
	_restock_box.add_child(grid)


# --- Fryer minigame ----------------------------------------------------------

func _build_fry() -> void:
	_fry = PanelContainer.new()
	_fry.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_fry.position = Vector2(-230, -250)
	_fry.custom_minimum_size = Vector2(460, 0)
	var v := UIKit.vbox([], 8)
	v.add_child(UIKit.label("Pull the batch in the green zone!", 18, UIKit.INK, true))
	_fry_bar = Control.new()
	_fry_bar.custom_minimum_size = Vector2(430, 46)
	_fry_bar.draw.connect(_draw_fry_bar)
	v.add_child(_fry_bar)
	var pull := UIKit.button("PULL!  (F)", fry_pull, Color("#ff8a3d"))
	pull.custom_minimum_size = Vector2(0, 60)
	pull.add_theme_font_size_override("font_size", 24)
	v.add_child(pull)
	v.add_child(UIKit.button("Let the crew handle it", func(): _fry.visible = false, UIKit.MUTED))
	_fry.add_child(v)
	_fry.visible = false
	add_child(_fry)


func _on_fry_started(st: Station) -> void:
	if Game.day <= 2 and not _fry.visible:
		show_toast("A batch is frying — tap the Fryer to pull it yourself!", Color("#ff8a3d"))
	if _fry.visible and _fry_station == null:
		_fry_station = st


func open_fry(st: Station) -> void:
	if world.player_take_fryer(st):
		_fry_station = st
		_fry.visible = true


func fry_pull() -> void:
	if _fry_station == null or not _fry.visible:
		# Pull whichever fryer is frying
		for st in world.by_type.get("fryer", []):
			if st.current_task != null and st.current_task.kind == "fry_batch":
				open_fry(st)
				return
		return
	var grade := world.player_pull(_fry_station)
	if grade != "":
		Sfx.play("pop")
	_fry.visible = false
	_fry_station = null


func _draw_fry_bar() -> void:
	var r := Rect2(Vector2.ZERO, _fry_bar.size)
	_fry_bar.draw_rect(r, Color("#3a3a3a"))
	var perfect := float(DB.fry.get("perfect", 0.62))
	var window := float(DB.fry.get("window", 0.12)) + Game.current().station_stat(DB, "fryer", "quality") * 0.5
	var w := r.size.x
	_fry_bar.draw_rect(Rect2(0, 0, w * (perfect - window - 0.2), r.size.y), Color("#f3d08a"))
	_fry_bar.draw_rect(Rect2(w * (perfect - window - 0.2), 0, w * 0.2, r.size.y), Color("#e8b860"))
	_fry_bar.draw_rect(Rect2(w * (perfect - window), 0, w * window * 2.0, r.size.y), Color("#2fae6b"))
	_fry_bar.draw_rect(Rect2(w * (perfect + window), 0, w * (1.0 - perfect - window), r.size.y), Color("#b8732f"))
	_fry_bar.draw_rect(Rect2(w * 0.97, 0, w * 0.03, r.size.y), Color("#e5383b"))
	if _fry_station != null and _fry_station.current_task != null:
		var t := _fry_station.current_task.ratio()
		var x := w * t
		_fry_bar.draw_rect(Rect2(x - 3, -6, 6, r.size.y + 12), Color.WHITE)
		_fry_bar.draw_rect(Rect2(x - 3, -6, 6, r.size.y + 12), Color.BLACK, false, 1.5)


# --- Update loop -------------------------------------------------------------

func _process(delta: float) -> void:
	if world == null:
		return
	_update_top()
	if _fry.visible:
		if _fry_station == null or _fry_station.current_task == null or _fry_station.current_task.kind != "fry_batch":
			_fry.visible = false
			_fry_station = null
		else:
			_fry_bar.queue_redraw()
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.3
		_update_crew()
		_update_tickets()
		_update_dashboard()
		_slow_refresh -= 1
		# Rebuilding panels with buttons only every ~1s, and never mid-press, so taps aren't lost.
		if _slow_refresh > 0 or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			return
		_slow_refresh = 3
		if _card.visible:
			if _selected == null or not is_instance_valid(_selected):
				_on_select(null)
			elif not (_selected is Employee and _card_box.get_child_count() > 0 and _has_open_dropdown()):
				_rebuild_card()
		if _restock.visible:
			_rebuild_restock()
		if world.employees.size() != _crew.get_child_count():
			_rebuild_crew()


func _has_open_dropdown() -> bool:
	for c in _card_box.get_children():
		if c is OptionButton and c.get_popup().visible:
			return true
	return false
