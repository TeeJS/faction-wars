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
## back here), or exactly one pack installed. ONE PACK PER PROCESS
## (FactionRegistry): there is no way back here from the Cockpit.
##
## The last choice is remembered in user://pack.cfg and pre-focused next time;
## packs/active.json stays the headless default.

const MENU_SCENE := "res://Menu.tscn"
const LastFile := "user://pack.cfg"

## pack id -> the Play button, for the test and the keyboard.
var _play: Dictionary = {}
var _cards: HBoxContainer


func _ready() -> void:
	if FactionRegistry.IsLoaded() or not _cmdline_pack().is_empty():
		FactionRegistry.EnsureLoaded()
		_go()
		return
	var ids := FactionRegistry.ListPackIds()
	if ids.size() == 1:
		Choose(ids[0])
		return
	_build(ids)


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
		var pack := PackLoader.Load("%s/%s" % [FactionRegistry.PACKS_ROOT, id], errors)
		var play := _card(id, pack, errors)
		if focus_first == null or id == last:
			focus_first = play
	if focus_first != null and not focus_first.disabled:
		focus_first.grab_focus()

	var exit := Button.new()
	exit.text = "Exit"
	exit.custom_minimum_size = Vector2(160, 40)
	exit.pressed.connect(func() -> void: get_tree().quit())
	var foot := CenterContainer.new()
	foot.add_child(exit)
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
		picture.texture = load("%s/%s/%s" % [FactionRegistry.PACKS_ROOT, id, pack.Manifest.MapImage])
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
