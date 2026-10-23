class_name Station
extends Node2D
## A workstation in the store. Draws itself, tracks who's using it, and shows
## work progress. Gameplay effects of tasks live in StoreWorld.

var type: String = "mixer"
var label: String = ""
var size: Vector2 = Vector2(120, 70)
var user = null                 # Employee currently reserving the station
var current_task: WorkTask = null
var broken: bool = false
var powered: bool = true
var stand_offset: Vector2 = Vector2(0, 58)   # where an employee stands to work
var anim: float = 0.0
var level: int = 0
var world = null                 # StoreWorld
var _steam: CPUParticles2D


func _ready() -> void:
	if type in ["coffee", "fryer"]:
		_steam = CPUParticles2D.new()
		_steam.amount = 14
		_steam.lifetime = 1.4
		_steam.position = Vector2(-20.0 if type == "coffee" else 0.0, -size.y * 0.5)
		_steam.direction = Vector2(0, -1)
		_steam.spread = 18.0
		_steam.gravity = Vector2(0, -20)
		_steam.initial_velocity_min = 18.0
		_steam.initial_velocity_max = 34.0
		_steam.scale_amount_min = 3.0
		_steam.scale_amount_max = 7.0
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 0.55))
		g.set_color(1, Color(1, 1, 1, 0.0))
		_steam.color_ramp = g
		_steam.emitting = false
		add_child(_steam)


func stand_point() -> Vector2:
	return global_position + stand_offset


func is_available() -> bool:
	return user == null and not broken and powered


func usable() -> bool:
	return not broken and powered


func reserve(emp) -> void:
	user = emp


func free_up() -> void:
	user = null
	current_task = null


func hit_test(p: Vector2) -> bool:
	return Rect2(global_position - size * 0.5 - Vector2(6, 6), size + Vector2(12, 12)).has_point(p)


func _process(delta: float) -> void:
	anim += delta * Game.time_scale
	if _steam:
		_steam.emitting = current_task != null and Game.time_scale > 0.0 and usable()
	queue_redraw()


# --- Drawing -----------------------------------------------------------------

func _draw() -> void:
	var r := Rect2(-size * 0.5, size)
	# Shadow
	draw_rect(Rect2(r.position + Vector2(4, 8), r.size), Color(0, 0, 0, 0.12))
	match type:
		"mixer": _draw_mixer(r)
		"fryer": _draw_fryer(r)
		"glaze": _draw_glaze(r)
		"coffee": _draw_coffee(r)
		"cold": _draw_cold(r)
		"register": _draw_register(r)
		"pickup": _draw_pickup(r)
		"case": _draw_case(r)
		"break": _draw_break(r)
	# Progress bar
	if current_task != null:
		var pr := Rect2(r.position + Vector2(8, r.size.y + 6), Vector2(r.size.x - 16, 7))
		draw_rect(pr, Color(0, 0, 0, 0.25))
		var fill := Color("#2fae6b")
		if type == "fryer" and current_task.kind == "fry_batch":
			fill = Color("#ff8a3d")
		draw_rect(Rect2(pr.position, Vector2(pr.size.x * current_task.ratio(), pr.size.y)), fill)
	if broken:
		_draw_badge(Vector2(r.end.x - 10, r.position.y + 6), Color("#e5383b"), "!")
	elif not powered:
		_draw_badge(Vector2(r.end.x - 10, r.position.y + 6), Color("#444444"), "⚡")
	# Level pips
	for i in level:
		draw_circle(Vector2(r.position.x + 10 + i * 9, r.position.y + 8), 3.0, Color("#ffd23f"))
	if label != "":
		var font := ThemeDB.fallback_font
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 13).x
		draw_string(font, Vector2(-w * 0.5, r.end.y + 26), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.25, 0.18, 0.15, 0.85))


func _draw_badge(p: Vector2, c: Color, txt: String) -> void:
	draw_circle(p, 11, c)
	var font := ThemeDB.fallback_font
	draw_string(font, p + Vector2(-4, 5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)


func _counter(r: Rect2, top: Color, front: Color) -> void:
	draw_rect(r, front)
	draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.42)), top)
	draw_rect(r, Color(0, 0, 0, 0.18), false, 2.0)


func _draw_mixer(r: Rect2) -> void:
	_counter(r, Color("#e7eef5"), Color("#b9c6d3"))
	var c := r.get_center() + Vector2(0, -6)
	draw_circle(c, 24, Color("#9fb0c0"))
	draw_circle(c, 20, Color("#d9e2ea"))
	var wob := sin(anim * 9.0) * 2.0 if current_task else 0.0
	draw_circle(c + Vector2(wob, 0), 13, Color("#f3dcb0"))
	draw_line(c + Vector2(0, -28), c + Vector2(wob * 2, -4), Color("#5c6b7a"), 4.0)
	if world:
		var d: int = Game.current().inventory.dough
		draw_string(ThemeDB.fallback_font, r.position + Vector2(r.size.x - 34, r.size.y - 8), "%d" % d,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.2, 0.2, 0.25))


func _draw_fryer(r: Rect2) -> void:
	_counter(r, Color("#c7ccd1"), Color("#8f979f"))
	var vat := Rect2(r.position + Vector2(12, 8), Vector2(r.size.x - 24, r.size.y * 0.6))
	draw_rect(vat, Color("#3a3a3a"))
	var oil := Color("#d9a441") if usable() else Color("#7a6a4a")
	draw_rect(vat.grow(-4), oil)
	if current_task != null and current_task.kind == "fry_batch":
		var t := current_task.ratio()
		var dc := Color("#f3d08a").lerp(Color("#b8732f"), clampf(t * 1.2, 0, 1)).lerp(Color("#3a2414"), clampf((t - 0.85) * 4.0, 0, 1))
		for i in 6:
			var p := vat.position + Vector2(18 + (i % 3) * (vat.size.x - 36) / 2.0, 14 + (i / 3) * (vat.size.y - 26))
			draw_circle(p, 10, dc)
			draw_circle(p, 4, oil)
		# bubbles
		for i in 5:
			var bp := vat.position + Vector2(fmod(i * 37.0 + anim * 40.0, vat.size.x - 8) + 4, vat.size.y - 6 - fmod(anim * 20.0 + i * 9.0, vat.size.y - 8))
			draw_circle(bp, 2.0, Color(1, 1, 0.8, 0.6))


func _draw_glaze(r: Rect2) -> void:
	_counter(r, Color("#fff4e6"), Color("#e8c9a0"))
	var tray := Rect2(r.position + Vector2(10, 6), Vector2(r.size.x - 20, r.size.y * 0.5))
	draw_rect(tray, Color("#d9d9d9"))
	if current_task != null and current_task.kind == "finish_batch":
		var did: String = current_task.payload.get("donut", "glazed")
		var def: Dictionary = DB.donut(did)
		var done := int(current_task.ratio() * 6.0)
		for i in 6:
			var p := tray.position + Vector2(12 + i * (tray.size.x - 24) / 5.0, tray.size.y * 0.5)
			draw_circle(p, 8, Color(def.get("color", "#f0b860")))
			if i < done:
				draw_circle(p, 7, Color(def.get("topping", "#ffffff")))
			draw_circle(p, 2.5, Color("#d9d9d9"))
	# icing bowls
	draw_circle(r.position + Vector2(18, r.size.y - 14), 8, Color("#6b3a22"))
	draw_circle(r.position + Vector2(38, r.size.y - 14), 8, Color("#ff8fb4"))
	draw_circle(r.position + Vector2(58, r.size.y - 14), 8, Color("#fff3d6"))
	if Game.current().has_item("auto_glazer"):
		draw_rect(Rect2(r.end.x - 30, r.position.y - 12, 24, 16), Color("#4f8cff"))
		draw_string(ThemeDB.fallback_font, Vector2(r.end.x - 27, r.position.y), "AUTO", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)


func _draw_coffee(r: Rect2) -> void:
	_counter(r, Color("#e9e2da"), Color("#7b5b45"))
	var m := Rect2(r.position + Vector2(10, -16), Vector2(r.size.x * 0.55, r.size.y * 0.75))
	draw_rect(m, Color("#c0392b") if level < 2 else Color("#2c3e50"))
	draw_rect(Rect2(m.position + Vector2(6, 6), Vector2(m.size.x - 12, 10)), Color("#ecf0f1"))
	draw_circle(m.position + Vector2(m.size.x * 0.5, m.size.y * 0.6), 8, Color("#bdc3c7"))
	# grinder
	var g := Rect2(r.position + Vector2(r.size.x * 0.68, -8), Vector2(22, 40))
	draw_rect(g, Color("#34495e"))
	draw_rect(Rect2(g.position + Vector2(2, -10), Vector2(18, 12)), Color("#5a3520"))
	if current_task != null:
		var cup := m.position + Vector2(m.size.x * 0.5, m.size.y + 8)
		draw_rect(Rect2(cup - Vector2(6, 8), Vector2(12, 14)), Color.WHITE)
		var did: String = current_task.payload.get("drink", "hot_coffee")
		var fillh := 12.0 * current_task.ratio()
		draw_rect(Rect2(cup + Vector2(-5, 5 - fillh), Vector2(10, fillh)), Color(DB.drink(did).get("color", "#5a3520")))


func _draw_cold(r: Rect2) -> void:
	_counter(r, Color("#e6f6ff"), Color("#5aa9d6"))
	draw_rect(Rect2(r.position + Vector2(8, 6), Vector2(36, 26)), Color("#bfe8ff"))
	for i in 6:
		draw_rect(Rect2(r.position + Vector2(11 + (i % 3) * 11, 9 + (i / 3) * 11), Vector2(8, 8)), Color(1, 1, 1, 0.85))
	if Game.current().has_item("blender"):
		var b := r.position + Vector2(r.size.x - 30, -6)
		draw_rect(Rect2(b, Vector2(20, 30)), Color(0.85, 0.95, 1.0, 0.8))
		draw_rect(Rect2(b + Vector2(-2, 28), Vector2(24, 10)), Color("#2c3e50"))
		if current_task != null and current_task.payload.get("drink", "") == "frozen_coffee":
			draw_circle(b + Vector2(10, 16 + sin(anim * 30.0) * 2.0), 6, Color("#b98c62"))
	if current_task != null:
		var did: String = current_task.payload.get("drink", "iced_coffee")
		var cup := r.get_center() + Vector2(4, -6)
		draw_rect(Rect2(cup - Vector2(7, 10), Vector2(14, 20)), Color(1, 1, 1, 0.7))
		var fh := 18.0 * current_task.ratio()
		draw_rect(Rect2(cup + Vector2(-6, 9 - fh), Vector2(12, fh)), Color(DB.drink(did).get("color", "#8a5a36")))


func _draw_register(r: Rect2) -> void:
	_counter(r, Color("#ffe1ea"), Color("#ff6f91"))
	var s := Rect2(r.get_center() + Vector2(-18, -26), Vector2(36, 24))
	draw_rect(s, Color("#2c3e50"))
	draw_rect(s.grow(-3), Color("#7ad3ff") if current_task else Color("#34495e"))
	draw_rect(Rect2(s.position + Vector2(12, 24), Vector2(12, 8)), Color("#2c3e50"))


func _draw_pickup(r: Rect2) -> void:
	_counter(r, Color("#fff8ec"), Color("#ffb347"))
	draw_string(ThemeDB.fallback_font, r.position + Vector2(10, 22), "PICKUP", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#8a4b14"))
	if current_task != null:
		var bag := r.get_center() + Vector2(24, -6)
		draw_rect(Rect2(bag - Vector2(9, 10), Vector2(18, 20)), Color("#d8b48a"))
		draw_rect(Rect2(bag - Vector2(9, 10), Vector2(18, 5)), Color("#ff6f91"))


func _draw_case(r: Rect2) -> void:
	draw_rect(r, Color("#f7f1e8"))
	draw_rect(Rect2(r.position + Vector2(4, 4), r.size - Vector2(8, 8)), Color(0.8, 0.93, 1.0, 0.55))
	draw_rect(r, Color(0, 0, 0, 0.2), false, 2.0)
	var inv: Inventory = Game.current().inventory
	var row := 0
	for d in DB.donuts:
		if not Game.is_unlocked(d["id"]):
			continue
		var n := inv.case_count(d["id"])
		var y := r.position.y + 12 + row * (r.size.y - 16) / 5.0
		for i in mini(n, 10):
			var p := Vector2(r.position.x + 12 + i * ((r.size.x - 24) / 9.0), y)
			draw_circle(p, 5.5, Color(d.get("color", "#f0b860")))
			draw_circle(p, 4.5, Color(d.get("topping", "#fff")))
			draw_circle(p, 1.6, Color(0.8, 0.93, 1.0))
		if n == 0:
			draw_line(Vector2(r.position.x + 8, y), Vector2(r.end.x - 8, y), Color(0.9, 0.3, 0.3, 0.35), 2.0)
		row += 1


func _draw_break(r: Rect2) -> void:
	var comfy: bool = Game.current().has_item("break_room")
	draw_rect(r, Color("#d6eadf") if comfy else Color("#e6e2dc"))
	draw_rect(r, Color(0, 0, 0, 0.15), false, 2.0)
	var sofa := Rect2(r.position + Vector2(14, r.size.y - 44), Vector2(r.size.x - 28, 30))
	draw_rect(sofa, Color("#6c5ce7") if comfy else Color("#a29486"))
	draw_rect(Rect2(sofa.position - Vector2(0, 12), Vector2(sofa.size.x, 14)), (Color("#6c5ce7") if comfy else Color("#a29486")).darkened(0.2))
	if comfy:
		draw_circle(r.position + Vector2(r.size.x - 26, 24), 12, Color("#2fae6b"))
		draw_rect(Rect2(r.position + Vector2(r.size.x - 30, 34), Vector2(8, 14)), Color("#8a5a36"))
	draw_string(ThemeDB.fallback_font, r.position + Vector2(10, 20), "BREAK ROOM", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.3, 0.3, 0.3, 0.8))
