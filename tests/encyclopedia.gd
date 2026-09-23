extends SceneTree
## The Galactic Encyclopedia (manual p073-p074, Figs 3.10 / 3.11): Index view
## with the Topic entry box, the seven database tabs, the list and View
## Topic / View Index / Close; Topic view with the name, left/right arrows,
## the picture and the description; the database chosen persists; the
## imported picture and text show when present, the pack's own facts
## otherwise; reachable by kind and id from the right-click menus. Writes and
## removes its own test files under user://.
##
##   .\tools\run-gd.ps1 tests/encyclopedia.gd -- --pack=ww2
##   .\tools\run-gd.ps1 tests/encyclopedia.gd              (Star Wars)

const Art := preload("res://src/ui/artwork.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[encyclopedia] ok   %s" % what)
	else:
		_fails += 1
		print("[encyclopedia] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = "user://test-encyclopedia-art"   # never the player's own
	FactionRegistry.EnsureLoaded()
	if FactionRegistry.Pack.Manifest.ArtSets.is_empty():
		print("[encyclopedia] (this pack declares no art set - the original's pictures do not apply)")
		print("[encyclopedia] 0 checks, 0 failed")
		quit(0)
		return
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 5:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	var pack: PackLoader.LoadedPack = FactionRegistry.Pack
	var pack_id: String = pack.Manifest.Id

	# Open from the control: Index view, All Databases.
	ui.OpenEncyclopedia()
	for _i in 3:
		await process_frame
	var w: EncyclopediaWindow = ui._openWindows.get("Encyclopedia")
	_check(w != null and w.visible, "the Encyclopedia opens")
	_check(w._indexView.visible and not w._topicView.visible, "it opens in Index view")
	var total: int = pack.Map.Planets.size() + pack.Units.size() + pack.Facilities.size() + pack.Characters.size() \
		+ Lq.count(pack.Missions, func(m) -> bool: return not m.Id.begins_with("unnamed"))
	_check(w._index.item_count == total, "All Databases lists every pack row (%d)" % w._index.item_count)
	_check(w._tabs.size() == 7 and w._tabs[0].text == "All Databases" and w._tabs[6].text == "Personnel", "the seven database tabs are there")

	# Personnel database: every character, alphabetical.
	w._tabs[6].pressed.emit()
	_check(w._index.item_count == pack.Characters.size(), "the Personnel database lists every character (%d)" % w._index.item_count)
	var names: Array = []
	for i in w._index.item_count:
		names.append(w._index.get_item_text(i))
	var sorted_names := names.duplicate()
	sorted_names.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)
	_check(names == sorted_names, "the index is alphabetical")

	# The Topic box jumps to a name.
	var who: PackDefs.CharacterDef = pack.Characters[pack.Characters.size() / 2]
	w._topicBox.text = who.DisplayName.substr(0, 4)
	w._topicBox.text_changed.emit(w._topicBox.text)
	var sel: PackedInt32Array = w._index.get_selected_items()
	_check(sel.size() == 1 and w._index.get_item_text(sel[0]).to_lower().begins_with(who.DisplayName.substr(0, 4).to_lower()), "typing the first letters selects that entry")

	# View Topic: the name, the pack's own facts, the picture placeholder.
	w.ViewTopic()
	_check(w._topicView.visible and not w._indexView.visible, "View Topic switches to Topic view")
	_check(w._topicTitle.text == w._index.get_item_text(sel[0]), "the topic carries the entry's name")
	_check(not w._text.text.is_empty() and w._text.text != "No description.", "a character with no imported text shows the pack's ratings")
	_check(w._picture.get_node_or_null("Picture") == null, "no imported picture: the placeholder")

	# Arrows browse the chosen database only.
	var before: String = w._topicTitle.text
	w.Next()
	_check(w._topicTitle.text != before and w.CurrentEntry().Kind == "characters", "the right arrow steps to the next character")
	w.Prev()
	_check(w._topicTitle.text == before, "the left arrow steps back")
	w._viewIndexBtn.pressed.emit()
	_check(w._indexView.visible and w._tabs[6].button_pressed, "View Index returns to the Personnel index")

	# Imported text and picture: a unit, from the test art set.
	var unit: PackDefs.UnitDef = pack.Units[0]
	var dir := "%s/%s" % [Art.UserArtRoot, FactionRegistry.Pack.Manifest.ArtSets[0]]
	DirAccess.make_dir_recursive_absolute(dir + "/units")
	var img := Image.create(400, 200, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.2, 0.4, 0.7))
	var pic_path := "%s/units/%s.png" % [dir, unit.Id]
	img.save_png(pic_path)
	var f := FileAccess.open(dir + "/descriptions.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"units": {unit.Id: "Refined Material Cost:\t\t20\n\nA test entry for %s." % unit.DisplayName}}))
	f.close()
	Art.Reset()
	ui.OpenEncyclopedia("units", unit.Id)
	for _i in 2:
		await process_frame
	_check(w._topicView.visible and w._topicTitle.text == unit.DisplayName, "opened by kind and id (a right-click's Encyclopedia) it shows that topic")
	_check(w._text.text.contains("A test entry for"), "the imported description is shown")
	_check(w._picture.get_node_or_null("Picture") != null, "the imported picture is shown")
	_check(w._tabs[2].button_pressed or w._tabs[5].button_pressed, "the database follows the entry (Ship or Troop)")

	DirAccess.remove_absolute(pic_path)
	DirAccess.remove_absolute(dir + "/descriptions.json")
	Art.Reset()

	print("[encyclopedia] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
