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
var IdleFleets: Array = []       ## our non-empty fleets not en route and not pinned

# --- Written by Reactions (M4). Reprioritise, never spend (AR-4) ----------
var Interrupts: Array = []       ## situational urgencies raised by events this cycle
var Inferences: Dictionary = {}  ## fog-legal deductions, e.g. planet -> "diplomat here"


## STAGE: CONTEXT. Categorise the whole galaxy for one faction, intel-gated for
## other sides' worlds. Populated at M1. (M0: skeleton returns an empty context.)
static func Build(_galaxy: Array, us: Faction, day: int) -> AIContext:
	var c := AIContext.new()
	c.Us = us
	c.Day = day
	return c
