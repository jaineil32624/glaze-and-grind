class_name Ledger
extends RefCounted
## Tracks one day's money in categories, and keeps a history of past days.

const REVENUE_KEYS := ["sales", "tips"]
const EXPENSE_KEYS := ["ingredients", "wages", "maintenance", "rent", "repairs", "delivery", "hiring", "equipment", "fines"]

var today: Dictionary = {}
var history: Array = []          # [{day, revenue, expenses, profit, rating, served, lost}]
var hourly_revenue: PackedFloat32Array = PackedFloat32Array()


func _init() -> void:
	reset_day()


func reset_day() -> void:
	today = {}
	for k in REVENUE_KEYS + EXPENSE_KEYS:
		today[k] = 0.0
	hourly_revenue = PackedFloat32Array()
	hourly_revenue.resize(15)  # 6:00 .. 20:00
	hourly_revenue.fill(0.0)


func add_revenue(category: String, amount: float, hour: float = -1.0) -> void:
	assert(category in REVENUE_KEYS, "Unknown revenue category: " + category)
	today[category] = float(today.get(category, 0.0)) + amount
	if hour >= 6.0:
		var idx := clampi(int(hour) - 6, 0, hourly_revenue.size() - 1)
		hourly_revenue[idx] += amount


func add_expense(category: String, amount: float) -> void:
	assert(category in EXPENSE_KEYS, "Unknown expense category: " + category)
	today[category] = float(today.get(category, 0.0)) + amount


func revenue() -> float:
	var t := 0.0
	for k in REVENUE_KEYS:
		t += float(today.get(k, 0.0))
	return t


func expenses() -> float:
	var t := 0.0
	for k in EXPENSE_KEYS:
		t += float(today.get(k, 0.0))
	return t


func profit() -> float:
	return revenue() - expenses()


func close_day(day: int, rating: float, served: int, lost: int) -> Dictionary:
	var rec := {
		"day": day,
		"revenue": snappedf(revenue(), 0.01),
		"expenses": snappedf(expenses(), 0.01),
		"profit": snappedf(profit(), 0.01),
		"rating": snappedf(rating, 0.01),
		"served": served,
		"lost": lost,
		"breakdown": today.duplicate(),
	}
	history.append(rec)
	if history.size() > 60:
		history = history.slice(history.size() - 60)
	return rec


func to_dict() -> Dictionary:
	return {"history": history}


func from_dict(d: Dictionary) -> void:
	history = d.get("history", [])
