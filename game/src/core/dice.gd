class_name Dice
extends RefCounted
## The one source of randomness for game rules. Seeded, so fights and
## checks can be replayed in tests.

var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = -1) -> void:
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()


func reseed(seed_value: int) -> void:
	_rng.seed = seed_value


## Integer in [lo, hi], inclusive.
func range_i(lo: int, hi: int) -> int:
	if hi <= lo:
		return lo
	return _rng.randi_range(lo, hi)


## Percentile roll: 1..100.
func d100() -> int:
	return _rng.randi_range(1, 100)


## True with the given percent chance (clamped 0..100).
func chance(percent: float) -> bool:
	return d100() <= int(round(clampf(percent, 0.0, 100.0)))


func pick(arr: Array) -> Variant:
	if arr.is_empty():
		return null
	return arr[_rng.randi_range(0, arr.size() - 1)]


func get_state() -> int:
	return _rng.state


func set_state(s: int) -> void:
	_rng.state = s
