class_name AIContext
extends RefCounted
## The shared reader — docs/ai-framework/01-architecture.md "Context".
## Read-only to every stage; written only by Reactions (AR-4: a per-day snapshot).
##
## FOG-LEGAL BY CONSTRUCTION (charter "The fairness rule", G3). Every field derives
## from exactly one of: our own faction state, GalaxyView categorisation of what we
## can see, or IntelManager staleness reads. NEVER raw enemy state. The M1 fog
## audit (BUILD-PLAN.md) lists every field and its source and confirms this.
##
## Categories mirror the original's own galaxy read (was AiManager.GalaxyView):
## our worlds split strong/weak by support, their *seen* worlds likewise, neutral,
## unexplored, and our threatened worlds. WeakSupportCeiling is the original's
## split and is preserved.

const WeakSupportCeiling := 50   ## support < this == "weak" (was ai_manager.gd:12)

var Us: Faction
var Day: int = 0

# --- World, as WE legitimately see it -------------------------------------
var OursStrong: Array = []
var OursWeak: Array = []
var TheirsStrong: Array = []     ## intel-gated: only worlds we Know
var TheirsWeak: Array = []       ## intel-gated
var Neutral: Array = []
var Unexplored: Array = []
var Threatened: Array = []       ## our worlds with a hostile fleet in orbit

# --- Own free assets ------------------------------------------------------
var FreeCharacters: Array = []   ## our characters awaiting orders, on a planet
var FreeSpecForces: Array = []   ## our SpecForce units awaiting orders (probe droids,
                                 ## Longprobe teams, saboteurs) — the ONLY units that
                                 ## can run Reconnaissance (p107) and most Sabotage
var IdleFleets: Array = []       ## our non-empty fleets not en route and not pinned

# --- Written by Reactions (M4). Reprioritise, never spend (AR-4) ----------
var Interrupts: Array = []       ## situational urgencies raised by events this cycle
var Inferences: Dictionary = {}  ## fog-legal deductions, e.g. planet -> "diplomat here"


## Our own worlds (control == us). Convenience for the policies.
var Held: Array = []


## STAGE: CONTEXT. Categorise the whole galaxy for one faction, intel-gated for
## other sides' worlds, and collect our own free assets. FOG-LEGAL: the only reads
## of another side's world are behind IntelManager.Knows / p.ExploredBy; our own
## worlds and roster are ours to read fully. (Mirrors the original's Evaluate,
## which the corpus judged faithful; the categories are unchanged.)
static func Build(galaxy: Array, us: Faction, day: int) -> AIContext:
	var c := AIContext.new()
	c.Us = us
	c.Day = day

	for s in galaxy:
		for p in s.Planets:
			# Unexplored is UNKNOWN, not empty — we may not read its contents at all.
			if not p.ExploredBy(us):
				c.Unexplored.append(p)
				continue
			if not p.IsInhabited:
				continue
			var owner: Faction = p.ControllingFaction
			if owner == us:
				c.Held.append(p)
				# A hostile, non-empty fleet in our orbit == a threatened world.
				if Lq.any(p.FleetsInOrbit(), func(f): return f.Faction != null and f.Faction != us and not f.IsEmpty()):
					c.Threatened.append(p)
				if p.SupportFor(us) < WeakSupportCeiling:
					c.OursWeak.append(p)
				else:
					c.OursStrong.append(p)
			elif owner == null or owner == FactionRegistry.Neutral:
				c.Neutral.append(p)
			else:
				# Another side's world: only categorise it if intel says we KNOW its
				# status. Staleness, not concealment — this is what we last saw.
				if not IntelManager.Knows(us, p, Enums.IntelSection.SystemStatus):
					continue
				if p.SupportFor(owner) < WeakSupportCeiling:
					c.TheirsWeak.append(p)
				else:
					c.TheirsStrong.append(p)

	# Our free characters: ours, awaiting orders, on a planet, not captured/off-map,
	# not already committed to a mission team.
	for ch in GameState.ActiveRoster:
		if ch.Faction == us and ch.Status == Enums.Status.AwaitingOrders \
				and ch.Attached is Planet and not ch.IsCaptured() and not ch.IsOffMap() \
				and not MissionManager.IsOnMissionTeam(ch):
			c.FreeCharacters.append(ch)

	# Our free SpecForce units (on our own or explored worlds), awaiting orders and
	# not already on a mission team. These carry recon and most sabotage.
	for p in GameState.AllPlanets():
		for u in p.SpecForces():
			if u.Faction == us and u.Status == Enums.Status.AwaitingOrders \
					and not MissionManager.IsOnMissionTeam(u):
				c.FreeSpecForces.append(u)

	# Our idle fleets: ours, non-empty, not en route. "Busy" (guarding/blockading)
	# filtering is a fleet-policy concern (M2); context just reports what exists.
	for p in GameState.AllPlanets():
		for f in p.FleetsInOrbit():
			if f.Faction == us and not f.IsEmpty() and f.Status != Enums.Status.Enroute:
				c.IdleFleets.append(f)

	return c


## Fog-legal read helpers, so stages go through Context rather than touching raw
## enemy state directly.

## What we last saw of a support figure. For our own worlds this is live; for
## others it is only meaningful when Knows() is true (staleness model).
func SeenSupportFor(p: Planet, of: Faction) -> int:
	return p.SupportFor(of)


## Do we legitimately know this category of this world?
func Knows(p: Planet, section: int) -> bool:
	return IntelManager.Knows(Us, p, section)


## The day we last saw this category (0 if never / live if we hold it). Staleness
## drives "refresh intel" decisions (RULE-02-01).
func IntelDayOf(p: Planet, section: int) -> int:
	return IntelManager.View(Us, p, section).Day
