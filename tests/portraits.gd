extends SceneTree
## The original's portraits and list miniatures, from the player's own
## import (src/ui/artwork.gd): the Character Status window's portrait (manual
## p101), the Unit Status window's, the Message window's picture of the
## character a message is about, and the miniature beside a name in the
## Defenses window's personnel list (p100: "right-click the character's
## portrait"). Nothing imported means the placeholders, as before. Writes and
## removes its own test files under user://.
##
##   .\tools\run-gd.ps1 tests/portraits.gd -- --pack=ww2
##   .\tools\run-gd.ps1 tests/portraits.gd              (Star Wars)

const Art := preload("res://src/ui/artwork.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[portraits] ok   %s" % what)
	else:
		_fails += 1
		print("[portraits] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true   # only what this test writes counts
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 5:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	var us: Faction = GameSettings.PlayerFaction
	var pack_id: String = FactionRegistry.Pack.Manifest.Id
	var who: Character = Lq.first_or_null(GameState.ActiveRoster, func(c: Character) -> bool: return c.Faction == us and c.Attached is Planet)
	var home: Planet = who.Attached
	var garrisoned: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool: return p.ControllingFaction == us and not p.Garrison.is_empty())
	var troop: Unit = garrisoned.Garrison[0] if garrisoned != null else null
	_check(who != null and troop != null, "%s has a character on a world (%s at %s) and a garrison unit (%s)" % [us.Id, who.Name, home.Name, troop.Name if troop != null else "-"])

	# --- Without the overlay: placeholders. ---
	Art.Reset()
	ui.OpenCharacterStatusWindow(who)
	for _i in 3:
		await process_frame
	var csw: DraggableWindow = _window_titled_like(ui, "Status_" + who.Name)
	_check(csw != null and csw.get_node(CharacterStatusWindow.PortraitPath).get_node_or_null("Picture") == null, "no portrait node without an import")
	if csw == null:
		quit(1)
		return
	csw.CloseWindow()
	for _i in 2:
		await process_frame

	# --- Write portraits and a miniature under user://original. ---
	var dir := "user://original/%s" % pack_id
	for sub in ["portraits/characters", "portraits/units", "miniatures/characters"]:
		DirAccess.make_dir_recursive_absolute("%s/%s" % [dir, sub])
	var written: Array[String] = []
	var p80 := Image.create(80, 80, false, Image.FORMAT_RGBA8)
	p80.fill(Color(0.8, 0.6, 0.4))
	for path in ["%s/portraits/characters/%s.png" % [dir, who.PackId], "%s/portraits/units/%s.png" % [dir, troop.PackId]]:
		p80.save_png(path)
		written.append(path)
	var mini := Image.create(61, 25, false, Image.FORMAT_RGBA8)
	mini.fill(Color(0.4, 0.6, 0.8))
	var mini_path := "%s/miniatures/characters/%s.png" % [dir, who.PackId]
	mini.save_png(mini_path)
	written.append(mini_path)
	Art.Reset()

	# Character Status: the portrait fills the placeholder, label hidden.
	ui.OpenCharacterStatusWindow(who)
	for _i in 3:
		await process_frame
	csw = _window_titled_like(ui, "Status_" + who.Name)
	if csw == null:
		quit(1)
		return
	var rect: Control = csw.get_node(CharacterStatusWindow.PortraitPath)
	var pic: TextureRect = rect.get_node_or_null("Picture")
	_check(pic != null and pic.texture != null and pic.texture.get_width() == 80, "Character Status shows the 80x80 portrait")
	_check(pic != null and pic.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "the portrait keeps its aspect, centred")
	var lbl: Label = Lq.first_or_null(rect.get_children(), func(c) -> bool: return c is Label)
	_check(lbl != null and not lbl.visible, "the placeholder text is hidden under the portrait")

	# Unit Status: the unit's portrait.
	ui.OpenUnitStatusWindow(troop)
	for _i in 3:
		await process_frame
	var usw: DraggableWindow = _window_titled_like(ui, "Status_" + troop.Name)
	var upic: TextureRect = usw.get_node(UnitStatusWindow.PortraitPath).get_node_or_null("Picture") if usw != null else null
	_check(upic != null and upic.texture != null, "Unit Status shows the unit's portrait")

	# Defenses window: the miniature beside the name.
	ui.OnDefenseClicked(home)
	for _i in 3:
		await process_frame
	var dw: DraggableWindow = _window_titled_like(ui, home.Name)
	var row: Button = _row_for(dw, who)
	_check(row != null and row.has_meta("miniature") and row.icon != null and row.icon.get_width() == 61, "the Defenses personnel row carries the 61x25 miniature")

	# Message window: the character's portrait on a message about them.
	var msg := GameMessage.new("Test", "A message about %s." % who.Name, Enums.MessageCategory.Missions, StrategicTickManager.Today, home, who)
	_check(MessageWindow.MessagePicture(msg) != null and MessageWindow.MessagePicture(msg).get_width() == 80, "a message about a character carries their portrait")
	var plain := GameMessage.new("Test", "About nobody.", Enums.MessageCategory.Missions, StrategicTickManager.Today, null, null)
	_check(MessageWindow.MessagePicture(plain) == null, "a message about nobody carries no picture")

	# --- Remove the files: placeholders again, and no stale face on repaint. ---
	for path in written:
		DirAccess.remove_absolute(path)
	Art.Reset()
	csw.Populate(who)
	_check(rect.get_node_or_null("Picture") == null and lbl.visible, "repainting after the files are gone removes the portrait and shows the placeholder")

	print("[portraits] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _row_for(w: DraggableWindow, c: Character) -> Button:
	if w == null:
		return null
	for n in w.find_children("*", "Button", true, false):
		if "CharacterData" in n and n.CharacterData == c:
			return n
	return null


## Windows are keyed by name with the spaces stripped ("Status_MonMothma").
static func _window_titled_like(ui: UIManager, part: String) -> DraggableWindow:
	var key := part.replace(" ", "")
	for name in ui._openWindows.keys():
		var w: DraggableWindow = ui._openWindows[name]
		if is_instance_valid(w) and (str(name).contains(part) or str(name).contains(key)):
			return w
	return null
