class_name UIKit
extends RefCounted
## Theme + small builders so every screen is consistent and touch-friendly.

const PINK := Color("#ff6f91")
const PINK_DARK := Color("#e8457a")
const CREAM := Color("#fff8ec")
const BROWN := Color("#4a2c1d")
const BLUE := Color("#4f8cff")
const GREEN := Color("#2fae6b")
const RED := Color("#e5383b")
const AMBER := Color("#ffb020")
const INK := Color("#3a2a22")
const MUTED := Color("#8a7568")


static func build_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 17
	var panel := _box(CREAM, 14, Color(0, 0, 0, 0.12), 2)
	panel.shadow_color = Color(0, 0, 0, 0.18)
	panel.shadow_size = 8
	panel.content_margin_left = 14
	panel.content_margin_right = 14
	panel.content_margin_top = 10
	panel.content_margin_bottom = 10
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)

	var b_normal := _box(PINK, 12, PINK_DARK, 0)
	b_normal.border_width_bottom = 4
	var b_hover := _box(PINK.lightened(0.1), 12, PINK_DARK, 0)
	b_hover.border_width_bottom = 4
	var b_pressed := _box(PINK_DARK, 12, PINK_DARK, 0)
	b_pressed.content_margin_top = 10
	var b_disabled := _box(Color("#d9cfc7"), 12, Color("#c2b6ad"), 0)
	b_disabled.border_width_bottom = 4
	var b_focus := _box(Color(0, 0, 0, 0), 12, Color("#ffd23f"), 3)
	for sb in [b_normal, b_hover, b_pressed, b_disabled]:
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		if sb != b_pressed:
			sb.content_margin_top = 8
		sb.content_margin_bottom = 8
	t.set_stylebox("normal", "Button", b_normal)
	t.set_stylebox("hover", "Button", b_hover)
	t.set_stylebox("pressed", "Button", b_pressed)
	t.set_stylebox("disabled", "Button", b_disabled)
	t.set_stylebox("focus", "Button", b_focus)
	t.set_color("font_color", "Button", Color.WHITE)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color("#8a7d74"))
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_color", "Label", INK)
	t.set_constant("separation", "HBoxContainer", 10)
	t.set_constant("separation", "VBoxContainer", 8)

	var tab_sel := _box(CREAM, 10, PINK, 0)
	tab_sel.border_width_bottom = 4
	tab_sel.content_margin_left = 16
	tab_sel.content_margin_right = 16
	tab_sel.content_margin_top = 8
	tab_sel.content_margin_bottom = 8
	var tab_un := _box(Color("#f2e3d3"), 10, Color(0, 0, 0, 0), 0)
	tab_un.content_margin_left = 16
	tab_un.content_margin_right = 16
	tab_un.content_margin_top = 8
	tab_un.content_margin_bottom = 8
	t.set_stylebox("tab_selected", "TabContainer", tab_sel)
	t.set_stylebox("tab_unselected", "TabContainer", tab_un)
	t.set_stylebox("tab_hovered", "TabContainer", tab_un)
	t.set_stylebox("panel", "TabContainer", _box(Color("#fffdf8"), 12, Color(0, 0, 0, 0.08), 1))
	t.set_color("font_selected_color", "TabContainer", PINK_DARK)
	t.set_color("font_unselected_color", "TabContainer", MUTED)
	t.set_color("font_hovered_color", "TabContainer", INK)

	var bar_bg := _box(Color(0, 0, 0, 0.12), 6, Color(0, 0, 0, 0), 0)
	var bar_fill := _box(GREEN, 6, Color(0, 0, 0, 0), 0)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)
	t.set_color("font_color", "ProgressBar", INK)
	t.set_stylebox("slider", "HSlider", _box(Color(0, 0, 0, 0.15), 4, Color(0, 0, 0, 0), 0))
	t.set_stylebox("grabber_area", "HSlider", _box(PINK, 4, Color(0, 0, 0, 0), 0))
	return t


static func _box(bg: Color, radius: int, border: Color, border_w: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(border_w)
	s.anti_aliasing = true
	return s


static func label(text: String, size: int = 17, color: Color = INK, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_constant_override("outline_size", 1)
		l.add_theme_color_override("font_outline_color", color)
	return l


static func button(text: String, cb: Callable, color: Color = PINK, min_w: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 48)
	b.focus_mode = Control.FOCUS_ALL
	if color != PINK:
		var n := _box(color, 12, color.darkened(0.25), 0)
		n.border_width_bottom = 4
		n.content_margin_left = 14
		n.content_margin_right = 14
		n.content_margin_top = 8
		n.content_margin_bottom = 8
		var h := n.duplicate()
		h.bg_color = color.lightened(0.1)
		var p := n.duplicate()
		p.bg_color = color.darkened(0.15)
		p.border_width_bottom = 0
		p.content_margin_top = 10
		b.add_theme_stylebox_override("normal", n)
		b.add_theme_stylebox_override("hover", h)
		b.add_theme_stylebox_override("pressed", p)
	b.pressed.connect(func():
		Sfx.play("click", 0.0)
		cb.call())
	return b


static func hbox(children: Array = [], sep: int = 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	for c in children:
		h.add_child(c)
	return h


static func vbox(children: Array = [], sep: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	for c in children:
		v.add_child(c)
	return v


static func panel(child: Control, bg: Color = CREAM) -> PanelContainer:
	var p := PanelContainer.new()
	if bg != CREAM:
		var sb := _box(bg, 14, Color(0, 0, 0, 0.12), 2)
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 10
		sb.content_margin_bottom = 10
		p.add_theme_stylebox_override("panel", sb)
	p.add_child(child)
	return p


static func spacer(h: bool = true) -> Control:
	var c := Control.new()
	if h:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


static func bar(value: float, max_v: float, color: Color, w: float = 120.0) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.max_value = max_v
	pb.value = value
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(w, 12)
	var f := _box(color, 6, Color(0, 0, 0, 0), 0)
	pb.add_theme_stylebox_override("fill", f)
	return pb


static func money(n: float) -> String:
	var neg := n < 0.0
	var s := "%.2f" % absf(n)
	var parts := s.split(".")
	var ip: String = parts[0]
	var out := ""
	for i in ip.length():
		if i > 0 and (ip.length() - i) % 3 == 0:
			out += ","
		out += ip[i]
	return ("-$" if neg else "$") + out + "." + parts[1]


static func stars(r: float) -> String:
	var full := int(floor(r + 0.25))
	var s := ""
	for i in 5:
		s += "★" if i < full else "☆"
	return s


## Anchor a control to a preset and set its offsets explicitly (code-built UI
## can't rely on `position`, which ignores anchors).
static func place(c: Control, preset: int, l: float, t: float, r: float, b: float,
		grow_h: int = Control.GROW_DIRECTION_END, grow_v: int = Control.GROW_DIRECTION_END) -> void:
	c.set_anchors_preset(preset)
	c.offset_left = l
	c.offset_top = t
	c.offset_right = r
	c.offset_bottom = b
	c.grow_horizontal = grow_h
	c.grow_vertical = grow_v


## The brand donut, drawn (no emoji font needed).
static func donut_icon(sz: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(sz, sz)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		var ctr := Vector2(sz, sz) * 0.5
		var r := sz * 0.46
		c.draw_circle(ctr + Vector2(0, 1.5), r, Color("#c98a3c"))
		c.draw_circle(ctr, r, Color("#f0b860"))
		c.draw_circle(ctr - Vector2(0, 1.5), r * 0.82, PINK)
		c.draw_circle(ctr, r * 0.32, Color("#fff8ec"))
		var sprinkle_cols := [Color("#4f8cff"), Color("#ffd23f"), Color("#2fae6b"), Color.WHITE]
		for i in 7:
			var a := i * TAU / 7.0 + 0.3
			var p := ctr + Vector2.from_angle(a) * r * 0.6
			c.draw_line(p, p + Vector2.from_angle(a + 1.2) * sz * 0.08, sprinkle_cols[i % 4], maxf(1.5, sz * 0.05)))
	return c


static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


## Wrap content in a scroll container that expands.
static func scroll(child: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(child)
	return s
