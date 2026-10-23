extends Node
## App state machine: menu → shift → summary → management → shift …

enum State { MENU, SHIFT, SUMMARY, MANAGEMENT }

var state: int = State.MENU
var world: StoreWorld
var hud: HUD
var summary: SummaryScreen
var management: ManagementScreen
var menus: Menus
var _ui: CanvasLayer
var _day_snapshot: Dictionary = {}
var _paused_from_speed := 1.0


func _ready() -> void:
	world = StoreWorld.new()
	world.name = "World"
	add_child(world)
	world.visible = false

	_ui = CanvasLayer.new()
	_ui.name = "UI"
	add_child(_ui)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIKit.build_theme()
	_ui.add_child(root)

	hud = HUD.new()
	root.add_child(hud)
	hud.visible = false
	hud.menu_requested.connect(_open_pause)

	summary = SummaryScreen.new()
	root.add_child(summary)
	summary.visible = false
	summary.continue_pressed.connect(_to_management)

	management = ManagementScreen.new()
	root.add_child(management)
	management.visible = false
	management.start_day.connect(_start_shift)
	management.save_requested.connect(func(): _open_menu_page(Menus.Page.SAVE))
	management.menu_requested.connect(_to_main_menu)

	menus = Menus.new()
	root.add_child(menus)
	menus.new_game.connect(_new_game)
	menus.load_slot.connect(_load)
	menus.resume.connect(_resume)
	menus.save_slot.connect(_save_to)
	menus.to_main_menu.connect(_to_main_menu)

	Bus.shift_ended.connect(_on_shift_ended)
	get_viewport().size_changed.connect(_fit_world)
	_fit_world()
	menus.show_page(Menus.Page.MAIN)
	Sfx.start_music()


## Scale the 1280×720 store to fit any screen (phones, tablets, ultrawide).
func _fit_world() -> void:
	var vs := get_viewport().get_visible_rect().size
	var s := minf(vs.x / StoreWorld.W, (vs.y - 4.0) / StoreWorld.H)
	world.scale = Vector2(s, s)
	world.position = Vector2((vs.x - StoreWorld.W * s) * 0.5, (vs.y - StoreWorld.H * s) * 0.5 + 6.0)


# --- Flow ---------------------------------------------------------------------

func _new_game() -> void:
	Game.new_game()
	Saves.configure_cloud()
	menus.visible = false
	_start_shift()


func _load(slot: String) -> void:
	if Saves.load_slot(slot):
		menus.visible = false
		Bus.toast.emit("Loaded " + slot.replace("_", " "), UIKit.BLUE)
		_to_management()
	else:
		Bus.toast.emit("Couldn't load that save", UIKit.RED)


func _start_shift() -> void:
	management.visible = false
	summary.visible = false
	menus.visible = false
	_day_snapshot = Game.to_dict()
	Saves.save(Saves.AUTOSAVE, _day_snapshot)
	state = State.SHIFT
	world.visible = true
	hud.visible = true
	hud.clear_event()
	world.start_shift()
	hud.bind(world)


func _on_shift_ended() -> void:
	var s := world.close_day()
	state = State.SUMMARY
	hud.visible = false
	Game.time_scale = 1.0
	summary.show_summary(s)
	summary.visible = true
	Saves.save(Saves.AUTOSAVE)
	Sfx.play("levelup" if s["profit"] >= 0 else "angry")
	if s.get("ranked_up", false):
		world._on_burst(Vector2(640, 360), "confetti")


func _to_management() -> void:
	state = State.MANAGEMENT
	summary.visible = false
	world.visible = false
	hud.visible = false
	management.open()


func _to_main_menu() -> void:
	world.stop()
	world.visible = false
	hud.visible = false
	summary.visible = false
	management.visible = false
	state = State.MENU
	Game.time_scale = 1.0
	Game.started = false
	menus.show_page(Menus.Page.MAIN)


func _open_pause() -> void:
	if state != State.SHIFT:
		return
	_paused_from_speed = Game.time_scale if Game.time_scale > 0.0 else 1.0
	Game.time_scale = 0.0
	menus.show_page(Menus.Page.PAUSE)


func _open_menu_page(page: int) -> void:
	menus._back_page = Menus.Page.PAUSE if state == State.SHIFT else Menus.Page.MAIN
	menus.show_page(page)
	if state == State.MANAGEMENT:
		# Return to management when they back out
		menus._back_page = -1


func _resume() -> void:
	menus.visible = false
	if state == State.SHIFT:
		hud.set_speed(_paused_from_speed)
	elif state == State.MANAGEMENT:
		management.open()


func _save_to(slot: String) -> void:
	var ok: bool
	if state == State.SHIFT:
		ok = Saves.save(slot, _day_snapshot)
	else:
		ok = Saves.save(slot)
	Bus.toast.emit("Saved" if ok else "Save failed", UIKit.GREEN if ok else UIKit.RED)


# --- Input --------------------------------------------------------------------

func _unhandled_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("menu") or ev.is_action_pressed("ui_cancel"):
		if menus.visible and state == State.SHIFT:
			_resume()
		elif state == State.SHIFT:
			_open_pause()
		get_viewport().set_input_as_handled()
		return
	if state != State.SHIFT or menus.visible:
		return
	if ev.is_action_pressed("pause"):
		hud.toggle_pause()
	elif ev.is_action_pressed("speed_1"):
		hud.set_speed(1.0)
	elif ev.is_action_pressed("speed_2"):
		hud.set_speed(2.0)
	elif ev.is_action_pressed("speed_3"):
		hud.set_speed(3.0)
	elif ev.is_action_pressed("toggle_dashboard"):
		hud.toggle_dashboard()
	elif ev.is_action_pressed("fry_pull"):
		hud.fry_pull()
	elif ev.is_action_pressed("quick_save"):
		_save_to(Saves.SLOTS[0])
	else:
		return
	get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	# Mobile: autosave when the app is backgrounded.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if Game.started:
			Saves.save(Saves.AUTOSAVE, _day_snapshot if state == State.SHIFT else {})
