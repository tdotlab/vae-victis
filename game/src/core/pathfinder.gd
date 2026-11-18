class_name Pathfinder
extends RefCounted
## A* over a MapData hex grid.


## Path from start to goal, excluding start. Empty if unreachable.
## blocked: cells that can't be entered (occupied by others). The goal may be
## blocked when allow_blocked_goal is set (to walk up next to someone).
static func find_path(map: MapData, start: Vector2i, goal: Vector2i, blocked: Dictionary = {}, max_cost: int = 400, stop_adjacent: bool = false) -> Array[Vector2i]:
	var empty: Array[Vector2i] = []
	if start == goal:
		return empty
	if not stop_adjacent and (not map.is_walkable(goal) or blocked.has(goal)):
		return empty
	var open := _Heap.new()
	var came: Dictionary = {}
	var cost: Dictionary = {start: 0}
	open.push(start, Hex.distance(start, goal))
	var found := Vector2i(-99999, -99999)
	while not open.is_empty():
		var cur: Vector2i = open.pop()
		if cur == goal or (stop_adjacent and Hex.distance(cur, goal) == 1):
			found = cur
			break
		var cc: int = cost[cur]
		if cc > max_cost:
			continue
		for n in Hex.neighbors(cur):
			if not map.is_walkable(n) or blocked.has(n):
				continue
			var nc := cc + map.move_cost(n)
			if nc < int(cost.get(n, 1 << 30)):
				cost[n] = nc
				came[n] = cur
				open.push(n, nc + Hex.distance(n, goal))
	if found.x == -99999:
		return empty
	var path: Array[Vector2i] = []
	var c := found
	while c != start:
		path.push_front(c)
		c = came[c]
	return path


## Total movement cost of walking a path (excludes the start cell).
static func path_cost(map: MapData, path: Array[Vector2i]) -> int:
	var t := 0
	for c in path:
		t += map.move_cost(c)
	return t


class _Heap:
	var _items: Array = []  # [priority, seq, value]
	var _seq := 0

	func is_empty() -> bool:
		return _items.is_empty()

	func push(v: Variant, pri: int) -> void:
		_seq += 1
		_items.append([pri, _seq, v])
		var i := _items.size() - 1
		while i > 0:
			var p := (i - 1) / 2
			if _less(_items[i], _items[p]):
				var t = _items[i]
				_items[i] = _items[p]
				_items[p] = t
				i = p
			else:
				break

	func pop() -> Variant:
		var top = _items[0][2]
		var last = _items.pop_back()
		if not _items.is_empty():
			_items[0] = last
			var i := 0
			var n := _items.size()
			while true:
				var l := 2 * i + 1
				var r := l + 1
				var m := i
				if l < n and _less(_items[l], _items[m]):
					m = l
				if r < n and _less(_items[r], _items[m]):
					m = r
				if m == i:
					break
				var t = _items[i]
				_items[i] = _items[m]
				_items[m] = t
				i = m
		return top

	func _less(a: Array, b: Array) -> bool:
		return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1])
