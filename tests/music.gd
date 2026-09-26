extends SceneTree
## The original's score in the game (docs/music-plan.md, phases 2 and 3), on a
## synthetic one-second tone (tests/fixtures/music_test.ogg, made with FFmpeg's
## sine source - never the original's) standing in for every track:
##   - pack.json `music` loads, and rule 24 refuses a bad map;
##   - without the art set's tracks nothing plays;
##   - the Cockpit plays the `menu` track, looped, on the Music bus, and asking
##     again does not restart it; the volume drives the bus and is kept; Play
##     Music off stops it and on starts it again; a movie holds it;
##   - a game plays its playlist (Rebellion 2's model): how the war goes -
##     inhabited worlds 3:1 strong advantage, 2:1 advantage, 1:2 or worse
##     disadvantage, x10 when the other side holds none - first, then three
##     `play` tracks, then again; none looped;
##   - a Battle Alert's cue replaces it (not restarted by a second alert), a
##     battle's result cue by how it came out for this side; when the battle's
##     windows are gone the playlist goes on.
## Game Options' switch and knob are tested in tests/options_screen.gd.
## Writes and removes its own files under user://.
##
##   .\tools\run-gd.ps1 tests/music.gd

const MusicLib := preload("res://src/ui/music.gd")
const MoviesLib := preload("res://src/ui/movies.gd")
const Art := preload("res://src/ui/artwork.gd")
const Fixture := "res://tests/fixtures/music_test.ogg"
const MovieFixture := "res://tests/fixtures/movie_test.ogv"
const ArtRoot := "user://test-music-art"
const Settings := "user://test-music.cfg"

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[music] ok   %s" % what)
	else:
		_fails += 1
		print("[music] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true   # only what this test writes counts
	Art.UserArtRoot = ArtRoot
	_remove(ArtRoot)
	MusicLib.SettingsFile = Settings
	DirAccess.remove_absolute(Settings)
	MusicLib._loaded = false
	MusicLib.PlayMusic = true
	MusicLib.Volume = MusicLib.DEFAULT_VOLUME
	MusicLib.PlayHeadless = true
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	var m: PackDefs.PackManifest = FactionRegistry.Pack.Manifest
	var set_ref := func(n: int) -> String: return "swr-original:music/%d.ogg" % n
	_check(m.Id == "star-wars-rebellion" and m.MusicGiven and m.Music.size() == 15
		and m.Music["menu"] == [set_ref.call(300)] and m.Music["play"] == [set_ref.call(301), set_ref.call(302), set_ref.call(303)]
		and m.Music["strong_advantage.alliance"] == [set_ref.call(305)] and m.Music["advantage.empire"] == [set_ref.call(310)]
		and m.Music["battle_alert"] == [set_ref.call(307)] and m.Music["battle_victory.empire"] == [set_ref.call(314)],
		"the Star Wars pack's music: menu 300, play 301-303, the sides' standings, the battle cues (%d moments)" % m.Music.size())
	_Rule24()

	# No art set: no track, nothing plays.
	_check(MusicLib.Track("menu").is_empty(), "without the art set's music there is no track")
	MusicLib.Play(self, "menu")
	await process_frame
	_check(MusicLib.Playing().is_empty(), "... and nothing plays")

	# The art set's music (the test tone under every name) - all but 309 and
	# 313, which the pack does not use.
	var dir := "%s/swr-original/music" % ArtRoot
	DirAccess.make_dir_recursive_absolute(dir)
	var bytes := FileAccess.get_file_as_bytes(Fixture)
	_check(bytes.size() > 1000, "the test tone is there (%d bytes)" % bytes.size())
	for n in [300, 301, 302, 303, 305, 306, 307, 308, 310, 311, 314, 315]:
		var f := FileAccess.open("%s/%d.ogg" % [dir, n], FileAccess.WRITE)
		f.store_buffer(bytes)
		f.close()
	var file := func(n: int) -> String: return "%s/%d.ogg" % [dir, n]
	_check(MusicLib.Track("menu") == file.call(300), "with it, menu's track is the art set's music/300.ogg")
	_check(MusicLib.Tracks("play") == [file.call(301), file.call(302), file.call(303)], "play's pool is 301-303")

	# The Cockpit plays it.
	var menu: Control = load("res://Menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	await process_frame
	var player: AudioStreamPlayer = MusicLib._player
	_check(MusicLib.Playing() == file.call(300), "the Cockpit plays the menu track")
	_check(player != null and player.bus == MusicLib.BUS and AudioServer.get_bus_index(MusicLib.BUS) >= 0, "... on the Music bus")
	_check(player != null and player.stream is AudioStreamOggVorbis and (player.stream as AudioStreamOggVorbis).loop, "... looped")
	var stream: AudioStream = player.stream if player != null else null
	MusicLib.Play(self, "menu")
	_check(MusicLib._player == player and player.stream == stream, "asking for it again does not restart it")

	# The volume.
	MusicLib.SetVolume(0.25)
	var bus := MusicLib.Bus()
	_check(is_equal_approx(AudioServer.get_bus_volume_db(bus), linear_to_db(0.25)) and not AudioServer.is_bus_mute(bus), "volume 0.25 sets the Music bus to %.1f dB" % linear_to_db(0.25))
	MusicLib.SetVolume(0.0)
	_check(AudioServer.is_bus_mute(bus), "volume 0 mutes it")
	MusicLib.SetVolume(0.6)
	var cfg := ConfigFile.new()
	_check(cfg.load(Settings) == OK and is_equal_approx(float(cfg.get_value("music", "volume", -1.0)), 0.6), "the volume is kept in the settings file")
	MusicLib._loaded = false
	MusicLib.Volume = 1.0
	MusicLib.Load()
	_check(is_equal_approx(MusicLib.Volume, 0.6), "... and read back")

	# Play Music off and on.
	MusicLib.SetPlayMusic(false)
	_check(MusicLib.Playing().is_empty(), "Play Music off stops it")
	MusicLib.Play(self, "menu")
	_check(MusicLib.Playing().is_empty(), "... and nothing starts while it is off")
	MusicLib.SetPlayMusic(true)
	_check(MusicLib.Playing() == file.call(300), "Play Music on starts the moment's track again")

	# A movie holds it and gives it back.
	var movie: Node = MoviesLib.Player.new()
	var paths: Array[String] = [MovieFixture]
	movie.Paths = paths
	root.add_child(movie)
	await process_frame
	_check(is_instance_valid(movie) and not str(movie.Playing()).is_empty() and MusicLib.Playing().is_empty(), "a movie holds the music")
	movie.Skip()
	await process_frame
	_check(not is_instance_valid(movie) and MusicLib.Playing() == file.call(300), "when it ends the music plays again")

	# A game: its playlist in place of the Cockpit's music.
	menu.queue_free()
	await process_frame
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 3:
		await process_frame
	(main as GameManager).MenuOpened(true)   # the clock stops: nothing moves under the test
	var ui: UIManager = main.get_node("UIManager")
	var side: Faction = GameSettings.LocalFaction()
	var other: Faction = Lq.first_or_null(FactionRegistry.Playable, func(f: Faction) -> bool: return f != side)
	var standing := MusicLib.Standing(side)
	var first := MusicLib.Playing()
	var want: Array[String] = MusicLib.Tracks("play") if standing.is_empty() else MusicLib.Tracks("%s.%s" % [standing, side.Id])
	_check(MusicLib._mode == "playlist" and want.has(first), "a game starts its playlist with how the war goes (%s, ratio %d): %s"
		% [standing if not standing.is_empty() else "even", MusicLib.Ratio(side), first.get_file()])
	_check(MusicLib._player != null and not (MusicLib._player.stream as AudioStreamOggVorbis).loop, "... not looped")

	# How the war goes: inhabited worlds only, the neutrals left out.
	var cases := [[3, 1, "strong_advantage"], [2, 1, "advantage"], [5, 4, ""], [1, 1, ""], [1, 2, "disadvantage"], [1, 3, "disadvantage"],
		[20, 0, "advantage"], [30, 0, "strong_advantage"], [0, 0, "disadvantage"]]
	for c in cases:
		_worlds(side, other, c[0], c[1])
		_check(MusicLib.Standing(side) == c[2], "%d worlds against %d: ratio %d, %s" % [c[0], c[1], MusicLib.Ratio(side), c[2] if c[2] != "" else "neither (a play track)"])

	# The cadence: the standing's track, three from play, the standing's again.
	_worlds(side, other, 3, 1)
	MusicLib.StartGame(self)
	var order: Array[String] = [MusicLib.Playing()]
	for _i in 4:
		MusicLib._finished()
		order.append(MusicLib.Playing())
	var strong: String = MusicLib.Tracks("strong_advantage.%s" % side.Id)[0]
	var pool := MusicLib.Tracks("play")
	_check(order[0] == strong and pool.has(order[1]) and pool.has(order[2]) and pool.has(order[3]) and order[4] == strong,
		"strong advantage, three from play, strong advantage: %s" % ", ".join(order.map(func(p: String) -> String: return p.get_file())))

	# A Battle Alert's cue, not restarted by a second; a result's, by the outcome.
	MusicLib.Cue(self, "battle_alert", false)
	_check(MusicLib.InCue() and MusicLib.Playing() == file.call(307), "a Battle Alert plays its cue, 307, in place of the playlist")
	var cue_stream: AudioStream = MusicLib._player.stream
	MusicLib.Cue(self, "battle_alert", false)
	_check(MusicLib._player.stream == cue_stream, "a second alert does not restart it")
	var won := _report(side, other, false, false)
	var lost := _report(side, other, true, false)
	var even := _report(side, other, true, true)
	_check(UIManager.BattleMusic(won) == "battle_victory.%s" % side.Id and UIManager.BattleMusic(lost) == "battle_defeat.%s" % side.Id
		and UIManager.BattleMusic(even) == "battle_draw.%s" % side.Id, "a battle's result music: victory, defeat, draw for this side")
	MusicLib.Cue(self, UIManager.BattleMusic(won), true)
	_check(MusicLib.Playing() == MusicLib.Tracks("battle_victory.%s" % side.Id)[0], "a won battle's results play its victory cue (%s)" % MusicLib.Playing().get_file())
	MusicLib._player.stop()
	MusicLib._finished()
	_check(MusicLib.InCue() and MusicLib.Playing().is_empty(), "a cue that ends is silence - the playlist waits for the windows")
	MusicLib.Cue(self, "battle_victory.nobody", true)
	_check(MusicLib.InCue() and MusicLib._event == "battle_victory.%s" % side.Id, "a moment with no track changes nothing")

	# The battle's windows gone: the playlist goes on.
	var alert := Control.new()
	alert.name = "BattleAlertWindow"
	ui.add_child(alert)
	var results := Control.new()
	results.name = "BattleResultsWindow"
	ui.add_child(results)
	alert.queue_free()
	await process_frame
	await process_frame
	_check(MusicLib.InCue(), "the alert gone, its results still up: the cue holds")
	results.queue_free()
	await process_frame
	await process_frame
	_check(MusicLib._mode == "playlist" and not MusicLib.Playing().is_empty(), "the results gone too: the playlist goes on (%s)" % MusicLib.Playing().get_file())

	# Play Music off and on in a game.
	MusicLib.SetPlayMusic(false)
	_check(MusicLib.Playing().is_empty(), "Play Music off silences the playlist")
	MusicLib.SetPlayMusic(true)
	_check(MusicLib._mode == "playlist" and not MusicLib.Playing().is_empty(), "... and on starts it again")

	main.queue_free()
	await process_frame
	_finish()


## The first `mine` worlds this side's and inhabited, the next `theirs` the
## other side's, the rest uninhabited (which never count).
func _worlds(side: Faction, other: Faction, mine: int, theirs: int) -> void:
	var i := 0
	for p: Planet in GameState.AllPlanets():
		p.IsInhabited = i < mine + theirs
		if i < mine:
			p.ControllingFaction = side
		elif i < mine + theirs:
			p.ControllingFaction = other
		i += 1


func _report(side: Faction, other: Faction, side_lost: bool, draw: bool) -> FleetBattleManager.BattleReport:
	var r := FleetBattleManager.BattleReport.new()
	r.Ours = Fleet.new()
	r.Ours.Faction = side
	r.Theirs = Fleet.new()
	r.Theirs.Faction = other
	r.WeLost = side_lost
	r.TheirsLost = not side_lost or draw
	r.DrawBothLost = draw
	return r


## Rule 24 on copies of the manifest's `music`.
func _Rule24() -> void:
	var pack: PackLoader.LoadedPack = FactionRegistry.Pack
	var saved: Variant = pack.Manifest.MusicRaw
	var cases := [
		[{"menu": "swr-original:music/300.ogg"}, ""],
		[{"_comment": "an author's note", "menu": "swr-original:music/301.ogg"}, ""],
		[{"play": ["swr-original:music/301.ogg", "swr-original:music/302.ogg"], "battle_alert": "swr-original:music/307.ogg"}, ""],
		[{"strong_advantage.empire": "swr-original:music/311.ogg", "battle_draw.alliance": ["swr-original:music/315.ogg"]}, ""],
		["not an object", "must be an object"],
		[{"intro": "swr-original:music/300.ogg"}, "is not a moment"],
		[{"advantage.rebels": "swr-original:music/306.ogg"}, "names no faction"],
		[{"menu": []}, "names no track"],
		[{"menu": 5}, "each track is a text reference"],
		[{"play": ["swr-original:music/301.ogg", ""]}, "each track is a text reference"],
		[{"menu": "other-set:music/300.ogg"}, "which art_sets does not declare"],
		[{"menu": "swr-original:music/300.wav"}, "is not an .ogg track"],
		[{"menu": "no-such-file.ogg"}, "is not in"],
	]
	for c in cases:
		pack.Manifest.MusicRaw = c[0]
		pack.Manifest.MusicGiven = true
		var errors: Array[String] = []
		PackLoader._validate_music(pack, FactionRegistry.LoadedDir, errors)
		var want: String = c[1]
		var ok: bool = errors.is_empty() if want.is_empty() else (errors.size() >= 1 and errors[0].contains(want))
		_check(ok, "rule 24: %s -> %s" % [JSON.stringify(c[0]), str(errors) if not errors.is_empty() else "accepted"])
	pack.Manifest.MusicRaw = saved


func _finish() -> void:
	MusicLib.Stop()
	_remove(ArtRoot)
	DirAccess.remove_absolute(Settings)
	MusicLib.SettingsFile = MusicLib.SETTINGS
	MusicLib._loaded = false
	MusicLib.PlayHeadless = false
	Art.Reset()
	print("[music] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


static func _remove(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in DirAccess.get_directories_at(path):
		_remove("%s/%s" % [path, sub])
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute("%s/%s" % [path, file])
	DirAccess.remove_absolute(path)
