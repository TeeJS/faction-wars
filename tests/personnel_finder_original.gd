extends SceneTree
## The Personnel Finder as the original's (manual p099 Fig. 3.42; TeeJ,
## 2026-09-24: "Char Info should be renamed Personnel Finder and should have
## the same UI as the original - note the side buttons for characters and
## Special Forces"): the bottom bar's button opens it; a tab per side; the
## characters in play, "Name - Location" (none not yet recruited); the side
## buttons switch to the special forces grid and back; theirs only as sighted.
## Writes and removes its own test art.
##
##   .\tools\run-gd.ps1 tests/personnel_finder_original.gd

const Art := preload("res://src/ui/artwork.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[personnel_finder_original] ok   %s" % what)
	else:
		_fails += 1
		print("[personnel_finder_original] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = "user://test-personnel-finder-art"
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	var sets: Array = FactionRegistry.Pack.Manifest.ArtSets
	var dir := "%s/%s" % [Art.UserArtRoot, sets[0] if not sets.is_empty() else "swr-original"]
	for sub in ["windows", "tabs", "buttons"]:
		DirAccess.make_dir_recursive_absolute("%s/%s" % [dir, sub])
	_png("%s/windows/finder_side4.alliance.png" % dir, 58, 330, Color(0.5, 0.5, 0.6))
	for side in ["alliance", "empire"]:
		_png("%s/windows/frame.%s.png" % [dir, side], 470, 331, Color(0.4, 0.4, 0.4, 0.5))
		for w in ["finder_personnel", "finder_specforces"]:
			_png("%s/windows/%s.%s.png" % [dir, w, side], 400, 306, Color(0.1, 0.1, 0.4))
		for b in ["ency_close", "finder_display", "finder_btn_characters", "finder_btn_specforces"]:
			_png("%s/buttons/%s.%s.png" % [dir, b, side], 32, 31, Color(0.6, 0.6, 0.6))
			_png("%s/buttons/%s.%s.pressed.png" % [dir, b, side], 32, 31, Color(0.9, 0.3, 0.3))
	for t in ["finder_tab_rebel", "finder_tab_imperial"]:
		for st in ["", ".pressed", ".grey"]:
			_png("%s/tabs/%s%s.png" % [dir, t, st], 49, 41, Color(0.3, 0.3, 0.3))
	for b in ["scroll_up", "scroll_down", "scroll_thumb_top", "scroll_thumb_mid", "scroll_thumb_bottom"]:
		_png("%s/buttons/%s.png" % [dir, b], 13, 9, Color(0.5, 0.5, 0.5))
	Art.Reset()

	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 5:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	var viewer: Faction = GameSettings.PlayerFaction
	var btn: Button = main.get_node("%CharInfo")
	_check(btn.text == "Personnel Finder", "the bottom bar's button says 'Personnel Finder' ('%s')" % btn.text)
	btn.pressed.emit()
	for _i in 3:
		await process_frame
	var w: PersonnelFinder = Lq.first_or_null(ui.get_children(), func(n: Node) -> bool: return n is PersonnelFinder)
	_check(w != null and not w._o.is_empty(), "it opens the Personnel Finder, the original's")
	if w == null or w._o.is_empty():
		_finish()
		return
	var body: Control = w._o["body"]
	_check((body.get_node("Title") as Label).text == "Personnel Finder" and (body.get_node("NameLabel") as Label).text == "Name",
		"titled 'Personnel Finder', its field 'Name'")
	_check(w._tab == FactionRegistry.Playable.find(viewer) and not w.SpecForces, "our side's characters first")
	var inPlay: int = Lq.count(GameState.ActiveRoster, func(c: Character) -> bool:
		return c.Faction == viewer and c.Attached != null and not c.IsOffMap() and c.Status != Enums.Status.Dead)
	_check(w._shown.size() == inPlay and Lq.all(w._shown, func(e: PersonnelFinder.Entry) -> bool: return not e.Text.ends_with("Unknown")),
		"our characters in play, none not yet recruited (%d)" % inPlay)
	_check(w._o["list"].get_selected_items().is_empty(), "none picked on opening")

	(w._o["buttons"]["finder_btn_specforces"] as TextureButton).pressed.emit()
	_check(w.SpecForces and w._grid.visible and not (w._o["list"] as Control).visible, "the Special Forces button shows the grid")
	_check((w._o["buttons"]["finder_btn_specforces"] as TextureButton).texture_normal == w._o["buttons"]["finder_btn_specforces"].get_meta("pressed_tex"),
		"its button lit")
	var ours := 0
	for p in GameState.AllPlanets():
		ours += Lq.count(p.SpecForces(), func(u: Unit) -> bool: return u.Faction == viewer)
	var counted := 0
	for e in PersonnelFinder.SpecForceRows(viewer):
		for n in (e as PersonnelFinder.Entry).Counts.values():
			counted += int(n)
	_check(counted >= ours, "our special forces counted (%d on worlds)" % ours)
	(w._o["buttons"]["finder_btn_characters"] as TextureButton).pressed.emit()
	_check(not w.SpecForces and (w._o["list"] as Control).visible, "the Characters button back")

	# Theirs: only sighted.
	var them: Faction = Lq.first_or_null(FactionRegistry.Playable, func(f: Faction) -> bool: return f != viewer)
	var seen: Dictionary = w._EnemySightings(viewer)
	_check(Lq.all(w.CharactersOf(them), func(e: PersonnelFinder.Entry) -> bool: return seen.has(e.Char.Name)), "their characters only as sighted")
	_finish()


func _finish() -> void:
	_remove(Art.UserArtRoot)
	Art.Reset()
	print("[personnel_finder_original] %d checks, %d failed" % [_checks, _fails])
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
