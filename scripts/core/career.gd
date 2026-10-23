class_name Career
extends RefCounted
## Career rank from lifetime profit and store rating. Ranks never go down.


static func rank_for(career_defs: Array, lifetime_profit: float, rating: float, current_rank: int = 0) -> int:
	var best := current_rank
	for c in career_defs:
		var r := int(c.get("rank", 0))
		if r > best and lifetime_profit >= float(c.get("profit", 0)) and rating >= float(c.get("rating", 0)):
			best = r
	return best


static func next_goal(career_defs: Array, current_rank: int) -> Dictionary:
	for c in career_defs:
		if int(c.get("rank", 0)) == current_rank + 1:
			return c
	return {}
