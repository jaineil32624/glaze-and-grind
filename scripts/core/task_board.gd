class_name TaskBoard
extends RefCounted
## Open work for the crew. The store posts tasks, employees claim the best one.

var tasks: Array = []   # Array[WorkTask]


func post(task: WorkTask) -> WorkTask:
	tasks.append(task)
	return task


func remove(task: WorkTask) -> void:
	tasks.erase(task)


func release(task: WorkTask) -> void:
	if task == null:
		return
	task.claimant = null
	task.station = null
	task.assist = 0.0


func open_tasks() -> Array:
	return tasks.filter(func(t): return t.claimant == null and not t.cancelled)


func count(kind: String, pred: Callable = Callable()) -> int:
	var n := 0
	for t in tasks:
		if t.kind == kind and not t.cancelled and (not pred.is_valid() or pred.call(t)):
			n += 1
	return n


## Choose the best open task for an employee.
## station_for: Callable(task) -> a free station node for that task, or null
## pos_of: Callable(station) -> Vector2
## urgency_of: Callable(task) -> float 0..1
## can_start: Callable(task) -> bool  (ingredients available etc.)
func best_for(staff_level: int, focus: String, emp_pos: Vector2, now: float,
		station_for: Callable, pos_of: Callable, urgency_of: Callable, can_start: Callable) -> Dictionary:
	var best: WorkTask = null
	var best_station = null
	var best_score := -INF
	for t in tasks:
		if t.claimant != null or t.cancelled:
			continue
		if staff_level < t.skill:
			continue
		var st = station_for.call(t)
		if st == null:
			continue
		if not can_start.call(t):
			continue
		var dist: float = emp_pos.distance_to(pos_of.call(st))
		var s := WorkTask.score(t, now, urgency_of.call(t), dist, focus, staff_level)
		if s > best_score:
			best_score = s
			best = t
			best_station = st
	return {"task": best, "station": best_station, "score": best_score}


func clear() -> void:
	tasks.clear()
