extends SceneTree
## The droids speak (docs/advisor-plan.md, phase 2), on synthetic stand-ins -
## the test tone (tests/fixtures/music_test.ogg) for every sound and a 4x3,
## two-frame run for every animation, never the original's:
##   - pack.json `advisor`, `voices`, `sounds` load; rules 25-27 refuse bad maps;
##   - an animation run (fwa.gd) decodes: the first frame, a change added on
##     it, index 0 clear;
##   - news the simulation tags reaches the droids for this side - a
##     character's own report where the pack has one - the message droid
##     first, then the agent; Translate Counterpart off keeps the agent's
##     translated line quiet;
##   - news waits its days and does not play again within repeat_days;
##   - a character's own line follows; an order is acknowledged;
##   - Translate Counterpart and the sound effects volume are kept;
##   - the cockpit's controls make their sounds;
##   - the agent answers at once, stopping the news playing (phase 3), and the
##     engine's refusals carry the reason he answers (Result.code).
## Writes and removes its own files under user://.
##
##   .\tools\run-gd.ps1 tests/advisor.gd

const SoundLib := preload("res://src/ui/sound.gd")
const MusicLib := preload("res://src/ui/music.gd")
const Fwa := preload("res://src/ui/fwa.gd")
const AdvisorScript := preload("res://src/ui/advisor.gd")
const Frame := preload("res://src/ui/command_frame.gd")
const Art := preload("res://src/ui/artwork.gd")
const Tone := "res://tests/fixtures/music_test.ogg"
const ArtRoot := "user://test-advisor-art"
const Settings := "user://test-advisor.cfg"

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[advisor] ok   %s" % what)
	else:
		_fails += 1
		print("[advisor] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = ArtRoot
	_remove(ArtRoot)
	MusicLib.SettingsFile = Settings
	DirAccess.remove_absolute(Settings)
	SoundLib._loaded = false
	SoundLib.TranslateCounterpart = true
	SoundLib.Volume = SoundLib.DEFAULT_VOLUME
	SoundLib.PlayHeadless = true
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	var alliance: Faction = FactionRegistry.ById("alliance")
	GameSettings.PlayerFaction = alliance
	StrategicTickManager.Today = 100
	var m: PackDefs.PackManifest = FactionRegistry.Pack.Manifest
	_check(m.AdvisorGiven and (m.Advisor["alliance"] as Dictionary).size() == 45 and (m.Advisor["empire"] as Dictionary).size() == 45
		and int(m.Advisor["repeat_days"]) == 60 and not m.Advisor.has("_comment"),
		"the Star Wars pack's advisor: 37 kinds of news and 8 answers a side, repeat_days 60, the comment left out")
	_check(m.Advisor["alliance"]["answer_in_transit"]["agent"]["sound"] == "swr-original:sound/alsprite/1096.ogg"
		and m.Advisor["empire"]["answer_in_transit"]["agent"]["sound"] == "swr-original:sound/emsprite/1596.ogg"
		and m.Advisor["alliance"]["answer_no_maintenance"]["agent"]["sound"] == "swr-original:sound/alsprite/1105.ogg",
		"the agent's answers: in transit 1096 / 1596, not enough maintenance 1105")
	_check(m.Voices.size() == 6 and m.Voices["emperor_palpatine"]["mission_failure"] == "swr-original:sound/emsprite/1387.ogg",
		"its voices: six characters; the Emperor's mission failure is 1387")
	_check(m.Sounds.get("cockpit_exit", "") == "swr-original:sound/common/8002.ogg", "its sounds: the cockpit's ejector handle is COMMON 8002")
	_Rules()

	# An animation run: first frame whole, the next a change on it.
	var run_bytes := _run_file()
	var run_path := "user://test-advisor-run.fwa"
	var f := FileAccess.open(run_path, FileAccess.WRITE)
	f.store_buffer(run_bytes)
	f.close()
	var run: RefCounted = Fwa.Open(run_path)
	_check(run != null and run.Width == 4 and run.Height == 3 and run.Count == 2, "a run opens: 4x3, two frames")
	var first: Image = run.Picture()
	_check(first.get_pixel(0, 0).a == 0.0 and first.get_pixel(1, 0) == Color(1, 0, 0), "the first frame: index 0 clear, index 1 red")
	_check(run.Next() and run.Picture().get_pixel(1, 0) == Color(0, 1, 0) and run.Picture().get_pixel(2, 0) == Color(1, 0, 0),
		"the second: the change added (1 + 1 = 2, green), the rest kept")
	_check(not run.Next(), "and no third")
	DirAccess.remove_absolute(run_path)

	# The art set's stand-ins for the news the test uses.
	var events: Dictionary = m.Advisor["alliance"]
	for e in ["research", "ship_repaired", "report.luke_skywalker"]:
		for role in ["messenger", "agent"]:
			_stand_in(str(events[e][role]["anim"]), run_bytes)
			_stand_in(str(events[e][role]["sound"]), FileAccess.get_file_as_bytes(Tone))
	for line in ["mission_success", "order"]:
		for ref in m.Voices["luke_skywalker"][line]:
			_stand_in(str(ref), FileAccess.get_file_as_bytes(Tone))
	_stand_in(str(m.Sounds["cockpit_exit"]), FileAccess.get_file_as_bytes(Tone))

	# The droids and their advisor.
	var agent: Control = Frame.Droid.new()
	var messenger: Control = Frame.Droid.new()
	root.add_child(agent)
	root.add_child(messenger)
	var advisor: Node = AdvisorScript.new()
	advisor.Agent = agent
	advisor.Messenger = messenger
	root.add_child(advisor)

	var luke := Character.new()
	luke.PackId = "luke_skywalker"
	luke.Name = "Luke Skywalker"
	var nobody := Character.new()
	nobody.PackId = "nobody_in_particular"
	_check(AdvisorScript.Resolve("personnel_report", luke) == "report.luke_skywalker" and AdvisorScript.Resolve("personnel_report", nobody) == "personnel_report"
		and AdvisorScript.Resolve("", luke) == "" and AdvisorScript.Resolve("no_such_news", null) == "",
		"news resolves: Luke's own report, anyone else's the general one, nothing for no tag")

	# Research: the message droid, then the agent (Translate Counterpart on).
	EventBus.Tell(alliance, GameMessage.new("New technology", "", Enums.MessageCategory.Manufacturing, 100).With("research"))
	await process_frame
	await process_frame
	_check(advisor.Busy() and messenger.Talking() and _playing(events["research"]["messenger"]["sound"]),
		"research: the message droid talks, with its sound")
	var agent_heard := await _until(func() -> bool: return agent.Talking(), 4.0)
	_check(agent_heard and _playing(events["research"]["agent"]["sound"]), "... then the agent says it aloud")
	_check(await _until(func() -> bool: return not advisor.Busy(), 5.0), "... and they are done")

	# The same news again within repeat_days: waits, does not play.
	EventBus.Tell(alliance, GameMessage.new("New technology", "", Enums.MessageCategory.Manufacturing, 100).With("research"))
	await process_frame
	await process_frame
	_check(not advisor.Busy() and advisor.Pending().has("research"), "research again the same day: it waits (repeat_days)")
	StrategicTickManager.Today = 111
	await process_frame
	_check(not advisor.Pending().has("research") and not advisor.Busy(), "... and after its 10 days it is gone, never said")

	# Translate Counterpart off: the agent's translated line stays quiet.
	SoundLib.SetTranslateCounterpart(false)
	EventBus.Tell(alliance, GameMessage.new("Repaired", "", Enums.MessageCategory.Missions, 111).With("ship_repaired"))
	await process_frame
	await process_frame
	_check(messenger.Talking(), "a ship repaired: the message droid reports it")
	var spoke := await _until(func() -> bool: return agent.Talking(), 3.0)
	_check(not spoke and not advisor.Busy(), "... and with Translate Counterpart off the agent says nothing")
	var cfg := ConfigFile.new()
	_check(cfg.load(Settings) == OK and cfg.get_value("effects", "translate_counterpart", true) == false, "Translate Counterpart is kept, off")
	SoundLib.SetTranslateCounterpart(true)

	# Another side's news is not ours.
	var empire: Faction = FactionRegistry.ById("empire")
	EventBus.Tell(empire, GameMessage.new("Their news", "", Enums.MessageCategory.Missions, 111).With("research"))
	await process_frame
	_check(not advisor.Pending().has("research") and not advisor.Busy(), "the other side's news is not ours")

	# Luke's report, then his own line.
	var report := GameMessage.new("Luke: done", "", Enums.MessageCategory.Missions, 111, null, luke).With("personnel_report", "mission_success")
	EventBus.Tell(alliance, report)
	await process_frame
	await process_frame
	_check(advisor.Busy() and _playing(events["report.luke_skywalker"]["messenger"]["sound"]), "Luke's report: his own news")
	var lines: Array = m.Voices["luke_skywalker"]["mission_success"]
	var said := await _until(func() -> bool: return lines.any(func(r: String) -> bool: return _playing(r)), 6.0)
	_check(said, "... then Luke's own line, one of his mission successes")

	# An order acknowledged, at once.
	await _until(func() -> bool: return not advisor.Busy() and _sounds().is_empty(), 4.0)
	AdvisorScript.SayOrder(self, [nobody, luke])
	await process_frame
	var orders: Array = m.Voices["luke_skywalker"]["order"]
	_check(orders.any(func(r: String) -> bool: return _playing(r)), "an order: Luke acknowledges it (the first with a voice)")

	# The sound effects volume.
	SoundLib.SetVolume(0.5)
	_check(is_equal_approx(AudioServer.get_bus_volume_db(SoundLib.Bus()), linear_to_db(0.5)), "the sound effects volume sets the Effects bus")
	cfg = ConfigFile.new()
	_check(cfg.load(Settings) == OK and is_equal_approx(float(cfg.get_value("effects", "volume", -1)), 0.5), "... and is kept")

	# The cockpit's ejector handle.
	var menu: Control = load("res://Menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	var handle := PackDefs.MenuRegionDef.new()
	handle.Action = "debug_only"
	menu._cockpit_sound(handle)
	handle.Action = "exit"
	menu._cockpit_sound(handle)
	await process_frame
	_check(_playing(m.Sounds["cockpit_exit"]), "the cockpit's ejector handle makes its sound")
	menu.queue_free()

	# The agent's answer: at once, over the news, which stops.
	for e in ["answer_in_transit", "answer_garrisons_on"]:
		_stand_in(str(events[e]["agent"]["anim"]), run_bytes)
		_stand_in(str(events[e]["agent"]["sound"]), FileAccess.get_file_as_bytes(Tone))
	await _until(func() -> bool: return not advisor.Busy() and _sounds().is_empty(), 6.0)
	StrategicTickManager.Today = 300
	EventBus.Tell(alliance, GameMessage.new("New technology", "", Enums.MessageCategory.Manufacturing, 300).With("research"))
	await process_frame
	await process_frame
	_check(messenger.Talking() and _playing(events["research"]["messenger"]["sound"]), "news playing: the message droid reports research")
	AdvisorScript.AnswerOn(self, "in_transit")
	await process_frame
	_check(not messenger.Talking() and not _playing(events["research"]["messenger"]["sound"]) and agent.Talking()
		and _playing(events["answer_in_transit"]["agent"]["sound"]), "an order refused, in transit: the news stops and the agent answers (1096)")
	var over := await _until(func() -> bool: return not advisor.Busy(), 6.0)
	await process_frame
	_check(over and not agent.Talking() and not messenger.Talking(), "... and the interrupted news does not come back to finish")
	var none_said: bool = advisor.Answer("no_such_answer") or advisor.Answer("")
	_check(not advisor.Busy() and not none_said, "an answer the pack does not have: nothing, and he says he did not")
	var answered: bool = AdvisorScript.AnswerOn(self, "garrisons_on")
	await process_frame
	_check(answered and _playing(events["answer_garrisons_on"]["agent"]["sound"]), "Manage Garrisons on: the agent says so (1137), and AnswerOn says he did")
	# An answer whose recording is not there: he says nothing - so a window may
	# say it instead (the No Mission Available box without the droid's line).
	_check(not AdvisorScript.AnswerOn(self, "no_mission") or not SoundLib.FileOf(str(events.get("answer_no_mission", {}).get("agent", {}).get("sound", ""))).is_empty(),
		"an answer without its recording: AnswerOn says he did not")

	# The engine's refusals carry their reason.
	var short: Result = Result.fail("Need 3 maintenance capacity, have 1.").coded("no_maintenance")
	var some: Result = Planet._Placed(1, short)
	var none: Result = Planet._Placed(0, short)
	_check(some.ok and int(some.value) == 1 and some.code == "no_maintenance" and some.error == short.error
		and not none.ok and none.code == "no_maintenance" and Planet._Placed(2, Result.success()).code == "",
		"a build refused for maintenance says so (code no_maintenance), also when some were queued")
	advisor.queue_free()
	await process_frame
	_finish()


## Rules 25-27 on copies of the manifest's maps.
func _Rules() -> void:
	var pack: PackLoader.LoadedPack = FactionRegistry.Pack
	var m := pack.Manifest
	var saved := [m.AdvisorRaw, m.VoicesRaw, m.SoundsRaw]
	var cases := [
		["advisor", {"repeat_days": 60, "alliance": {"research": {"days": 10, "messenger": {"anim": "swr-original:anim/alsprite/3331.fwa", "sound": "swr-original:sound/alsprite/1505.ogg"}}}}, ""],
		["advisor", {"alliance": {"report.luke_skywalker": {"agent": {"sound": "swr-original:sound/alsprite/1128.ogg", "translated": true}}}}, ""],
		["advisor", "no", "must be an object"],
		["advisor", {"rebels": {}}, "neither a faction"],
		["advisor", {"alliance": {"gossip": {}}}, "is not news the droids speak about"],
		["advisor", {"alliance": {"report.yoda_the_great": {}}}, "names no character"],
		["advisor", {"alliance": {"research": {"messenger": {"anim": "swr-original:anim/alsprite/3331.png"}}}}, "is not a .fwa file"],
		["advisor", {"alliance": {"research": {"agent": {"translated": "yes"}}}}, "must be true or false"],
		["advisor", {"frame_seconds": 0}, "must be a positive number"],
		["voices", {"luke_skywalker": {"order": ["swr-original:sound/alsprite/1301.ogg", "swr-original:sound/alsprite/1302.ogg"]}}, ""],
		["voices", {"yoda_the_great": {}}, "is no character"],
		["voices", {"luke_skywalker": {"sings": "swr-original:sound/alsprite/1.ogg"}}, "is not a line"],
		["voices", {"luke_skywalker": {"order": []}}, "names no sound"],
		["voices", {"luke_skywalker": {"order": "other-set:sound/x/1.ogg"}}, "which art_sets does not declare"],
		["sounds", {"cockpit_exit": "swr-original:sound/common/8002.ogg"}, ""],
		["sounds", {"cockpit_whistle": "swr-original:sound/common/8003.ogg"}, "is not a moment"],
		["sounds", {"cockpit_exit": "swr-original:sound/common/8002.wav"}, "is not a .ogg file"],
	]
	for c in cases:
		var errors: Array[String] = []
		match c[0]:
			"advisor":
				m.AdvisorRaw = c[1]
				m.AdvisorGiven = true
				PackLoader._validate_advisor(pack, FactionRegistry.LoadedDir, errors)
			"voices":
				m.VoicesRaw = c[1]
				m.VoicesGiven = true
				PackLoader._validate_voices(pack, FactionRegistry.LoadedDir, errors)
			"sounds":
				m.SoundsRaw = c[1]
				m.SoundsGiven = true
				PackLoader._validate_sounds(pack, FactionRegistry.LoadedDir, errors)
		var want: String = c[2]
		var ok: bool = errors.is_empty() if want.is_empty() else (errors.size() >= 1 and errors[0].contains(want))
		_check(ok, "rule %s: %s -> %s" % [{"advisor": 25, "voices": 26, "sounds": 27}[c[0]], JSON.stringify(c[1]), str(errors) if not errors.is_empty() else "accepted"])
	m.AdvisorRaw = saved[0]
	m.VoicesRaw = saved[1]
	m.SoundsRaw = saved[2]


## A 4x3 run of two frames: the first 0 1 1 0 / 1 1 1 1 / 0 1 1 0 (1 red, 2
## green), the second adding 1 to the top row's second pixel.
func _run_file() -> PackedByteArray:
	var b := PackedByteArray()
	b.append_array("FWA1".to_ascii_buffer())
	for v in [4, 3, 2]:
		b.append(v & 0xFF)
		b.append(v >> 8)
	var palette := PackedByteArray()
	palette.resize(768)
	palette[3] = 255     # index 1: red
	palette[7] = 255     # index 2: green
	b.append_array(palette)
	b.append_array(PackedByteArray([0, 1, 1, 0, 1, 1, 1, 1, 0, 1, 1, 0]))
	var frame := PackedByteArray()
	frame.resize(17)
	frame.encode_u16(0, 4)
	frame.encode_u16(2, 3)
	frame.encode_u32(4, 6)
	for off in [0, 4, 5]:
		var o := PackedByteArray()
		o.resize(4)
		o.encode_u32(0, off)
		frame.append_array(o)
	frame.append_array(PackedByteArray([1, 1, 1, 2, 4, 4]))
	var length := PackedByteArray()
	length.resize(4)
	length.encode_u32(0, frame.size())
	b.append_array(length)
	b.append_array(frame)
	return b


func _stand_in(ref: String, bytes: PackedByteArray) -> void:
	var split: PackedStringArray = PackLoader.SplitArtRef(ref)
	var path := "%s/%s/%s" % [ArtRoot, split[0], split[1]]
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()


func _sounds() -> Array:
	# By the file each plays: a second "Sound" while the first is being freed
	# takes a made-up name.
	return root.get_children().filter(func(n: Node) -> bool: return n is AudioStreamPlayer and n.has_meta("path") and (n as AudioStreamPlayer).playing)


func _playing(ref: Variant) -> bool:
	var file := SoundLib.FileOf(str(ref))
	return not file.is_empty() and _sounds().any(func(p: AudioStreamPlayer) -> bool: return str(p.get_meta("path", "")) == file)


func _until(cond: Callable, seconds: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < seconds * 1000.0:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func _finish() -> void:
	_remove(ArtRoot)
	DirAccess.remove_absolute(Settings)
	MusicLib.SettingsFile = MusicLib.SETTINGS
	SoundLib._loaded = false
	SoundLib.PlayHeadless = false
	Art.Reset()
	print("[advisor] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


static func _remove(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in DirAccess.get_directories_at(path):
		_remove("%s/%s" % [path, sub])
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute("%s/%s" % [path, file])
	DirAccess.remove_absolute(path)
