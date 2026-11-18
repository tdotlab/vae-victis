extends SceneTree
## Headless test runner. Usage (from the repo root):
##   tools/test.sh            (imports the project, then runs this)
## Runs every res://tests/test_*.gd file; each test_* method is one test.
## Optional filter: pass "-- --only=<substring>" to run matching files.

## Counts engine and script errors so a test that crashes mid-way fails
## instead of silently passing.
class ErrorCounter extends Logger:
	var count := 0
	var last := ""
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		count += 1
		last = "%s (%s:%d %s)" % [rationale if rationale != "" else code, file.get_file(), line, function]
	func _log_message(_message: String, _error: bool) -> void:
		pass


func _initialize() -> void:
	var errors := ErrorCounter.new()
	OS.add_logger(errors)
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	var files: Array[String] = []
	var dir := DirAccess.open("res://tests")
	for f in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd") and f != "test_case.gd":
			if only == "" or f.contains(only):
				files.append(f)
	files.sort()
	var total := 0
	var failed := 0
	var messages: Array[String] = []
	for f in files:
		var before_load := errors.count
		var script: GDScript = load("res://tests/" + f)
		if script == null or not script.can_instantiate() or errors.count > before_load:
			messages.append("%s: failed to load" % f)
			failed += 1
			continue
		var methods: Array[String] = []
		for m in script.get_script_method_list():
			var n: String = m["name"]
			if n.begins_with("test_") and not methods.has(n):
				methods.append(n)
		methods.sort()
		for m in methods:
			var inst = script.new()
			inst.current_test = "%s::%s" % [f.get_basename(), m]
			var before := errors.count
			inst.call(m)
			total += 1
			if errors.count > before:
				inst.failures.append("%s: script error: %s" % [inst.current_test, errors.last])
			if not inst.failures.is_empty():
				failed += 1
				messages.append_array(inst.failures)
	for msg in messages:
		printerr("FAIL " + msg)
	print("%d tests, %d failed" % [total, failed])
	quit(1 if failed > 0 else 0)
