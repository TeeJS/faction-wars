extends SceneTree
## The original's window sounds (TeeJ, 2026-09-28: "we are missing the sounds
## for opening/minimizing sectors, planetary defences/manufacturing/fleets").
## REBEXE: a sector window opens with STRATEGY 604 and closes with 605; a
## system's Manufacturing, Defenses, Fleet and Mission windows open with 606
## and close with 607; minimising plays 611 for the Alliance, 610 for the
## Empire, restoring 613 / 612. With the test tone standing in for the art
## set's sounds:
##   - the pack names the moments, as the original's ids;
##   - each window opens and closes with its kind's sounds;
##   - minimise and restore play the player's side's;
##   - a window already on screen only comes forward, silently;
##   - a planet window has none, and nothing sounds when the game goes.
##
##   .\tools\run-gd.ps1 tests/window_sounds.gd

const Art := preload("res://src/ui/artwork.gd")
const SoundLib := preload("res://src/ui/sound.gd")
const MusicLib := preload("res://src/ui/music.gd")
const Tone := "res://tests/fixtures/music_test.ogg"
const ArtRoot := "user://test-window-sounds-art"
const Settings := "user://test-window-sounds.cfg"
const Ids := {
	"window_open_sector": 604, "window_close_sector": 605, "window_open_system": 606, "window_close_system": 607,
	"window_minimize_alliance": 611, "window_minimize_empire": 610, "window_restore_alliance": 613, "window_restore_empire": 612,
}

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[window_sounds] ok   %s" % what)
	else:
		_fails += 1
		print("[window_sounds] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = ArtRoot
	_remove(ArtRoot)
	MusicLib.SettingsFile = Settings
	DirAccess.remove_absolute(Settings)
	SoundLib._loaded = false
	SoundLib.Volume = SoundLib.DEFAULT_VOLUME
	SoundLib.PlayHeadless = true
	FactionRegistry.EnsureLoaded()
	var m: PackDefs.PackManifest = FactionRegistry.Pack.Manifest
	var named := true
	for key in Ids:
		named = named and m.Sounds.get(key, "") == "swr-original:sound/strategy/%d.ogg" % Ids[key]
		_stand_in(str(m.Sounds.get(key, "")), FileAccess.get_file_as_bytes(Tone))
	_check(named, "the pack names the window sounds: sector 604/605, system 606/607, minimise 611/610, restore 613/612")
	Art.Reset()

	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	GameSettings.PlayerFaction = FactionRegistry.ById("alliance")
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 10:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	ui.CloseAllWindows()
	for _i in 3:
		await process_frame
	_stop()

	# A sector window.
	var sector: Sector = GameState.ActiveGalaxy[0]
	ui.OnSectorClicked(sector)
	await process_frame
	var sw: DraggableWindow = ui._openWindows.get(sector.Name)
	_check(sw != null and _heard(604), "a sector window opens with 604 (%s)" % str(_playing()))
	_stop()
	ui.OnSectorClicked(sector)
	await process_frame
	_check(_playing().is_empty(), "opened again while on screen: it comes forward, silently")
	sw.MinimizeWindow()
	await process_frame
	_check(not sw.visible and _heard(611), "minimised: the Alliance's 611")
	_stop()
	ui.OnSectorClicked(sector)
	await process_frame
	_check(sw.visible and _heard(613), "opened again from minimised: the Alliance's restore, 613")
	_stop()
	sw.CloseWindow()
	await process_frame
	_check(_heard(605) and _playing().size() == 1, "closed: 605")
	_stop()

	# A system's windows: Defenses, Fleet, Manufacturing, Missions.
	var planet: Planet = sector.Planets[0]
	var opens := {
		"Defenses": ui.OnDefenseClicked, "Fleets": ui.OnFleetClicked,
		"Economy": ui.OnEconomyClicked, "Missions": ui.OnMissionClicked,
	}
	for kind in opens:
		(opens[kind] as Callable).call(planet)
		await process_frame
		var w: DraggableWindow = ui._openWindows.get(planet.Name + " " + kind)
		_check(w != null and _heard(606), "%s opens with 606 (%s)" % [kind, str(_playing())])
		_stop()
		if w == null:
			continue
		var close: Button = w.get_node_or_null("%CloseButton")
		_check(close != null, "... it has its Close")
		if close != null:
			close.pressed.emit()
			await process_frame
			_check(_heard(607) and (not is_instance_valid(w) or w.is_queued_for_deletion()), "... and its Close closes it with 607 (%s)" % str(_playing()))
		_stop()

	# The Empire's minimise and restore.
	GameSettings.PlayerFaction = FactionRegistry.ById("empire")
	ui.OnDefenseClicked(planet)
	await process_frame
	var dw: DraggableWindow = ui._openWindows.get(planet.Name + " Defenses")
	_stop()
	dw.MinimizeWindow()
	await process_frame
	_check(_heard(610), "the Empire minimises with 610 (%s)" % str(_playing()))
	_stop()
	ui.RestoreWindow(dw)
	await process_frame
	_check(_heard(612), "... and restores from the bar with 612")
	_stop()
	GameSettings.PlayerFaction = FactionRegistry.ById("alliance")

	# A planet window: none of these.
	ui.OnPlanetClicked(planet)
	await process_frame
	_check(_playing().is_empty(), "a planet window opens silently")

	# The game going takes its windows with it, silently.
	ui.OnSectorClicked(sector)
	await process_frame
	_stop()
	root.remove_child(main)
	main.free()
	await process_frame
	_check(_playing().is_empty(), "the game going closes its windows silently (%s)" % str(_playing()))

	_remove(ArtRoot)
	DirAccess.remove_absolute(Settings)
	print("[window_sounds] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _heard(id: int) -> bool:
	return _playing().any(func(p: String) -> bool: return p.ends_with("strategy/%d.ogg" % id))


func _playing() -> Array:
	var out := []
	for n in root.get_children():
		if n is AudioStreamPlayer and n.has_meta("path") and not n.is_queued_for_deletion():
			out.append(str(n.get_meta("path")))
	return out


func _stop() -> void:
	for n in root.get_children():
		if n is AudioStreamPlayer:
			(n as AudioStreamPlayer).stop()
			n.free()


func _stand_in(ref: String, bytes: PackedByteArray) -> void:
	if ref.is_empty():
		return
	var split: PackedStringArray = PackLoader.SplitArtRef(ref)
	var path := "%s/%s/%s" % [ArtRoot, split[0], split[1]]
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()


static func _remove(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in DirAccess.get_directories_at(path):
		_remove("%s/%s" % [path, sub])
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute("%s/%s" % [path, file])
	DirAccess.remove_absolute(path)
