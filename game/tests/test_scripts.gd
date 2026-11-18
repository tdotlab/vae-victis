extends TestCase
## Every script under res://src must compile. Catches typos in UI code that
## the rule tests never load.


func test_all_scripts_compile() -> void:
	var stack: Array[String] = ["res://src"]
	var n := 0
	while not stack.is_empty():
		var d: String = stack.pop_back()
		var dir := DirAccess.open(d)
		for sub in dir.get_directories():
			stack.append(d + "/" + sub)
		for f in dir.get_files():
			if f.ends_with(".gd"):
				var s: GDScript = load(d + "/" + f)
				check(s != null and s.can_instantiate(), "%s/%s compiles" % [d, f])
				n += 1
	check(n > 10, "found scripts")
