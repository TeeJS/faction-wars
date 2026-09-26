extends SceneTree
## The original's score in the game (docs/music-plan.md, phase 2), on a
## synthetic one-second tone (tests/fixtures/music_test.ogg, made with FFmpeg's
## sine source - never the original's):
##   - pack.json `music` loads, and rule 24 refuses a bad map;
##   - without the art set's track nothing plays;
##   - with it the Cockpit plays the `menu` track, looped, on the Music bus,
##     and asking again does not restart it;
##   - the volume drives the bus (0 mutes it) and is kept; Play Music off
##     stops it and on starts it again;
##   - a movie holds it and gives it back; a game starting stops it.
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
	_check(m.Id == "star-wars-rebellion" and m.MusicGiven and m.Music == {"menu": "swr-original:music/300.ogg"},
		"the Star Wars pack's music: menu 300 (%s)" % str(m.Music))
	_Rule24()

	# No art set: no track, nothing plays.
	_check(MusicLib.Track("menu").is_empty(), "without the art set's music there is no track")
	MusicLib.Play(self, "menu")
	await process_frame
	_check(MusicLib.Playing().is_empty(), "... and nothing plays")

	# The art set's 300 (the test tone under its name).
	var dir := "%s/swr-original/music" % ArtRoot
	DirAccess.make_dir_recursive_absolute(dir)
	var bytes := FileAccess.get_file_as_bytes(Fixture)
	_check(bytes.size() > 1000, "the test tone is there (%d bytes)" % bytes.size())
	var f := FileAccess.open(dir + "/300.ogg", FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()
	_check(MusicLib.Track("menu") == dir + "/300.ogg", "with it, menu's track is the art set's music/300.ogg")
	_check(MusicLib.Track("battle_alert").is_empty(), "a moment the pack does not map has none")

	# The Cockpit plays it.
	var menu: Control = load("res://Menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	await process_frame
	var player: AudioStreamPlayer = MusicLib._player
	_check(MusicLib.Playing() == dir + "/300.ogg", "the Cockpit plays the menu track")
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
	_check(MusicLib.Playing() == dir + "/300.ogg", "Play Music on starts the moment's track again")

	# A movie holds it and gives it back.
	var movie: Node = MoviesLib.Player.new()
	var paths: Array[String] = [MovieFixture]
	movie.Paths = paths
	root.add_child(movie)
	await process_frame
	_check(is_instance_valid(movie) and not str(movie.Playing()).is_empty() and MusicLib.Playing().is_empty(), "a movie holds the music")
	movie.Skip()
	await process_frame
	_check(not is_instance_valid(movie) and MusicLib.Playing() == dir + "/300.ogg", "when it ends the music plays again")

	# A game starting stops it (GameManager._ready).
	menu.queue_free()
	await process_frame
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 3:
		await process_frame
	_check(MusicLib.Playing().is_empty(), "a game starting stops the Cockpit's music")
	main.queue_free()
	await process_frame
	_finish()


## Rule 24 on copies of the manifest's `music`.
func _Rule24() -> void:
	var pack: PackLoader.LoadedPack = FactionRegistry.Pack
	var saved: Variant = pack.Manifest.MusicRaw
	var cases := [
		[{"menu": "swr-original:music/300.ogg"}, ""],
		[{"_comment": "an author's note", "menu": "swr-original:music/301.ogg"}, ""],
		["not an object", "must be an object"],
		[{"intro": "swr-original:music/300.ogg"}, "is not a moment"],
		[{"menu": ["swr-original:music/300.ogg"]}, "a track is a text reference"],
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
