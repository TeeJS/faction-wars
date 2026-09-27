extends RefCounted
## THE AGENT'S ADVICE MESSAGES (manual p022, p079; docs/advisor-plan.md): the
## agent's tips, in the Message Index's Advice tab - "the only category not
## also shown under All Messages", and the one kind never deleted on its own
## (manual p079). Their titles, texts and picture come from the art set
## (exporter 2.6.2: advice.json, the original's own lists from TEXTSTRA.DLL,
## and windows/advice.<side>.png); the pack's `advice` says, per side, which
## list is this side's, which group a game opens with, and the picture.
##
## AGENT ADVICE, on the agent's menu (manual p078: "When checked (the default
## state), the agent periodically gives you tips on playing the game. This
## advice is channeled through the message system"), and Alt+A. "Agent Advice
## only appears in an Easy game. If you wish for advice in Medium or Hard
## games, you must enable Agent Advice on the Agent menu" (manual p022): so a
## new game starts with it on in Easy only.
##
## While it is on, the side has its opening advice - the opening group, in the
## list's order: top to bottom in the Message Index, as on TeeJ's screenshot
## of the original's Advice tab (2026-09-27), the nine messages of group 7,
## the group the original posts when its advice starts (FUN_00439f20,
## open-rebellion's Ghidra notes). A new game in Easy posts it at once;
## turning Agent Advice on later posts it then, once a game.
##
## NOT BUILT: the rest of each list, tips the original posts one at a time as
## the game goes on (FUN_0043a0b0 / FUN_00439fb0). Which events set them off,
## and how often, only REBEXE would say (docs/advisor-plan.md).
##
## Without the art set's file nothing is posted. Preloaded by path (as AdviceLib).

const MusicLib := preload("res://src/ui/music.gd")

## Agent Advice is on (the agent's menu). Set by Start at a new game.
static var On: bool = false
## The opening advice has been posted this game.
static var _opened: bool = false


## A new game: Agent Advice on in Easy only (manual p022), and the opening
## advice posted if it is. Returns how many messages were posted.
static func Start(side: Faction, day: int) -> int:
	On = GameSettings.SelectedDifficulty == Enums.Difficulty.Easy
	_opened = false
	return _open(side, day) if On else 0


## Agent Advice switched on or off from the agent's menu. Switched on, the
## opening advice is posted if this game has not had it. Returns how many
## messages were posted.
static func SetOn(side: Faction, on: bool, day: int) -> int:
	On = on
	return _open(side, day) if on else 0


## A loaded game or none: nothing posted, Agent Advice as its difficulty
## starts it (messages are not saved, so neither is this).
static func Reset() -> void:
	On = GameSettings.SelectedDifficulty == Enums.Difficulty.Easy
	_opened = true


static func _open(side: Faction, day: int) -> int:
	if _opened:
		return 0
	var n := PostOpening(side, day)
	_opened = n > 0
	return n


## `side`'s advice in the pack, or {}.
static func ForSide(side: Faction) -> Dictionary:
	if side == null or FactionRegistry.Pack == null:
		return {}
	var v: Variant = FactionRegistry.Pack.Manifest.Advice.get(side.Id, {})
	return v if v is Dictionary else {}


## `side`'s list from the art set's file, each {n, group, key, title, text};
## [] without the file.
static func Messages(side: Faction) -> Array:
	var cfg := ForSide(side)
	var file := MusicLib.FileOf(str(cfg.get("messages", "")))
	if file.is_empty():
		return []
	var json: Variant = JSON.parse_string(FileAccess.get_file_as_string(file))
	if not json is Dictionary:
		return []
	var list: Variant = (json as Dictionary).get(str(cfg.get("list", "")), [])
	return list if list is Array else []


## The messages a game opens with: the `opening` group's, in the list's order.
static func Opening(side: Faction) -> Array:
	var cfg := ForSide(side)
	if not cfg.has("opening"):
		return []
	var group := int(cfg["opening"])
	return Messages(side).filter(func(e: Variant) -> bool:
		return e is Dictionary and int((e as Dictionary).get("group", -1)) == group)


## Posts `side`'s opening advice to it, dated `day`. Returns how many.
static func PostOpening(side: Faction, day: int) -> int:
	var picture := str(ForSide(side).get("picture", ""))
	var n := 0
	for e: Dictionary in Opening(side):
		var msg := GameMessage.new(str(e.get("title", "")), str(e.get("text", "")), Enums.MessageCategory.Advice, day)
		msg.Picture = picture
		EventBus.Tell(side, msg)
		n += 1
	return n
