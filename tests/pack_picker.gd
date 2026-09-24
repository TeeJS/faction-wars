extends SceneTree
## The pack picker: one card per installed pack, built from the pack's own
## manifest, and Play loads that pack and moves on to its Cockpit.
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

	# The player's imports (docs/original-art-plan.md, phase 3): the button,
	# the Star Wars card saying whether its art set is there, and a rebuild
	# that shows an import at once. A test art root, never the player's own.
	const ArtScript := preload("res://src/ui/artwork.gd")
	const Importer := preload("res://src/ui/pack_import.gd")
	_check(picker.find_child("ImportButton", true, false) != null, "the Import pack file button is on the picker")
	ArtScript.IgnoreProjectFolder = true
	ArtScript.UserArtRoot = "user://test-picker-art"
	Importer._remove(ArtScript.UserArtRoot)
	picker._on_imported({"ok": true, "message": "nothing yet"})
	# The card must agree with Artwork, whatever it finds.
	var look: Label = picker.find_child("OriginalLook", true, false)
	var has: bool = ArtScript.HasArtSet("swr-original")
	_check(look != null and look.text == ("Original look: yes" if has else "Original look: import your art set (below)"),
		"the Star Wars card says whether its art set is there (%s)" % (look.text if look != null else "no label"))
	DirAccess.make_dir_recursive_absolute(ArtScript.UserArtRoot + "/swr-original")
	var m := FileAccess.open(ArtScript.UserArtRoot + "/swr-original/manifest.json", FileAccess.WRITE)
	m.store_string(JSON.stringify({"format": 1, "kind": "art_set", "id": "swr-original", "title": "Test art", "exporter": "2.0.0", "files": {"a.png": "00"}}))
	m.close()
	picker._on_imported({"ok": true, "message": "Imported the art set."})
	look = picker.find_child("OriginalLook", true, false)
	_check(look != null and look.text == "Original look: yes", "after an import the card says so at once")
	_check(_labels(picker).has("Art set: Test art - 1 files, exporter 2.0.0") and _labels(picker).has("Imported the art set."),
		"the import is listed with its exporter's version, with Remove, and its result shown")
	var outdated: Label = picker.find_child("Outdated", true, false)
	_check(outdated != null and outdated.text.contains("needs %s or later" % Importer.MIN_EXPORTER["swr-original"]), "an art set older than the game needs says to export again")
	Importer._remove(ArtScript.UserArtRoot)
	ArtScript.IgnoreProjectFolder = false
	ArtScript.UserArtRoot = "user://art"
	PackPicker._last_import = {}
	picker._on_imported({})
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
