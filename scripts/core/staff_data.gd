class_name StaffData
extends RefCounted
## Everything about one crew member that persists between days.

const FIRST_NAMES := ["Ava", "Leo", "Maya", "Noah", "Zoe", "Eli", "Priya", "Sam", "Lena", "Omar", "Jada", "Theo",
	"Rosa", "Kai", "Ivy", "Mateo", "Nina", "Ravi", "Tess", "Diego", "Hana", "Jonah", "Lucia", "Felix", "Amara", "Ben"]
const PERSONALITIES := {
	"steady":        {"label": "Steady",        "speed": 1.0,  "mistake": 1.0, "stress": 1.0,  "desc": "No surprises."},
	"cheerful":      {"label": "Cheerful",      "speed": 1.0,  "mistake": 1.0, "stress": 0.7,  "desc": "Stress builds slowly."},
	"perfectionist": {"label": "Perfectionist", "speed": 0.88, "mistake": 0.5, "stress": 1.1,  "desc": "Careful but slower."},
	"speedy":        {"label": "Speedy",        "speed": 1.18, "mistake": 1.5, "stress": 1.0,  "desc": "Fast and a bit sloppy."},
	"chatty":        {"label": "Chatty",        "speed": 0.92, "mistake": 1.0, "stress": 0.9,  "desc": "Customers love them at the register."},
}
const XP_LEVELS := [0, 40, 110, 220, 380]   # xp needed to reach level 1..5
const SKIN := ["#f5d0b5", "#e8b896", "#c68e6a", "#a26c4a", "#7a4e33", "#f1c9a5"]
const HAIR := ["#2b1d14", "#5a3a22", "#c88a3c", "#1d1d1d", "#8a2b1d", "#e3c26f"]

var uid: String = ""
var name: String = ""
var personality: String = "steady"
var speed: int = 5
var accuracy: int = 5
var intelligence: int = 5
var teamwork: int = 5
var reliability: int = 5
var stress: float = 0.0
var happiness: float = 75.0
var xp: float = 0.0
var level: int = 1
var wage: float = 12.0          # $ per in-game hour
var focus: String = ""          # station type to prefer, "" = any
var skin: String = "#f5d0b5"
var hair: String = "#2b1d14"
var days_worked: int = 0
var mistakes_today: int = 0
var tasks_today: int = 0


static func generate(rng: RandomNumberGenerator, quality_bias: float = 0.0) -> StaffData:
	var s := StaffData.new()
	s.uid = "%d%d" % [Time.get_ticks_usec(), rng.randi() % 100000]
	s.name = FIRST_NAMES[rng.randi() % FIRST_NAMES.size()]
	var keys := PERSONALITIES.keys()
	s.personality = keys[rng.randi() % keys.size()]
	var roll := func() -> int: return clampi(int(round(rng.randfn(5.0 + quality_bias, 1.8))), 1, 10)
	s.speed = roll.call()
	s.accuracy = roll.call()
	s.intelligence = roll.call()
	s.teamwork = roll.call()
	s.reliability = roll.call()
	s.skin = SKIN[rng.randi() % SKIN.size()]
	s.hair = HAIR[rng.randi() % HAIR.size()]
	s.happiness = rng.randf_range(65.0, 85.0)
	s.wage = s.fair_wage()
	return s


func stat_total() -> int:
	return speed + accuracy + intelligence + teamwork + reliability


func fair_wage() -> float:
	return snappedf(9.0 + stat_total() * 0.22 + (level - 1) * 1.25, 0.25)


func pers() -> Dictionary:
	return PERSONALITIES.get(personality, PERSONALITIES["steady"])


## Multiplier on how fast work progresses.
func work_speed() -> float:
	var stress_pen := 1.0 if stress < 60.0 else lerpf(1.0, 0.8, (stress - 60.0) / 40.0)
	return (0.6 + speed * 0.08) * float(pers()["speed"]) * stress_pen * (1.0 + (level - 1) * 0.06)


func walk_speed() -> float:
	return 110.0 + speed * 12.0


func stress_mult() -> float:
	if stress >= 75.0:
		return 2.0
	if stress >= 50.0:
		return 1.4
	return 1.0


## Probability that a task of this kind goes wrong.
func mistake_chance(kind: String) -> float:
	var base: float = WorkTask.BASE_MISTAKE.get(kind, 0.04)
	var p := base * (11.0 - accuracy) / 10.0 * stress_mult() * float(pers()["mistake"]) * (1.0 - 0.08 * (level - 1))
	return clampf(p, 0.0, 0.6)


## Fry pull precision: standard deviation of the pull time error (fraction of fry time).
func fry_error_sigma() -> float:
	return clampf(0.16 - accuracy * 0.012 - (level - 1) * 0.008, 0.02, 0.2) * stress_mult()


func can_do(skill_level: int) -> bool:
	return level >= skill_level


func add_stress(amount: float) -> void:
	stress = clampf(stress + amount * float(pers()["stress"]), 0.0, 100.0)


func recover(amount: float) -> void:
	stress = clampf(stress - amount, 0.0, 100.0)


func gain_xp(amount: float) -> bool:
	xp += amount * (0.7 + intelligence * 0.06)
	if level < XP_LEVELS.size() and xp >= XP_LEVELS[level]:
		level += 1
		# Small stat growth on level up
		if accuracy <= speed:
			accuracy = mini(accuracy + 1, 10)
		else:
			speed = mini(speed + 1, 10)
		return true
	return false


func next_level_xp() -> float:
	return float(XP_LEVELS[level]) if level < XP_LEVELS.size() else xp


func late_chance() -> float:
	return clampf((11 - reliability) * 0.018, 0.0, 0.2)


func skill_label() -> String:
	match level:
		1: return "Register · Mixer · Fryer · Glaze · Brew"
		2: return "+ Espresso drinks"
		_: return "+ Espresso + Blended drinks"


func to_dict() -> Dictionary:
	return {
		"uid": uid, "name": name, "personality": personality,
		"speed": speed, "accuracy": accuracy, "intelligence": intelligence,
		"teamwork": teamwork, "reliability": reliability,
		"stress": stress, "happiness": happiness, "xp": xp, "level": level,
		"wage": wage, "focus": focus, "skin": skin, "hair": hair, "days_worked": days_worked,
	}


static func from_dict(d: Dictionary) -> StaffData:
	var s := StaffData.new()
	for k in d:
		if k in ["speed", "accuracy", "intelligence", "teamwork", "reliability", "level", "days_worked"]:
			s.set(k, int(d[k]))
		elif k in ["stress", "happiness", "xp", "wage"]:
			s.set(k, float(d[k]))
		else:
			s.set(k, d[k])
	return s
