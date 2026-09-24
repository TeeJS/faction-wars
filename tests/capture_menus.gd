extends SceneTree
## Renders the original-style pop-up menus to PNGs, to lay beside TeeJ's
## screenshots of the original's: a character's menu (its Command caret) on a
## system's Personnel page, and the Speed Control's menu. Needs a window (NOT
## --headless), like tests/capture_sector.gd:
##
##   Godot_console.exe --path . --resolution 1440x850 -s tests/capture_menus.gd -- --out=C:/tmp/menus [--side=empire]

func _init() -> void:
	await process_frame
	var out := _arg("--out=", "user://menus")
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	var side := _arg("--side=", "")
	if not side.is_empty():
		GameSettings.PlayerFaction = FactionRegistry.ById(side)
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 8:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	var us: Faction = GameSettings.PlayerFaction
	var who: Character = Lq.first_or_null(GameState.ActiveRoster, func(c: Character) -> bool:
		return c.Faction == us and c.Attached is Planet and c.CanTakeOrders())
	var home: Planet = who.Attached
	ui.OnDefenseClicked(home)
	for _i in 4:
		await process_frame

	# The character's menu, where the card is.
	var menu: PopupMenu = null
	for n in ui.find_children("*", "PopupMenu", true, false):
		var m := n as PopupMenu
		if m.item_count > 3 and m.get_item_text(0) == "Move" and Lq.any(range(m.item_count), func(i: int) -> bool: return m.get_item_text(i) == "Command"):
			menu = m
			break
	var shots := 0
	if menu != null:
		var card: Control = menu.get_parent() as Control
		var at := Vector2i(card.global_position + Vector2(30, 20)) if card != null else Vector2i(400, 300)
		menu.popup(Rect2i(at, Vector2i.ZERO))
		for _i in 4:
			await process_frame
		_save("%s/character_menu.png" % out, Rect2i(at - Vector2i(40, 40), menu.size + Vector2i(80, 80)))
		shots += 1
		menu.hide()
	else:
		print("[capture_menus] no character menu found")

	# The Speed Control's menu.
	var gm: Node = main   # Main.tscn's root is the GameManager
	var speed: PopupPanel = gm.get("_oSpeedMenu") if gm != null else null
	if speed != null:
		const OriginalMenu := preload("res://src/ui/original_menu.gd")
		OriginalMenu.MarkSpeed(speed, int(gm.get("_speed")))
		speed.popup(Rect2i(Vector2i(300, 120), Vector2i.ZERO))
		for _i in 4:
			await process_frame
		_save("%s/speed_menu.png" % out, Rect2i(Vector2i(260, 80), speed.size + Vector2i(80, 80)))
		shots += 1
	else:
		print("[capture_menus] no original speed menu (art missing?)")
	print("[capture_menus] %d pictures -> %s" % [shots, out])
	quit(0 if shots == 2 else 1)


func _save(path: String, region: Rect2i) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	region = region.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	img.get_region(region).save_png(path)


func _arg(prefix: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return fallback
