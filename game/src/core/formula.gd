class_name Formula
extends RefCounted
## Evaluates small arithmetic formulas from data files, such as
## "10 + 2*(STR+AGI)", against named integer inputs. Integer results.

static var _compiled: Dictionary = {}
const NAMES := ["STR", "END", "AGI", "PER", "WIT", "PRE", "FOR", "LVL"]


static func eval_int(expr: String, vars: Dictionary) -> int:
	var e: Expression = _compiled.get(expr)
	if e == null:
		e = Expression.new()
		var err := e.parse(expr, PackedStringArray(NAMES))
		if err != OK:
			push_error("Formula parse error in '%s': %s" % [expr, e.get_error_text()])
			return 0
		_compiled[expr] = e
	var inputs: Array = []
	for n in NAMES:
		# Floats so floor() and division behave; result is truncated to int.
		inputs.append(float(vars.get(n, 0)))
	var result = e.execute(inputs, null, false)
	if e.has_execute_failed():
		push_error("Formula exec error in '%s'" % expr)
		return 0
	return int(floor(result))
