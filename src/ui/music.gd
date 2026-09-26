extends RefCounted
## THE ORIGINAL'S SCORE (docs/music-plan.md). The exporter puts the original's
## 16 tracks into the art set as Ogg Vorbis (music/<nnn>.ogg; TeeJ,
## 2026-09-26: "yes to including the music with the art"); the pack says which
## plays when (pack.json `music`, SCHEMA.md section 2). A moment names one
## track or a pool one is drawn from at random. Three ways of playing:
##   - LOOPED: `menu`, the Shuttle Cockpit's track, while the Cockpit is up;
##   - THE GAME'S PLAYLIST (phase 3, Rebellion 2's model - single-source; TeeJ,
##     2026-09-26: "Build from rebellion 2"): one track after another, none
##     looped. First a track for how the war goes, then NeutralBetween from
##     `play`, then again. How the war goes is the local side's inhabited
##     worlds against the other sides': x RatioScale / theirs (x
##     NoOpponentMultiplier when they hold none) - at StrongAdvantageMin or
##     more `strong_advantage.<side>`, at AdvantageMin `advantage.<side>`, at
##     DisadvantageMax or less `disadvantage.<side>`, between them a `play`
##     track. A side with no track for its standing gets a `play` track;
##   - A CUE, once, in place of the playlist: `battle_alert` when a Battle
##     Alert comes up, `battle_victory` / `battle_defeat` / `battle_draw.<side>`
##     when that battle's results do (UIManager). The playlist goes on
##     (Resume) when the battle's windows are gone.
##
## Game Options' Play Music and music volume (manual p076 Fig. 3.16) drive it,
## kept in user://music.cfg. It plays on its own bus, "Music", which the
## volume sets. A movie holds it and gives it back (movie_player.gd). Without
## the art set - or with an art set from an exporter before 2.5.0 - there is
## no track and nothing plays. It never touches the game's own random numbers.
##
## Preloaded by path (as MusicLib): a new script can lag the editor's class cache.

const Art := preload("res://src/ui/artwork.gd")

const SETTINGS := "user://music.cfg"
const BUS := "Music"
## The volume the game starts at: full (the original's own default is not
## known; its volume knob sat at the track's left end on TeeJ's screenshot).
const DEFAULT_VOLUME := 1.0
## Rebellion 2's numbers (its FactionThemes.xml, StrategyMusic): single-source.
const NeutralBetween := 3
const RatioScale := 100
const NoOpponentMultiplier := 10
const StrongAdvantageMin := 300
const AdvantageMin := 200
const DisadvantageMax := 50

static var SettingsFile: String = SETTINGS
static var PlayMusic: bool = true
## 0 to 1.
static var Volume: float = DEFAULT_VOLUME
## No music in a headless run: the test runs share the player's user://.
static var PlayHeadless: bool = false
## The draw from a pool - its own generator, never the game's (Prng).
static var Rng: RandomNumberGenerator = RandomNumberGenerator.new()

static var _loaded: bool = false
static var _player: AudioStreamPlayer = null
## "loop" (a moment looped), "playlist" (the game's), "cue" (a battle's), "".
static var _mode: String = ""
static var _event: String = ""
static var _tree: SceneTree = null
static var _held: bool = false
static var _neutralLeft: int = 0


## The settings, once.
static func Load() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(SettingsFile) == OK:
		PlayMusic = bool(cfg.get_value("music", "play", true))
		Volume = clampf(float(cfg.get_value("music", "volume", DEFAULT_VOLUME)), 0.0, 1.0)
	_apply_volume()


static func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("music", "play", PlayMusic)
	cfg.set_value("music", "volume", Volume)
	cfg.save(SettingsFile)


## Play Music on or off (Game Options): off stops it, on starts what was
## playing again - the moment, the playlist or the cue.
static func SetPlayMusic(on: bool) -> void:
	Load()
	PlayMusic = on
	_save()
	if not on:
		_stop_player()
	elif _tree != null:
		match _mode:
			"loop": Play(_tree, _event)
			"playlist": _next()
			"cue": _start(Track(_event), false)


static func SetVolume(v: float) -> void:
	Load()
	Volume = clampf(v, 0.0, 1.0)
	_save()
	_apply_volume()


## The Music bus, made when first needed, sending to Master.
static func Bus() -> int:
	var idx := AudioServer.get_bus_index(BUS)
	if idx < 0:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, BUS)
		AudioServer.set_bus_send(idx, "Master")
	return idx


static func _apply_volume() -> void:
	var idx := Bus()
	AudioServer.set_bus_mute(idx, Volume <= 0.0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(Volume, 0.0001)))


## The loaded pack's tracks for `event` that are there to play.
static func Tracks(event: String) -> Array[String]:
	var files: Array[String] = []
	if FactionRegistry.Pack == null or (DisplayServer.get_name() == "headless" and not PlayHeadless):
		return files
	for ref in FactionRegistry.Pack.Manifest.Music.get(event, []):
		var file := FileOf(str(ref))
		if not file.is_empty():
			files.append(file)
	return files


## One of `event`'s tracks, drawn at random, or "" when it has none.
static func Track(event: String) -> String:
	var files := Tracks(event)
	return "" if files.is_empty() else files[Rng.randi_range(0, files.size() - 1)]


## A reference's file, or "" when it is not there: "<art set>:<path>" in an
## art set the pack declares, else a file in the pack.
static func FileOf(ref: String) -> String:
	var split: PackedStringArray = PackLoader.SplitArtRef(ref)
	if split[0].is_empty():
		var own := "%s/%s" % [FactionRegistry.LoadedDir, ref]
		return own if FileAccess.file_exists(own) else ""
	if FactionRegistry.Pack == null or not FactionRegistry.Pack.Manifest.ArtSets.has(split[0]):
		return ""
	for root in Art._set_roots(split[0]):
		var path := "%s/%s" % [root, split[1]]
		if FileAccess.file_exists(path) or ResourceLoader.exists(path):
			return path
	return ""


## Plays `event`'s track, looped, unless it is already playing. With Play
## Music off, or no track, it only remembers the moment.
static func Play(tree: SceneTree, event: String) -> void:
	Load()
	_mode = "loop"
	_event = event
	_tree = tree
	var path := Track(event)
	if path.is_empty() or not PlayMusic:
		_stop_player()
		return
	if Playing() == path or (_held and _player != null and is_instance_valid(_player) and _player.get_meta("path", "") == path):
		_player.stream.loop = true
		return
	_start(path, true)


## A game begins: its playlist from the top - how the war goes, first.
static func StartGame(tree: SceneTree) -> void:
	Load()
	_tree = tree
	_mode = "playlist"
	_event = ""
	_neutralLeft = 0
	_next()


## The playlist goes on (after a battle's cue): the next track in its order.
## Nothing changes while it is already playing.
static func Resume(tree: SceneTree) -> void:
	Load()
	_tree = tree
	if _mode == "playlist" and not Playing().is_empty():
		return
	_mode = "playlist"
	_event = ""
	_next()


## `event`'s track once, in place of the playlist. `restart` false keeps it
## going when it is already the one playing (a second Battle Alert). A moment
## with no track changes nothing.
static func Cue(tree: SceneTree, event: String, restart: bool) -> void:
	Load()
	_tree = tree
	var files := Tracks(event)
	if files.is_empty():
		return
	_mode = "cue"
	_event = event
	if not restart and files.has(Playing()):
		return
	_start(files[Rng.randi_range(0, files.size() - 1)], false)


## True while a battle's cue holds the playlist.
static func InCue() -> bool:
	return _mode == "cue"


## The Cockpit is gone, or the game: the music stops.
static func Stop() -> void:
	_mode = ""
	_event = ""
	_stop_player()


## The playlist's next track (none with Play Music off or nothing to play).
static func _next() -> void:
	if not PlayMusic or _tree == null:
		return
	var path := _choose()
	if path.is_empty():
		_stop_player()
		return
	_start(path, false)


static func _choose() -> String:
	if _neutralLeft > 0:
		_neutralLeft -= 1
		var neutral := Track("play")
		if not neutral.is_empty():
			return neutral
	_neutralLeft = NeutralBetween
	var side: Faction = GameSettings.LocalFaction()
	var standing := Standing(side)
	var strategic := "" if standing.is_empty() or side == null else Track("%s.%s" % [standing, side.Id])
	return strategic if not strategic.is_empty() else Track("play")


## How the war goes for `side`, by Rebellion 2's thresholds: "strong_advantage",
## "advantage", "disadvantage", or "" between them.
static func Standing(side: Faction) -> String:
	if side == null:
		return ""
	var ratio := Ratio(side)
	if ratio >= StrongAdvantageMin:
		return "strong_advantage"
	if ratio >= AdvantageMin:
		return "advantage"
	if ratio <= DisadvantageMax:
		return "disadvantage"
	return ""


## The side's inhabited worlds against the other sides' (the neutrals left
## out), scaled: RatioScale is even. Rebellion 2 counts one opponent; with two
## sides, the only kind of game there is, the others ARE the opponent.
static func Ratio(side: Faction) -> int:
	var mine := 0
	var theirs := 0
	for p: Planet in GameState.AllPlanets():
		if not p.IsInhabited or p.ControllingFaction == null:
			continue
		if p.ControllingFaction == side:
			mine += 1
		elif FactionRegistry.OrderOf(p.ControllingFaction) >= 0:
			theirs += 1
	return mine * NoOpponentMultiplier if theirs == 0 else mine * RatioScale / theirs


static func _start(path: String, loop: bool) -> void:
	if path.is_empty() or not PlayMusic or _tree == null:
		return
	var stream: AudioStreamOggVorbis = null
	if path.begins_with("res://") and ResourceLoader.exists(path):
		stream = (load(path) as AudioStreamOggVorbis).duplicate()
	else:
		stream = AudioStreamOggVorbis.load_from_file(path)
	if stream == null:
		push_warning("Music %s could not be read." % path)
		_stop_player()
		return
	stream.loop = loop
	if _player == null or not is_instance_valid(_player):
		_player = AudioStreamPlayer.new()
		_player.name = "MusicPlayer"
		_player.process_mode = Node.PROCESS_MODE_ALWAYS
		_player.finished.connect(_finished)
		_tree.root.add_child(_player)
	_player.bus = BUS
	_player.stream = stream
	_player.set_meta("path", path)
	_player.stream_paused = _held
	_player.play()


## A track ran out (never a looped one): the playlist's next; a cue's end is
## silence until the playlist resumes.
static func _finished() -> void:
	if _mode == "playlist":
		_next()


static func _stop_player() -> void:
	if _player != null and is_instance_valid(_player):
		_player.stop()
		_player.stream = null
		_player.set_meta("path", "")


## A movie holds the music and gives it back where it was.
static func Hold(on: bool) -> void:
	_held = on
	if _player != null and is_instance_valid(_player):
		_player.stream_paused = on


## What plays now, for tests: its file, or "".
static func Playing() -> String:
	if _player == null or not is_instance_valid(_player) or not _player.playing or _player.stream_paused:
		return ""
	return str(_player.get_meta("path", ""))
