extends SceneTree
## MENUS, DIALOGS, TOOLTIPS AND ONE FINDER IN A PACK'S LOOK (look.gd
## InstallPopups, look_window.gd; docs/ww2-look-plan.md phase 5). One pack per
## process:
##
##   .\tools\run-gd.ps1 tests/look_popups.gd -- --pack=ww2 --seed=12345
##   .\tools\run-gd.ps1 tests/look_popups.gd -- --pack=star-wars-rebellion --seed=12345
##
## With a look: a popup menu wears the instrument panel wherever it is made
## (and the speed menu made before the hook); a dialog is an order sheet -
## parchment, ink, command keys - over a dim that shows and goes with it and
## takes no clicks; a tooltip is a field note; the System Finder and the Game
## Menu wear the frame, the finder's systems as ledger rows in the sides'
## colours. Without one (Star Wars, no art set, the stand-ins off): none of it.

const Art := preload("res://src/ui/artwork.gd")
const StandIns := preload("res://src/ui/art_standins.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[look_popups] ok   %s" % what)
	else:
		_fails += 1
		print("[look_popups] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = "user://test-look-popups-none"
	# The plain windows, which are what a look dresses (art_standins.gd).
	StandIns.Enabled = false
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	GameSettings.PlayerFaction = FactionRegistry.Playable[0]
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 8:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	var id := FactionRegistry.LoadedId()
	_check(not GameState.ActiveGalaxy.is_empty() and main.get_script() != null and main.has_method("SetSpeed"),
		"%s: the game started (%d theatres)" % [id, GameState.ActiveGalaxy.size()])

	# A popup menu, made anywhere.
	var menu := PopupMenu.new()
	menu.add_item("Encyclopedia")
	ui.add_child(menu)
	await process_frame
	# A dialog, the way every refused order shows one.
	ui.ShowRefusal("Look test: refused.")
	await process_frame
	await process_frame
	var box: AcceptDialog = null
	for c in ui.get_children():
		if c is AcceptDialog and (c as AcceptDialog).dialog_text == "Look test: refused.":
			box = c
	_check(box != null, "%s: the refusal dialog opened" % id)
	# A tooltip's panel, as the viewport makes one.
	var tip := PopupPanel.new()
	tip.theme_type_variation = &"TooltipPanel"
	ui.add_child(tip)
	await process_frame
	var dim: CanvasLayer = root.get_node_or_null("LookDim")

	if not Look.Active():
		_check(menu.theme == null and tip.theme == null, "%s: no look - menus and tooltips as the engine draws them" % id)
		_check(box != null and box.theme == null, "a dialog as the engine draws it")
		_check(dim == null, "no dim behind it")
		ui.OpenPlanetFinder()
		for _i in 3:
			await process_frame
		var plain: Control = ui._openWindows.get("PlanetFinder")
		_check(plain != null and plain.theme == null, "the System Finder as it was drawn")
		_done()
		return

	# Menus.
	_check(menu.theme == Look.GetTheme(), "a popup menu wears the look")
	var panel: StyleBox = menu.get_theme_stylebox("panel")
	_check(panel is StyleBoxFlat and (panel as StyleBoxFlat).bg_color == Look.C("chassis_deep"), "an instrument panel: steel, brass-edged")
	var speed: Variant = main.get("_speedMenu")
	_check(speed is PopupMenu and (speed as PopupMenu).theme == Look.GetTheme(), "the speed menu, made before the hook, wears it too")

	# Dialogs.
	if box != null:
		_check(box.theme == Look.SheetTheme(), "the dialog is an order sheet")
		var sheet: StyleBox = box.get_theme_stylebox("panel")
		_check(sheet is StyleBoxTexture or (sheet is StyleBoxFlat and (sheet as StyleBoxFlat).bg_color == Look.C("paper")),
			"its body parchment")
		_check(box.get_label().get_theme_color("font_color") == Look.C("ink"), "its words in ink")
		_check(box.get_ok_button().theme_type_variation == Look.COMMAND, "its OK a command key")
		_check(box.exclusive, "it is modal")
		_check(dim != null and dim.visible and dim.layer > 100, "the screen is dimmed behind it")
		var shade: ColorRect = dim.get_node_or_null("Shade") if dim != null else null
		_check(shade != null and shade.color == Look.Dim() and shade.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"the dim is the look's, and takes no clicks")
		box.hide()
		await process_frame
		_check(dim != null and not dim.visible, "hidden, the dim goes with it")
		box.queue_free()
		await process_frame
		await process_frame
		_check(root.get_node_or_null("LookDim") == null, "closed, the dim is gone")

	# Tooltips.
	_check(tip.theme == Look.GetTheme(), "a tooltip wears the look")
	var note: StyleBox = tip.get_theme_stylebox("panel")
	_check(note is StyleBoxFlat and (note as StyleBoxFlat).bg_color == Look.C("note"), "a field note")

	# The System Finder.
	ui.OpenPlanetFinder()
	for _i in 3:
		await process_frame
	var finder: Control = ui._openWindows.get("PlanetFinder")
	_check(finder != null and finder.theme == Look.GetTheme(), "the System Finder wears the look")
	if finder != null:
		var bar: ColorRect = finder.get_node("%TitleBar")
		_check(bar.color == Look.C("chassis_deep") and bar.get_node_or_null("LookRule") != null, "its bar is steel with a brass rule")
		var field: Label = finder.get_node("MainVBox/ContentArea/Padding/VBox/SearchHBox/SearchLabel")
		_check(field.theme_type_variation == Look.HEADING, "its field label a heading")
		var list: VBoxContainer = finder.get_node("%AllList")
		var rows := 0
		var sided := 0
		var us: Faction = GameSettings.PlayerFaction
		for b in list.get_children():
			if b is Button and not b.is_queued_for_deletion():
				rows += 1
				if (b as Button).theme_type_variation != Look.ROW or (b as Button).flat:
					_check(false, "row %s is a ledger row" % (b as Button).text)
				if (b as Button).get_theme_color("font_color") == Look.SideColor(us):
					sided += 1
		_check(rows > 0, "its systems are listed (%d)" % rows)
		_check(sided > 0, "ours in our side's colour (%d)" % sided)
	ui.CloseAllWindows()
	for _i in 2:
		await process_frame

	# The Game Menu.
	ui.OnMenuButtonClicked()
	for _i in 3:
		await process_frame
	var gm: Control = ui._openWindows.get("GameMenu")
	_check(gm != null and gm.theme == Look.GetTheme(), "the Game Menu wears the look")
	if gm != null:
		for b in gm.get_node("MainVBox/ContentArea/MenuButtonsVBox").get_children():
			if b is Button:
				_check((b as Button).theme_type_variation == Look.COMMAND, "a command key: %s" % (b as Button).text)
	_done()


func _done() -> void:
	print("[look_popups] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
