extends RefCounted
## THE AGENT'S ADVICE MESSAGES (manual p022, p078, p079; docs/advisor-plan.md
## phase 5): the agent's tips, in the Message Index's Advice tab - "the only
## category not also shown under All Messages", and the one kind never deleted
## on its own (p079). Their titles, texts and picture come from the art set
## (exporter 2.6.2: advice.json, the original's own lists from TEXTSTRA.DLL,
## and windows/advice.<side>.png); the pack's `advice` says, per side, which
## list is this side's, its groups' moments, and the picture.
##
## AGENT ADVICE, on the agent's menu and Alt+A (p078: "When checked (the
## default state), the agent periodically gives you tips on playing the game.
## This advice is channeled through the message system"). "Agent Advice only
## appears in an Easy game. If you wish for advice in Medium or Hard games, you
## must enable Agent Advice on the Agent menu" (p022; REBEXE's agent sets its
## advice-off flag at creation unless the game is Easy, FUN_00439320).
##
## What the original does (REBEXE, read 2026-09-27 with TeeJ's approval; the
## functions as open-rebellion's Ghidra notes name them):
##   - its advice starts by posting the `opening` group, in the list's order
##     (FUN_00439f20) - the nine on TeeJ's screenshot of the original's Advice
##     tab. It starts when the briefing ends, or at the first moment below;
##   - the rest wait in the order of their keys (a sorted tree, FUN_005f4f10);
##   - the first time the player opens each kind of window (`events`) - a
##     sector window, or a system's Manufacturing, Fleet, Defenses or Missions
##     window - the first waiting tip of that kind's group comes at once
##     (FUN_0043a0b0, reached through FUN_00429ce0 and FUN_0045aac0);
##   - every `every` ticks (300) since the last tip, the first waiting tip of
##     the `periodic` group, or of a group whose window has been opened
##     (FUN_00439bc0 -> FUN_00439fb0);
##   - with Agent Advice off, nothing happens, and windows opened are not
##     counted.
## A tick is the original's: a day is 600 of them at Very Slow, 60 at Slow,
## 12 at Medium, 4 at Fast (FUN_00487eb0) - so a tip comes every half day at
## Very Slow and every 75 days at Fast, about the same time at the table.
##
## Single player only, as the briefing. Without the art set's file nothing is
## posted. Preloaded by path (as AdviceLib).

const MusicLib := preload("res://src/ui/music.gd")

## Ticks a day at each speed (GameManager.SpeedNames' order): REBEXE FUN_00487eb0.
const TICKS_PER_DAY: Array[int] = [0, 600, 60, 12, 4]

## Agent Advice is on (the agent's menu). Set by Start.
static var On: bool = false
static var _opened: bool = false      # the opening group has been posted
static var _side: Faction = null
static var _waiting: Array = []       # the other tips, by key
static var _seen: Dictionary = {}     # window kind -> true, opened while on
static var _ticks: float = 0.0        # ticks since the game started
static var _last: float = 0.0         # the tick of the last tip


## A game begins or is loaded (`side` null in head-to-head: no advice): Agent
## Advice on in Easy only (p022), no window seen, every tip but the opening
## group waiting. The opening advice comes when the briefing ends (a new
## game's; UIManager.BriefingOver) or at the first moment.
static func Start(side: Faction) -> void:
	On = side != null and GameSettings.SelectedDifficulty == Enums.Difficulty.Easy
	_side = side
	_opened = false
	_seen = {}
	_ticks = 0.0
	_last = 0.0
	var opening := int(ForSide(side).get("opening", -1))
	_waiting = Messages(side).filter(func(e: Variant) -> bool:
		return e is Dictionary and int((e as Dictionary).get("group", -1)) != opening)
	_waiting.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("key", 0)) < int(b.get("key", 0)))


## The briefing has ended (the original's: FUN_004c0fc0 case 0xd): the
## opening advice, if Agent Advice is on. Returns how many were posted.
static func BriefingEnded(day: int) -> int:
	return _open(day) if On else 0


## Whether this game's opening advice has been posted.
static func Given() -> bool:
	return _opened


## Agent Advice switched on or off from the agent's menu. The opening advice,
## if the game has not had it, comes at the next moment, as the original's.
static func SetOn(on: bool) -> void:
	On = on


## The player opened a window of `kind` (PackLoader.KNOWN_ADVICE_EVENTS). The
## first time, while Agent Advice is on, the first waiting tip of its group.
## Returns how many were posted.
static func Opened(kind: String, day: int) -> int:
	if not On or _side == null:
		return 0
	var n := _open(day)
	if _seen.has(kind):
		return n
	_seen[kind] = true
	var group: Variant = (ForSide(_side).get("events", {}) as Dictionary).get(kind) if ForSide(_side).get("events") is Dictionary else null
	if group == null:
		return n
	for e: Dictionary in _waiting:
		if int(e.get("group", -1)) == int(group):
			_post(e, day)
			_last = _ticks
			return n + 1
	return n


## The clock ran `ticks` ticks. Every `every` ticks since the last tip, while
## Agent Advice is on, the first waiting tip it may give. Returns how many
## were posted.
static func Advance(ticks: float, day: int) -> int:
	_ticks += ticks
	var cfg := ForSide(_side)
	if not On or _side == null or not cfg.has("every") or _ticks < _last + float(cfg["every"]):
		return 0
	var n := _open(day)
	var groups := {int(cfg.get("periodic", -1)): true}
	var events: Variant = cfg.get("events", {})
	for kind in _seen:
		if events is Dictionary and (events as Dictionary).has(kind):
			groups[int(events[kind])] = true
	for e: Dictionary in _waiting:
		if groups.has(int(e.get("group", -1))):
			_post(e, day)
			n += 1
			break
	_last = _ticks
	return n


## Ticks in `seconds` of a day that lasts `day_seconds` at `speed`.
static func TicksIn(seconds: float, day_seconds: float, speed: int) -> float:
	if speed <= 0 or speed >= TICKS_PER_DAY.size() or day_seconds <= 0.0:
		return 0.0
	return seconds / day_seconds * TICKS_PER_DAY[speed]


static func _open(day: int) -> int:
	if _opened or _side == null:
		return 0
	var n := PostOpening(_side, day)
	_opened = n > 0
	return n


static func _post(e: Dictionary, day: int) -> void:
	_waiting.erase(e)
	var msg := GameMessage.new(str(e.get("title", "")), str(e.get("text", "")), Enums.MessageCategory.Advice, day)
	msg.Picture = str(ForSide(_side).get("picture", ""))
	EventBus.Tell(_side, msg)


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
