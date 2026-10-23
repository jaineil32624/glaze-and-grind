class_name Menus
extends Control
## Main menu, pause menu, save/load slots and settings — one overlay, several pages.

signal new_game
signal load_slot(slot: String)
signal resume
signal save_slot(slot: String)
signal to_main_menu

enum Page { MAIN, PAUSE, LOAD, SAVE, SETTINGS }

var _page: int = Page.MAIN
var _box: VBoxContainer
var _bg: ColorRect
var _back_page: int = Page.MAIN
var _anim := 0.0
var _art: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)
	_art = Control.new()
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.draw.connect(_draw_art)
	add_child(_art)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(440, 0)
	center.add_child(p)
	_box = UIKit.vbox([], 10)
	p.add_child(_box)


func _process(delta: float) -> void:
	if visible and _page in [Page.MAIN, Page.LOAD, Page.SETTINGS] and not Game.started:
		_anim += delta
		_art.queue_redraw()


func show_page(page: int) -> void:
	_page = page
	visible = true
	_bg.color = Color("#ff9fb5") if not Game.started or page == Page.MAIN else Color(0.15, 0.08, 0.1, 0.6)
	UIKit.clear(_box)
	match page:
		Page.MAIN: _build_main()
		Page.PAUSE: _build_pause()
		Page.LOAD: _build_slots(false)
		Page.SAVE: _build_slots(true)
		Page.SETTINGS: _build_settings()
	await get_tree().process_frame
	for c in _box.get_children():
		if c is Button and not c.disabled:
			c.grab_focus()
			break


func _back() -> void:
	if _back_page < 0:
		resume.emit()
	else:
		show_page(_back_page)


func _go(back: int, page: int) -> void:
	_back_page = back
	show_page(page)


func _title(text: String, sub: String = "") -> void:
	var t := UIKit.label(text, 40, UIKit.PINK_DARK, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(t)
	if sub != "":
		var s := UIKit.label(sub, 15, UIKit.MUTED)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_box.add_child(s)


func _build_main() -> void:
	_title("Glaze & Grind", "Donut & coffee shop tycoon")
	var cont := UIKit.button("Continue", func(): load_slot.emit(Saves.AUTOSAVE), UIKit.GREEN)
	cont.disabled = not Saves.has_save(Saves.AUTOSAVE)
	if not cont.disabled:
		cont.text = "Continue  ·  " + Saves.summary(Saves.AUTOSAVE)
	_box.add_child(cont)
	_box.add_child(UIKit.button("New Game", func(): new_game.emit()))
	_box.add_child(UIKit.button("Load Game", func(): _go(Page.MAIN, Page.LOAD), UIKit.BLUE))
	_box.add_child(UIKit.button("Settings", func(): _go(Page.MAIN, Page.SETTINGS), UIKit.MUTED))
	if not OS.has_feature("web") and not OS.has_feature("mobile"):
		_box.add_child(UIKit.button("Quit", func(): get_tree().quit(), UIKit.INK))
	if DB.loaded_mods.size() > 0:
		_box.add_child(UIKit.label("Mods loaded: " + ", ".join(DB.loaded_mods), 12, UIKit.MUTED))
	var v := UIKit.label("v" + str(ProjectSettings.get_setting("application/config/version", "0.1.0")), 12, UIKit.MUTED)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(v)


func _build_pause() -> void:
	_title("Paused")
	_box.add_child(UIKit.button("Resume", func(): resume.emit(), UIKit.GREEN))
	_box.add_child(UIKit.button("Save Game", func(): _go(Page.PAUSE, Page.SAVE), UIKit.BLUE))
	_box.add_child(UIKit.button("Settings", func(): _go(Page.PAUSE, Page.SETTINGS), UIKit.MUTED))
	_box.add_child(UIKit.button("Quit to Main Menu", func(): to_main_menu.emit(), UIKit.INK))
	var note := UIKit.label("Saves store your progress as of the start of today's shift.", 12, UIKit.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	_box.add_child(note)


func _build_slots(saving: bool) -> void:
	_title("Save Game" if saving else "Load Game")
	var slots: Array = Saves.SLOTS.duplicate()
	if not saving:
		slots.push_front(Saves.AUTOSAVE)
	for slot in slots:
		var label: String = ("Autosave" if slot == Saves.AUTOSAVE else slot.replace("_", " ").capitalize()) + "  ·  " + Saves.summary(slot)
		var b := UIKit.button(label, func():
			if saving:
				save_slot.emit(slot)
				show_page(Page.SAVE)
			else:
				load_slot.emit(slot), UIKit.BLUE)
		if not saving and not Saves.has_save(slot):
			b.disabled = true
		_box.add_child(b)
	_box.add_child(UIKit.button("Back", _back, UIKit.MUTED))


func _build_settings() -> void:
	_title("Settings")
	for key in ["music", "sfx"]:
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.05
		s.value = float(Game.settings.get(key, 0.7))
		s.custom_minimum_size = Vector2(240, 32)
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.value_changed.connect(func(v):
			Game.settings[key] = v
			Sfx.apply_volumes())
		var l := UIKit.label("Music" if key == "music" else "Sound FX", 16)
		l.custom_minimum_size = Vector2(100, 0)
		_box.add_child(UIKit.hbox([l, s]))
	var tut := CheckButton.new()
	tut.text = "Show tips on day 1"
	tut.button_pressed = bool(Game.settings.get("show_tutorial", true))
	tut.toggled.connect(func(on): Game.settings["show_tutorial"] = on)
	_box.add_child(tut)
	if not OS.has_feature("mobile") and not OS.has_feature("web"):
		var fs := CheckButton.new()
		fs.text = "Fullscreen"
		fs.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		fs.toggled.connect(func(on): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED))
		_box.add_child(fs)
	var cloud := OptionButton.new()
	for o in [["off", "Cloud save: Off"], ["mirror", "Cloud save: Mirror folder"], ["http", "Cloud save: HTTP endpoint"]]:
		cloud.add_item(o[1])
		cloud.set_item_metadata(cloud.item_count - 1, o[0])
		if Game.settings.get("cloud", "off") == o[0]:
			cloud.select(cloud.item_count - 1)
	cloud.custom_minimum_size = Vector2(0, 44)
	_box.add_child(cloud)
	var url := LineEdit.new()
	url.placeholder_text = "https://your-server.example/saves"
	url.text = str(Game.settings.get("cloud_url", ""))
	url.custom_minimum_size = Vector2(0, 40)
	url.visible = Game.settings.get("cloud", "off") == "http"
	url.text_changed.connect(func(t):
		Game.settings["cloud_url"] = t
		Saves.configure_cloud())
	_box.add_child(url)
	cloud.item_selected.connect(func(i):
		Game.settings["cloud"] = cloud.get_item_metadata(i)
		url.visible = Game.settings["cloud"] == "http"
		Saves.configure_cloud())
	_box.add_child(UIKit.button("Back", _back, UIKit.MUTED))


## Animated donuts drifting behind the main menu.
func _draw_art() -> void:
	if Game.started and _page == Page.PAUSE:
		return
	var sz := _art.size
	var cols := [Color("#ff8fb4"), Color("#6b3a22"), Color("#fff3d6"), Color("#b8732f"), Color("#7ad3ff")]
	for i in 18:
		var x := fmod(i * 173.0 + _anim * (20.0 + i % 5 * 6.0), sz.x + 160.0) - 80.0
		var y := fmod(i * 97.0 + sin(_anim * 0.7 + i) * 20.0, sz.y)
		var r := 26.0 + (i % 4) * 8.0
		_art.draw_circle(Vector2(x, y), r, Color("#f0b860"))
		_art.draw_circle(Vector2(x, y - 2), r * 0.88, cols[i % cols.size()])
		_art.draw_circle(Vector2(x, y), r * 0.34, Color("#ff9fb5"))
