extends SceneTree
## The original's sector window docks clear of the bottom bars (TeeJ,
## 2026-09-23: at the map's top it ran into the GID band and the HUD row and
## made them unusable): on either side, the 235x360 window drawn twice as
## large lies under the top row and above the GID band, measured on the
## running screen rather than on the constants.
##
##   .\tools\run-gd.ps1 tests/sector_dock.gd

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[sector_dock] ok   %s" % what)
	else:
		_fails += 1
		print("[sector_dock] FAIL %s" % what)


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
	var ui: UIManager = main.get_node("UIManager")

	# The bars as laid out: the top row, the GID band, the HUD row.
	var top_row: Control = ui.get_node("Resources")
	var hud: Control = ui.get_node("HBoxContainer")
	var gid: GidBar = Lq.first_or_null(main.find_children("*", "GidBar", true, false), func(_n) -> bool: return true)
	var band: Control = Lq.first_or_null(gid.get_children() if gid != null else [], func(n: Node) -> bool: return n is PanelContainer and (n as Control).anchor_top == 1.0)   # not the GID key (upper left)
	_check(top_row != null and hud != null and band != null, "the top row, the GID band and the HUD row are on screen")
	if band == null:
		_finish()
		return
	print("[sector_dock] viewport %s, band %s, hud %s, top %s" % [str(root.get_visible_rect()), str(band.get_global_rect()), str(hud.get_global_rect()), str(top_row.get_global_rect())])
	var size := Vector2(SectorWindow.OW, SectorWindow.OH) * SectorWindow.K
	for right in [true, false]:
		var r := Rect2(SectorWindow.DockPosition(right), size)
		var side: String = "right" if right else "left"
		_check(r.position.y >= top_row.get_global_rect().end.y, "docked %s, it starts under the top row (%.0f >= %.0f)" % [side, r.position.y, top_row.get_global_rect().end.y])
		_check(r.end.y <= band.get_global_rect().position.y, "docked %s, it ends above the GID band (%.0f <= %.0f)" % [side, r.end.y, band.get_global_rect().position.y])
		_check(not r.intersects(hud.get_global_rect()), "docked %s, it leaves the HUD row clear" % side)
	_finish()


func _finish() -> void:
	print("[sector_dock] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
