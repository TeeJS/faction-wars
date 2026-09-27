extends RefCounted
## THE ORIGINAL'S VOICES AND SOUND EFFECTS (docs/advisor-plan.md). The exporter
## puts every one of them into the art set (sound/<dll>/<id>.ogg, exporter
## 2.6.0); the pack says which plays when (pack.json `advisor`, `voices`,
## `sounds`). They play once each, on their own bus, "Effects", which Game
## Options' sound effects volume sets (manual p076 Fig. 3.16). Translate
## Counterpart - the agent droid's menu, Alt+V, "on by default" (manual) - lets
## the agent say aloud what the message droid reports. Both are kept in the
## music's settings file (music.gd), section "effects".
##
## Without the art set's sounds nothing plays. They are held with the scene
## tree: a movie's pause holds them too.
##
## Preloaded by path (as SoundLib): a new script can lag the editor's class cache.

const MusicLib := preload("res://src/ui/music.gd")

const BUS := "Effects"
const DEFAULT_VOLUME := 1.0

## 0 to 1.
static var Volume: float = DEFAULT_VOLUME
## The agent says the message droid's reports aloud (manual: on by default).
static var TranslateCounterpart: bool = true
## No sound in a headless run: the test runs share the player's user://.
static var PlayHeadless: bool = false

static var _loaded: bool = false


## The settings, once.
static func Load() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(MusicLib.SettingsFile) == OK:
		Volume = clampf(float(cfg.get_value("effects", "volume", DEFAULT_VOLUME)), 0.0, 1.0)
		TranslateCounterpart = bool(cfg.get_value("effects", "translate_counterpart", true))
	_apply_volume()


static func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(MusicLib.SettingsFile)
	cfg.set_value("effects", "volume", Volume)
	cfg.set_value("effects", "translate_counterpart", TranslateCounterpart)
	cfg.save(MusicLib.SettingsFile)


static func SetVolume(v: float) -> void:
	Load()
	Volume = clampf(v, 0.0, 1.0)
	_save()
	_apply_volume()


static func SetTranslateCounterpart(on: bool) -> void:
	Load()
	TranslateCounterpart = on
	_save()


## The Effects bus, made when first needed, sending to Master.
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


## Whether sounds may play here (not in a headless run, unless a test asks).
static func Enabled() -> bool:
	return FactionRegistry.Pack != null and (DisplayServer.get_name() != "headless" or PlayHeadless)


## A reference's file, or "" - "<art set>:<path>" or a file in the pack.
static func FileOf(ref: String) -> String:
	if ref.is_empty() or not Enabled():
		return ""
	return MusicLib.FileOf(ref)


## One of `refs` (a reference or a list, a pool drawn from at random) that is
## there to play, or "".
static func Pick(refs: Variant) -> String:
	var files: Array[String] = []
	for r in (refs if refs is Array else [refs]):
		var f := FileOf(str(r))
		if not f.is_empty():
			files.append(f)
	return "" if files.is_empty() else files[MusicLib.Rng.randi_range(0, files.size() - 1)]


## Plays a sound file once on the Effects bus; `done` when it ends (at once
## when there is nothing to play). Returns the player, or null.
static func PlayFile(tree: SceneTree, file: String, done: Callable = Callable()) -> AudioStreamPlayer:
	Load()
	var stream: AudioStreamOggVorbis = null
	if not file.is_empty():
		stream = AudioStreamOggVorbis.load_from_file(file)
	if stream == null or tree == null:
		if done.is_valid():
			done.call()
		return null
	stream.loop = false
	var p := AudioStreamPlayer.new()
	p.name = "Sound"
	p.bus = BUS
	p.stream = stream
	p.set_meta("path", file)
	p.finished.connect(func() -> void:
		p.queue_free()
		if done.is_valid():
			done.call())
	tree.root.add_child(p)
	p.play()
	return p


## Plays one of a pack reference's sounds (a reference or a pool).
static func Play(tree: SceneTree, refs: Variant, done: Callable = Callable()) -> AudioStreamPlayer:
	return PlayFile(tree, Pick(refs), done)
