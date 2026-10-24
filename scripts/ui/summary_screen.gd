class_name SummaryScreen
extends Control
## End-of-day ledger and highlights.

signal continue_pressed

var _box: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.15, 0.08, 0.1, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(760, 560)
	center.add_child(p)
	_box = UIKit.vbox([], 8)
	p.add_child(_box)


func show_summary(s: Dictionary) -> void:
	UIKit.clear(_box)
	var profit: float = s["profit"]
	var head := UIKit.hbox([
		UIKit.label("Day %d Closed" % s["day"], 30, UIKit.INK, true), UIKit.spacer(),
		UIKit.label(("Profit " if profit >= 0 else "Loss ") + UIKit.money(profit), 26, UIKit.GREEN if profit >= 0 else UIKit.RED, true)])
	_box.add_child(head)
	if s.get("event", "") != "":
		_box.add_child(UIKit.label("Today's event: " + s["event"], 15, UIKit.MUTED))

	var cols := UIKit.hbox([], 24)
	# Ledger
	var led := UIKit.vbox([], 3)
	led.custom_minimum_size = Vector2(330, 0)
	led.add_child(UIKit.label("Ledger", 19, UIKit.PINK_DARK, true))
	var b: Dictionary = s["breakdown"]
	for k in ["sales", "tips"]:
		if float(b.get(k, 0)) != 0.0:
			led.add_child(_line(k.capitalize(), float(b[k]), UIKit.GREEN))
	for k in ["ingredients", "wages", "rent", "maintenance", "repairs", "delivery", "hiring", "equipment", "fines"]:
		if float(b.get(k, 0)) != 0.0:
			led.add_child(_line(k.capitalize(), -float(b[k]), UIKit.RED))
	led.add_child(HSeparator.new())
	led.add_child(_line("Net", profit, UIKit.GREEN if profit >= 0 else UIKit.RED))
	if absf(float(s.get("passive", 0.0))) > 0.01:
		led.add_child(_line("Other stores", float(s["passive"]), UIKit.BLUE))
	if float(s.get("restock", 0.0)) > 0.0:
		led.add_child(UIKit.label("Smart Inventory restocked tomorrow's supplies: %s" % UIKit.money(s["restock"]), 12, UIKit.MUTED))
	cols.add_child(led)

	# Performance
	var perf := UIKit.vbox([], 3)
	perf.add_child(UIKit.label("Performance", 19, UIKit.PINK_DARK, true))
	perf.add_child(UIKit.label("Customers served: %d   ·   Walked out: %d" % [s["served"], s["lost"]], 15))
	perf.add_child(UIKit.label("Donuts sold: %d   ·   Drinks sold: %d" % [s["donuts_sold"], s["drinks_sold"]], 15))
	perf.add_child(UIKit.label("Happiness: %.0f%%   ·   Accuracy: %.0f%%" % [s["satisfaction"] * 100.0, s["accuracy"] * 100.0], 15))
	perf.add_child(UIKit.label("Crew efficiency: %.0f%%" % (s["efficiency"] * 100.0), 15))
	var rd: float = s["rating_delta"]
	perf.add_child(UIKit.label("Rating: %s %.2f (%s%.2f)" % [UIKit.stars(s["rating"]), s["rating"], "+" if rd >= 0 else "", rd], 15,
		UIKit.GREEN if rd >= 0 else UIKit.RED))
	perf.add_child(UIKit.label("Perfect fries: %d   ·   Burned batches: %d" % [s["perfect_fries"], s["burned"]], 15))
	perf.add_child(UIKit.label("Food waste: %s  (%d donuts went stale)" % [UIKit.money(s["waste"]), s["spoiled"]], 15))
	var ms: Dictionary = s["mistakes"]
	if not ms.is_empty():
		var parts: PackedStringArray = []
		var names := {"spill": "spills", "wrong_order": "wrong orders", "forgot_topping": "forgotten toppings",
			"bad_dough": "bad dough", "burned": "burned batches", "late": "late arrivals"}
		for k in ms:
			parts.append("%d %s" % [ms[k], names.get(k, k)])
		var ml := UIKit.label("Mistakes: " + ", ".join(parts), 14, UIKit.RED)
		ml.autowrap_mode = TextServer.AUTOWRAP_WORD
		ml.custom_minimum_size = Vector2(360, 0)
		perf.add_child(ml)
	cols.add_child(perf)
	_box.add_child(cols)

	# Highlights
	var notes: Array = []
	if s.get("ranked_up", false):
		notes.append(["★ Promoted to %s! New upgrades and stores may be unlocked." % Game.rank_title(s["rank"]), Color("#c9a227")])
	if s.get("critic", "") != "":
		notes.append(["Food critic left a review: " + s["critic"], Color("#c9a227")])
	if s.get("viral", false):
		notes.append(["An influencer's post about you went viral!", Color("#c45bff")])
	if s.get("inspection", "") != "":
		notes.append(["Health inspection grade: " + s["inspection"], UIKit.GREEN if s["inspection"] in ["A", "B"] else UIKit.RED])
	for n in s.get("quit", []):
		notes.append(["%s quit — they were unhappy. Watch stress and pay." % n, UIKit.RED])
	for n in s.get("late", []):
		notes.append(["%s arrived late." % n, UIKit.AMBER])
	if s.get("sick", "") != "":
		notes.append(["%s called in sick (paid half)." % s["sick"], UIKit.MUTED])
	if s["lost"] > s["served"] * 0.25 and s["served"] > 0:
		notes.append(["Lots of customers walked out. Try more staff, a second register, or faster equipment.", UIKit.AMBER])
	if Game.money < 0:
		notes.append(["You're in debt! Cut costs or you won't be able to restock.", UIKit.RED])
	if not notes.is_empty():
		_box.add_child(HSeparator.new())
		for n in notes:
			var l := UIKit.label(n[0], 15, n[1])
			l.autowrap_mode = TextServer.AUTOWRAP_WORD
			_box.add_child(l)
	_box.add_child(UIKit.spacer(false))
	var cont := UIKit.button("Continue to Management  →", func(): continue_pressed.emit(), UIKit.GREEN)
	cont.custom_minimum_size = Vector2(0, 56)
	_box.add_child(cont)
	cont.grab_focus.call_deferred()


func _line(label: String, amount: float, color: Color) -> HBoxContainer:
	return UIKit.hbox([UIKit.label(label, 15), UIKit.spacer(), UIKit.label(UIKit.money(amount), 15, color)])
