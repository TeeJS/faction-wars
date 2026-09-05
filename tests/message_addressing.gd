extends SceneTree
## Faction-specific messages must be addressed to their owner, not broadcast to
## everyone. Regression test for the leak where the Alliance player saw the Empire's
## "Darth Vader Arrives" / "... has recovered" etc. The message window already
## filters by EventBus.Visible(); the bug was the messages carrying For==null.
##
##   Godot_console.exe --headless --path . -s tests/message_addressing.gd

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
	var engine := GameSession.new_game("alliance", Enums.Difficulty.Medium, Enums.GalaxySize.Standard, 4243)
	var empire: Faction = FactionRegistry.ById("empire")
	var alliance: Faction = GameSettings.PlayerFaction   # the local (human) side
	_check(alliance != null and alliance.Id == "alliance", "the local player is the Alliance")

	# Send an Empire character on a plain (non-mission) move that lands this tick.
	var ec := _free_enemy_char(empire)
	var dest := _other_planet(ec.Attached if ec != null and ec.Attached is Planet else null)
	_check(ec != null and dest != null, "an Empire character and a destination exist")
	if ec == null or dest == null:
		_finish(); return
	ec.Status = Enums.Status.Enroute
	ec.Destination = dest
	ec.DaysToDestination = 1

	engine.AdvanceDay()

	# The arrival message for that Empire character must be addressed to the Empire
	# and NOT visible to the local Alliance player.
	var arr := _find_msg(Enums.MessageType.PersonnelArrive, ec)
	_check(arr != null, "the Empire character's arrival raised a PersonnelArrive message")
	if arr != null:
		_check(arr.For == empire, "the arrival is addressed to the Empire (For==empire), not broadcast")
		_check(not EventBus.Visible(arr), "the Alliance player does NOT see the Empire arrival")

	# And an Alliance character's own arrival IS visible to the Alliance player.
	var ac := _free_own_char(alliance)
	var adest := _other_planet(ac.Attached if ac != null and ac.Attached is Planet else null)
	if ac != null and adest != null:
		ac.Status = Enums.Status.Enroute
		ac.Destination = adest
		ac.DaysToDestination = 1
		engine.AdvanceDay()
		var ours := _find_msg(Enums.MessageType.PersonnelArrive, ac)
		_check(ours != null and ours.For == alliance, "our own arrival is addressed to us")
		if ours != null:
			_check(EventBus.Visible(ours), "the Alliance player DOES see its own arrival")

	_finish()


func _free_enemy_char(empire: Faction) -> Character:
	for c in GameState.ActiveRoster:
		if c.Faction == empire and c.Attached is Planet and c.Status == Enums.Status.AwaitingOrders \
				and not c.IsCaptured() and not MissionManager.IsOnMissionTeam(c):
			return c
	return null


func _free_own_char(us: Faction) -> Character:
	for c in GameState.ActiveRoster:
		if c.Faction == us and c.Attached is Planet and c.Status == Enums.Status.AwaitingOrders \
				and not c.IsCaptured() and not MissionManager.IsOnMissionTeam(c):
			return c
	return null


func _other_planet(not_this: Planet) -> Planet:
	for p in GameState.AllPlanets():
		if p != not_this:
			return p
	return null


## Newest matching message for a character (the arrival we just triggered).
func _find_msg(type: int, who: Character) -> GameMessage:
	for i in range(EventBus.MessageLog.size() - 1, -1, -1):
		var m: GameMessage = EventBus.MessageLog[i]
		if m.Type == type and m.AssociatedCharacter == who:
			return m
	return null


func _finish() -> void:
	print("[message_addressing] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
