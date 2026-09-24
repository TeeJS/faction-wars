extends SceneTree
## The System Finder (manual p075, Fig. 3.12; TeeJ, 2026-09-24: "planet info
## should be renamed System Finder and match the original"): the bottom bar
## says "System Finder"; with the art imported the window is the original's -
## its title and System Name, five tabs (All, Rebel, Imperial, Neutral,
## Unexplored Systems), a band naming the tab; a system goes under the tab of
## the owner we KNOW of, not its live owner; typing locates rather than
## filters; Display opens the system's Sector and Manufacturing windows and
## closes the Finder. Writes and removes its own test art.
##
##   .\tools\run-gd.ps1 tests/system_finder.gd

const Art := preload("res://src/ui/artwork.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[system_finder] ok   %s" % what)
	else:
		_fails += 1
		print("[system_finder] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = "user://test-finder-art"
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	var sets: Array = FactionRegistry.Pack.Manifest.ArtSets
	var dir := "%s/%s" % [Art.UserArtRoot, sets[0] if not sets.is_empty() else "swr-original"]
	for sub in ["windows", "tabs", "buttons"]:
		DirAccess.make_dir_recursive_absolute("%s/%s" % [dir, sub])
	_png("%s/windows/finder_systems.png" % dir, 400, 306, Color(0.1, 0.1, 0.4))
	_png("%s/windows/finder_side2.alliance.png" % dir, 58, 330, Color(0.5, 0.5, 0.6))
	for side in ["alliance", "empire"]:
		_png("%s/windows/frame.%s.png" % [dir, side], 470, 331, Color(0.4, 0.4, 0.4, 0.5))
		for b in ["ency_close", "finder_display"]:
			_png("%s/buttons/%s.%s.png" % [dir, b, side], 32, 31, Color(0.6, 0.6, 0.6))
	for t in ["finder_tab_all", "finder_tab_rebel", "finder_tab_imperial", "finder_tab_neutral", "finder_tab_unexplored"]:
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
	var btn: Button = main.get_node("UIManager/HBoxContainer/PlanetInfo")
	_check(btn.text == "System Finder", "the bottom bar's button says 'System Finder' ('%s')" % btn.text)
	btn.pressed.emit()
	for _i in 3:
		await process_frame
	var w: PlanetFinder = Lq.first_or_null(ui.get_children(), func(n: Node) -> bool: return n is PlanetFinder)
	_check(w != null and not w._o.is_empty(), "the Finder is the original's")
	if w == null or w._o.is_empty():
		_finish()
		return
	var body: Control = w._o["body"]
	_check((body.get_node("Title") as Label).text == "Planetary System Finder" and (body.get_node("NameLabel") as Label).text == "System Name",
		"titled 'Planetary System Finder', its field 'System Name'")
	_check(w._o["tabs"].size() == 5, "five tabs")
	var captions: Array = []
	for i in 5:
		captions.append(PlanetFinder.Caption(i))
	_check(captions == ["All Systems", "Rebel Systems", "Imperial Systems", "Neutral Systems", "Unexplored Systems"], "the bands: %s" % str(captions))

	# Filed by what we know, never the live owner.
	var viewer: Faction = GameSettings.PlayerFaction
	var leak := 0
	for p in PlanetFinder.SystemsOn(1) + PlanetFinder.SystemsOn(2):
		var seen: Faction = IntelManager.OwnerSeen(viewer, p)
		if seen != p.ControllingFaction and not p.ExploredBy(viewer):
			leak += 1
	_check(leak == 0, "no system filed by an owner we have not seen")
	var total := 0
	for i in range(1, 5):
		total += PlanetFinder.SystemsOn(i).size()
	_check(total == PlanetFinder.SystemsOn(0).size(), "every system under exactly one of the four tabs (%d)" % total)

	# Typing locates, it does not filter.
	var all_count: int = int(w._o["list"].get("item_count"))
	var target: Planet = PlanetFinder.SystemsOn(0)[5]
	(w._o["field"] as LineEdit).text = target.Name.substr(0, 4)
	(w._o["field"] as LineEdit).text_changed.emit(target.Name.substr(0, 4))
	_check(int(w._o["list"].get("item_count")) == all_count, "typing keeps the whole list")
	_check(w.Selected() != null and w.Selected().Name.to_lower().begins_with(target.Name.substr(0, 4).to_lower()),
		"and picks the first system it begins ('%s')" % (w.Selected().Name if w.Selected() != null else "-"))

	# A tab lists its own.
	(w._o["tabs"][1] as TextureButton).pressed.emit()
	_check(w._shown == PlanetFinder.SystemsOn(1) and (w._o["header"] as Label).text == "Rebel Systems", "the Rebel tab lists the Rebel systems")

	# Display: the Sector and Manufacturing windows, the Finder closed.
	(w._o["tabs"][0] as TextureButton).pressed.emit()
	w._o["list"].call("select", 0)
	var picked: Planet = w.Selected()
	(w._o["buttons"]["finder_display"] as TextureButton).pressed.emit()
	for _i in 3:
		await process_frame
	var sector: Sector = Lq.first_or_null(GameState.ActiveGalaxy, func(s: Sector) -> bool: return s.Planets.has(picked))
	var sectorOpen: bool = Lq.any(ui.get_children(), func(n: Node) -> bool: return n is DraggableWindow and (n as DraggableWindow).WindowTitle == sector.Name)
	_check(sectorOpen, "Display opens %s's Sector window" % picked.Name)
	_check(not is_instance_valid(w) or w.is_queued_for_deletion() or not w.visible, "and the Finder closes")
	_finish()


func _finish() -> void:
	_remove(Art.UserArtRoot)
	Art.Reset()
	print("[system_finder] %d checks, %d failed" % [_checks, _fails])
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
