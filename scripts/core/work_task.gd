class_name WorkTask
extends RefCounted
## A unit of work performed at a station by one employee.

const BASE_PRIORITY := {
	"take_order": 60.0,
	"assemble": 70.0,
	"make_drink": 50.0,
	"finish_batch": 38.0,
	"fry_batch": 30.0,
	"mix_dough": 26.0,
}
## Base mistake probability per task kind (before stats).
const BASE_MISTAKE := {
	"take_order": 0.0,
	"assemble": 0.05,
	"make_drink": 0.06,
	"finish_batch": 0.06,
	"fry_batch": 0.0,   # frying quality comes from pull timing instead
	"mix_dough": 0.03,
}

static var _next_id: int = 1

var id: int
var kind: String
var station_type: String
var duration: float = 3.0
var progress: float = 0.0
var created_at: float = 0.0
var skill: int = 1
var claimant = null              # Employee node
var station = null               # Station node reserved on claim
var payload: Dictionary = {}     # order, drink_index, donut_id, qualities, customer...
var assist: float = 0.0          # extra speed from a helping coworker
var cancelled: bool = false


func _init(p_kind: String, p_station: String, p_duration: float, p_payload: Dictionary = {}, p_skill: int = 1) -> void:
	id = _next_id
	_next_id += 1
	kind = p_kind
	station_type = p_station
	duration = p_duration
	payload = p_payload
	skill = p_skill


func is_claimed() -> bool:
	return claimant != null


func ratio() -> float:
	return clampf(progress / maxf(duration, 0.01), 0.0, 1.0)


## Priority score of this task for one employee.
## urgency: 0..1 (e.g. how unhappy the waiting customer is).
static func score(task: WorkTask, now: float, urgency: float, distance: float, focus: String, staff_level: int) -> float:
	if staff_level < task.skill:
		return -INF
	var s: float = BASE_PRIORITY.get(task.kind, 10.0)
	s += urgency * 45.0
	s += minf(now - task.created_at, 60.0) * 0.5
	if focus != "" and focus == task.station_type:
		s += 40.0
	elif focus != "" and focus != task.station_type:
		s -= 15.0
	s -= distance * 0.02
	return s
