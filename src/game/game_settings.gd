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
static var SelectedSize: Enums.GalaxySize = Enums.GalaxySize.Large
static var HQOnlyVictory: bool = false

## The session's PRNG seed - see Prng. Printed at start; --seed=N replays.
static var Seed: int = 0
