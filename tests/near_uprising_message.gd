extends SceneTree
## The garrison warning names its system, as the original's does: TEXTSTRA
## 0x00f3f6 is "|" + field 1 + " Near Uprising" - "<system> Near Uprising".
## Ours said "Near Uprising" alone (TeeJ, 2026-09-27: "NEAR UPRISING message
## is missing the planet name").
##
##   .\tools\run-gd.ps1 tests/near_uprising_message.gd

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[near_uprising_message] ok   %s" % what)
	else:
		_fails += 1
		print("[near_uprising_message] FAIL %s" % what)


func _init() -> void:
	await process_frame
	GameSettings.PlayerFaction = FactionRegistry.ById("empire")
	GameSession.new_game("empire", Enums.Difficulty.Medium, Enums.GalaxySize.Standard, 4243)
	var us: Faction = FactionRegistry.ById("empire")
	GameSettings.PlayerFaction = us
	var world: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool: return p.ControllingFaction == us)
	_check(world != null, "a world of ours")
	if world != null:
		world.IsNearUprising = false
		world.WarnGarrison(2, 0)
		var msg: GameMessage = Lq.first_or_null(EventBus.MessageLog, func(m: GameMessage) -> bool: return m.Type == Enums.MessageType.GarrisonWarning)
		_check(msg != null and msg.Title == "%s Near Uprising" % world.Name, "the title names the system: '%s'" % (msg.Title if msg != null else "none"))
		_check(msg != null and msg.Body.begins_with("Unrest has pushed %s close to uprising." % world.Name), "the body, the original's words first")
	print("[near_uprising_message] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
