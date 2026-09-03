class_name DebugKeys
extends Node
## backend/DebugKeys.cs - DEVELOPER SHORTCUTS. Nothing here is a game feature
## and none of it is in the manual. Every key is CTRL+SHIFT so none can be hit
## by accident mid-game, and every one prints what it did.

var _engine: StrategicTickManager
var _galaxy: Array


func Setup(engine: StrategicTickManager, galaxy: Array) -> void:
	_engine = engine
	_galaxy = galaxy
	print("[Debug] Ctrl+Shift+H for the key list.")


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if not event.ctrl_pressed or not event.shift_pressed:
		return

	match event.keycode:
		KEY_H: PrintHelp()
		KEY_M: GrantMaterials(200)
		KEY_D: SkipDays(10)
		KEY_F: SkipDays(50)
		KEY_UP:   ShiftSupport(GameSettings.PlayerFaction, +15)
		KEY_DOWN: ShiftSupport(GameSettings.PlayerFaction, -15)
		KEY_E:    ShiftSupport(OpposingFaction(), +15)
		KEY_X: RevealGalaxy()
		KEY_R: GrantResearch(60)
		KEY_J: GrantForce(25)
		KEY_S: DumpState()
		_: return

	get_viewport().set_input_as_handled()


static func PrintHelp() -> void:
	print(
		"\n=== DEBUG KEYS (Ctrl+Shift+...) ===\n" +
		"  M   +200 refined material\n" +
		"  D   skip 10 days\n" +
		"  F   skip 50 days\n" +
		"  Up  +15 popular support for you, every explored world\n" +
		"  Dn  -15 popular support for you\n" +
		"  E   +15 support for the OPPONENT - drives your loyalty down\n" +
		"  X   reveal the whole galaxy\n" +
		"  R   +60 research points on all three tracks\n" +
		"  J   +25 Force to every Force-capable character of yours\n" +
		"  S   dump a state summary\n" +
		"  H   this list\n")


static func OpposingFaction() -> Faction:
	return Lq.first_or_null(FactionRegistry.Playable, func(f: Faction) -> bool: return f != GameSettings.PlayerFaction)


static func GrantMaterials(amount: int) -> void:
	Economy.For(GameSettings.PlayerFaction).RefinedMaterials += amount
	print("[Debug] +%d refined -> %d" % [amount, Economy.For(GameSettings.PlayerFaction).RefinedMaterials])


## Runs the real day tick - fast-forward, not a shortcut around the simulation.
func SkipDays(days: int) -> void:
	if _engine == null:
		print("[Debug] no engine")
		return
	for i in days:
		_engine.AdvanceDay()
	print("[Debug] skipped %d days -> day %d" % [days, StrategicTickManager.Today])


func ShiftSupport(f: Faction, delta: int) -> void:
	if f == null or _galaxy == null:
		return
	var touched := 0
	for s in _galaxy:
		for p in s.Planets:
			if not p.IsExplored:
				continue
			p.ShiftSupport(f, delta)
			touched += 1
	print("[Debug] %s%d support for %s on %d worlds" % ["+" if delta >= 0 else "", delta, f.DisplayName, touched])
	EventBus.BroadcastChanged()


func RevealGalaxy() -> void:
	var n := 0
	for s in _galaxy:
		for p in s.Planets:
			if not p.IsExplored:
				p.IsExplored = true
				n += 1
	print("[Debug] revealed %d systems" % n)
	EventBus.BroadcastChanged()


static func GrantResearch(points: int) -> void:
	var f: Faction = GameSettings.PlayerFaction
	for track in Enums.ResearchTrackKind.size():
		ResearchManager.DebugGrant(f, track, points, StrategicTickManager.Today)
	print("[Debug] +%d research on all three tracks" % points)
	EventBus.BroadcastChanged()


static func GrantForce(amount: int) -> void:
	var n := 0
	for c in GameState.ActiveRoster:
		if c.Faction != GameSettings.PlayerFaction or c.JediProbability <= 0:
			continue
		c.IsKnownJedi = true
		c.JediLevel += amount
		print("[Debug]   %s -> Force %d (%s)" % [c.Name, c.JediLevel, JsonUtil.enum_name(Enums.ForceRanking, c.ForceRank())])
		n += 1
	print("[Debug] +%d Force to %d characters" % [amount, n])
	EventBus.BroadcastChanged()


func DumpState() -> void:
	var f: Faction = GameSettings.PlayerFaction
	var econ: Economy.FactionEconomy = Economy.For(f)

	print("\n=== DAY %d - %s ===" % [StrategicTickManager.Today, f.DisplayName if f != null else ""])
	print("  refined %d" % econ.RefinedMaterials)

	var worlds := 0
	var explored := 0
	for s in _galaxy:
		for p in s.Planets:
			if p.IsExplored:
				explored += 1
			if p.ControllingFaction == f:
				worlds += 1
	print("  worlds %d, explored %d" % [worlds, explored])

	for t in Enums.ResearchTrackKind.size():
		print("  research track %d: %d pts" % [t, ResearchManager.PointsIn(f, t)])

	print("  active missions: %d" % MissionManager.Active().size())

	for c in GameState.ActiveRoster:
		if c.Faction != f:
			continue
		var bits: PackedStringArray = PackedStringArray()
		if c.IsCaptured():
			bits.append("CAPTURED by %s" % c.CapturedBy.DisplayName)
		if c.IsInjured():
			bits.append("injured")
		if c.Status == Enums.Status.Dead:
			bits.append("DEAD")
		if c.TraitorRevealed:
			bits.append("TRAITOR")
		if c.ForceRank() != Enums.ForceRanking.None:
			bits.append("Force %s" % JsonUtil.enum_name(Enums.ForceRanking, c.ForceRank()))
		if not bits.is_empty():
			print("    %s: %s" % [c.Name, ", ".join(bits)])
	print("")
