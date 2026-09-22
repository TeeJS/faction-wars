extends SceneTree
## The pack hydration regression: load the active pack exactly as the game does,
## write every loaded file in canonical form, and compare it with the committed
## fixture. A DTO change that silently drops, renames or re-types a field shows
## up here as a diff. Run headless:
##
##   Godot_console.exe --headless --path . -s tests/dto_parity.gd
##   ... -s tests/dto_parity.gd -- --rebaseline     (rewrite the fixture; say so in the commit)
##   ... -s tests/dto_parity.gd -- --out=C:\path\gd-dto.json   (dump only)
##
## History: HANDOFF step 1A compared this dump with the C# source's own dump of
## data/*.json. That folder and its loaders are gone (2026-09-22); the pack is
## the only data the engine reads, so the fixture is the port's own.

const FIXTURE := "res://tests/fixtures/dto-pack.json"


func _init() -> void:
	var out_path := _arg("--out=")
	var rebaseline := OS.get_cmdline_user_args().has("--rebaseline")

	FactionRegistry.EnsureLoaded()
	var pack_id: String = str(JsonUtil.get_ci(JsonUtil.parse("res://packs/active.json"), "pack"))
	var errors: Array[String] = []
	var pack := PackLoader.Load("res://packs/%s" % pack_id, errors)
	if pack == null:
		push_error("[dto_parity] the pack did not load: %s" % ", ".join(errors))
		quit(2)
		return

	var dump := {
		"pack_manifest":  pack.Manifest,
		"factions":       pack.Factions,
		"map":            pack.Map,
		"characters":     pack.Characters,
		"facilities":     pack.Facilities,
		"units":          pack.Units,
		"weapons":        pack.Weapons,
		"missions":       pack.Missions,
		"mission_tables": pack.MissionTables,
		"rules":          pack.Rules,
		"setup":          pack.Setup,
		"display":        pack.Display,
	}
	var text := Canonical.to_json(dump)

	var counts := []
	for k in dump.keys():
		var v = dump[k]
		counts.append("%s=%d" % [k, v.size() if (v is Array or v is Dictionary) else 1])
	print("[dto_parity] pack '%s': %s" % [pack_id, ", ".join(counts)])

	if not out_path.is_empty():
		_write(out_path, text)
		quit(0)
		return
	if rebaseline:
		_write(FIXTURE, text)
		print("[dto_parity] fixture rewritten: %s" % FIXTURE)
		quit(0)
		return

	var expected := FileAccess.get_file_as_string(FIXTURE)
	if expected.is_empty():
		push_error("[dto_parity] no fixture at %s - run with --rebaseline once" % FIXTURE)
		quit(2)
		return
	if expected == text:
		print("[dto_parity] PASS: the loaded pack matches %s byte for byte" % FIXTURE)
		quit(0)
		return
	# Say WHERE, not just that.
	var a := expected.split("\n")
	var b := text.split("\n")
	var first := -1
	for i in mini(a.size(), b.size()):
		if a[i] != b[i]:
			first = i
			break
	if first < 0:
		first = mini(a.size(), b.size())
	print("[dto_parity] FAIL: differs from %s at line %d of %d/%d" % [FIXTURE, first + 1, a.size(), b.size()])
	print("  fixture: %s" % (a[first] if first < a.size() else "<end>"))
	print("  loaded:  %s" % (b[first] if first < b.size() else "<end>"))
	_write("user://dto-pack-actual.json", text)
	print("  full dump written to user://dto-pack-actual.json (tools/compare_json.py shows every field)")
	quit(1)


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("[dto_parity] cannot write %s" % path)
		quit(1)
		return
	f.store_string(text)
	f.close()


func _arg(prefix: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	for a in OS.get_cmdline_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return ""
