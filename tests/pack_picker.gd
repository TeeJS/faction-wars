extends SceneTree
## The pack picker: one card per installed pack, built from the pack's own
## manifest, and Play loads that pack and moves on to its Cockpit - or, for a
## pack whose art set is missing or too old, opens the artwork window first.
##
##   .\tools\run-gd.ps1 tests/pack_picker.gd
##
## Run without --pack for the cards; with --pack=<id> it checks the skip path
## instead (the picker loads that pack and goes straight to the Cockpit).
## packs/active.json is never consulted by the picker.

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[pack_picker] ok   %s" % what)
	else:
		_fails += 1
		print("[pack_picker] FAIL %s" % what)


func _init() -> void:
	await process_frame
	_check(not FactionRegistry.IsLoaded(), "nothing is loaded before the picker")

	var picker: PackPicker = load("res://PackPicker.tscn").instantiate()
	root.add_child(picker)
	await process_frame
	await process_frame

	# With --pack=<id> the picker never shows: it loads that pack and goes
	# straight to the Cockpit. That is the whole check for this path.
	var forced := PackPicker._cmdline_pack()
	if not forced.is_empty():
		_check(FactionRegistry.LoadedId() == forced, "--pack=%s skipped the picker and loaded it ('%s')" % [forced, FactionRegistry.LoadedId()])
		_check(current_scene != null and current_scene is Menu, "the Cockpit is the scene when the picker is skipped")
		_check(picker.PlayButtons().is_empty(), "no cards were built")
		print("[pack_picker] %d checks, %d failed" % [_checks, _fails])
		quit(1 if _fails > 0 else 0)
		return

	var ids := FactionRegistry.ListPackIds()
	_check(ids.size() >= 2, "at least two packs are installed (%d) - the picker only shows for more than one" % ids.size())
	var plays := picker.PlayButtons()
	_check(plays.size() == ids.size(), "one card per installed pack (%d of %d)" % [plays.size(), ids.size()])
	for id in ids:
		_check(plays.has(id) and not (plays[id] as Button).disabled, "'%s' has an enabled Play" % id)
	_check(not FactionRegistry.IsLoaded(), "building the cards loads no pack")

	# THE LAUNCH SCREEN (TeeJ, 2026-09-24): nothing under the cards; a pack
	# whose art set is not imported opens the artwork window on Play; with the
	# art in, Clear artwork pack; an imported pack has Remove pack. A test art
	# root and a test packs root, never the player's own.
	const ArtScript := preload("res://src/ui/artwork.gd")
	const Importer := preload("res://src/ui/pack_import.gd")
	ArtScript.IgnoreProjectFolder = true
	ArtScript.UserArtRoot = "user://test-picker-art"
	Importer._remove(ArtScript.UserArtRoot)
	picker._rebuild()
	_check(picker.find_child("Imports", true, false) == null and picker.find_child("ImportButton", true, false) == null
		and picker.find_child("OriginalLook", true, false) == null, "nothing under the cards: no import list, no Original look")
	var sw_card: Node = (picker.PlayButtons()["star-wars-rebellion"] as Node).get_parent()
	var pic: TextureRect = sw_card.get_node_or_null("Picture")
	_check(pic != null and pic.texture != null, "without its art set the Star Wars card shows its own picture (card_image)")
	_check(sw_card.get_node_or_null("ClearArtwork") == null and sw_card.get_node_or_null("RemovePack") == null,
		"no Clear artwork pack without artwork, and a shipped pack has no Remove")

	# Play without the art: the artwork window, not the game.
	(picker.PlayButtons()["star-wars-rebellion"] as Button).pressed.emit()
	await process_frame
	var win: Control = picker.ArtworkWindow()
	_check(win != null and not FactionRegistry.IsLoaded(), "Play without the art opens the artwork window and loads nothing")
	if win != null:
		for part in ["ImportArtwork", "ContinueWithout", "CancelArtwork", "ExporterLink"]:
			_check(win.find_child(part, true, false) != null, "the artwork window has %s" % part)
		var said := " ".join(_labels(win))
		_check(said.contains("own copy") and said.contains("1.") and said.contains("4.") and said.contains("swr-original.art.zip"),
			"it says why, and the four steps")
	# A refused file: its reasons in the window.
	picker._on_imported({"ok": false, "message": "Not imported: a test refusal."})
	await process_frame
	win = picker.ArtworkWindow()
	var result: Label = win.find_child("ArtworkResult", true, false) if win != null else null
	_check(result != null and result.text == "Not imported: a test refusal.", "an import's refusal is shown in the artwork window")
	(win.find_child("CancelArtwork", true, false) as Button).pressed.emit()
	await process_frame
	_check(picker.ArtworkWindow() == null, "Cancel closes it")

	# Art imported by too old an exporter: the window again, saying export again.
	DirAccess.make_dir_recursive_absolute(ArtScript.UserArtRoot + "/swr-original")
	var m := FileAccess.open(ArtScript.UserArtRoot + "/swr-original/manifest.json", FileAccess.WRITE)
	m.store_string(JSON.stringify({"format": 1, "kind": "art_set", "id": "swr-original", "title": "Test art", "exporter": "2.0.0", "files": {"a.png": "00"}}))
	m.close()
	ArtScript.Reset()
	picker._rebuild()
	(picker.PlayButtons()["star-wars-rebellion"] as Button).pressed.emit()
	await process_frame
	win = picker.ArtworkWindow()
	_check(win != null and " ".join(_labels(win)).contains("needs %s or later" % Importer.MIN_EXPORTER["swr-original"]),
		"an art set older than the game needs opens the window, saying export again")
	picker._close_art_window()
	var sw_pack: PackLoader.LoadedPack = picker._packs["star-wars-rebellion"]
	m = FileAccess.open(ArtScript.UserArtRoot + "/swr-original/manifest.json", FileAccess.WRITE)
	m.store_string(JSON.stringify({"format": 1, "kind": "art_set", "id": "swr-original", "title": "Test art", "exporter": Importer.MIN_EXPORTER["swr-original"], "files": {"a.png": "00"}}))
	m.close()
	ArtScript.Reset()
	_check(PackPicker.ArtState(sw_pack) == "", "a current art set: Play goes straight on")
	picker._rebuild()
	sw_card = (picker.PlayButtons()["star-wars-rebellion"] as Node).get_parent()
	var clear: Button = sw_card.get_node_or_null("ClearArtwork")
	_check(clear != null and clear.get_index() > (picker.PlayButtons()["star-wars-rebellion"] as Node).get_index(),
		"with the art in, Clear artwork pack is under Play")
	if clear != null:
		clear.pressed.emit()
		await process_frame
		var ask: ConfirmationDialog = picker.get_node_or_null("Confirm")
		_check(ask != null, "Clear artwork pack asks first")
		if ask != null:
			ask.confirmed.emit()
			await process_frame
		_check(not ArtScript.HasArtSet("swr-original") and picker.find_child("ClearArtwork", true, false) == null,
			"... and removes the artwork, and the button with it")

	# A pack the player imported: its own card, with Remove pack.
	var real_packs: String = FactionRegistry.USER_PACKS_ROOT
	FactionRegistry.USER_PACKS_ROOT = "user://test-picker-packs"
	Importer._remove(FactionRegistry.USER_PACKS_ROOT)
	var mine := FactionRegistry.USER_PACKS_ROOT + "/test-picker-pack"
	DirAccess.make_dir_recursive_absolute(mine)
	for f in FactionRegistry.PACK_FILES:
		var text := FileAccess.get_file_as_string("res://packs/ww2/" + f)
		if f == "pack.json":
			var d: Dictionary = JSON.parse_string(text)
			d["id"] = "test-picker-pack"
			d["display_name"] = "Test Pack"
			d["map_image"] = "ww2map.png"
			text = JSON.stringify(d)
		var w := FileAccess.open(mine + "/" + f, FileAccess.WRITE)
		w.store_string(text)
		w.close()
	var map_img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	map_img.save_png(mine + "/ww2map.png")
	picker._rebuild()
	var mine_play: Button = picker.PlayButtons().get("test-picker-pack")
	var remove: Button = mine_play.get_parent().get_node_or_null("RemovePack") if mine_play != null else null
	_check(mine_play != null and not mine_play.disabled and remove != null, "an imported pack has its card, Play and Remove pack")
	if remove != null:
		remove.pressed.emit()
		await process_frame
		var ask2: ConfirmationDialog = picker.get_node_or_null("Confirm")
		_check(ask2 != null, "Remove pack asks first")
		if ask2 != null:
			ask2.confirmed.emit()
			await process_frame
		_check(not picker.PlayButtons().has("test-picker-pack"), "... and the pack and its card are gone")
	Importer._remove(FactionRegistry.USER_PACKS_ROOT)
	FactionRegistry.USER_PACKS_ROOT = real_packs
	Importer._remove(ArtScript.UserArtRoot)
	ArtScript.IgnoreProjectFolder = false
	ArtScript.UserArtRoot = "user://art"
	ArtScript.Reset()
	picker._rebuild()
	plays = picker.PlayButtons()

	# The card text comes from the manifest, not from the id.
	var labels := _labels(picker)
	var sw := PackLoader.Load("%s/star-wars-rebellion" % FactionRegistry.PACKS_ROOT, [])
	_check(labels.has(sw.Manifest.DisplayName), "the Star Wars card shows the pack's display_name")
	_check(not sw.Manifest.Summary.is_empty() and labels.has(sw.Manifest.Summary), "the Star Wars card shows the pack's summary")
	for f in sw.Factions:
		_check(labels.has(f.DisplayName), "the Star Wars card names the '%s' side" % f.DisplayName)

	# Play on the WWII card loads WWII and heads for the Cockpit.
	(plays["ww2"] as Button).pressed.emit()
	await process_frame
	await process_frame
	_check(FactionRegistry.LoadedId() == "ww2", "Play loaded the chosen pack ('%s')" % FactionRegistry.LoadedId())
	_check(current_scene != null and current_scene is Menu, "the Cockpit (Menu.tscn) is the scene after Play")
	_check(FactionRegistry.Pack.Manifest.Menu == null, "the WWII pack's Cockpit is the button form (it declares no picture)")

	# The Cockpit's Exit comes back here, unloads, and another pack can be chosen.
	PackPicker.ExitToPicker(self)
	await process_frame
	await process_frame
	_check(current_scene is PackPicker, "Exit from the Cockpit returns to the picker")
	_check(not FactionRegistry.IsLoaded(), "the pack is unloaded on the way back")
	var again: PackPicker = current_scene
	_check(again.PlayButtons().size() == ids.size(), "the cards are rebuilt (%d)" % again.PlayButtons().size())
	_check((again.PlayButtons()["ww2"] as Button).has_focus(), "the pack just left is the focused card")
	(again.PlayButtons()["star-wars-rebellion"] as Button).pressed.emit()
	# Without the art here, the artwork window first: Continue without artwork.
	# (Asked at once: with the art, the picker is on its way out already.)
	if again.ArtworkWindow() != null:
		(again.ArtworkWindow().find_child("ContinueWithout", true, false) as Button).pressed.emit()
	await process_frame
	await process_frame
	_check(FactionRegistry.LoadedId() == "star-wars-rebellion", "another pack loads after the switch ('%s')" % FactionRegistry.LoadedId())
	_check(current_scene is Menu, "and its Cockpit is the scene")
	_check(FactionRegistry.Pack.Manifest.Menu != null, "the Star Wars Cockpit is the picture form - the new pack, not the old one")

	print("[pack_picker] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


static func _labels(node: Node) -> Array[String]:
	var out: Array[String] = []
	if node is Label:
		out.append((node as Label).text)
	for c in node.get_children():
		out.append_array(_labels(c))
	return out
