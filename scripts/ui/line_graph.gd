class_name LineGraph
extends Control
## Small real-time line/area chart for the dashboard.

var title := ""
var values: PackedFloat32Array = PackedFloat32Array()
var color := Color("#4f8cff")
var fmt := "%.0f"
var fixed_min := NAN
var fixed_max := NAN
var bars := false


func _init() -> void:
	custom_minimum_size = Vector2(260, 96)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_data(v: PackedFloat32Array) -> void:
	values = v
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(1, 1, 1, 0.65))
	draw_string(font, Vector2(8, 18), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#8a7568"))
	var cur := fmt % values[values.size() - 1] if values.size() > 0 else "—"
	var cw := font.get_string_size(cur, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	draw_string(font, Vector2(size.x - cw - 8, 20), cur, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, color.darkened(0.2))
	var plot := Rect2(8, 28, size.x - 16, size.y - 36)
	draw_line(Vector2(plot.position.x, plot.end.y), plot.end, Color(0, 0, 0, 0.12), 1.0)
	if values.size() < 2:
		draw_string(font, plot.get_center() - Vector2(30, -4), "collecting…", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0, 0, 0, 0.3))
		return
	var lo := fixed_min if not is_nan(fixed_min) else values[0]
	var hi := fixed_max if not is_nan(fixed_max) else values[0]
	if is_nan(fixed_min) or is_nan(fixed_max):
		for v in values:
			if is_nan(fixed_min):
				lo = minf(lo, v)
			if is_nan(fixed_max):
				hi = maxf(hi, v)
	if is_equal_approx(hi, lo):
		hi = lo + 1.0
	var n := values.size()
	if bars:
		var bw := plot.size.x / n
		for i in n:
			var h := (values[i] - lo) / (hi - lo) * plot.size.y
			draw_rect(Rect2(plot.position.x + i * bw + 1, plot.end.y - h, bw - 2, h), color)
		return
	var pts := PackedVector2Array()
	for i in n:
		var x := plot.position.x + plot.size.x * i / float(n - 1)
		var y := plot.end.y - (values[i] - lo) / (hi - lo) * plot.size.y
		pts.append(Vector2(x, y))
	var area := pts.duplicate()
	area.append(Vector2(pts[n - 1].x, plot.end.y))
	area.append(Vector2(pts[0].x, plot.end.y))
	draw_colored_polygon(area, Color(color, 0.15))
	draw_polyline(pts, color, 2.5, true)
	draw_circle(pts[n - 1], 4, color)
