class_name GameSettings
extends RefCounted
## backend/GameSettings.cs - the choices made on the menu, plus the session seed.

static var SelectedDifficulty: Enums.Difficulty = Enums.Difficulty.Medium
## No default: the pack decides which factions exist, so this is only valid once
## the menu has chosen one from FactionRegistry.Playable.
static var PlayerFaction: Faction = null
## THE HUMAN SIDES. Single player: the one chosen on the menu. Head-to-head: both.
## The SIMULATION asks IsHuman(f); it never reads PlayerFaction, which is the
## LOCAL client's side and is for presentation only (docs/m0-audit.md section 5).
static var HumanFactions: Array[Faction] = []


static func IsHuman(f: Faction) -> bool:
	return f != null and HumanFactions.has(f)


## The side this client plays - the name PlayerFaction keeps for the UI.
static func LocalFaction() -> Faction:
	return PlayerFaction


## THE HOST'S SIDE in a head-to-head game; null in single player.
static var HostFaction: Faction = null


## THE SIDE WHOSE ROW OF THE HUMAN-KEYED TABLES IS READ. SDPRTB (side_lottery.json)
## is laid out per player side x difficulty x side, so even its "mp" column sits
## under a player-side row. Single player: the human. Head-to-head: the host's
## side - PROPOSED, not sourced (docs/m0-audit.md question 2); the same on both
## clients, which is what lockstep needs.
static func SeedingFaction() -> Faction:
	if HumanFactions.size() > 1 and HostFaction != null:
		return HostFaction
	return PlayerFaction
static var SelectedSize: Enums.GalaxySize = Enums.GalaxySize.Large
static var HQOnlyVictory: bool = false
## Head-to-head only (TeeJ, room AM-LFGGG3LVQSSJGXSP7P7JE9Q745 #75): how the two
## players' speed settings combine. "slowest" is the manual's rule (p163);
## "average" is TeeJ's addition: floor((a + b) / 2), so adjacent settings give
## the slower one and an unbalanced pair rounds down. Pause on either side
## pauses both under either rule.
static var SpeedRule: String = "slowest"

## The session's PRNG seed - see Prng. Printed at start; --seed=N replays.
static var Seed: int = 0
