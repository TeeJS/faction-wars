extends SceneTree
## A click is not lost to a repaint (BACKLOG #55; TeeJ, 2026-09-27: right-click,
## Mission, click an enemy battery - "nothing happened"). A day's refresh
## rebuilds every open window; one landing between a click's press and its
## release replaced the button under the mouse and the release did nothing.
## Now a button held on a window holds its repaint until the release
## (DraggableWindow.CanRefresh), and the repaint follows. On the System
## Defenses window in the original's look (stand-in pictures), Han Solo and
## Chewbacca's Mission crosshair on an enemy Planetary Battery:
##   - with no click under way, the day's refresh rebuilds the window at once;
##   - pressed, a day passes: the card under the mouse stays; released, the
##     held-back repaint follows;
##   - the crosshair's click with a day passing mid-click: the battery is the
##     target.
## Writes and removes its own files under user://.
##
##   .\tools\run-gd.ps1 tests/window_click_refresh.gd

const Art := preload("res://src/ui/artwork.gd")
const ArtRoot := "user://test-window-click-art"

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[window_click_refresh] ok   %s" % what)
	else:
		_fails += 1
		print("[window_click_refresh] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = ArtRoot
	_remove(ArtRoot)
	var dir := "%s/swr-original" % ArtRoot
	for sub in ["windows", "tabs"]:
		DirAccess.make_dir_recursive_absolute("%s/%s" % [dir, sub])
	_png("%s/windows/defense_background.png" % dir, 235, 304, Color(0.1, 0.1, 0.3))
	for n in ["personnel", "troops", "fighters", "planetary_shield", "planetary_battery"]:
		_png("%s/tabs/%s.alliance.png" % [dir, n], 30, 30, Color(0.5, 0.5, 0.5))
	FactionRegistry.EnsureLoaded()
	Art.Reset()
	MpSetup.reset()
	GameSettings.PendingLoadPath = ""
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	GameSettings.PlayerFaction = FactionRegistry.ById("alliance")
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 6:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	var briefing: Node = ui.Briefing()
	if briefing != null:
		briefing.Skip()
		briefing.Skip()
	await process_frame

	var us: Faction = GameSettings.PlayerFaction
	var them: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool:
		return p.ControllingFaction != null and p.ControllingFaction != us and p.ControllingFaction != FactionRegistry.Neutral)
	var team: Array = Lq.where(GameState.ActiveRoster, func(c: Character) -> bool: return c.PackId in ["han_solo", "chewbacca"])
	_check(them != null and team.size() == 2, "an enemy system, and Han Solo and Chewbacca")
	if them == null or team.size() != 2:
		_finish(main)
		return
	them.AddFacility("turbolaser_battery")
	IntelManager.Capture(us, them, StrategicTickManager.Today, IntelManager.EspionageCategories)
	ui.OnDefenseClicked(them)
	for _i in 3:
		await process_frame
	var w: DraggableWindow = ui._openWindows.get(them.Name + " Defenses")
	_check(w != null and w._original, "the System Defenses window, in the original's look")
	if w == null:
		_finish(main)
		return
	(w.get_node("%DefenseTabs") as TabContainer).current_tab = 4
	for _i in 3:
		await process_frame

	# No click under way: the day's refresh rebuilds at once.
	var before: int = _card_id(w)
	ui.RefreshActiveWindows(StrategicTickManager.Today)
	await process_frame
	_check(before != 0 and _card_id(w) not in [0, before], "no click under way: a day's refresh rebuilds the window at once")

	# A plain click on the battery, a day passing in the middle of it: the
	# window waits for the release, then the refresh follows.
	var card: Button = _card(w)
	var card_id: int = card.get_instance_id()
	var at: Vector2 = card.get_global_rect().get_center()
	_move(at)
	await process_frame
	_button(at, true)
	await process_frame
	ui.RefreshActiveWindows(StrategicTickManager.Today)
	await process_frame
	_check(_card_id(w) == card_id and w._pendingRefresh, "pressed on the battery, a day passes: the window waits (the card under the mouse stays)")
	_button(at, false)
	for _i in 3:
		await process_frame
	_check(not w._pendingRefresh and _card_id(w) not in [0, card_id], "released: the held-back refresh follows")

	# The crosshair: pressed on the battery, a day, released - the battery is
	# the target (Create Mission opens on it).
	w.StartMissionTargeting(team, ui)
	card = _card(w)
	at = card.get_global_rect().get_center()
	_move(at)
	await process_frame
	_button(at, true)
	await process_frame
	ui.RefreshActiveWindows(StrategicTickManager.Today)
	await process_frame
	_button(at, false)
	for _i in 3:
		await process_frame
	var label := _target_label(w)
	var battery: Facility = Lq.first_or_null(them.Facilities, func(f: Facility) -> bool: return f.Family() == "turbolaser_battery")
	_check(not ui.IsTargeting and battery != null and label.contains(battery.Name()),
		"Han Solo and Chewbacca's Mission crosshair, a day passing mid-click: the battery is the target ('%s')" % label)
	_finish(main)


## The live battery card's instance id, 0 when none (a freed card cannot be compared).
func _card_id(w: Node) -> int:
	var c: Button = _card(w)
	return c.get_instance_id() if c != null else 0


func _card(w: Node) -> Button:
	var found: Array = []
	_collect(w, found)
	return found[0] if not found.is_empty() else null


func _collect(n: Node, out: Array) -> void:
	if n is Button and n.has_meta("defence_type") and str(n.get_meta("defence_type")) == "turbolaser_battery" and not n.is_queued_for_deletion():
		out.append(n)
	for c in n.get_children():
		_collect(c, out)


func _move(at: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = at
	m.global_position = at
	root.push_input(m, true)


func _button(at: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = at
	e.global_position = at
	root.push_input(e, true)


## The Create Mission window's "Target:" line, or "".
func _target_label(n: Node) -> String:
	if n is Label and (n as Label).text.begins_with("Target:"):
		return (n as Label).text
	for c in n.get_children():
		var t := _target_label(c)
		if not t.is_empty():
			return t
	return ""


func _finish(main: Node) -> void:
	if main != null:
		main.queue_free()
	_remove(ArtRoot)
	Art.Reset()
	print("[window_click_refresh] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


static func _png(path: String, w: int, h: int, color: Color) -> void:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(color)
	img.save_png(path)


static func _remove(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in DirAccess.get_directories_at(path):
		_remove("%s/%s" % [path, sub])
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute("%s/%s" % [path, file])
	DirAccess.remove_absolute(path)
