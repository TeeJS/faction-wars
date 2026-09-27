extends SceneTree
## The opening briefing (docs/advisor-plan.md, phase 4; manual p022), on
## synthetic stand-ins - the test tone (tests/fixtures/music_test.ogg) for the
## recordings, a 4x3 two-frame run for the animations, a plain Command Center
## frame with its droids - never the original's:
##   - pack.json `briefing` is the original's script: 16 lines a side, in its
##     order, and the skip's line; rule 28 refuses bad briefings;
##   - a new game with the recordings: the agent droid speaks the lines in
##     order in its own place, the clock held and the droids' news waiting;
##   - each focus step puts its view on the display (the pack's `views`, as
##     recordings of the original show): the display off, a mode, a caption
##     with the systems it names lit; at the end the display is as it was;
##   - Esc skips: the line stops and the skip's plays; then, in an Easy game
##     (Agent Advice on, manual p022), the Message Index opens on Agent Advice,
##     and the clock runs; in Medium no Message Index opens (the original's);
##   - a left click skips too, and a second skip ends it at once;
##   - without the recordings there is no briefing, and a loaded game has none.
## Writes and removes its own files under user://.
##
##   .\tools\run-gd.ps1 tests/briefing.gd

const SoundLib := preload("res://src/ui/sound.gd")
const MusicLib := preload("res://src/ui/music.gd")
const Art := preload("res://src/ui/artwork.gd")
const BriefingScript := preload("res://src/ui/briefing.gd")
const Tone := "res://tests/fixtures/music_test.ogg"
const ArtRoot := "user://test-briefing-art"
const Settings := "user://test-briefing.cfg"
const Frames := 30
const Order := ["Loyalty", "Fleets", "Missions", "Resources", "Manufacturing", "Defense", "Conflict", "Advice", "Chat"]

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[briefing] ok   %s" % what)
	else:
		_fails += 1
		print("[briefing] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = ArtRoot
	_remove(ArtRoot)
	MusicLib.SettingsFile = Settings
	DirAccess.remove_absolute(Settings)
	SoundLib._loaded = false
	SoundLib.PlayHeadless = true
	FactionRegistry.EnsureLoaded()
	var m: PackDefs.PackManifest = FactionRegistry.Pack.Manifest

	# The pack's briefing: the original's script, both sides.
	var al: Dictionary = m.Briefing.get("alliance", {})
	var em: Dictionary = m.Briefing.get("empire", {})
	var al_lines: Array = (al.get("steps", []) as Array).filter(func(s: Dictionary) -> bool: return s.has("sound"))
	var em_lines: Array = (em.get("steps", []) as Array).filter(func(s: Dictionary) -> bool: return s.has("sound"))
	_check(m.BriefingGiven and not m.Briefing.has("_comment") and (al["steps"] as Array).size() == 34 and al_lines.size() == 16 and em_lines.size() == 16,
		"the Star Wars pack's briefing: 34 steps a side, 16 of them lines, the comment left out")
	_check(int(al["steps"][0].get("focus", -1)) == 12 and al_lines[0] == {"anim": "swr-original:anim/albrief/2101.fwa", "sound": "swr-original:sound/albrief/1155.ogg"}
		and al_lines[15]["sound"] == "swr-original:sound/albrief/1168.ogg",
		"the Alliance's opens on a focus, then C-3PO's first line (1155, run 2101); its last is 1168")
	_check(em_lines[0] == {"anim": "swr-original:anim/embrief/2100.fwa", "sound": "swr-original:sound/embrief/1147.ogg"},
		"the Empire's first line is IMP-22's 1147 (run 2100)")
	_check((al["skip"] as Array).size() == 3 and al["skip"][1]["sound"] == "swr-original:sound/albrief/1165.ogg"
		and em["skip"][1]["sound"] == "swr-original:sound/embrief/1157.ogg", "the skip's line: 1165 / 1157")
	_check((al["views"] as Dictionary).size() == 16 and (em["views"] as Dictionary).size() == 16
		and al["views"]["18"] == {"caption": "Yavin", "show": "system:yavin"} and em["views"]["18"]["show"] == "system:coruscant"
		and em["views"]["4"]["show"] == "unexplored" and al["views"]["12"]["show"] == "off",
		"the views: 16 a side as the recordings show them - the Alliance's 18 Yavin, the Empire's Coruscant, its 4 Unexplored Systems")
	_Rules()

	# The stand-ins: a plain frame with its droids, three lines and the skip's.
	var dir := "%s/swr-original" % ArtRoot
	for sub in ["windows", "alerts"]:
		DirAccess.make_dir_recursive_absolute("%s/%s" % [dir, sub])
	var side := "alliance"
	var win: Rect2 = CommandFrame.Layout[side]["window"]
	var img := Image.create(640, 481, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.6, 0.6, 0.62))
	img.fill_rect(Rect2i(win), Color(0, 0, 0, 0))
	img.save_png("%s/windows/command.%s.png" % [dir, side])
	for c in Order:
		_png("%s/alerts/%s.%s.png" % [dir, side, c.to_lower()], 27, 22, Color(0.1, 0.1, 0.1))
		_png("%s/alerts/%s.%s.lit.png" % [dir, side, c.to_lower()], 27, 22, Color(1, 0.8, 0))
	for role in ["agent", "messenger"]:
		var r: Rect2 = CommandFrame.Layout[side][role]
		_png("%s/windows/droid_%s.%s.png" % [dir, role, side], int(r.size.x) * 2, int(r.size.y), Color(0.8, 0.7, 0.2))
	var tone := FileAccess.get_file_as_bytes(Tone)
	var run := _run_file()
	for i in 3:
		_stand_in(str(al_lines[i]["sound"]), tone)
		_stand_in(str(al_lines[i]["anim"]), run)
	_stand_in(str(al["skip"][1]["sound"]), tone)
	_stand_in(str(al["skip"][1]["anim"]), run)
	# One opening advice message, so the Message Index has it to open on.
	_stand_in("swr-original:advice.json", JSON.stringify({"alliance": [{"n": 1, "group": 7, "key": 10, "title": "Tip", "text": "Advice."}]}).to_utf8_buffer())
	Art.Reset()

	# A new game in Easy: the briefing plays.
	var main: Node = await _start(side, Enums.Difficulty.Easy)
	var ui: UIManager = main.get_node("UIManager")
	var b: Control = ui.get_node_or_null("Briefing")
	var advisor: Node = ui.get_node_or_null("Advisor")
	var agent: Node = advisor.Agent if advisor != null else null
	_check(b != null and agent != null, "a new game with the recordings: the briefing starts")
	if b == null or agent == null:
		_finish(main)
		return
	_check(b.anchor_left == 0.0 and b.anchor_top == 0.0 and b.anchor_right == 1.0 and b.anchor_bottom == 1.0 and b.mouse_filter == Control.MOUSE_FILTER_STOP,
		"... over the whole screen: a click anywhere is the briefing's")
	_check(agent.Talking() and _playing(al_lines[0]["sound"]) and b.At() == 1, "C-3PO speaks the first line in his own place (its animation and its recording)")
	var map: GalaxyMap = ui.ActiveGalaxyMap
	var before: Gid.GidMode = Gid.ActiveMode()
	_check(map != null and bool(map.ViewShown().get("off", false)), "his introduction: the display off (focus 12)")
	_check(main._briefing and main._tickTimer.is_stopped() and advisor.Held, "the clock is held and the droids keep their news")
	var day: int = StrategicTickManager.Today
	var second := await _until(func() -> bool: return _playing(al_lines[1]["sound"]), 8.0)
	_check(second and b.At() == 3 and StrategicTickManager.Today == day, "then the second line (past the focus between them); no day has passed")
	_check(map.ViewShown().is_empty() and Gid.ActiveMode() != null and Gid.ActiveMode().Id == "popular_support", "... over Popular Support (focus 1)")
	var third := await _until(func() -> bool: return _playing(al_lines[2]["sound"]), 8.0)
	var lit: Dictionary = map.ViewShown().get("lit", {})
	var ours: Faction = FactionRegistry.ById("alliance")
	_check(third and str(map.ViewShown().get("caption", "")) == "Systems Loyal to the Alliance" and not lit.is_empty()
		and Lq.all(lit.keys(), func(p: Planet) -> bool: return p.ControllingFaction == ours and lit[p] == ours.ArtSkin),
		"the third line: \"Systems Loyal to the Alliance\", only the Alliance's systems lit (%d)" % lit.size())

	# Esc: the line stops, the skip's plays.
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	root.push_input(esc)
	await process_frame
	await process_frame
	_check(b.Skipped() and not _playing(al_lines[2]["sound"]) and _playing(al["skip"][1]["sound"]),
		"Esc: the line stops and the skip's plays (\"I do hope you know what you're doing\")")
	var ended := await _until(func() -> bool: return ui.get_node_or_null("Briefing") == null, 8.0)
	await process_frame
	_check(ended and ui.get_node_or_null("Briefing") == null, "then the briefing is over")
	var comms: Node = ui._openWindows.get("Communications")
	_check(comms != null and is_instance_valid(comms) and _category(comms) == "Advice", "the Message Index opens on Agent Advice (%s)" % (_category(comms) if comms != null else "none"))
	_check(not main._briefing and not main._tickTimer.is_stopped() and not advisor.Held, "the clock runs again and the droids may speak")
	_check(map.ViewShown().is_empty() and Gid.ActiveMode() == before, "the display is as it was before the briefing")
	_Views(map)
	await _stop(main)

	# A left click skips too; a second skip ends it at once.
	main = await _start(side, Enums.Difficulty.Easy)
	ui = main.get_node("UIManager")
	b = ui.get_node_or_null("Briefing")
	_check(b != null, "another new game: the briefing again")
	if b != null:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = Vector2(20, 20)
		b._gui_input(click)
		await process_frame
		_check(b.Skipped() and _playing(al["skip"][1]["sound"]), "a left click skips it")
		b.Skip()
		await process_frame
		await process_frame
		_check(ui.get_node_or_null("Briefing") == null and not main._briefing and ui._openWindows.get("Communications") != null,
			"a second skip during the skip's line ends it at once, and the Message Index opens")
	await _stop(main)

	# Medium: Agent Advice starts off, and after the briefing no Message Index.
	main = await _start(side, Enums.Difficulty.Medium)
	ui = main.get_node("UIManager")
	b = ui.get_node_or_null("Briefing")
	var started := b != null
	if started:
		b.Skip()
		await process_frame
		b.Skip()
		for _i in 3:
			await process_frame
	_check(started and ui.get_node_or_null("Briefing") == null and ui._openWindows.get("Communications") == null and not main._briefing,
		"Medium: the briefing plays and ends; no Message Index opens (Agent Advice off, as the original's)")
	await _stop(main)

	# Without the recordings: none.
	_remove("%s/sound" % dir)
	main = await _start(side, Enums.Difficulty.Medium)
	ui = main.get_node("UIManager")
	_check(ui.get_node_or_null("Briefing") == null and not main._briefing, "without the art set's recordings: no briefing, the clock runs")
	await _stop(main)
	_finish(null)


## What each view lights, on the game running.
func _Views(map: GalaxyMap) -> void:
	var yavin: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool: return p.PackId == "yavin")
	var one: Dictionary = BriefingScript.Lit("system:yavin")
	_check(one.size() == 1 and one.has(yavin), "system:yavin lights Yavin alone")
	var hq: Dictionary = BriefingScript.Lit("hq:alliance")
	_check(hq.size() == 1 and (hq.keys()[0] as Planet).HasHeadquarters(), "hq:alliance lights the Alliance's headquarters")
	var luke: Character = Lq.first_or_null(GameState.ActiveRoster, func(c: Character) -> bool: return c.PackId == "luke_skywalker")
	var at: Dictionary = BriefingScript.Lit("character:luke_skywalker")
	_check(luke != null and at.size() == 1 and at.has(OrderManager.SystemOf(luke.Attached)), "character:luke_skywalker lights his system")
	var dark: Dictionary = BriefingScript.Lit("unexplored")
	_check(not dark.is_empty() and Lq.all(dark.keys(), func(p: Planet) -> bool: return not p.IsExplored) and Lq.all(dark.values(), func(s: String) -> bool: return s == "neutral"),
		"unexplored lights the unexplored systems, in neutral's star (%d)" % dark.size())
	var held: Dictionary = BriefingScript.Lit("military")
	_check(Lq.all(held.keys(), func(p: Planet) -> bool: return p.GarrisonRequirement() > 0), "military lights only systems held short of support (%d)" % held.size())
	map.ShowView("Test", one, false)
	_check(map.VisualSignature().begins_with("view|Test"), "a view shows its caption")
	map.ShowView("", {}, true)
	_check(bool(map.ViewShown().off), "the off view")
	map.ClearView()
	_check(map.ViewShown().is_empty(), "and back")


func _Rules() -> void:
	var pack: PackLoader.LoadedPack = FactionRegistry.Pack
	var m := pack.Manifest
	var saved: Variant = m.BriefingRaw
	var line := {"anim": "swr-original:anim/albrief/2101.fwa", "sound": "swr-original:sound/albrief/1155.ogg"}
	var cases := [
		[{"alliance": {"steps": [{"focus": 12}, line], "skip": [line]}}, ""],
		["no", "must be an object"],
		[{"rebels": {}}, "is not a faction"],
		[{"alliance": []}, "must be an object (steps, skip)"],
		[{"alliance": {"prologue": []}}, "neither steps, skip nor views"],
		[{"alliance": {"views": {"12": {"show": "off"}, "14": {"caption": "Ours", "show": "loyal:alliance"}, "18": {"show": "system:yavin"},
			"7": {"show": "character:mon_mothma"}, "1": {"show": "mode:popular_support"}, "3": {"show": "hq:empire"}}}}, ""],
		[{"alliance": {"views": []}}, "must be an object of focus number -> view"],
		[{"alliance": {"views": {"first": {"show": "off"}}}}, "the key must be a focus number"],
		[{"alliance": {"views": {"1": {"caption": "x"}}}}, "must be an object with a show"],
		[{"alliance": {"views": {"1": {"show": "sparkle"}}}}, "is not a view"],
		[{"alliance": {"views": {"1": {"show": "system:alderaan_two"}}}}, "names nothing this pack has"],
		[{"alliance": {"views": {"1": {"show": "mode:weather"}}}}, "names nothing this pack has"],
		[{"alliance": {"steps": "all of it"}}, "must be a list"],
		[{"alliance": {"steps": [7]}}, "must be an object"],
		[{"alliance": {"steps": [{"focus": "Yavin"}]}}, "focus: must be a number"],
		[{"alliance": {"steps": [{"pause": 2}]}}, "neither a focus nor a line"],
		[{"alliance": {"steps": [{"sound": "swr-original:sound/albrief/1155.wav"}]}}, "is not a .ogg file"],
		[{"alliance": {"steps": [{"anim": "other-set:anim/albrief/2101.fwa"}]}}, "which art_sets does not declare"],
	]
	for c in cases:
		var errors: Array[String] = []
		m.BriefingRaw = c[0]
		m.BriefingGiven = true
		PackLoader._validate_briefing(pack, FactionRegistry.LoadedDir, errors)
		var want: String = c[1]
		var ok: bool = errors.is_empty() if want.is_empty() else (errors.size() >= 1 and errors[0].contains(want))
		_check(ok, "rule 28: %s -> %s" % [JSON.stringify(c[0]), str(errors) if not errors.is_empty() else "accepted"])
	m.BriefingRaw = saved


func _category(w: Node) -> String:
	if w == null or not is_instance_valid(w):
		return ""
	if w._original:
		return str(w._oCategory)
	var tc: TabContainer = w._tabContainer
	return str(tc.get_child(tc.current_tab).name)


func _start(side: String, difficulty: int) -> Node:
	Art.Reset()
	MpSetup.reset()
	GameSettings.PendingLoadPath = ""
	GameSettings.SelectedDifficulty = difficulty
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	GameSettings.PlayerFaction = FactionRegistry.ById(side)
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 6:
		await process_frame
	return main


func _stop(main: Node) -> void:
	for p in _sounds():
		p.queue_free()
	main.queue_free()
	for _i in 3:
		await process_frame


## A 4x3 run of Frames frames (as tests/advisor.gd's, longer): 2 seconds, so
## the agent is still talking when first looked at.
func _run_file() -> PackedByteArray:
	var b := PackedByteArray()
	b.append_array("FWA1".to_ascii_buffer())
	for v in [4, 3, Frames]:
		b.append(v & 0xFF)
		b.append(v >> 8)
	var palette := PackedByteArray()
	palette.resize(768)
	palette[3] = 255
	palette[7] = 255
	b.append_array(palette)
	b.append_array(PackedByteArray([0, 1, 1, 0, 1, 1, 1, 1, 0, 1, 1, 0]))
	var frame := PackedByteArray()
	frame.resize(17)
	frame.encode_u16(0, 4)
	frame.encode_u16(2, 3)
	frame.encode_u32(4, 6)
	for off in [0, 4, 5]:
		var o := PackedByteArray()
		o.resize(4)
		o.encode_u32(0, off)
		frame.append_array(o)
	frame.append_array(PackedByteArray([1, 1, 1, 2, 4, 4]))
	var length := PackedByteArray()
	length.resize(4)
	length.encode_u32(0, frame.size())
	for _i in Frames - 1:
		b.append_array(length)
		b.append_array(frame)
	return b


func _stand_in(ref: String, bytes: PackedByteArray) -> void:
	var split: PackedStringArray = PackLoader.SplitArtRef(ref)
	var path := "%s/%s/%s" % [ArtRoot, split[0], split[1]]
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()


func _sounds() -> Array:
	return root.get_children().filter(func(n: Node) -> bool: return n is AudioStreamPlayer and n.has_meta("path") and (n as AudioStreamPlayer).playing)


func _playing(ref: Variant) -> bool:
	var file := SoundLib.FileOf(str(ref))
	return not file.is_empty() and _sounds().any(func(p: AudioStreamPlayer) -> bool: return str(p.get_meta("path", "")) == file)


func _until(cond: Callable, seconds: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < seconds * 1000.0:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func _finish(main: Node) -> void:
	if main != null:
		main.queue_free()
	_remove(ArtRoot)
	DirAccess.remove_absolute(Settings)
	MusicLib.SettingsFile = MusicLib.SETTINGS
	SoundLib._loaded = false
	SoundLib.PlayHeadless = false
	Art.Reset()
	print("[briefing] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


static func _png(path: String, w: int, h: int, color: Color) -> void:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(color)
	img.save_png(path)


static func _remove(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in DirAccess.get_directories_at(path):
		_remove("%s/%s" % [path, sub])
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute("%s/%s" % [path, file])
	DirAccess.remove_absolute(path)
