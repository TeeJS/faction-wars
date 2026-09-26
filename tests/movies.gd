extends SceneTree
## The original's movies in the game (docs/cutscenes-plan.md, phase 3), on a
## synthetic one-second test movie (tests/fixtures/movie_test.ogv, made with
## FFmpeg's test pattern - never the original's):
##   - pack.json `movies` loads, and rule 23 refuses a bad map;
##   - a movies file imports (kind "movies") to Movies.UserRoot/<id>/, and
##     is listed and removed like an art set;
##   - Movies.For finds the movies there are, in order, and skips the rest;
##   - the player holds the scene tree, skips on Esc and on a click, ends on
##     its own, and gives the tree back;
##   - the launch movies play once a run; View credits plays the credits
##     movie when there is one, else the credits window.
## Writes and removes its own files under user://.
##
##   .\tools\run-gd.ps1 tests/movies.gd

const MoviesLib := preload("res://src/ui/movies.gd")
const Importer := preload("res://src/ui/pack_import.gd")
const Fixture := "res://tests/fixtures/movie_test.ogv"
const Root := "user://test-movies"
const ZipPath := "user://test-movies.zip"

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[movies] ok   %s" % what)
	else:
		_fails += 1
		print("[movies] FAIL %s" % what)


func _init() -> void:
	await process_frame
	MoviesLib.UserRoot = Root
	MoviesLib.PlayHeadless = true
	Importer._remove(Root)
	FactionRegistry.EnsureLoaded()
	var m: PackDefs.PackManifest = FactionRegistry.Pack.Manifest
	_check(m.Id == "star-wars-rebellion", "the Star Wars pack is loaded")
	_check(m.Movies.get("launch", []) == ["swr-original:movies/000.ogv", "swr-original:movies/001.ogv"]
		and m.Movies.get("credits", []) == ["swr-original:movies/005.ogv"] and m.Movies.size() == 12
		and m.Movies.get("start.empire", []) == ["swr-original:movies/004.ogv"] and m.Movies.get("headquarters_lost.alliance", []) == ["swr-original:movies/102.ogv"],
		"its movies: launch 000 + 001, credits 005, the Empire's start 004, the Alliance's headquarters 102, and eight more (%d events)" % m.Movies.size())
	_Rule23()

	# Nothing imported: nothing to play.
	_check(MoviesLib.For("launch").is_empty() and not MoviesLib.Has("credits"), "without the movies file nothing plays")
	var done_calls := [0]
	_check(MoviesLib.Play(self, "launch", func() -> void: done_calls[0] += 1) == null and done_calls[0] == 1,
		"Play with nothing to play calls done at once")

	# A movies file holding 000 and 005 (the fixture under both names).
	var bytes := FileAccess.get_file_as_bytes(Fixture)
	_check(bytes.size() > 1000, "the test movie is there (%d bytes)" % bytes.size())
	_zip({"movies/000.ogv": bytes, "movies/005.ogv": bytes})
	var result: Dictionary = Importer.ImportFile(ZipPath)
	_check(result.get("ok", false) and result.get("kind", "") == Importer.KIND_MOVIES, "the movies file imports (%s)" % result.get("message", ""))
	_check(FileAccess.file_exists(Root + "/swr-original/movies/000.ogv"), "... to Movies.UserRoot/swr-original/movies/")
	var listed := Importer.Installed().filter(func(e: Dictionary) -> bool: return e.kind == Importer.KIND_MOVIES)
	_check(listed.size() == 1 and listed[0].id == "swr-original" and listed[0].files == 2, "Installed lists it (%s)" % str(listed))
	_check(MoviesLib.For("launch") == [Root + "/swr-original/movies/000.ogv"], "launch: 000 is there, 001 is not and is skipped")
	_check(MoviesLib.Has("credits") and not MoviesLib.Has("system_destroyed"), "credits has its movie; system_destroyed has none")

	# The player: the tree held, Esc skips to the end.
	done_calls[0] = 0
	var p: Node = MoviesLib.Play(self, "launch", func() -> void: done_calls[0] += 1)
	await process_frame
	await process_frame
	_check(p != null and is_instance_valid(p) and paused, "a movie plays over everything and holds the scene tree")
	var video: VideoStreamPlayer = p.get_node_or_null("Video") if p != null else null
	_check(video != null and video.is_playing(), "... it is playing")
	root.push_input(_esc())
	await process_frame
	await process_frame
	_check(not is_instance_valid(p) and not paused and done_calls[0] == 1, "Esc skips it: the player goes, the tree runs, done once")

	# A click skips too; two movies skip one at a time.
	done_calls[0] = 0
	p = MoviesLib.Player.new()
	var two: Array[String] = [MoviesLib.PathOf("swr-original:movies/000.ogv"), MoviesLib.PathOf("swr-original:movies/005.ogv")]
	p.Paths = two
	p.Done = func() -> void: done_calls[0] += 1
	root.add_child(p)
	await process_frame
	_check(p.Playing().ends_with("000.ogv"), "two movies: the first plays")
	root.push_input(_click())
	await process_frame
	_check(is_instance_valid(p) and p.Playing().ends_with("005.ogv") and done_calls[0] == 0, "a click skips to the second")
	# The second ends on its own (the test movie is one second long).
	var t0 := Time.get_ticks_msec()
	while is_instance_valid(p) and Time.get_ticks_msec() - t0 < 5000:
		await process_frame
	_check(not is_instance_valid(p) and done_calls[0] == 1 and not paused, "the last ends on its own, and the tree runs again")

	# The launch movies once a run.
	MoviesLib.LaunchPlayed = false
	p = MoviesLib.PlayLaunch(self)
	_check(p != null and MoviesLib.LaunchPlayed, "the launch movies play the first time")
	if p != null:
		p.Skip()
		await process_frame
	_check(MoviesLib.PlayLaunch(self) == null, "... and not again")

	# View credits: the movie when there is one, else the window.
	var menu: Control = load("res://Menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	menu.OpenCredits()
	await process_frame
	var player: Node = root.get_node_or_null("MoviePlayer")
	_check(player != null and menu.get_node_or_null("CreditsWindow") == null, "View credits plays the credits movie")
	if player != null:
		player.Skip()
		await process_frame
	Importer.Remove(Importer.KIND_MOVIES, "swr-original")
	_check(not DirAccess.dir_exists_absolute(Root + "/swr-original") and not MoviesLib.Has("credits"), "Remove takes the movies away")
	menu.OpenCredits()
	await process_frame
	_check(menu.get_node_or_null("CreditsWindow") != null and root.get_node_or_null("MoviePlayer") == null,
		"without the movie, View credits opens the credits window, as before")
	menu.queue_free()
	_finish()


## Rule 23 on copies of the manifest's `movies`.
func _Rule23() -> void:
	var pack: PackLoader.LoadedPack = FactionRegistry.Pack
	var saved: Variant = pack.Manifest.MoviesRaw
	var cases := [
		[{"launch": "swr-original:movies/000.ogv"}, ""],
		[{"victory.empire": ["swr-original:movies/108.ogv"]}, ""],
		["not an object", "must be an object"],
		[{"intro": "swr-original:movies/000.ogv"}, "is not an event"],
		[{"victory.rebels": "swr-original:movies/105.ogv"}, "names no faction"],
		[{"launch": "other-set:movies/000.ogv"}, "which art_sets does not declare"],
		[{"launch": "swr-original:movies/000.smk"}, "is not an .ogv movie"],
		[{"launch": "no-such-file.ogv"}, "is not in"],
		[{"launch": []}, "names no movie"],
	]
	for c in cases:
		pack.Manifest.MoviesRaw = c[0]
		pack.Manifest.MoviesGiven = true
		var errors: Array[String] = []
		PackLoader._validate_movies(pack, FactionRegistry.LoadedDir, errors)
		var want: String = c[1]
		var ok: bool = errors.is_empty() if want.is_empty() else (errors.size() >= 1 and errors[0].contains(want))
		_check(ok, "rule 23: %s -> %s" % [JSON.stringify(c[0]), str(errors) if not errors.is_empty() else "accepted"])
	pack.Manifest.MoviesRaw = saved


func _zip(files: Dictionary) -> void:
	var listed := {}
	for p in files:
		var ctx := HashingContext.new()
		ctx.start(HashingContext.HASH_SHA256)
		ctx.update(files[p])
		listed[p] = ctx.finish().hex_encode()
	var zip := ZIPPacker.new()
	zip.open(ZipPath)
	for p in files:
		zip.start_file(p)
		zip.write_file(files[p])
		zip.close_file()
	zip.start_file("manifest.json")
	zip.write_file(JSON.stringify({"format": 1, "kind": "movies", "id": "swr-original", "title": "Test movies", "files": listed}).to_utf8_buffer())
	zip.close_file()
	zip.close()


func _esc() -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = KEY_ESCAPE
	e.pressed = true
	return e


func _click() -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	return e


func _finish() -> void:
	Importer._remove(Root)
	DirAccess.remove_absolute(ZipPath)
	MoviesLib.UserRoot = MoviesLib.USER_ROOT
	print("[movies] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
