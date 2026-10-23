class_name Employee
extends Node2D
## An autonomous crew member driven by a behaviour tree.

const BREAK_ENTER := 85.0
const BREAK_EXIT := 28.0

var data: StaffData
var world = null                 # StoreWorld
var task: WorkTask = null
var station: Station = null
var tree: BT.BTNode
var on_break := false
var present := true
var arrive_hour := 6.0
var status := "Idle"
var selected := false
var started := false             # current task has been started at its station
var fry_pull_at := 0.62

var _anim := 0.0
var _moving := false
var _facing := 1.0
var _assist_task: WorkTask = null
var _assist_check := 0.0
var _idle_target := Vector2.ZERO
var _idle_timer := 0.0
var _cleaning := false
var _pick_cooldown := 0.0
var _levelup_flash := 0.0

# Efficiency stats for the dashboard
var busy_time := 0.0
var shift_time := 0.0


func _ready() -> void:
	tree = BT.Selector.new("root", [
		BT.Sequence.new("break", [BT.Condition.new(&"needs_break"), BT.Action.new(&"do_break")]),
		BT.Sequence.new("work", [BT.Condition.new(&"has_task"), BT.Action.new(&"do_task")]),
		BT.Action.new(&"pick_task"),
		BT.Sequence.new("assist", [BT.Condition.new(&"wants_assist"), BT.Action.new(&"do_assist")]),
		BT.Action.new(&"do_idle"),
	])
	_idle_target = position


func tick(delta: float) -> void:
	_anim += delta
	_levelup_flash = maxf(0.0, _levelup_flash - delta)
	if not present:
		return
	shift_time += delta
	_pick_cooldown = maxf(0.0, _pick_cooldown - delta)
	_moving = false
	tree.tick(self, delta)
	if task != null and started:
		busy_time += delta
		data.add_stress(delta * 0.75 * (1.0 + world.queue_pressure()))
	elif not on_break:
		data.recover(delta * 0.5)
	z_index = int(position.y)
	queue_redraw()


func move_to(target: Vector2, delta: float) -> bool:
	var d := position.distance_to(target)
	if d < 3.0:
		position = target
		return true
	var step := data.walk_speed() * delta
	_facing = signf(target.x - position.x) if absf(target.x - position.x) > 2.0 else _facing
	position = position.move_toward(target, step)
	_moving = true
	return position.distance_to(target) < 3.0


# --- Behaviour tree leaves ----------------------------------------------------

func needs_break() -> bool:
	if on_break:
		return true
	if data.stress >= BREAK_ENTER and task == null and world.can_take_break(self):
		on_break = true
		Bus.float_text.emit(global_position + Vector2(0, -60), "Break time", Color("#6c5ce7"))
		return true
	return false


func do_break(delta: float) -> int:
	status = "On break"
	_release_assist()
	if not move_to(world.break_point(self), delta):
		return BT.Status.RUNNING
	var rate := 9.0 * (2.0 if Game.current().has_item("break_room") else 1.0)
	data.recover(delta * rate)
	data.happiness = minf(100.0, data.happiness + delta * 0.3)
	if data.stress <= BREAK_EXIT:
		on_break = false
		status = "Idle"
		return BT.Status.SUCCESS
	return BT.Status.RUNNING


func has_task() -> bool:
	return task != null


func do_task(delta: float) -> int:
	if task.cancelled:
		world.abandon_task(self)
		return BT.Status.FAILURE
	if station == null or not station.usable():
		world.abandon_task(self)
		return BT.Status.FAILURE
	status = _task_status()
	if not move_to(station.stand_point(), delta):
		return BT.Status.RUNNING
	_facing = 1.0
	if not started:
		if not world.start_task(task, self):
			world.abandon_task(self)
			_pick_cooldown = 0.6
			return BT.Status.FAILURE
		started = true
		if task.kind == "fry_batch":
			# Plan when to pull: accuracy decides how close to perfect.
			var fry: Dictionary = DB.fry
			fry_pull_at = clampf(float(fry.get("perfect", 0.62)) + world.rng.randfn(0.0, data.fry_error_sigma()), 0.35, 1.05)
	var mult: float = world.station_speed(station) * (1.0 + task.assist)
	task.progress += delta * data.work_speed() * mult
	if task.kind == "fry_batch":
		var t := task.ratio()
		if task.payload.get("player", false):
			if t >= 1.0:
				world.complete_task(task, self)
				return BT.Status.SUCCESS
			return BT.Status.RUNNING
		if t >= fry_pull_at:
			world.complete_task(task, self)
			return BT.Status.SUCCESS
		return BT.Status.RUNNING
	if task.progress >= task.duration:
		world.complete_task(task, self)
		return BT.Status.SUCCESS
	return BT.Status.RUNNING


func pick_task(_delta: float) -> int:
	if _pick_cooldown > 0.0:
		return BT.Status.FAILURE
	_pick_cooldown = 0.25
	var picked: bool = world.assign_task(self)
	if picked:
		_release_assist()
		_cleaning = false
		return BT.Status.SUCCESS
	return BT.Status.FAILURE


func wants_assist() -> bool:
	if _assist_task != null:
		if _assist_task.claimant == null or _assist_task.cancelled or _assist_task.claimant == self:
			_release_assist()
			return false
		return true
	_assist_check -= get_process_delta_time() * Game.time_scale
	if _assist_check > 0.0:
		return false
	_assist_check = 1.5
	if world.rng.randf() > data.teamwork / 12.0:
		return false
	_assist_task = world.find_assist_target(self)
	return _assist_task != null


func do_assist(delta: float) -> int:
	var st = _assist_task.station
	if st == null:
		_release_assist()
		return BT.Status.FAILURE
	status = "Helping " + str(_assist_task.claimant.data.name)
	var spot: Vector2 = st.stand_point() + Vector2(36, 6)
	if move_to(spot, delta):
		_assist_task.assist = 0.3 + data.teamwork * 0.04
		busy_time += delta
	return BT.Status.RUNNING


func _release_assist() -> void:
	if _assist_task != null:
		_assist_task.assist = 0.0
	_assist_task = null


func do_idle(delta: float) -> int:
	_idle_timer -= delta
	if _idle_timer <= 0.0:
		_cleaning = world.rng.randf() < 0.6 and Game.current().cleanliness < 98.0
		_idle_target = world.idle_point(self)
		_idle_timer = world.rng.randf_range(2.0, 4.0)
	if move_to(_idle_target, delta) and _cleaning:
		status = "Cleaning"
		Game.current().cleanliness = minf(100.0, Game.current().cleanliness + delta * 1.2)
	else:
		status = "Idle"
	return BT.Status.RUNNING


func _task_status() -> String:
	if task == null:
		return "Idle"
	match task.kind:
		"take_order": return "Taking order"
		"mix_dough": return "Mixing dough"
		"fry_batch": return "Frying " + str(DB.donut(task.payload.get("donut", "")).get("name", "donuts"))
		"finish_batch": return "Glazing " + str(DB.donut(task.payload.get("donut", "")).get("name", "donuts"))
		"make_drink": return "Making " + str(DB.drink(task.payload.get("drink", "")).get("name", "drink"))
		"assemble": return "Packing order #%d" % task.payload["order"].id
	return task.kind


func level_up_fx() -> void:
	_levelup_flash = 1.5


func hit_test(p: Vector2) -> bool:
	return global_position.distance_to(p + Vector2(0, 20)) < 30.0


# --- Drawing -----------------------------------------------------------------

func _draw() -> void:
	if not present:
		return
	var bob := sin(_anim * 14.0) * 2.5 if _moving else sin(_anim * 3.0) * 0.8
	var work_bob := sin(_anim * 18.0) * 1.5 if (task != null and started) else 0.0
	# selection ring + shadow
	if selected:
		draw_arc(Vector2(0, 2), 26, 0, TAU, 32, Color("#ffd23f"), 3.0)
	draw_set_transform(Vector2(0, 2), 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 18, Color(0, 0, 0, 0.18))
	draw_set_transform(Vector2.ZERO)
	var base := Vector2(0, -6 + bob)
	# legs
	var leg := sin(_anim * 14.0) * 4.0 if _moving else 0.0
	draw_rect(Rect2(base + Vector2(-8, 4 + leg * 0.2), Vector2(6, 10 + leg)), Color("#3b3b4f"))
	draw_rect(Rect2(base + Vector2(2, 4 - leg * 0.2), Vector2(6, 10 - leg)), Color("#3b3b4f"))
	# body (uniform) + apron
	var uni := Color("#ff6f91")
	draw_rect(Rect2(base + Vector2(-13, -26), Vector2(26, 32)), uni)
	draw_circle(base + Vector2(-13, -20), 6, uni)
	draw_circle(base + Vector2(13, -20), 6, uni)
	draw_rect(Rect2(base + Vector2(-9, -16), Vector2(18, 22)), Color("#fff8ec"))
	# arms
	var arm := work_bob
	draw_line(base + Vector2(-13, -18), base + Vector2(-17, -4 + arm), Color(data.skin), 5.0)
	draw_line(base + Vector2(13, -18), base + Vector2(17, -4 - arm), Color(data.skin), 5.0)
	# head
	var head := base + Vector2(0, -38)
	draw_circle(head, 13, Color(data.skin))
	draw_arc(head + Vector2(0, -2), 13, PI, TAU, 16, Color(data.hair), 7.0)
	# visor cap
	draw_rect(Rect2(head + Vector2(-13, -14), Vector2(26, 6)), Color("#e8457a"))
	draw_rect(Rect2(head + Vector2(-2 + 8 * _facing, -10), Vector2(10 * _facing, 4)).abs(), Color("#e8457a"))
	# face
	var eye_y := head.y + 1
	draw_circle(Vector2(head.x - 4 + _facing * 2, eye_y), 1.8, Color("#2b1d14"))
	draw_circle(Vector2(head.x + 4 + _facing * 2, eye_y), 1.8, Color("#2b1d14"))
	if data.stress > 70.0:
		draw_line(head + Vector2(-4, 7), head + Vector2(4, 6), Color("#2b1d14"), 1.5)
	else:
		draw_arc(head + Vector2(_facing * 1.5, 5), 4, 0.2, PI - 0.2, 8, Color("#2b1d14"), 1.5)
	# stress indicator
	if data.stress > 60.0 and not on_break:
		var c := Color("#ff8a3d") if data.stress < 85.0 else Color("#e5383b")
		for i in 3:
			draw_line(head + Vector2(14 + i * 4, -14 - i * 3), head + Vector2(17 + i * 4, -8 - i * 3), c, 2.0)
	if on_break:
		var font := ThemeDB.fallback_font
		draw_string(font, head + Vector2(10, -16 - fmod(_anim * 8.0, 10.0)), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#6c5ce7"))
		draw_string(font, head + Vector2(18, -24 - fmod(_anim * 8.0 + 5.0, 10.0)), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#6c5ce7"))
	# work progress ring
	if task != null and started:
		var t := task.ratio()
		draw_arc(head + Vector2(0, -24), 7, -PI * 0.5, -PI * 0.5 + TAU * t, 20, Color("#2fae6b"), 3.0)
	if _levelup_flash > 0.0:
		var a := _levelup_flash / 1.5
		draw_string(ThemeDB.fallback_font, head + Vector2(-26, -30 - (1.0 - a) * 20.0), "LEVEL UP!", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.82, 0.25, a))
	# level badge
	draw_circle(base + Vector2(14, 2), 7, Color("#4f8cff"))
	draw_string(ThemeDB.fallback_font, base + Vector2(10.5, 6.5), str(data.level), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
