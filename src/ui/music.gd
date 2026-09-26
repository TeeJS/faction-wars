extends RefCounted
## THE ORIGINAL'S SCORE (docs/music-plan.md, phase 2). The exporter puts the
## original's 16 tracks into the art set as Ogg Vorbis (music/<nnn>.ogg; TeeJ,
## 2026-09-26: "yes to including the music with the art"); the pack says which
## plays when (pack.json `music`, SCHEMA.md section 2). Played now: `menu`, the
## Shuttle Cockpit's track, looped while the Cockpit is up. The in-play
## playlist and the battle alert wait on the plan's phase 0.
##
## Game Options' Play Music and music volume (manual p076 Fig. 3.16) drive it,
## kept in user://music.cfg. It plays on its own bus, "Music", which the
## volume sets. A movie holds it and gives it back (movie_player.gd). Without
## the art set - or with an art set from an exporter before 2.5.0 - there is
## no track and nothing plays.
##
## Preloaded by path (as MusicLib): a new script can lag the editor's class cache.

const Art := preload("res://src/ui/artwork.gd")

const SETTINGS := "user://music.cfg"
const BUS := "Music"
## The volume the game starts at: full (the original's own default is not
## known; its volume knob sat at the track's left end on TeeJ's screenshot).
const DEFAULT_VOLUME := 1.0

static var SettingsFile: String = SETTINGS
static var PlayMusic: bool = true
## 0 to 1.
static var Volume: float = DEFAULT_VOLUME
## No music in a headless run: the test runs share the player's user://.
static var PlayHeadless: bool = false

static var _loaded: bool = false
static var _player: AudioStreamPlayer = null
static var _event: String = ""
static var _tree: SceneTree = null
static var _held: bool = false


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


## Play Music on or off (Game Options): off stops it, on starts the moment's
## track again.
static func SetPlayMusic(on: bool) -> void:
	Load()
	PlayMusic = on
	_save()
	if not on:
		_stop_player()
	elif not _event.is_empty() and _tree != null:
		Play(_tree, _event)


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


## The loaded pack's track for `event` that is there to play, or "".
static func Track(event: String) -> String:
	if FactionRegistry.Pack == null or (DisplayServer.get_name() == "headless" and not PlayHeadless):
		return ""
	var ref: String = str(FactionRegistry.Pack.Manifest.Music.get(event, ""))
	return FileOf(ref) if not ref.is_empty() else ""


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
	_event = event
	_tree = tree
	var path := Track(event)
	if path.is_empty() or not PlayMusic:
		_stop_player()
		return
	if _player != null and is_instance_valid(_player) and _player.get_meta("path", "") == path and _player.playing:
		return
	var stream: AudioStreamOggVorbis = null
	if path.begins_with("res://") and ResourceLoader.exists(path):
		stream = load(path) as AudioStreamOggVorbis
	else:
		stream = AudioStreamOggVorbis.load_from_file(path)
	if stream == null:
		push_warning("Music %s could not be read." % path)
		_stop_player()
		return
	stream.loop = true
	if _player == null or not is_instance_valid(_player):
		_player = AudioStreamPlayer.new()
		_player.name = "MusicPlayer"
		_player.process_mode = Node.PROCESS_MODE_ALWAYS
		tree.root.add_child(_player)
	_player.bus = BUS
	_player.stream = stream
	_player.set_meta("path", path)
	_player.stream_paused = _held
	_player.play()


## The Cockpit is gone (a game starts): its music stops.
static func Stop() -> void:
	_event = ""
	_stop_player()


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
