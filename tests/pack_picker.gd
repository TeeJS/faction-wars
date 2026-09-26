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
	# The last pack and the favorites in a scratch file, never the player's own.
	PackPicker.LastFile = "user://test-picker.cfg"
	DirAccess.remove_absolute(PackPicker.LastFile)
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
	var sw_card: Node = picker._panels["star-wars-rebellion"]
	var pic: TextureRect = sw_card.find_child("Picture", true, false)
	_check(pic != null and pic.texture != null, "without its art set the Star Wars card shows its own picture (card_image)")
	_check(sw_card.find_child("ClearArtwork", true, false) == null and sw_card.find_child("RemovePack", true, false) == null,
		"no Clear artwork pack without artwork, and a shipped pack has no Remove")
	# Every card's Play the same, narrower than its card (TeeJ, 2026-09-24).
	await process_frame
	var sizes: Array = []
	for id in picker.VisibleIds():
		if picker.PlayButtons().has(id):
			var pb: Button = picker.PlayButtons()[id]
			sizes.append(pb.size)
			_check(pb.size.x < (picker._panels[id] as Control).size.x - 40, "%s's Play is narrower than its card (%.0f of %.0f)" % [id, pb.size.x, (picker._panels[id] as Control).size.x])
	_check(sizes.size() >= 2 and sizes.all(func(s: Vector2) -> bool: return s == sizes[0]), "every Play is the same size (%s)" % str(sizes))
	var ys: Array = []
	for id in picker.VisibleIds():
		if picker.PlayButtons().has(id):
			ys.append(roundi((picker.PlayButtons()[id] as Control).global_position.y))
	_check(ys.size() >= 2 and ys.all(func(y: int) -> bool: return y == ys[0]), "... and at the same height on every card (%s)" % str(ys))

	# Play without the art: the artwork window, not the game.
	(picker.PlayButtons()["star-wars-rebellion"] as Button).pressed.emit()
	await process_frame
	var win: Control = picker.ArtworkWindow()
	_check(win != null and not FactionRegistry.IsLoaded(), "Play without the art opens the artwork window and loads nothing")
	if win != null:
		for part in ["ImportArtwork", "ContinueWithout", "CancelArtwork", "ExporterLink"]:
			_check(win.find_child(part, true, false) != null, "the artwork window has %s" % part)
		_check((win.find_child("ContinueWithout", true, false) as Button).text == "Continue without artwork", "with no art yet, 'Continue without artwork'")
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
	# The old artwork stays in use if the player goes on (TeeJ, 2026-09-25).
	var goOn: Button = win.find_child("ContinueWithout", true, false) if win != null else null
	_check(goOn != null and goOn.text == "Continue without updating", "out of date, the way on reads 'Continue without updating'")
	picker._close_art_window()
	var sw_pack: PackLoader.LoadedPack = picker._packs["star-wars-rebellion"]
	m = FileAccess.open(ArtScript.UserArtRoot + "/swr-original/manifest.json", FileAccess.WRITE)
	m.store_string(JSON.stringify({"format": 1, "kind": "art_set", "id": "swr-original", "title": "Test art", "exporter": Importer.MIN_EXPORTER["swr-original"], "files": {"a.png": "00"}}))
	m.close()
	ArtScript.Reset()
	_check(PackPicker.ArtState(sw_pack) == "", "a current art set: Play goes straight on")
	picker._rebuild()
	sw_card = picker._panels["star-wars-rebellion"]
	var clear: Button = sw_card.find_child("ClearArtwork", true, false)
	await process_frame
	_check(clear != null and clear.global_position.y > (picker.PlayButtons()["star-wars-rebellion"] as Control).global_position.y,
		"with the art in, Clear artwork pack is under Play")
	_check(clear != null and clear.tooltip_text.begins_with("Remove the imported artwork"), "... and says what it does")
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
	_make_pack(FactionRegistry.USER_PACKS_ROOT, "test-picker-pack", "Test Pack", "1.3")
	picker._rebuild()
	var mine_play: Button = picker.PlayButtons().get("test-picker-pack")
	var remove: Button = (picker._panels["test-picker-pack"] as Node).find_child("RemovePack", true, false) if mine_play != null else null
	_check(mine_play != null and not mine_play.disabled and remove != null, "an imported pack has its card, Play and Remove pack")
	var version: Label = (picker._panels["test-picker-pack"] as Node).find_child("Version", true, false) if mine_play != null else null
	_check(version != null and version.text == "v1.3", "pack.json version 1.3: the card says v1.3")
	_check((picker._panels["ww2"] as Node).find_child("Version", true, false) == null, "a pack without a version: no version on its card")
	if remove != null:
		remove.pressed.emit()
		await process_frame
		var ask2: ConfirmationDialog = picker.get_node_or_null("Confirm")
		_check(ask2 != null, "Remove pack asks first")
		if ask2 != null:
			ask2.confirmed.emit()
			await process_frame
		_check(not picker.PlayButtons().has("test-picker-pack"), "... and the pack and its card are gone")

	# THE CAROUSEL AND THE FAVORITES (TeeJ, 2026-09-24).
	picker._start = 0
	picker._rebuild()
	var shown := picker.VisibleIds()
	_check(shown.size() == 3 and shown.back() == PackPicker.ADD_CARD and picker._left.visible and picker._left.disabled and picker._right.disabled,
		"two packs and the + card fit: all on show, the arrows there but dimmed (%s)" % str(shown))
	_check(picker.find_child("AddPack", true, false) != null and picker._order.back() == PackPicker.ADD_CARD, "the + card is last")
	# Every secondary control says what it does (TeeJ, 2026-09-24).
	var add_tip: String = (picker.find_child("AddPack", true, false) as Control).tooltip_text
	_check(add_tip.begins_with("Import a faction pack (.zip file).") and picker.find_child("ChooseFile", true, false) != null,
		"the + card says what it takes, and shows its action ('%s')" % add_tip.replace("\n", " | "))
	_check(picker._left.tooltip_text == "Every setting is on screen", "a dimmed arrow says why ('%s')" % picker._left.tooltip_text)
	_check(not " ".join(_labels(picker)).contains("CHOOSE A SETTING"), "no 'CHOOSE A SETTING' line")
	# Tooltips that read: the screen's tooltip style reaches what is under it
	# (a tooltip is shown under the control that owns it).
	var probe := Label.new()
	probe.theme_type_variation = "TooltipLabel"
	var add_node: Control = picker.find_child("AddPack", true, false)
	add_node.add_child(probe)
	_check(probe.get_theme_font_size("font_size") == 15 and probe.get_theme_color("font_color") == PackPicker.CText,
		"tooltips on this screen: light 15 px type (%d)" % probe.get_theme_font_size("font_size"))
	var tip_panel := PanelContainer.new()
	tip_panel.theme_type_variation = "TooltipPanel"
	add_node.add_child(tip_panel)
	var sb: StyleBoxFlat = tip_panel.get_theme_stylebox("panel") as StyleBoxFlat
	_check(sb != null and sb.bg_color.a > 0.9, "... on a solid dark panel")
	probe.free()
	tip_panel.free()
	for k in 3:
		_make_pack(FactionRegistry.USER_PACKS_ROOT, "test-carousel-%d" % k, "Carousel %d" % k)
	picker._rebuild()
	var order: Array[String] = picker._order
	_check(order.size() == 6 and order[0] == "star-wars-rebellion" and order[1] == "ww2" and order[2] == "test-carousel-0" and order[5] == PackPicker.ADD_CARD,
		"with no favorites: the shipped packs, the player's own, then + (%s)" % str(order))
	_check(picker.VisibleIds() == order.slice(0, 3) and not picker._left.disabled and not picker._right.disabled and picker._dots.visible,
		"three on show, the arrows live, the dots showing (%s)" % str(picker.VisibleIds()))
	_check(picker._left.tooltip_text == "Previous setting" and picker._right.tooltip_text == "Next setting", "live arrows say which way")
	picker._right.pressed.emit()
	_check(picker.VisibleIds() == order.slice(1, 4), "the right arrow turns it one card (%s)" % str(picker.VisibleIds()))
	picker.Turn(-1)
	picker.Turn(-1)
	_check(picker.VisibleIds() == [order[5], order[0], order[1]], "turning left from the first wraps round to the + card (%s)" % str(picker.VisibleIds()))
	var key := InputEventKey.new()
	key.keycode = KEY_RIGHT
	key.pressed = true
	root.push_input(key)
	_check(picker.VisibleIds() == order.slice(0, 3), "the Right key turns it too (%s)" % str(picker.VisibleIds()))
	# Stars: up to three; they come first when the screen loads.
	for id in ["test-carousel-2", "test-carousel-1", "test-carousel-0"]:
		picker._bring_into_view(id)
		var star: PackPicker.StarButton = (picker._panels[id] as Node).find_child("Star", true, false)
		star.pressed.emit()
		_check(star.on and PackPicker.Favorites().has(id), "%s starred" % id)
		_check(star.tooltip_text == "Remove from favorites", "a filled star says 'Remove from favorites' ('%s')" % star.tooltip_text)
	var ww2_star: PackPicker.StarButton = (picker._panels["ww2"] as Node).find_child("Star", true, false)
	ww2_star.pressed.emit()
	await process_frame
	_check(not ww2_star.on and PackPicker.Favorites().size() == 3 and picker.get_node_or_null("Favorites") != null,
		"a fourth star is refused, and says so")
	_check(ww2_star.tooltip_text == "Add to favorites", "an empty star says 'Add to favorites' ('%s')" % ww2_star.tooltip_text)
	var said: Node = picker.get_node_or_null("Favorites")
	if said != null:
		said.queue_free()
	picker._start = 0
	picker._rebuild()
	_check(picker.VisibleIds() == ["test-carousel-2", "test-carousel-1", "test-carousel-0"],
		"on load the favorites are the cards on show, in star order (%s)" % str(picker.VisibleIds()))
	_check(((picker._panels["test-carousel-2"] as Node).find_child("Star", true, false) as PackPicker.StarButton).on, "a favorite's star is lit on its card")
	# The + card: the file picker (none headless - the refusal says so).
	(picker._panels[PackPicker.ADD_CARD] as Button).pressed.emit()
	await process_frame
	var told: AcceptDialog = picker.get_node_or_null("ImportResult")
	_check(told != null, "the + card imports a file (headless: '%s')" % (told.dialog_text if told != null else "nothing"))
	if told != null:
		told.queue_free()
		await process_frame   # closed before the next question opens
	# A starred pack removed is no favorite.
	var rm: Button = (picker._panels["test-carousel-2"] as Node).find_child("RemovePack", true, false)
	rm.pressed.emit()
	await process_frame
	(picker.get_node("Confirm") as ConfirmationDialog).confirmed.emit()
	await process_frame
	_check(not PackPicker.Favorites().has("test-carousel-2") and not picker._order.has("test-carousel-2"), "removing a starred pack unstars it")
	for id in PackPicker.Favorites():
		PackPicker.SetFavorite(id, false)
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

	DirAccess.remove_absolute(PackPicker.LastFile)
	print("[pack_picker] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## A copy of the WWII pack under `root`, as a player's import.
static func _make_pack(root: String, id: String, display_name: String, version: String = "") -> void:
	var dir := "%s/%s" % [root, id]
	DirAccess.make_dir_recursive_absolute(dir)
	for f in FactionRegistry.PACK_FILES:
		var text := FileAccess.get_file_as_string("res://packs/ww2/" + f)
		if f == "pack.json":
			var d: Dictionary = JSON.parse_string(text)
			d["id"] = id
			d["display_name"] = display_name
			d["map_image"] = "ww2map.png"
			if not version.is_empty():
				d["version"] = version
			text = JSON.stringify(d)
		var w := FileAccess.open(dir + "/" + f, FileAccess.WRITE)
		w.store_string(text)
		w.close()
	Image.create(8, 8, false, Image.FORMAT_RGBA8).save_png(dir + "/ww2map.png")


static func _labels(node: Node) -> Array[String]:
	var out: Array[String] = []
	if node is Label:
		out.append((node as Label).text)
	for c in node.get_children():
		out.append_array(_labels(c))
	return out
