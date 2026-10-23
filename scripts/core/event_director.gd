class_name EventDirector
extends RefCounted
## Rolls today's random event (if any).


static func roll(rng: RandomNumberGenerator, day: int, event_defs: Array, chance: float) -> Dictionary:
	if day < 2 or rng.randf() > chance:
		return {}
	var pool := event_defs.filter(func(e): return day >= int(e.get("min_day", 1)))
	if pool.is_empty():
		return {}
	var total := 0.0
	for e in pool:
		total += float(e.get("weight", 1.0))
	var r := rng.randf() * total
	for e in pool:
		r -= float(e.get("weight", 1.0))
		if r <= 0.0:
			return e
	return pool[pool.size() - 1]


## Combine store mix with an event's mix boosts.
static func merged_mix(store_mix: Dictionary, event: Dictionary) -> Dictionary:
	var m := store_mix.duplicate()
	var boost: Dictionary = event.get("mix", {})
	for k in boost:
		m[k] = float(m.get(k, 0.5)) * float(boost[k])
	return m
