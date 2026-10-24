extends SceneTree
## Drives a scripted showcase of the game for Godot's Movie Maker mode.
## Run: xvfb-run godot --rendering-driver opengl3 --fixed-fps 30 --resolution 1280x720 \
##        --write-movie /tmp/showreel.avi --path . -s tests/record_showreel.gd

var main
var frame := 0
var G


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	frame += 1
	G = root.get_node("Game")
	match frame:
		1:
			root.get_node("Saves").save_dir = "user://reel_saves/"
		45:   # 1.5 s on the menu, then start
			main._new_game()
			G.time_scale = 6.0
			root.get_node("Game").settings["show_tutorial"] = false
		150:  # into the morning rush: select a crew member
			var e = main.world.employees[0]
			e.selected = true
			root.get_node("Bus").employee_selected.emit(e)
		240:
			root.get_node("Bus").employee_selected.emit(null)
			for x in main.world.employees:
				x.selected = false
		300:  # fryer minigame if something is frying
			for st in main.world.by_type["fryer"]:
				if st.current_task != null and st.current_task.kind == "fry_batch":
					main.hud.open_fry(st)
					G.time_scale = 1.5
					break
		360:
			if main.hud._fry.visible:
				main.hud.fry_pull()
			G.time_scale = 6.0
		420:
			main.hud.toggle_dashboard()
		510:
			main.hud.toggle_dashboard()
			G.time_scale = 40.0   # race to evening lights
		_:
			pass
	if frame > 510 and main.world.clock.hour >= 18.4 and G.time_scale > 6.0:
		G.time_scale = 4.0
	if frame >= 700:
		quit(0)
		return true
	return false
