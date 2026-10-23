class_name BT
extends RefCounted
## Tiny behaviour-tree library. Nodes tick against an `actor` and return a Status.

enum Status { SUCCESS, FAILURE, RUNNING }


class BTNode extends RefCounted:
	var label: String = ""
	func tick(_actor, _delta: float) -> int:
		return Status.FAILURE


## Runs children in order; succeeds on the first child that succeeds or runs.
class Selector extends BTNode:
	var children: Array = []
	func _init(p_label: String, p_children: Array) -> void:
		label = p_label
		children = p_children
	func tick(actor, delta: float) -> int:
		for c in children:
			var s: int = c.tick(actor, delta)
			if s != Status.FAILURE:
				return s
		return Status.FAILURE


## Runs children in order; fails on the first child that fails.
class Sequence extends BTNode:
	var children: Array = []
	func _init(p_label: String, p_children: Array) -> void:
		label = p_label
		children = p_children
	func tick(actor, delta: float) -> int:
		for c in children:
			var s: int = c.tick(actor, delta)
			if s != Status.SUCCESS:
				return s
		return Status.SUCCESS


## Calls actor.<method>() -> bool.
class Condition extends BTNode:
	var method: StringName
	func _init(p_method: StringName) -> void:
		method = p_method
		label = str(p_method)
	func tick(actor, _delta: float) -> int:
		return Status.SUCCESS if actor.call(method) else Status.FAILURE


## Calls actor.<method>(delta) -> Status.
class Action extends BTNode:
	var method: StringName
	func _init(p_method: StringName) -> void:
		method = p_method
		label = str(p_method)
	func tick(actor, delta: float) -> int:
		return actor.call(method, delta)
