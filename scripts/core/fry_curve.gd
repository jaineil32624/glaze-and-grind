class_name FryCurve
extends RefCounted
## Fry quality as a function of when the batch is pulled.
## t = fraction of the fry cycle elapsed (0..1.2). Pulling past the burn point ruins the batch.

const BURN_POINT := 1.0


## Quality 0..1 for pulling at t. `perfect` is the ideal pull point, `window`
## is the half-width that still gives ≥ 0.9 quality. `bonus` widens the window
## (fryer upgrades).
static func quality(t: float, perfect: float, window: float, bonus: float = 0.0) -> float:
	if t >= BURN_POINT:
		return 0.0
	var w := window + bonus * 0.5
	var d := absf(t - perfect)
	if d <= w:
		return lerpf(1.0, 0.9, d / maxf(w, 0.001))
	# Falls off toward under-done (0.25) or over-done edge
	var falloff := 0.35
	return clampf(lerpf(0.9, 0.25, (d - w) / falloff), 0.25, 0.9)


static func is_burned(t: float) -> bool:
	return t >= BURN_POINT


## Label for feedback text.
static func grade(q: float) -> String:
	if q >= 0.95:
		return "PERFECT!"
	if q >= 0.85:
		return "Great"
	if q >= 0.6:
		return "Good"
	if q > 0.0:
		return "Meh"
	return "BURNED"
