class_name FloatText
extends Node2D
## Short-lived rising text ("+$4.20", "PERFECT!", "Spilled!").

var text := ""
var color := Color.WHITE
var life := 1.4
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	position.y -= delta * 38.0
	if _t >= life:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var a := clampf(1.0 - (_t / life) ** 2, 0.0, 1.0)
	var font := ThemeDB.fallback_font
	var size := 18
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := Vector2(-w * 0.5, 0)
	draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(0, 0, 0, 0.55 * a))
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(color, a))
