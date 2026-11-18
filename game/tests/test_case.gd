class_name TestCase
extends RefCounted
## Minimal assertion base for the headless test runner. Test files extend
## this and define methods named test_*.

var failures: Array[String] = []
var current_test := ""


func fail(msg: String) -> void:
	failures.append("%s: %s" % [current_test, msg])


func check(cond: bool, msg: String = "expected true") -> void:
	if not cond:
		fail(msg)


func eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	if typeof(actual) != typeof(expected) and not (_is_num(actual) and _is_num(expected)):
		fail("%s expected %s (%s), got %s (%s)" % [msg, str(expected), type_string(typeof(expected)), str(actual), type_string(typeof(actual))])
	elif actual != expected:
		fail("%s expected %s, got %s" % [msg, str(expected), str(actual)])


func near(actual: float, expected: float, tol: float = 0.001, msg: String = "") -> void:
	if absf(actual - expected) > tol:
		fail("%s expected ~%s, got %s" % [msg, expected, actual])


func _is_num(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT
