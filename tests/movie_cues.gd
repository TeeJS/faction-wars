extends SceneTree
## The movies at their moments in a game (docs/cutscenes-plan.md, phase 4),
## on the synthetic test movie under each mapped name:
##   - the simulation names the moment (EventBus.Cue) and the sides it
##     concerns; the UI plays the pack's movie only for its own side;
##   - a real Death Star bombardment that destroys a system cues
##     "system_destroyed" for the destroyer and the holder;
##   - a war won: the winner's victory movie, everyone else's defeat - each
##     client its own side's (Star Wars: 105/108, 106/107);
##   - a second moment while a movie plays follows it in the same player.
## Writes and removes its own files under user://.
##
##   .\tools\run-gd.ps1 tests/movie_cues.gd

const MoviesLib := preload("res://src/ui/movies.gd")
const Fixture := "res://tests/fixtures/movie_test.ogv"
const Root := "user://test-movie-cues"

var _fails := 0
var _checks := 0
var _heard: Array = []   # [event, sides]


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[movie_cues] ok   %s" % what)
	else:
		_fails += 1
		print("[movie_cues] FAIL %s" % what)


func _init() -> void:
	await process_frame
	MoviesLib.UserRoot = Root
	MoviesLib.PlayHeadless = true
	MoviesLib.LaunchPlayed = true
	_remove(Root)
	DirAccess.make_dir_recursive_absolute(Root + "/swr-original/movies")
	var bytes := FileAccess.get_file_as_bytes(Fixture)
	for n in ["101", "104", "105", "106", "107", "108"]:
		var f := FileAccess.open("%s/swr-original/movies/%s.ogv" % [Root, n], FileAccess.WRITE)
		f.store_buffer(bytes)
		f.close()

	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 5:
		await process_frame
	EventBus.OnMovieCue.append(_hear)
	var us: Faction = GameSettings.LocalFaction()
	var them: Faction = FactionRegistry.Opponents(us)[0]

	# Ours: it plays.
	EventBus.Cue("system_destroyed", [them, us])
	await process_frame
	await process_frame
	var p: Node = root.get_node_or_null("MoviePlayer")
	_check(p != null and str(p.Playing()).ends_with("101.ogv") and paused, "a system destroyed, ours: 101 plays and the game is held")
	await _skip_all()
	_check(root.get_node_or_null("MoviePlayer") == null and not paused, "skipped: the game runs again")

	# Not ours: nothing.
	EventBus.Cue("system_destroyed", [them, null])
	await process_frame
	await process_frame
	_check(root.get_node_or_null("MoviePlayer") == null, "the other side's moment plays nothing here")

	# A real Death Star over one of our worlds.
	var ds: PackDefs.UnitDef = MilitaryCatalog.FirstWithRole("superweapon")
	var fleet: Fleet = null
	for pl in GameState.AllPlanets():
		for f in pl.OrbitingFleets:
			if fleet == null and f.Faction == them and f.Status != Enums.Status.Enroute and not f.Ships.is_empty():
				fleet = f
	var target: Planet = null
	for pl in GameState.AllPlanets():
		if target == null and pl.ControllingFaction == us and pl.CountByRole("shield") == 0:
			target = pl
	_check(ds != null and fleet != null and target != null, "a superweapon, an enemy fleet, and an unshielded world of ours")
	if ds != null and fleet != null and target != null:
		fleet.Ships.append(MilitaryCatalog.Create(ds, them, fleet.Attached))
		_heard.clear()
		BombardmentManager.Bombard(fleet, target, BombardmentManager.BombardmentMode.DestroySystem, Prng.Session, StrategicTickManager.Today)
		_check(_heard.size() == 1 and _heard[0][0] == "system_destroyed" and _heard[0][1] == [them, us],
			"destroying %s cues system_destroyed for the destroyer and the holder (%s)" % [target.Name, str(_heard)])
		await process_frame
		await process_frame
		p = root.get_node_or_null("MoviePlayer")
		_check(p != null and str(p.Playing()).ends_with("101.ogv"), "... and 101 plays for us")
		await _skip_all()

	# The war won, by us and then by them.
	var mine: String = "105" if us.Id == "alliance" else "108"
	var lost: String = "106" if us.Id == "alliance" else "107"
	_heard.clear()
	VictoryManager.Declare(us, GameState.ActiveGalaxy, StrategicTickManager.Today)
	_check(_heard.map(func(h): return h[0]) == ["victory.%s" % us.Id, "defeat.%s" % them.Id] or _heard.map(func(h): return h[0]) == ["defeat.%s" % them.Id, "victory.%s" % us.Id],
		"a war won cues the winner's victory and the other's defeat (%s)" % str(_heard.map(func(h): return h[0])))
	await process_frame
	await process_frame
	p = root.get_node_or_null("MoviePlayer")
	_check(p != null and str(p.Playing()).ends_with(mine + ".ogv") and p.Paths.size() == 1, "we won: our victory movie, %s, and only that" % mine)
	await _skip_all()
	VictoryManager.Reset()
	VictoryManager.Declare(them, GameState.ActiveGalaxy, StrategicTickManager.Today)
	await process_frame
	await process_frame
	p = root.get_node_or_null("MoviePlayer")
	_check(p != null and str(p.Playing()).ends_with(lost + ".ogv"), "we lost: our defeat movie, %s" % lost)
	await _skip_all()
	VictoryManager.Reset()

	# Two moments at once: one player, one after the other.
	EventBus.Cue("system_destroyed", [us])
	EventBus.Cue("superweapon_sabotaged", [us])
	await process_frame
	await process_frame
	p = root.get_node_or_null("MoviePlayer")
	_check(p != null and p.Paths.size() == 2 and str(p.Paths[1]).ends_with("104.ogv"), "a second moment follows the first in the same player")
	await _skip_all()
	_finish()


func _skip_all() -> void:
	for _i in 6:
		var p: Node = root.get_node_or_null("MoviePlayer")
		if p == null:
			return
		p.Skip()
		await process_frame


func _hear(event: String, sides: Array) -> void:
	_heard.append([event, sides])


func _finish() -> void:
	# Nothing of this script may stay in a static list past quitting.
	EventBus.OnMovieCue.erase(_hear)
	_remove(Root)
	MoviesLib.UserRoot = MoviesLib.USER_ROOT
	print("[movie_cues] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


static func _remove(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in DirAccess.get_directories_at(path):
		_remove("%s/%s" % [path, sub])
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute("%s/%s" % [path, file])
	DirAccess.remove_absolute(path)
