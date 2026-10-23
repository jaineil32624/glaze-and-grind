extends SceneTree
## Headless smoke test: boots the real main scene, starts a new game and plays
## several full days at high speed, going through summary + management.
## Run: godot --headless --fixed-fps 60 --path . -s tests/smoke_sim.gd

const DAYS := 3
const SPEED := 8.0

var main
var days_done := 0
var frames := 0
var waiting_summary := false


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frames += 1
	var Game = root.get_node("Game")
	if frames == 1:
		root.get_node("Saves").save_dir = "user://test_saves/"
	if frames == 2:
		main._new_game()
		Game.time_scale = SPEED
	if frames < 3:
		return false
	if main.state == main.State.SUMMARY and not waiting_summary:
		waiting_summary = true
		var rec: Dictionary = Game.current().ledger.history.back()
		print("DAY %d: revenue $%.2f, expenses $%.2f, profit $%.2f, served %d, lost %d, rating %.2f, money $%.2f" % [
			rec["day"], rec["revenue"], rec["expenses"], rec["profit"], rec["served"], rec["lost"], rec["rating"], Game.money])
		print("   mistakes: ", main.world.stats["mistakes"], " perfect fries: ", main.world.stats["perfect_fries"],
			" burned: ", main.world.stats["burned"], " eff: %.2f" % main.world.efficiency())
		days_done += 1
		if days_done >= DAYS:
			print("SMOKE OK")
			quit(0)
			return true
		main._to_management()
		# exercise the management screen a bit
		main.world.call("auto_restock", Game.current())
		main._start_shift()
		Game.time_scale = SPEED
	elif main.state == main.State.SHIFT:
		waiting_summary = false
		if frames % 600 == 0:
			print("  t=%s customers=%d queue=%d pending=%d tasks=%d dough=%d case=%d" % [main.world.clock.clock_text(),
				main.world.customers.size(), main.world.queue.size(), main.world.pending_orders.size(),
				main.world.board.tasks.size(), Game.current().inventory.dough, Game.current().inventory.case_total()])
	if frames > 60 * 60 * 10:
		print("SMOKE TIMEOUT")
		quit(1)
		return true
	return false
