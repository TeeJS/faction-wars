extends SceneTree
## Compile check for the UI scripts: loads every .gd under src/ui and reports
## the ones that fail to parse. A window that does not compile cannot be
## instantiated, so this runs before the smoke test.
##
##   Godot_console.exe --headless --path . -s tests/ui_compile.gd


func _init() -> void:
	var failed: Array[String] = []
	var n := 0
	for path in _scripts("res://src/ui"):
		n += 1
		var s: Variant = load(path)
		if s == null or not (s is GDScript) or not s.can_instantiate():
			failed.append(path)
	print("[ui_compile] %d scripts, %d failed" % [n, failed.size()])
	for f in failed:
		print("  FAIL %s" % f)
	quit(1 if not failed.is_empty() else 0)


func _scripts(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir + "/" + d))
	return out
