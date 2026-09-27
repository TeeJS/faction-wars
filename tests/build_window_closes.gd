extends SceneTree
## The Build Selection window closes once a job is added (BACKLOG #54; TeeJ,
## 2026-09-27: "build window should close after successfully adding a job").
## It closed only when the order said how many were queued - and head-to-head
## an order is only accepted (CommandBus.issue: success, no count), applied
## with the phase, so the window stayed. On the original's window (stand-in
## pictures), at a shipyard of ours:
##   - single player: an order queues it and the window closes;
##   - head-to-head: an order goes to the opponent and the window closes;
##   - head-to-head, short of maintenance: refused here with its reason (as the
##     applier would), nothing sent, the window stays.
## Writes and removes its own files under user://; the session's mailbox too.
##
##   .\tools\run-gd.ps1 tests/build_window_closes.gd

const Art := preload("res://src/ui/artwork.gd")
const ArtRoot := "user://test-build-close-art"
const Box := "user://test-build-close-box"

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[build_window_closes] ok   %s" % what)
	else:
		_fails += 1
		print("[build_window_closes] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = ArtRoot
	_remove(ArtRoot)
	_remove(Box)
	var dir := "%s/swr-original" % ArtRoot
	for sub in ["windows", "buttons"]:
		DirAccess.make_dir_recursive_absolute("%s/%s" % [dir, sub])
	_png("%s/windows/build_plate.png" % dir, 210, 261, Color(0.1, 0.1, 0.3))
	_png("%s/windows/list_starfield.png" % dir, 200, 100, Color(0, 0, 0))
	for b in ["build_ok", "build_cancel", "build_up", "build_down", "build_encyclopedia", "build_list_open"]:
		_png("%s/buttons/%s.png" % [dir, b], 20, 20, Color(0.5, 0.5, 0.5))
	FactionRegistry.EnsureLoaded()
	Art.Reset()
	MpSetup.reset()
	GameSettings.PendingLoadPath = ""
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	GameSettings.PlayerFaction = FactionRegistry.Playable[0]
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
	Economy.For(us).RefinedMaterials = 5000
	var world: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool:
		return p.ControllingFaction == us and Lq.any(p.Facilities, func(f: Facility) -> bool: return f.HasRole("produces_unit")))
	_check(ui.BuildSelectionScript.CanBuild(), "the original's Build Selection window (stand-in pictures)")
	if world == null:
		# No shipyard of ours in this galaxy: give one of our worlds one.
		world = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool: return p.ControllingFaction == us)
		if world != null:
			world.AddFacility(FacilityCatalog.FirstWithRole("produces_unit").Family)
	_check(world != null, "a shipyard of ours (%s)" % (world.Name if world != null else "none"))
	if world == null:
		_finish(main)
		return
	ui.OnEconomyClicked(world)
	for _i in 3:
		await process_frame
	var ew: Node = ui._openWindows.get(world.Name + " Economy")

	# Single player.
	var bs: Node = await _open(ui, ew, world)
	var free: int = _free_item(bs, world)
	var before: int = world.ShipyardQueue.size()
	bs._choice = free
	bs._show(free)
	bs._on_build()
	await process_frame
	_check(world.ShipyardQueue.size() == before + 1 and _closed(ui), "single player: the order queues it (%d -> %d) and the window closes" % [before, world.ShipyardQueue.size()])

	# Head-to-head: the order is only accepted here.
	DirAccess.make_dir_recursive_absolute(Box)
	var them: Faction = Lq.first_or_null(FactionRegistry.Playable, func(f: Faction) -> bool: return f != us)
	var session := LockstepSession.new(MailboxTransport.new(Box, "host", "guest"), us, them, true)
	CommandBus.Immediate = false
	CommandBus.Session = session
	bs = await _open(ui, ew, world)
	bs._choice = free
	bs._show(free)
	bs._on_build()
	await process_frame
	_check(_sent(session) == 1 and _closed(ui), "head-to-head: the order goes to the opponent and the window closes")

	# Head-to-head, short of maintenance: refused here, the window stays.
	bs = await _open(ui, ew, world)
	var named: String = str(bs._items[free].name)
	var def: PackDefs.UnitDef = Lq.first_or_null(MilitaryCatalog.All(), func(r) -> bool: return r.DisplayName == named)
	var kept: int = def.MaintenanceCost
	def.MaintenanceCost = 999999
	bs._choice = free
	bs._show(free)
	bs._on_build()
	await process_frame
	_check(_sent(session) == 1 and not _closed(ui), "head-to-head, beyond the maintenance: nothing sent, the window stays")
	def.MaintenanceCost = kept
	bs.CloseWindow()
	CommandBus.Reset()
	_finish(main)


func _open(ui: UIManager, ew: Node, world: Planet) -> Node:
	ew.OpenBuildChooser(world, "produces_unit")
	for _i in 3:
		await process_frame
	return ui._openWindows.get("Build Selection")


## The first item nothing blocks here.
func _free_item(bs: Node, world: Planet) -> int:
	for i in bs._items.size():
		var def: PackDefs.UnitDef = Lq.first_or_null(MilitaryCatalog.All(), func(r) -> bool: return r.DisplayName == str(bs._items[i].name))
		if def != null and world.CanQueueUnit(def, world).ok:
			return i
	return 0


func _closed(ui: UIManager) -> bool:
	var w: Variant = ui._openWindows.get("Build Selection")
	return w == null or not is_instance_valid(w) or (w as Node).is_queued_for_deletion()


func _sent(s: LockstepSession) -> int:
	var n := 0
	for p in s._batch:
		n += (s._batch[p] as Array).size()
	return n


func _finish(main: Node) -> void:
	if main != null:
		main.queue_free()
	_remove(ArtRoot)
	_remove(Box)
	Art.Reset()
	print("[build_window_closes] %d checks, %d failed" % [_checks, _fails])
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
