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
