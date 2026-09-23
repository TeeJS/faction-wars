class_name PackPicker
extends Control
## The first screen: WHICH SETTING to play. One card per pack under packs/,
## built from the pack's own manifest - name, summary, the sides in their
## colours, the map picture - and a Play button that loads that pack and goes
## on to its Cockpit (Menu.tscn). Engine screen, not a manual one: the original
## had one setting, so its first screen is the Cockpit (manual p021); this one
## sits in front of it only because there is more than one pack to choose.
##
## Skipped straight through to the Cockpit when the choice is already made:
## `--pack=<id>` on the command line, a pack already loaded (a scene coming
## back here mid-flow), or exactly one pack installed.
##
## The Cockpit's Exit comes BACK here (ExitToPicker): the loaded pack is
## unloaded - the one place that happens - and another can be chosen. With
## nothing to choose (one pack, or --pack= forcing it) that Exit quits
## instead. Exit Game is this screen's own button, hidden on the web.
##
## The last choice is remembered in user://pack.cfg and pre-focused next time;
## packs/active.json stays the headless default.

## The pack's pictures, including an art set's (docs/original-art-plan.md).
const Art := preload("res://src/ui/artwork.gd")
## Importing the player's art set and faction packs (plan phase 3).
const PackImport := preload("res://src/ui/pack_import.gd")

const MENU_SCENE := "res://Menu.tscn"
const LastFile := "user://pack.cfg"
## The Faction Wars Exporter's download: always the newest release's zip.
const EXPORTER_URL := "https://github.com/TeeJS/faction-wars/releases/latest/download/FactionWarsExporter-win-x64.zip"

## pack id -> the Play button, for the test and the keyboard.
var _play: Dictionary = {}
var _cards: HBoxContainer
## Set by ExitToPicker: the next picker is a return from the Cockpit.
static var _returning: bool = false
## The last import's result, shown under the Import button (it survives the
## rebuild that shows the import).
static var _last_import: Dictionary = {}
var _column: VBoxContainer


func _ready() -> void:
	# A pack file dropped on the game imports from here on, on every screen.
	PackImport.ListenForDrops(get_tree())
	PackImport.OnImported = _on_imported
	var ids := FactionRegistry.ListPackIds()
	if _returning:
		_returning = false
		if not CanReturn():
			# Nothing else to choose: the Cockpit's Exit means quit here.
			get_tree().quit()
			if not OS.has_feature("web"):
				return
		FactionRegistry.Unload()
		_build(ids)
		return
	if FactionRegistry.IsLoaded() or not _cmdline_pack().is_empty():
		FactionRegistry.EnsureLoaded()
		_go()
		return
	if ids.size() == 1:
		Choose(ids[0])
		return
	_build(ids)


## Whether the Cockpit's Exit has anywhere to go: more than one pack, and
## none forced by --pack=. Otherwise that Exit quits, and says so.
static func CanReturn() -> bool:
	return FactionRegistry.ListPackIds().size() > 1 and _cmdline_pack().is_empty()


## The Cockpit's Exit: back to this screen to choose again. Remembers the
## pack being left so its card is the focused one.
static func ExitToPicker(tree: SceneTree) -> void:
	_returning = true
	if FactionRegistry.IsLoaded():
		_remember(FactionRegistry.LoadedId())
	tree.change_scene_to_file("res://PackPicker.tscn")


## Load `pack_id` and go on to its Cockpit. False when it cannot load.
func Choose(pack_id: String) -> bool:
	if not FactionRegistry.EnsureLoaded(pack_id):
		return false
	_remember(pack_id)
	_go()
	return true


## The Play buttons by pack id, in card order.
func PlayButtons() -> Dictionary:
	return _play


func _go() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)


static func _cmdline_pack() -> String:
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a.begins_with("--pack="):
			return a.substr("--pack=".length())
	return ""


static func _remember(pack_id: String) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("pack", "last", pack_id)
	cfg.save(LastFile)


static func _last() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(LastFile) != OK:
		return ""
	return str(cfg.get_value("pack", "last", ""))


func _build(ids: Array[String]) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	centre.add_child(column)
	_column = column

	var title := Label.new()
	title.text = "Choose a setting"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", 24)
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(_cards)

	var last := _last()
	var focus_first: Button = null
	for id in ids:
		var errors: Array[String] = []
		var pack := PackLoader.Load(FactionRegistry.PackDir(id), errors)
		var play := _card(id, pack, errors)
		if focus_first == null or id == last:
			focus_first = play
	if focus_first != null and not focus_first.disabled:
		focus_first.grab_focus()

	column.add_child(_imports())

	# A browser tab has no desktop to quit to (TeeJ, room #97).
	if not OS.has_feature("web"):
		var quit := Button.new()
		quit.text = "Exit Game"
		quit.custom_minimum_size = Vector2(160, 40)
		quit.pressed.connect(func() -> void: get_tree().quit())
		var foot := CenterContainer.new()
		foot.add_child(quit)
		column.add_child(foot)


## One pack's card. A pack that fails validation still gets a card, with its
## problems in place of the summary and no Play - the list must never lie
## about what is installed.
func _card(id: String, pack: PackLoader.LoadedPack, errors: Array[String]) -> Button:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(340, 0)
	_cards.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var name := Label.new()
	name.text = pack.Manifest.DisplayName if pack != null else id
	name.add_theme_font_size_override("font_size", 24)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name)

	if pack != null:
		var picture := TextureRect.new()
		picture.texture = Art.PackImage(pack.Manifest.MapImage, id, pack.Manifest.ArtSets)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.custom_minimum_size = Vector2(300, 170)
		box.add_child(picture)

		var summary := Label.new()
		summary.text = pack.Manifest.Summary
		summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		summary.custom_minimum_size = Vector2(300, 0)
		box.add_child(summary)

		var sides := HBoxContainer.new()
		sides.alignment = BoxContainer.ALIGNMENT_CENTER
		sides.add_theme_constant_override("separation", 16)
		for f in pack.Factions:
			var side := Label.new()
			side.text = f.DisplayName
			side.add_theme_color_override("font_color", FactionRegistry.ParseColor(f.ColorHex))
			sides.add_child(side)
		box.add_child(sides)

		# The original look needs the player's own art set (plan phase 3).
		if not pack.Manifest.ArtSets.is_empty():
			var ready := Lq.all(pack.Manifest.ArtSets, func(s: String) -> bool: return Art.HasArtSet(s))
			var look := Label.new()
			look.name = "OriginalLook"
			look.text = "Original look: yes" if ready else "Original look: import your art set (below)"
			look.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			look.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6) if ready else Color(0.9, 0.8, 0.5))
			box.add_child(look)
	else:
		var broken := Label.new()
		broken.text = "Cannot load this pack:\n" + "\n".join(errors.slice(0, 6))
		broken.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		broken.custom_minimum_size = Vector2(300, 0)
		broken.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
		box.add_child(broken)

	var play := Button.new()
	play.text = "Play"
	play.custom_minimum_size = Vector2(0, 40)
	play.disabled = pack == null
	play.pressed.connect(func() -> void: Choose(id))
	box.add_child(play)
	_play[id] = play
	return play


## The player's own imports (docs/original-art-plan.md): the art set the
## original look needs and any faction packs, each removable, and the button
## that imports a file (dropping one on the window does the same).
func _imports() -> Control:
	var box := VBoxContainer.new()
	box.name = "Imports"
	box.add_theme_constant_override("separation", 8)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var pick := Button.new()
	pick.name = "ImportButton"
	pick.text = "Import pack file..."
	pick.custom_minimum_size = Vector2(220, 40)
	pick.pressed.connect(func() -> void: PackImport.PickFile(_on_imported))
	row.add_child(pick)
	box.add_child(row)

	var how := Label.new()
	how.text = "Your art set comes from your own copy of Star Wars: Rebellion, exported with the Faction Wars Exporter. " \
		+ "Import it here, or drag the file onto this window. Keep the file: it restores the artwork if this browser forgets it."
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.custom_minimum_size = Vector2(700, 0)
	how.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	how.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	box.add_child(how)

	# Where to get the exporter. In the browser a link that opens it in a new
	# tab; on the desktop the address to copy (the game starts no other program).
	var get_it := HBoxContainer.new()
	get_it.name = "ExporterLink"
	get_it.alignment = BoxContainer.ALIGNMENT_CENTER
	var lead := Label.new()
	lead.text = "Download the Faction Wars Exporter (Windows):"
	get_it.add_child(lead)
	if OS.has_feature("web"):
		var link := LinkButton.new()
		link.text = "FactionWarsExporter-win-x64.zip"
		link.tooltip_text = EXPORTER_URL
		link.pressed.connect(func() -> void: JavaScriptBridge.eval("window.open('%s', '_blank')" % EXPORTER_URL, true))
		get_it.add_child(link)
	else:
		var address := LineEdit.new()
		address.text = EXPORTER_URL
		address.editable = false
		address.custom_minimum_size = Vector2(620, 0)
		get_it.add_child(address)
	box.add_child(get_it)

	for e in PackImport.Installed():
		var line := HBoxContainer.new()
		line.alignment = BoxContainer.ALIGNMENT_CENTER
		line.add_theme_constant_override("separation", 12)
		var what := Label.new()
		var details: Array[String] = ["%d files" % e.files]
		if not str(e.created_utc).is_empty():
			details.append(str(e.created_utc).substr(0, 10))
		if not str(e.exporter).is_empty():
			details.append("exporter %s" % e.exporter)
		what.text = "%s: %s - %s" % ["Art set" if e.kind == PackImport.KIND_ART_SET else "Faction pack",
			e.title, ", ".join(details)]
		line.add_child(what)
		var remove := Button.new()
		remove.text = "Remove"
		remove.pressed.connect(func() -> void:
			PackImport.Remove(e.kind, e.id)
			_on_imported({"ok": true, "message": "Removed %s." % e.title}))
		line.add_child(remove)
		box.add_child(line)
		# Too old for this version of the game: say so, and how to fix it.
		if e.outdated:
			var old := Label.new()
			old.name = "Outdated"
			old.text = PackImport.OutdatedNote(e.id, e.exporter)
			old.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			old.custom_minimum_size = Vector2(700, 0)
			old.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			old.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
			box.add_child(old)

	if not _last_import.is_empty():
		var said := Label.new()
		said.name = "ImportResult"
		said.text = str(_last_import.get("message", ""))
		said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		said.custom_minimum_size = Vector2(700, 0)
		said.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		said.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6) if _last_import.get("ok", false) else Color(1.0, 0.45, 0.45))
		box.add_child(said)
	return box


## An import (or a removal) finished: rebuild, so the cards and the list show it.
func _on_imported(result: Dictionary) -> void:
	_last_import = result
	if not is_inside_tree() or _cards == null:
		return
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_play.clear()
	_build(FactionRegistry.ListPackIds())
