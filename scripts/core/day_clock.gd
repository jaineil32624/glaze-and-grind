class_name DayClock
extends RefCounted
## In-game time for one shift (6:00 → 20:00), phases, traffic and lighting.

const OPEN_HOUR := 6.0
const CLOSE_HOUR := 20.0
const LAST_ENTRY := 19.6
const REAL_SECONDS_PER_DAY := 300.0
const PEAK_ARRIVALS_PER_HOUR := 5.6

# (hour, traffic) control points — piecewise linear.
const TRAFFIC_CURVE := [
	[6.0, 0.45], [7.0, 1.0], [8.75, 1.0], [9.5, 0.45], [11.5, 0.4], [12.25, 0.85], [13.25, 0.75],
	[13.75, 0.4], [16.25, 0.3], [17.25, 0.75], [18.25, 0.6], [19.0, 0.25], [20.0, 0.0],
]
const PHASES := [
	[6.0, "Morning Rush"], [9.5, "Late Morning"], [11.5, "Lunch Rush"], [13.5, "Afternoon Slowdown"],
	[16.5, "Evening Rush"], [18.5, "Closing Time"],
]
const LIGHT := [
	[6.0, Color(0.95, 0.82, 0.72)], [7.5, Color(1, 0.97, 0.93)], [16.5, Color(1, 1, 1)],
	[18.0, Color(1.0, 0.86, 0.72)], [19.2, Color(0.72, 0.7, 0.86)], [20.0, Color(0.6, 0.6, 0.8)],
]
const SKY := [
	[6.0, Color("#ffb58a")], [7.5, Color("#9fd8ff")], [16.5, Color("#8fcfff")],
	[18.0, Color("#ff9a6b")], [19.2, Color("#4b4f8f")], [20.0, Color("#232552")],
]

var hour: float = OPEN_HOUR


func reset() -> void:
	hour = OPEN_HOUR


func advance(real_delta: float) -> void:
	hour = minf(hour + real_delta * (CLOSE_HOUR - OPEN_HOUR) / REAL_SECONDS_PER_DAY, CLOSE_HOUR)


func is_open_for_entry() -> bool:
	return hour < LAST_ENTRY


func is_closed() -> bool:
	return hour >= CLOSE_HOUR


func ratio() -> float:
	return (hour - OPEN_HOUR) / (CLOSE_HOUR - OPEN_HOUR)


func clock_text() -> String:
	var h := int(hour)
	var m := int((hour - h) * 60.0) / 5 * 5
	var suffix := "AM" if h < 12 else "PM"
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, m, suffix]


func phase_name() -> String:
	var name: String = PHASES[0][1]
	for p in PHASES:
		if hour >= p[0]:
			name = p[1]
	return name


static func traffic_at(h: float) -> float:
	if h <= TRAFFIC_CURVE[0][0]:
		return TRAFFIC_CURVE[0][1]
	for i in range(1, TRAFFIC_CURVE.size()):
		var a: Array = TRAFFIC_CURVE[i - 1]
		var b: Array = TRAFFIC_CURVE[i]
		if h <= b[0]:
			return lerpf(a[1], b[1], (h - a[0]) / (b[0] - a[0]))
	return 0.0


## Arrivals per game hour at the current time.
func arrival_rate(store_traffic: float, event_traffic: float, rating: float, evening_surge: float = 1.0) -> float:
	var t := traffic_at(hour)
	if hour >= 16.5 and hour <= 19.0:
		t *= evening_surge
	var rating_factor := 0.55 + clampf(rating, 0.0, 5.0) * 0.13
	return PEAK_ARRIVALS_PER_HOUR * t * store_traffic * event_traffic * rating_factor


static func _sample_colors(table: Array, h: float) -> Color:
	if h <= table[0][0]:
		return table[0][1]
	for i in range(1, table.size()):
		if h <= table[i][0]:
			return (table[i - 1][1] as Color).lerp(table[i][1], (h - table[i - 1][0]) / (table[i][0] - table[i - 1][0]))
	return table[table.size() - 1][1]


func light_color() -> Color:
	return _sample_colors(LIGHT, hour)


func sky_color() -> Color:
	return _sample_colors(SKY, hour)


func lamps_on() -> bool:
	return hour >= 17.8
