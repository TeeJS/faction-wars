class_name Command
extends RefCounted
## One player order, as it crosses the wire and as it sits in the log
## (docs/m1-plan.md section 1). Args hold entity IDS and plain values only -
## never object references - so the same line means the same thing on both
## clients and on a replay.

var Day: int = 0
var Seq: int = 0
var Faction: String = ""
var Kind: String = ""
var Args: Dictionary = {}


static func make(kind: String, args: Dictionary) -> Command:
	var c := Command.new()
	c.Kind = kind
	c.Args = args
	return c


func to_json() -> String:
	return JSON.stringify({ "day": Day, "seq": Seq, "faction": Faction, "kind": Kind, "args": Args })


static func from_json(line: String) -> Command:
	var d: Variant = JSON.parse_string(line)
	if not (d is Dictionary) or not d.has("kind"):
		return null
	var c := Command.new()
	c.Day = int(d.get("day", 0))
	c.Seq = int(d.get("seq", 0))
	c.Faction = str(d.get("faction", ""))
	c.Kind = str(d.get("kind", ""))
	c.Args = d.get("args", {})
	return c


## Deterministic order within a day: faction order from the pack, then Seq.
static func sort_key(c: Command) -> Array:
	return [FactionRegistry.OrderOf(FactionRegistry.ById(c.Faction)), c.Seq]
