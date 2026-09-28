extends SceneTree
## THE ORIGINAL'S MISSION REPORTS (TEXTSTRA 28880-29125, REBEXE 0x4927c0; TeeJ,
## 2026-09-28: "make all of the messages text match"), word for word:
##   - Rescue, as TeeJ's screenshots of the original show it: "Rescue Mission
##     Report" / "The mission to rescue Chewbacca from Balmorra succeeded.\n\n
##     Personnel are returning to Selonia." over the side's ship, and the
##     prisoner's own "Chewbacca Escaped" / "... escaped from the Empire at
##     Balmorra." over its picture (1029); a major in the first person;
##   - Sabotage done and not done, Recon, Espionage, a research mission;
##   - one message a person: "<name> Captured" and "<name> Killed".
##
##   .\tools\run-gd.ps1 tests/mission_reports.gd

const Art := preload("res://src/ui/artwork.gd")
const MessageSounds := preload("res://src/ui/sound.gd")
const Tone := "res://tests/fixtures/music_test.ogg"
const ArtRoot := "user://test-mission-reports-art"

var _fails := 0
var _checks := 0


class AlwaysOnePrng extends Prng:
	func NextRange(min_value: int, _max_value: int) -> int: return min_value
	func NextMax(_max_value: int) -> int: return 0


class AlwaysMaxPrng extends Prng:
	func NextRange(_min_value: int, max_value: int) -> int: return max_value - 1
	func NextMax(max_value: int) -> int: return max_value - 1


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[mission_reports] ok   %s" % what)
	else:
		_fails += 1
		print("[mission_reports] FAIL %s" % what)


var us: Faction
var them: Faction


func _init() -> void:
	await process_frame
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSession.new_game("alliance", Enums.Difficulty.Medium, Enums.GalaxySize.Standard, 4243)
	us = GameSettings.PlayerFaction
	them = FactionRegistry.Opponents(us)[0]
	var home: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool: return p.ControllingFaction == us)
	var enemy: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool: return p.ControllingFaction == them and not p.Facilities.is_empty())
	var ours: Array = Lq.where(GameState.ActiveRoster, func(c: Character) -> bool: return c.Faction == us and c.Status != Enums.Status.Dead)
	var minor: Character = Lq.first_or_null(ours, func(c: Character) -> bool: return not c.IsMajor)
	var major: Character = Lq.first_or_null(ours, func(c: Character) -> bool: return c.IsMajor)
	var prisoner: Character = Lq.first_or_null(ours, func(c: Character) -> bool: return not c.IsMajor and c != minor)
	_check(home != null and enemy != null and minor != null and major != null and prisoner != null, "worlds and people to send")
	if home == null or enemy == null or minor == null or major == null or prisoner == null:
		_finish()
		return
	var back := "\nPersonnel are returning to %s." % home.Name

	# Rescue - TeeJ's screenshots of the original.
	for who in [minor, major]:
		_imprison(prisoner, enemy)
		var got := _run(Enums.MissionType.Rescue, who, enemy, home, AlwaysOnePrng.new(), prisoner)
		var report: GameMessage = _titled(got, "Rescue Mission Report" if who == minor else "%s Mission Report" % who.Name)
		var body := ("The mission to rescue %s from %s succeeded.\n" if who == minor else "My mission to rescue %s from %s was a success.\n") % [prisoner.Name, enemy.Name] + back
		_check(report != null and report.Body == body, "%s rescue: '%s' (%s)" % ["minor" if who == minor else "major", body.replace("\n", "/"), report.Body.replace("\n", "/") if report != null else "none"])
		_check(report != null and report.Scene == "message.1042", "... over the Alliance's ship, STRATEGY 1042 (%s)" % (report.Scene if report != null else ""))
		_check(report != null and report.Sound == "strategy/1148", "... with the Alliance's report sound, STRATEGY 1148 (%s)" % (report.Sound if report != null else ""))
		var escaped: GameMessage = _titled(got, "%s Escaped" % prisoner.Name)
		var free := "%s escaped from the %s at %s." % [prisoner.Name, them.ShortName, enemy.Name]
		_check(escaped != null and escaped.Body == free and escaped.Still == "message.1029" and escaped.Sound == "strategy/1100",
			"... and '%s Escaped' / '%s', STRATEGY 1029 and 1100" % [prisoner.Name, free])
		if who == minor:
			# The sound plays from the art set, when the message is shown.
			Art.IgnoreProjectFolder = true
			Art.UserArtRoot = ArtRoot
			MessageSounds.PlayHeadless = true
			var set_dir := "%s/%s/sound/strategy" % [ArtRoot, FactionRegistry.Pack.Manifest.ArtSets[0]]
			DirAccess.make_dir_recursive_absolute(set_dir)
			var out := FileAccess.open(set_dir + "/1148.ogg", FileAccess.WRITE)
			out.store_buffer(FileAccess.get_file_as_bytes(Tone))
			out.close()
			_check(report != null and MessageWindow.MessageSoundFile(report).ends_with("sound/strategy/1148.ogg"), "... which the message window plays from the art set's sound/strategy/1148.ogg (%s)" % MessageWindow.MessageSoundFile(report))
			_check(escaped != null and MessageWindow.MessageSoundFile(escaped).is_empty(), "... and a sound the art set lacks, nothing")
			_remove(ArtRoot)
			Art.IgnoreProjectFolder = false
			Art.UserArtRoot = "user://art"
			MessageSounds.PlayHeadless = false

	# Sabotage, done and not done.
	for case in [["done", AlwaysOnePrng.new(), "The target was destroyed."], ["not done", AlwaysMaxPrng.new(), "  The target was not destroyed."]]:   # 28901's own two spaces
		var f: Facility = enemy.Facilities[0]
		var got := _run(Enums.MissionType.Sabotage, minor, enemy, home, case[1], null, f)
		var report: GameMessage = _titled(got, "Sabotage Mission Report")
		var body := "The sabotage mission to %s targeting the %s is complete.  %s" % [enemy.Name, f.Name(), case[2]] + back
		_check(report != null and report.Body == body, "sabotage %s: '%s' (%s)" % [case[0], body.replace("\n", "/"), report.Body.replace("\n", "/") if report != null else "none"])

	# Recon and Espionage.
	var recon: GameMessage = _titled(_run(Enums.MissionType.Reconnaissance, minor, enemy, home, AlwaysOnePrng.new()), "Recon Mission Report")
	_check(recon != null and recon.Body == "The reconnaissance mission to %s was successful.\n" % enemy.Name + back, "recon: 'Recon Mission Report' / 'The reconnaissance mission to %s was successful.' (%s)" % [enemy.Name, recon.Body.replace("\n", "/") if recon != null else "none"])
	var spy: GameMessage = _titled(_run(Enums.MissionType.Espionage, minor, enemy, home, AlwaysOnePrng.new()), "Espionage Mission Report")
	_check(spy != null and spy.Body.begins_with("The espionage mission to %s was successful.  " % enemy.Name) and spy.Scene == "message.1045" and spy.Sound == "strategy/1152",
		"espionage: 'The espionage mission to %s was successful.', its surveillance room 1045 (%s)" % [enemy.Name, spy.Body.replace("\n", "/") if spy != null else "none"])

	# A research mission: its own name, the question.
	var lab: GameMessage = _titled(_run(Enums.MissionType.ShipDesignResearch, minor, home, home, AlwaysOnePrng.new()), "Ship Design Research Mission Report")
	_check(lab != null and lab.Body.begins_with("The Ship Design Research Mission at %s " % home.Name) and lab.Body.ends_with("  Do you wish the mission to continue?") and lab.Scene == "message.1017" and lab.Sound == "strategy/1151",
		"research: 'The Ship Design Research Mission at %s ...  Do you wish the mission to continue?', R&D 1017 (%s)" % [home.Name, lab.Body if lab != null else "none"])

	# One message a person.
	var before := EventBus.MessageLog.size()
	prisoner.CapturedBy = them
	MissionManager.TellCaptured(prisoner, enemy)
	var taken: GameMessage = _titled(EventBus.MessageLog.slice(before), "%s Captured" % prisoner.Name)
	_check(taken != null and taken.Body == "%s was captured by the %s at %s." % [prisoner.Name, them.ShortName, enemy.Name], "'%s Captured' / '... was captured by the %s at %s.'" % [prisoner.Name, them.ShortName, enemy.Name])
	before = EventBus.MessageLog.size()
	MissionManager.Kill(prisoner)
	var dead: GameMessage = _titled(EventBus.MessageLog.slice(before), "%s Killed" % prisoner.Name)
	_check(dead != null and dead.Body == "%s has been killed." % prisoner.Name and dead.Sound == "strategy/1140", "'%s Killed' / '%s has been killed.', 1140" % [prisoner.Name, prisoner.Name])
	_check(taken != null and taken.Sound == "strategy/1100", "... 'Captured' with 1100")
	_finish()


static func _remove(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in DirAccess.get_directories_at(path):
		_remove("%s/%s" % [path, sub])
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute("%s/%s" % [path, file])
	DirAccess.remove_absolute(path)


func _imprison(c: Character, at: Planet) -> void:
	c.CapturedBy = them
	c.Status = Enums.Status.Kidnapped
	c.Attached = at


## Resolve one mission of `type` by `who` at `target`, from `home`; the messages it sent.
func _run(type: int, who: Character, target: Planet, home: Planet, rng: Prng, victim: Character = null, thing: Variant = null) -> Array:
	var m := Mission.new()
	m.Type = type
	m.Faction = us
	m.Target = target
	m.HomeBase = home
	m.Team.append(who)
	m.Attempts = 1
	m.DaysToTarget = 0
	m.TargetCharacter = victim
	if thing is Facility:
		m.TargetFacility = thing
	var before := EventBus.MessageLog.size()
	MissionManager.Resolve(m, rng, 1)
	return EventBus.MessageLog.slice(before)


static func _titled(msgs: Array, title: String) -> GameMessage:
	for g in msgs:
		if (g as GameMessage).Title == title:
			return g
	return null


func _finish() -> void:
	print("[mission_reports] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
