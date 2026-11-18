class_name Inventory
extends RefCounted
## A bag of stacked items: item id -> count, in insertion order.

var _counts: Dictionary = {}


func add(id: String, n: int = 1) -> void:
	if n <= 0 or id == "":
		return
	_counts[id] = int(_counts.get(id, 0)) + n


func remove(id: String, n: int = 1) -> bool:
	var have: int = _counts.get(id, 0)
	if have < n:
		return false
	if have == n:
		_counts.erase(id)
	else:
		_counts[id] = have - n
	return true


func count(id: String) -> int:
	return int(_counts.get(id, 0))


func ids() -> Array:
	return _counts.keys()


func is_empty() -> bool:
	return _counts.is_empty()


func total_weight() -> float:
	var w := 0.0
	for id in _counts:
		w += float(DB.item(id).get("weight", 0)) * _counts[id]
	return w


func total_value() -> int:
	var v := 0
	for id in _counts:
		v += int(DB.item(id).get("value", 0)) * int(_counts[id])
	return v


func merge(other: Inventory) -> void:
	for id in other.ids():
		add(id, other.count(id))


func clear() -> void:
	_counts.clear()


func to_array() -> Array:
	var out := []
	for id in _counts:
		out.append([id, _counts[id]])
	return out


static func from_array(arr: Array) -> Inventory:
	var inv := Inventory.new()
	for e in arr:
		inv.add(str(e[0]), int(e[1]))
	return inv
