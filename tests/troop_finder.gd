extends SceneTree
## The Troop Finder (manual p132 Fig. 3.80; TeeJ, 2026-09-24: "troop info
## should be renamed Troop Finder and should be implemented with the same UI as
## the original"): the bottom bar's button opens it; a tab per side; a row per
## system or fleet holding that side's regiments, a count under each type's
## icon in the band's order; theirs only as sighted; Display opens the System
## Defenses (a system) or Fleet window (a fleet). Writes and removes its own
## test art.
##
##   .\tools\run-gd.ps1 tests/troop_finder.gd

const Art := preload("res://src/ui/artwork.gd")
const OUI := preload("res://src/ui/original_ui.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[troop_finder] ok   %s" % what)
	else:
		_fails += 1
		print("[troop_finder] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = "user://test-troop-finder-art"
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	var sets: Array = FactionRegistry.Pack.Manifest.ArtSets
	var dir := "%s/%s" % [Art.UserArtRoot, sets[0] if not sets.is_empty() else "swr-original"]
	for sub in ["windows", "tabs", "buttons"]:
		DirAccess.make_dir_recursive_absolute("%s/%s" % [dir, sub])
	_png("%s/windows/finder_side2.alliance.png" % dir, 58, 330, Color(0.5, 0.5, 0.6))
	for side in ["alliance", "empire"]:
		_png("%s/windows/frame.%s.png" % [dir, side], 470, 331, Color(0.4, 0.4, 0.4, 0.5))
		_png("%s/windows/finder_troops.%s.png" % [dir, side], 400, 306, Color(0.1, 0.1, 0.4))
		for b in ["ency_close", "finder_display"]:
			_png("%s/buttons/%s.%s.png" % [dir, b, side], 32, 31, Color(0.6, 0.6, 0.6))
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
	var btn: Button = main.get_node("UIManager/HBoxContainer/TroopInfo")
	_check(btn.text == "Troop Finder", "the bottom bar's button says 'Troop Finder' ('%s')" % btn.text)
	btn.pressed.emit()
	for _i in 3:
		await process_frame
	var w: TroopFinder = Lq.first_or_null(ui.get_children(), func(n: Node) -> bool: return n is TroopFinder)
	_check(w != null and not w._o.is_empty(), "it opens the Troop Finder, the original's")
	if w == null or w._o.is_empty():
		_finish()
		return
	var body: Control = w._o["body"]
	_check((body.get_node("Title") as Label).text == "Troop Finder" and (body.get_node("NameLabel") as Label).text == "Troop Location",
		"titled 'Troop Finder', its field 'Troop Location'")
	_check(w._o["tabs"].size() == 2 and TroopFinder.Caption(0).ends_with(" Troops"), "two tabs: %s, %s" % [TroopFinder.Caption(0), TroopFinder.Caption(1)])
	_check(w._tab == FactionRegistry.Playable.find(viewer), "our own side's tab first")

	# Our regiments, every one, by system and fleet.
	var rows: Array = TroopFinder.RowsFor(viewer)
	var listed := 0
	for r in rows:
		for n in (r as TroopFinder.Row).Counts.values():
			listed += int(n)
	var have := 0
	for p in GameState.AllPlanets():
		have += Lq.count(p.Troopers(), func(u: Unit) -> bool: return u.Faction == viewer)
		for f in p.OrbitingFleets:
			if f.Faction == viewer:
				for s in f.Ships:
					have += Lq.count([s] + s.Hangar, func(u: Unit) -> bool: return u.Type == Enums.UnitType.Troop)
	_check(listed == have and have > 0, "every regiment of ours is counted (%d)" % have)
	var skin: String = OUI.Side(viewer)
	var inColumns := 0
	for r in rows:
		for n in TroopFinder.CountsOf(r, skin):
			inColumns += int(n)
	_check(inColumns == have, "each under its own type's column")

	# The opponent's only as sighted on a system.
	var them: Faction = Lq.first_or_null(FactionRegistry.Playable, func(f: Faction) -> bool: return f != viewer)
	var unseen := 0
	for r in TroopFinder.RowsFor(them):
		var row: TroopFinder.Row = r
		if row.Fleet_ == null and not IntelManager.IsLive(viewer, row.Where) and not IntelManager.View(viewer, row.Where, Enums.IntelSection.Troopers).Known:
			unseen += 1
	_check(unseen == 0, "no opponent's regiments we have not seen")

	# Display a system of ours: its System Defenses window.
	var at: int = -1
	for i in w._shown.size():
		if (w._shown[i] as TroopFinder.Row).Fleet_ == null:
			at = i
			break
	if at >= 0:
		w._o["list"].call("select", at)
		(w._o["buttons"]["finder_display"] as TextureButton).pressed.emit()
		for _i in 3:
			await process_frame
		_check(Lq.any(ui.get_children(), func(n: Node) -> bool: return n is DefenseWindow), "Display opens the system's System Defenses window")
	_finish()


func _finish() -> void:
	_remove(Art.UserArtRoot)
	Art.Reset()
	print("[troop_finder] %d checks, %d failed" % [_checks, _fails])
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
