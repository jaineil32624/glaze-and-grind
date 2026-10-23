class_name Customer
extends Node2D
## A customer walking through the store: queue → order → wait → pickup → leave.

enum State { ENTER, QUEUE, TO_REGISTER, ORDERING, WAITING, TO_PICKUP, PAYING, LEAVING }

var profile: CustomerProfile
var order: Order                 # what they want; becomes the placed order
var world = null
var state: int = State.ENTER
var target: Vector2 = Vector2.ZERO
var register_station = null
var queue_index: int = -1
var waited: float = 0.0
var selected := false
var happy_result := -1.0         # set when served (0..1)
var _anim := 0.0
var _moving := false
var _facing := -1.0
var _skin := Color("#f5d0b5")
var _speed := 150.0
var _react_timer := 0.0
var _react_good := true


func setup(p: CustomerProfile, o: Order, w, rng: RandomNumberGenerator) -> void:
	profile = p
	order = o
	world = w
	order.customer = self
	_skin = Color(StaffData.SKIN[rng.randi() % StaffData.SKIN.size()])
	_speed = rng.randf_range(130.0, 170.0) * (0.8 if p.type_id == "family" else 1.0)


func is_waiting_state() -> bool:
	return state in [State.QUEUE, State.TO_REGISTER, State.ORDERING, State.WAITING]


func tick(delta: float) -> void:
	_anim += delta
	_react_timer = maxf(0.0, _react_timer - delta)
	_moving = false
	if is_waiting_state():
		waited += delta
		profile.mood = maxf(0.0, profile.mood - delta / profile.patience)
		if profile.mood <= 0.0:
			world.customer_gave_up(self)
			return
	var arrived := _walk(delta)
	match state:
		State.ENTER:
			if arrived:
				world.customer_reached_door(self)
		State.TO_REGISTER:
			if arrived:
				state = State.ORDERING
				world.customer_at_register(self)
		State.TO_PICKUP:
			if arrived:
				state = State.PAYING
				world.customer_pay(self)
		State.LEAVING:
			if arrived:
				world.customer_exit(self)
	z_index = int(position.y)
	queue_redraw()


func _walk(delta: float) -> bool:
	var d := position.distance_to(target)
	if d < 3.0:
		position = target
		return true
	if absf(target.x - position.x) > 2.0:
		_facing = signf(target.x - position.x)
	position = position.move_toward(target, _speed * delta)
	_moving = true
	return position.distance_to(target) < 3.0


func react(good: bool) -> void:
	_react_good = good
	_react_timer = 1.6


func hit_test(p: Vector2) -> bool:
	return global_position.distance_to(p + Vector2(0, 20)) < 28.0


func mood_color() -> Color:
	if profile.mood > 0.6:
		return Color("#2fae6b")
	if profile.mood > 0.3:
		return Color("#ffb020")
	return Color("#e5383b")


# --- Drawing -----------------------------------------------------------------

func _draw() -> void:
	var bob := sin(_anim * 13.0) * 2.0 if _moving else 0.0
	if selected:
		draw_arc(Vector2(0, 2), 24, 0, TAU, 32, Color("#4f8cff"), 3.0)
	draw_set_transform(Vector2(0, 2), 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 16, Color(0, 0, 0, 0.16))
	draw_set_transform(Vector2.ZERO)
	_draw_person(Vector2(0, bob), 1.0, profile.body, profile.accent)
	if profile.type_id == "family":
		_draw_person(Vector2(22, bob * 0.5 + 6), 0.65, profile.accent, profile.body)

	var head := Vector2(0, -44 + bob)
	# Mood pip
	if is_waiting_state():
		var mc := mood_color()
		draw_circle(head + Vector2(-18, -14), 6, mc)
		draw_arc(head + Vector2(-18, -14), 8, -PI * 0.5, -PI * 0.5 + TAU * profile.mood, 16, mc.darkened(0.3), 2.0)
	# Order bubble while waiting for food
	if state == State.WAITING or state == State.ORDERING:
		_draw_order_bubble(head + Vector2(6, -36))
	if _react_timer > 0.0:
		var a := minf(1.0, _react_timer)
		var p := head + Vector2(10, -30 - (1.6 - _react_timer) * 14.0)
		if _react_good:
			draw_circle(p, 9, Color(1, 0.4, 0.55, a))
			draw_string(ThemeDB.fallback_font, p + Vector2(-5, 5), "♥", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, a))
		else:
			draw_circle(p, 9, Color(0.3, 0.3, 0.3, a))
			draw_string(ThemeDB.fallback_font, p + Vector2(-4, 5), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, a))


func _draw_person(o: Vector2, s: float, body: Color, accent: Color) -> void:
	var leg := sin(_anim * 13.0) * 3.0 if _moving else 0.0
	draw_rect(Rect2(o + Vector2(-7, -6) * s, Vector2(5, 12 + leg) * s), Color("#3b3b4f"))
	draw_rect(Rect2(o + Vector2(2, -6) * s, Vector2(5, 12 - leg) * s), Color("#3b3b4f"))
	draw_rect(Rect2(o + Vector2(-12, -32) * s, Vector2(24, 28) * s), body)
	draw_circle(o + Vector2(-12, -26) * s, 5 * s, body)
	draw_circle(o + Vector2(12, -26) * s, 5 * s, body)
	var head := o + Vector2(0, -44) * s
	draw_circle(head, 12 * s, _skin)
	draw_circle(head + Vector2(-3.5 + _facing * 2, 1) * s, 1.6 * s, Color("#222"))
	draw_circle(head + Vector2(3.5 + _facing * 2, 1) * s, 1.6 * s, Color("#222"))
	if s < 0.9:
		return
	match profile.type_id:
		"business":
			draw_rect(Rect2(o + Vector2(-2, -30), Vector2(4, 16)), Color("#c0392b"))
			draw_rect(Rect2(o + Vector2(14, -16), Vector2(12, 10)), Color("#5b3a1e"))  # briefcase
		"student":
			draw_rect(Rect2(o + Vector2(-17 * _facing - 5, -30), Vector2(10, 18)), accent)  # backpack
			draw_arc(head + Vector2(0, -3), 12, PI, TAU, 12, Color("#2b1d14"), 6.0)
		"tourist":
			draw_rect(Rect2(head + Vector2(-16, -14), Vector2(32, 5)), accent)
			draw_rect(Rect2(head + Vector2(-9, -20), Vector2(18, 8)), accent)
			draw_rect(Rect2(o + Vector2(-6, -24), Vector2(12, 8)), Color("#222"))  # camera
		"influencer":
			draw_arc(head + Vector2(0, -2), 13, PI * 0.9, TAU + 0.2, 14, accent, 7.0)
			draw_rect(Rect2(o + Vector2(13, -36), Vector2(7, 12)), Color("#222"))
			draw_rect(Rect2(o + Vector2(14, -35), Vector2(5, 9)), Color("#7ad3ff"))
		"critic":
			draw_circle(head + Vector2(0, -10), 10, Color("#1d1d1d"))
			draw_rect(Rect2(o + Vector2(12, -24), Vector2(10, 13)), Color("#f5f0e1"))
			draw_rect(Rect2(head + Vector2(-8, -1), Vector2(16, 3)), accent)  # glasses
		"family":
			draw_arc(head + Vector2(0, -3), 12, PI, TAU, 12, Color("#5a3a22"), 6.0)


func _draw_order_bubble(p: Vector2) -> void:
	var ids := order.all_item_ids()
	var n := mini(ids.size(), 5)
	if n == 0:
		return
	var w := 14.0 + n * 14.0
	var r := Rect2(p - Vector2(w * 0.5, 10), Vector2(w, 22))
	draw_rect(r, Color(1, 1, 1, 0.92))
	draw_rect(r, Color(0, 0, 0, 0.15), false, 1.5)
	var i := 0
	for k in order.donuts:
		if i >= n:
			break
		var d := DB.donut(k)
		var c := r.position + Vector2(14 + i * 14, 11)
		draw_circle(c, 5.5, Color(d.get("color", "#f0b860")))
		draw_circle(c, 4.5, Color(d.get("topping", "#fff")))
		draw_circle(c, 1.5, Color.WHITE)
		i += 1
	for dr in order.drinks:
		if i >= n:
			break
		var dd := DB.drink(dr["id"])
		var c := r.position + Vector2(14 + i * 14, 11)
		draw_rect(Rect2(c - Vector2(4, 6), Vector2(8, 12)), Color.WHITE if dd.get("hot", true) else Color(0.85, 0.95, 1))
		draw_rect(Rect2(c - Vector2(3, 2), Vector2(6, 7)), Color(dd.get("color", "#5a3520")))
		if dr["done"]:
			draw_circle(c + Vector2(4, -5), 3, Color("#2fae6b"))
		i += 1
