# 03 — Economy Loop Policy

| | |
|---|---|
| **Status** | REVIEWED — Han (room #165); one correction applied |
| **Authors** | Doof (draft) |
| **Inputs** | `02-rule-corpus.md`; `manual/strategy-guide/analysis/ch03-developing-your-infrastructure.md`; `manual/strategy-guide/analysis/ch07-acquiring-new-systems.md` |
| **Scope** | Policy argument for the economy loop. Rule text lives in `02-rule-corpus.md`. This document argues how the rules fit together, what conflicts exist, and what the loop is trying to achieve. |

---

## What the economy loop is for

The economy loop produces and maintains the infrastructure that funds everything else. Maintenance income from mines paired with refineries pays for ships, garrisons, facilities, and missions. Every other loop draws on a budget the economy loop either replenishes or fails to replenish. An AI that loses the economy loop does not lose immediately — it loses slowly, by being unable to replace what it spends, until the deficit becomes irreversible. This is the loop where falling behind is most insidious precisely because the game does not announce it.

The loop's job is not to maximise production in isolation. It is to produce the right facilities in the right sectors in the right order, so that every other loop has the resources it needs when it needs them. A galaxy full of mines on one continent and shipyards on another is not a functioning economy — it is a collection of facilities waiting to be a bottleneck.

---

## Three-phase structure

The guide describes a pipeline for developing infrastructure without naming it as such. Naming it matters for the AI because the decision rules are not the same in each phase, and an AI that applies opening rules in the mid-game wastes capacity, while one that skips to late-game rules before coverage is established leaves sectors undefended and underproducing.

### Coverage phase — opening

The first task is presence. The AI must have at least one construction yard per sector it controls (RULE-03-01, RULE-03-02), at least one shipyard per sector (RULE-03-08), and at least one training center per sector (RULE-03-10). Until these three are in place for every controlled sector, they are the only legitimate contents of the build queue. The guide is explicit that construction yards are "nothing more important initially" (ch03 L1056–1057), and that this priority holds through the first several hundred game days.

Two rules bound the opening. RULE-03-07 suppresses mine and refinery construction for approximately the first 100 days — the initial stock is sufficient, and CY capacity should go to facilities, not extraction. RULE-03-14 requires the AI to survey all idle facilities at game start and immediately queue something at each one. Both rules establish the same discipline: CY time is precious in the opening, it should never sit idle (RULE-03-03), and it should not be diverted to extraction before coverage is established.

One tactical constraint governs how coverage is achieved: always use the nearest construction yard for remote builds (RULE-03-04). Cross-sector deployment adds months to transit time. The facility deployment code path lives in `AgentDroid`, which has not been audited — whether it selects the nearest CY or some other criterion is unknown. This is the most structurally important open question in the coverage phase.

The coverage phase is, to be direct, almost entirely NOT IMPLEMENTED. No sector-coverage check exists for CYs, shipyards, or training centers. The code that runs in this phase is AgentDroid.ManageProduction(), whose behaviour has not been audited. It may cover some of this ground; it may not. Until that function is read, the coverage phase's implementation status is unknown.

### Balance phase — mid-game

Once each controlled sector has at least one of each core facility type, the loop's character changes. The immediate priority of building coverage yields to the ongoing priority of keeping everything producing. Shipyards should be building ships continuously (RULE-03-09). All idle shipyards should be assigned a build — not just the largest one, which is the current code's behaviour. The priority inversion from CYs to shipyards (RULE-03-17) takes effect once coverage is established.

The balance phase introduces the mine:refinery ratio as an active management question. This is discussed in its own section below.

The balance phase also introduces facility placement discipline. When a new facility needs to be built, it should go on a planet that already has facilities of the same type, not an empty slot picked at random (RULE-03-11). Clustering multiplies speed. Two construction yards on the same planet build a third faster than one CY on each of two planets would. This is not just an efficiency preference — it is a rule with a real game mechanic behind it (confirmed via GAMEPLAY.md §3: "Two construction yards double the speed, three triple the speed, and so on"). The linear scaling is what makes the clustering argument load-bearing rather than a preference: every additional CY on the same planet yields another full-speed multiplier.

### Optimize phase — late game

Once a sector's facility network is mature, the economy loop shifts to refinement. Advanced facilities (unlocked by R&D) occupy one slot but produce as fast as two standard ones (confirmed: `src/game/planet.gd:180`, rate=2 vs rate=4). The AI should replace standard facilities with advanced ones one at a time after each unlock (RULE-03-13) — not sector-by-sector, but one replacement at a time, because dismantling an entire sector at once to upgrade it destroys current capacity during the transition.

Separately, sectors that are fully developed become candidates for scrap evaluation (RULE-03-12). A lone CY in a sector that already has three or more, with no other production on its system, is occupying a slot that could hold something more valuable. And outer-rim uninhabited systems, which have no value during the opening, become worthwhile as dedicated mining planets once core-sector infrastructure is stable (RULE-03-16).

---

## The mine:refinery mechanic is galaxy-wide, not per-system

This is the most important non-obvious fact about the economy loop. The guide states it explicitly, and GAMEPLAY.md §3 confirms it: refineries anywhere process raw materials from mines anywhere. The ratio that matters is total mines versus total refineries across the entire galaxy, not per-system or per-sector.

The operational consequence is significant. The AI does not need to match mines to refineries on the same planet, and it should not try. What it needs to monitor is two integers: galaxy_total_mines and galaxy_total_refineries. If mines exceed refineries and raw materials are visibly accumulating (RULE-03-06), queue a refinery. If refineries exceed mines, do not queue more refineries. The target is 1:1 galaxy-wide (RULE-03-05).

This is both simpler to implement than it sounds and more consequential than it appears. A mine:refinery imbalance is a maintenance income leak. Every mine without a paired refinery is raw material that accumulates instead of converting to maintenance income. In a game where maintenance funds ships, garrisons, and facilities, an imbalance that persists for hundreds of game days is the economy loop slowly hemorrhaging.

The current code has no mine:refinery logic in AiManager. Whether AgentDroid.ManageProduction() covers this is the first open question the implementation team must resolve.

---

## The phase transition is the hardest design question

RULE-03-17 states the priority inversion clearly: once shipyard coverage is established, keeping shipyards producing becomes more important than keeping construction yards busy. What it does not state is when that transition triggers. The corpus records the trigger condition as Unknown.

This is not a minor gap. An AI that never transitions runs coverage rules indefinitely, which means it keeps queuing CYs in sectors that already have them and neglects ship production. An AI that transitions too early cuts off coverage before remote sectors are served.

Two candidate triggers exist. The first is structural: transition when the AI has at least one shipyard in every sector it controls. This is measurable and clean. The second is temporal: transition at a fixed threshold, approximately 300 days, regardless of coverage state. This is simpler but brittle — a game with many sectors or a slow opening would trigger too early.

The structural trigger is preferable. It ties the transition to the actual condition the guide names (coverage established) rather than a proxy. Either trigger is better than no trigger at all, which is the current situation.

---

## The production priority queue is the loop's core mechanism

RULE-03-03 is the economy loop's standing order: construction yards should rarely be idle. This is not a goal statement; it is an operational requirement. The AI must always have the next item ready before the current one completes. A CY that sits idle for a day is a day's production lost permanently.

The queue contents change by phase, but the queue itself is always live. A useful approximation for each phase:

**Coverage phase:** For each controlled sector that lacks a CY: queue a CY (highest priority, nearest CY). For each controlled sector that has a CY but lacks a shipyard: queue a shipyard (second priority). For each controlled sector that lacks a training center: queue a training center (third priority). All other builds are deferred.

**Balance phase:** For each idle shipyard: queue the best affordable ship (RULE-03-09, RULE-04-02). For any sector where the mine:refinery ratio is off: queue the correcting facility (RULE-03-05, RULE-03-06). For each planet with open slots that could cluster same-type facilities: prefer those planets for new additions (RULE-03-11).

**Optimize phase:** When R&D unlocks an advanced facility: queue one replacement, one sector at a time (RULE-03-13). When a sector qualifies for scrap evaluation: run RULE-03-12. When stable core sectors are established and outer-rim uninhabited systems exist: develop some for mining (RULE-03-16).

The queue is not an abstract priority list — it produces concrete build orders for specific construction yards at specific planets. The AI's current structure sends everything through AgentDroid.ManageProduction(), which is a black box from AiManager's perspective. The implementation team needs to determine whether that function is implementing any of this, or whether AiManager needs to drive it explicitly.

---

## Scrap policy conflicts with the maintenance mandate

The guide's scrap rules have a structural tension with the loop's production mandate that the corpus records but does not resolve.

The mandate says never leave a CY idle (RULE-03-03). The scrap rule says a lone CY in a fully developed sector should be scrapped and its slot reassigned (RULE-03-12). These two rules are not contradictory — the scrap rule applies precisely when the lone CY has outlived its usefulness — but implementing the scrap rule requires the AI to make a judgment that goes beyond querying whether a CY is idle. It requires evaluating the sector-wide facility distribution, identifying "super sites" (three or more facilities of one type on one planet), and concluding that a specific slot would be better used for something else.

The mine and refinery equivalents are simpler. The guide says never scrap mines unless building a defensive facility in that slot, and never scrap refineries unless the slot is genuinely needed. These are constraints on an action (scrapping) the AI does not currently perform at all, so they are not currently violated. But they need to be encoded before any scrap logic is added, because scrap logic without these guardrails would produce an AI that dismantles its own income source.

The current situation is that the AI has no scrap logic whatsoever. A human player who captures a system with a lone CY and evaluates whether to scrap it has taken a meaningful strategic action. The AI cannot do this. It is not a trivial gap — the evaluation required for RULE-03-12 is classified as Hard in the corpus precisely because it requires multi-step inference across sector state.

The shipyard scrap constraint is the sharpest one: never scrap shipyards unless maintenance is critically negative and the AI's own agent is already auto-scrapping ships. This is a crisis-only rule. The AI should resist scrapping shipyards even when it looks efficient, because a shipyard is extremely slow to rebuild once lost.

---

## The current implementation gap

All 31 economy rules in the corpus carry implementation notes ranging from NOT IMPLEMENTED to PARTIALLY IMPLEMENTED. The only CONFIRMED rules in the entire corpus are RULE-12-01 and RULE-12-02, which cover name mapping and are not economy rules. This means the economy loop has zero confirmed implementations.

What the code actually does: AiManager calls BuildWarships() each game day. BuildWarships() picks the planet with the most shipyards and queues one ship. All other idle shipyards are ignored. AiManager delegates production management to AgentDroid.ManageProduction(), but what that function does has not been audited. No sector-coverage check exists for CYs, shipyards, or training centers. No mine:refinery balance logic exists in AiManager. No scrap logic exists anywhere.

The gap is wide, but the surface area of the first fixes is narrow. The three highest-value changes, ranked by implementation cost against policy impact:

1. **Mine:refinery balance check.** Two integer comparisons, one build order. This is the loop's most structurally important rule and likely the cheapest to implement (RULE-03-05, RULE-03-06).
2. **Multi-yard idle check.** BuildWarships() currently serves one yard. Extending it to iterate all idle yards with affordable builds covers RULE-03-09 and RULE-04-02 simultaneously.
3. **Sector-coverage check for CYs.** A loop over controlled sectors: does this sector contain an AI-owned CY? If not, queue one from the nearest existing CY. This is RULE-03-01 and RULE-03-02, and it is the structural foundation of the coverage phase.

None of these require inventing new game mechanics. All three are plumbing jobs — queries against existing data connected to existing build-order mechanisms. The design problem is already solved; the implementation problem is connecting the wires.

---

## Open questions

**What is AgentDroid.ManageProduction doing?** Until this function is read, the coverage phase's implementation status is genuinely unknown. It may cover some or all of RULE-03-01 through RULE-03-10. Reading it should be the first task before any economy loop implementation work begins.

**When is a sector "fully developed"?** RULE-03-12 triggers on a "fully developed" sector, but the corpus does not define the term precisely. A workable threshold: a sector is fully developed when it has at least one CY, one shipyard, and one training center, and at least one "super site" (three or more of one facility type on a single planet). This needs to be agreed and encoded before scrap logic can be written.

**Is the 80-day orbital shipyard build time verified?** The guide cites this figure at ch03 L1157, but the OCR is damaged and `data/production_facilities.json` has no `build_days` field. This number appears in the corpus as a note about CY scaling (three CYs reduce 80 days to approximately 27), but the base figure is unverified. Do not use it as a calibration point until it is confirmed against game data.
