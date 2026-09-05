extends SceneTree
## Two events that filed no message before now do, addressed to the owner:
##  - a character being INJURED (the counterpart to "has recovered"), and
##  - a system JOINING via diplomacy (manual: C-3PO "Good news, a system joined").
## Both go to the owning faction only - never broadcast to the enemy.
##
##   Godot_console.exe --headless --path . -s tests/event_messages.gd

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("  FAIL %s" % what)


func _init() -> void:
	await process_frame
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSession.new_game("alliance", Enums.Difficulty.Medium, Enums.GalaxySize.Standard, 4243)
	var alliance: Faction = GameSettings.PlayerFaction
	var empire: Faction = FactionRegistry.ById("empire")

	# --- INJURY (#4) ---------------------------------------------------------
	# Majors survive a wound (never killed), so Injure deterministically notifies.
	var ally_major: Character = _major(alliance)
	var imp_major: Character = _major(empire)
	_check(ally_major != null and imp_major != null, "a major on each side exists")
	if ally_major == null or imp_major == null:
		_finish(); return

	MissionManager.Injure(ally_major, Prng.Session)
	var ourHurt := _find(Enums.MessageType.CharacterHealth, ally_major, "injured")
	_check(ourHurt != null, "our injury raised a message")
	if ourHurt != null:
		_check(ourHurt.For == alliance, "our injury is addressed to us")
		_check(EventBus.Visible(ourHurt), "we see our own injury")

	MissionManager.Injure(imp_major, Prng.Session)
	var theirHurt := _find(Enums.MessageType.CharacterHealth, imp_major, "injured")
	_check(theirHurt != null and theirHurt.For == empire, "the enemy's injury is addressed to the Empire")
	if theirHurt != null:
		_check(not EventBus.Visible(theirHurt), "we do NOT see the enemy's injury (no leak)")

	# --- SYSTEM JOINS via diplomacy (#5) ------------------------------------
	var neutral: Planet = _first(func(p): return p.IsInhabited and FactionRegistry.OrderOf(p.ControllingFaction) < 0)
	var from: Planet = _first(func(p): return p.ControllingFaction == alliance)
	var dip: Character = _first_char(func(c): return c.Faction == alliance and c.DiplomacyRating > 0 and c.Status != Enums.Status.Dead and not c.IsInjured())
	_check(neutral != null and from != null and dip != null, "a neutral world, a base and a diplomat exist")
	if neutral != null and from != null and dip != null:
		neutral.SetExplored(alliance, true)  # diplomacy needs an explored target (p106)
		neutral.ShiftSupport(alliance, 60)   # already past the 50% join line
		dip.Status = Enums.Status.AwaitingOrders
		MilitaryCatalog.Relocate(dip, from)
		var m: Mission = MissionManager.Launch(Enums.MissionType.Diplomacy, [dip], from, neutral)
		_check(m != null, "diplomacy mission launched")
		if m != null:
			m.DaysToTarget = 1   # arrives (and lands) on the next ProcessDay
			for c in m.Team:
				c.DaysToDestination = 1
			# Resolve a few times if needed; a neutral world may take more than one pass.
			var joined_msg: GameMessage = null
			for _i in 12:
				if m in MissionManager.Active():
					m.DaysOnStation = 0   # skip the work-days wait so it resolves now
				MissionManager.ProcessDay(Prng.Session, StrategicTickManager.Today)
				joined_msg = _find(Enums.MessageType.SystemControl, null, "joined")
				if joined_msg != null:
					break
			_check(neutral.ControllingFaction == alliance, "the neutral world joined the Alliance")
			_check(joined_msg != null, "the join raised a SystemControl message")
			if joined_msg != null:
				_check(joined_msg.For == alliance, "the join message is addressed to us")

	_finish()


func _major(f: Faction) -> Character:
	return _first_char(func(c): return c.Faction == f and c.IsMajor and c.Status != Enums.Status.Dead)


func _first(pred: Callable) -> Planet:
	for p in GameState.AllPlanets():
		if pred.call(p):
			return p
	return null


func _first_char(pred: Callable) -> Character:
	for c in GameState.ActiveRoster:
		if pred.call(c):
			return c
	return null


## Newest message of a type, optionally about a character, whose title contains `word`.
func _find(type: int, who, word: String) -> GameMessage:
	for i in range(EventBus.MessageLog.size() - 1, -1, -1):
		var m: GameMessage = EventBus.MessageLog[i]
		if m.Type != type:
			continue
		if who != null and m.AssociatedCharacter != who:
			continue
		if not m.Title.to_lower().contains(word):
			continue
		return m
	return null


func _finish() -> void:
	print("[event_messages] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
