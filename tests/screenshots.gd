extends SceneTree
## Plays the game under a virtual display and saves screenshots for the README.
## Run: xvfb-run -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --fixed-fps 60 --path . -s tests/screenshots.gd

const OUT := "res://docs/screenshots/"

var main
var frame := 0
var step := 0
var wait_until := 0
var G
var S


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))


func shot(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("saved ", name)


func _process(_d: float) -> bool:
	frame += 1
	G = root.get_node("Game")
	S = root.get_node("Saves")
	if frame < wait_until:
		return false
	match step:
		0:
			S.save_dir = "user://shot_saves/"
			wait_until = frame + 40
		1:
			shot("01_main_menu")
			main._new_game()
			G.time_scale = 6.0
			wait_until = frame + 60 * 9      # into the morning rush
		2:
			G.time_scale = 1.0
			wait_until = frame + 30
		3:
			shot("02_morning_rush")
			# select the busiest employee
			var e = main.world.employees[0]
			e.selected = true
			root.get_node("Bus").employee_selected.emit(e)
			wait_until = frame + 20
		4:
			shot("03_staff_card")
			root.get_node("Bus").employee_selected.emit(null)
			main.hud.toggle_dashboard()
			G.time_scale = 6.0
			wait_until = frame + 60 * 6
		5:
			G.time_scale = 1.0
			wait_until = frame + 20
		6:
			shot("04_dashboard")
			main.hud.toggle_dashboard()
			G.time_scale = 4.0
			step = 7
			return false
		7:
			# wait for a fry to start, then open the minigame
			for st in main.world.by_type["fryer"]:
				if st.current_task != null and st.current_task.kind == "fry_batch" and st.current_task.ratio() > 0.3 and st.current_task.ratio() < 0.6:
					G.time_scale = 0.0
					main.hud.open_fry(st)
					wait_until = frame + 15
					step = 8
					return false
			return false
		8:
			shot("05_fryer_minigame")
			main.hud._fry.visible = false
			main.hud._toggle_restock()
			wait_until = frame + 15
		9:
			shot("06_rush_restock")
			main.hud._toggle_restock()
			G.time_scale = 10.0
			step = 10
			return false
		10:
			if main.world.clock.hour >= 18.9:
				G.time_scale = 0.5
				wait_until = frame + 40
				step = 11
			return false
		11:
			shot("07_evening")
			G.time_scale = 10.0
			step = 12
			return false
		12:
			if main.state == main.State.SUMMARY:
				wait_until = frame + 30
				step = 13
			return false
		13:
			shot("08_day_summary")
			main._to_management()
			wait_until = frame + 20
		14:
			shot("09_management_restock")
			main.management._tabs.current_tab = 1
			wait_until = frame + 20
		15:
			shot("10_management_staff")
			main.management._tabs.current_tab = 2
			wait_until = frame + 20
		16:
			shot("11_management_upgrades")
			main.management._tabs.current_tab = 4
			wait_until = frame + 20
		17:
			shot("12_management_stores")
			quit(0)
			return true
	step += 1
	return false
