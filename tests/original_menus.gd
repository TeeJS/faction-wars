extends SceneTree
## The original's pop-up menus (original_menu.gd; TeeJ, 2026-09-24): every
## menu in play gets the original's box, its font and its 20-pixel rows; an
## item that opens a submenu gets the caret, in the side's colour at half
## strength; the Speed Control's menu has each speed's bars and its name, the
## speed in force in the side's colour; the item under the mouse in the
## side's colour, and a ticked item the original's tick. Needs the original's
## art.
##
##   .\tools\run-gd.ps1 tests/original_menus.gd

const OriginalMenu := preload("res://src/ui/original_menu.gd")
const OUI := preload("res://src/ui/original_ui.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[original_menus] ok   %s" % what)
	else:
		_fails += 1
		print("[original_menus] FAIL %s" % what)


func _init() -> void:
	await process_frame
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 5:
		await process_frame
	if not OriginalMenu.Enabled():
		print("[original_menus] SKIP: the original's art is not imported")
		quit(0)
		return
	var ui: UIManager = main.get_node("UIManager")

	# A menu built the way the windows build theirs: styled as it enters the tree.
	var menu := PopupMenu.new()
	menu.add_item("Move", 0)
	var sub := PopupMenu.new()
	sub.add_item("General", 1)
	menu.add_child(sub)
	menu.add_submenu_node_item("Command", sub, 2)
	menu.add_item("Retire", 3)
	menu.set_item_disabled(2, true)
	ui.add_child(menu)
	await process_frame
	_check(menu.get_theme_stylebox("panel") is OriginalMenu.MenuBox, "the menu has the original's box")
	_check(sub.get_theme_stylebox("panel") is OriginalMenu.MenuBox, "and its submenu too")
	_check(menu.get_theme_font_size("font_size") == OriginalMenu.FontPx * OUI.K, "Arial %d at the drawn scale" % OriginalMenu.FontPx)
	_check(menu.get_theme_color("font_disabled_color") == OriginalMenu.Grey, "a greyed item in (128,128,128)")
	var face: Font = menu.get_theme_font("font")
	var row: int = ceili(face.get_height(menu.get_theme_font_size("font_size"))) + menu.get_theme_constant("v_separation")
	_check(row == OriginalMenu.Pitch * OUI.K, "rows %d pixels apart (%d at the drawn scale)" % [OriginalMenu.Pitch, row])
	_check(menu.get_item_icon(1) == OriginalMenu.Caret(GameSettings.PlayerFaction), "the Command item carries the caret")
	_check(menu.get_item_icon(0) == null and menu.get_item_icon(2) == null, "no other item does")
	var caret: Image = OriginalMenu.Caret(GameSettings.PlayerFaction).get_image()
	var side: Color = OUI.SideColor(GameSettings.PlayerFaction)
	var tip: Color = caret.get_pixel(caret.get_width() - 1, caret.get_height() / 2)
	var half := Color(side.r * 0.5, side.g * 0.5, side.b * 0.5)
	_check(absf(tip.r - half.r) < 0.01 and absf(tip.g - half.g) < 0.01 and absf(tip.b - half.b) < 0.01,
		"the caret is the side's colour at half strength (%s)" % tip)
	_check(menu.get_theme_constant("item_start_padding") + menu.get_theme_stylebox("panel").content_margin_left == OriginalMenu.CaretX * OUI.K,
		"the caret %d pixels in" % OriginalMenu.CaretX)

	# The item under the mouse in the side's colour, nothing behind it (the
	# original's agent menu, captured); a ticked item's mark the original's,
	# its words still 27 in (manual p077 Fig 3.17).
	_check(menu.get_theme_color("font_hover_color") == OUI.SideColor(GameSettings.PlayerFaction)
		and menu.get_theme_stylebox("hover") is StyleBoxEmpty, "the item under the mouse in the side's colour")
	if OriginalMenu.Tick() != null:
		var ticked := PopupMenu.new()
		ticked.add_item("Galaxy Overview", 0)
		ticked.add_check_item("Manage Garrisons", 1)
		ticked.set_item_checked(1, true)
		ui.add_child(ticked)
		ticked.popup()
		await process_frame
		var tick: Texture2D = ticked.get_theme_icon("checked")
		var textAt: int = ticked.get_theme_stylebox("panel").content_margin_left + ticked.get_theme_constant("item_start_padding") 			+ tick.get_width() + ticked.get_theme_constant("h_separation")
		_check(tick == OriginalMenu.Tick() and textAt == OriginalMenu.TextX * OUI.K,
			"a ticked item has the original's tick, the words %d in (%d at the drawn scale)" % [OriginalMenu.TextX, textAt])
		var plainRow: int = ceili(face.get_height(ticked.get_theme_font_size("font_size"))) + ticked.get_theme_constant("v_separation")
		_check(tick.get_height() <= ceili(face.get_height(ticked.get_theme_font_size("font_size"))) and plainRow == OriginalMenu.Pitch * OUI.K,
			"the tick no taller than a row's words, so its row is %d too" % OriginalMenu.Pitch)
		ticked.hide()

	# A text field's own menu keeps the engine's look.
	var field := LineEdit.new()
	ui.add_child(field)
	await process_frame
	var own: PopupMenu = field.get_menu()
	_check(not (own.get_theme_stylebox("panel") is OriginalMenu.MenuBox), "a text field's own menu is left alone")

	# The Speed Control's menu.
	var speed: PopupPanel = main.get("_oSpeedMenu")
	_check(speed != null, "the Speed Control has the original's menu")
	if speed != null:
		var rows: Node = speed.get_node("Rows")
		_check(rows.get_child_count() == 5, "five speeds")
		var sideName: String = OUI.Side(GameSettings.PlayerFaction)
		var bars := true
		for i in rows.get_child_count():
			var icon: TextureRect = rows.get_child(i).get_node("Bars")
			var want: Image = OUI.Pic("speed_bars.%s.%d" % [sideName, i]).get_image()
			bars = bars and icon.texture != null and icon.texture.get_image().get_data() == want.get_data()
		_check(bars, "each row shows that speed's own bars")
		OriginalMenu.MarkSpeed(speed, 3)
		var colours: Array = []
		for r in rows.get_children():
			colours.append((r.get_node("Name") as Label).get_theme_color("font_color"))
		_check(colours[3] == side and colours.count(Color.WHITE) == 4, "the speed in force in the side's colour, the rest white")
		(rows.get_child(1) as Button).pressed.emit()
		await process_frame
		_check(int(main.get("_speed")) == 1, "choosing Very Slow sets it")
	print("[original_menus] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
