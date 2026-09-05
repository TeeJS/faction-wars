# 07 — Combat loop: policy

| | |
|---|---|
| **Status** | APPROVED (Han, room #179) — two corrections applied |
| **Authors** | Doof (draft) |
| **Inputs** | `ch08-ship-to-ship-and-planetary-combat.md`; `ch04-building-fleets.md`; rule corpus §Combat (RULE-04-11, RULE-04-19, RULE-04-20, RULE-07-03, RULE-07-04, RULE-08-01 through RULE-08-16) |
| **Scope** | Policy argument for the combat operational loop. Rule text lives in `02-rule-corpus.md`. Code citations are read-only per charter §Scope |

---

## What the combat loop is actually for

The guide calls chapter 8 "ship-to-ship and planetary combat." That label is misleading. Roughly four-fifths of the chapter is about what you do *before* any shot is fired: pre-battle assessment, espionage requirements, GenCore shield checks, sabotage sequencing, bombardment targeting, troop composition, and troop ratio arithmetic. The word "combat" in the loop name describes the context, not the AI's primary task.

The combat loop's primary task is planning and executing a five-phase assault pipeline. The fight is the last step. An AI that skips the pipeline and dispatches a fleet at whatever system is closest is not making a suboptimal combat decision — it is making a category error. The guide's entire chapter is about how to arrive at a fight you have already won.

---

## The five-phase assault pipeline

The guide presents an explicit ordered sequence for every planetary assault. Each phase has hard preconditions that gate the next. The phases are:

**Phase 1 — Espionage.** Before a fleet moves, establish what is at the target. For the Empire this is an explicit requirement (RULE-08-02): do not commit the battle fleet without information on fighter count, specifically. The guide goes further: attach the espionage mission directly to the fleet so there is no lag between arrival and intelligence. "Keep running espionage missions — any new information will benefit you."

**Phase 2 — GenCore check.** Before any assault can be planned, check Planetary Shield count. This is a hard gate (RULE-08-09): zero shields means bombardment proceeds; one means assault is viable after bombardment; two or more means the system *cannot be assaulted at all* without eliminating shields through sabotage first. The Prima guide states the threshold incorrectly ("more than two GenCores") — the actual boundary, confirmed by `game_rules.json` EntryId 151, manual p123, and `assault_manager.gd:19,33`, is ≥2 blocks. An AI implementing the guide's text will attempt unviable assaults against fortified systems.

**Phase 3 — Sabotage.** Before the battle fleet engages, run sabotage missions against fighter squadrons, military units, defensive batteries, and any shields above the assault threshold (RULE-08-03, RULE-08-09). The Empire-specific version is explicit: pre-attack fighter sabotage is mandatory, not optional. It halves the combat multiplier that makes Alliance fighters the Empire's primary naval threat.

**Phase 4 — Bombardment.** Once the target is accessible, bombard military targets (RULE-08-10). Not general targets, not civilian targets — military. Military bombardment strips garrison troops and batteries while preserving the infrastructure you plan to use after capture. It also may trigger uprisings on systems held against their will, creating a sector-wide dividend. Cap at two bombardments, three at most; if the system is not viable after that, move on and return with better intelligence (RULE-08-11).

**Phase 5 — Invasion.** Troops composed entirely of highest-attack-value units (RULE-08-12), in numbers that exceed the defender's 2:1 structural advantage (RULE-08-13). Garrison troops with high defensive rating are built *after* the system is taken; invasion forces carry only attack value. Empire-specific: troop ships travel in a separate fleet that moves up only after the battle fleet has cleared the system (RULE-08-07).

None of these five phases exist in the current AI. The AI has no assault call site in `ai_manager.gd` (gap G-08-1). The pipeline is absent entirely.

---

## One implemented rule that cannot be reached; one partially reached

The most important fact about the combat loop's current state is not that most rules are missing — it is that rules closest to the engine are partially or fully reachable without any AI logic for them, while the AI still cannot initiate combat.

**RULE-08-09 (GenCore gate) — PARTIALLY IMPLEMENTED.** R2D2's audit (room #174) confirmed that `ai_manager.gd:Invade()` calls `AssaultManager.CanAssault(f, target)` and skips fleets where the check fails. The shield gate — ≥2 shields blocks the assault — is already enforced. What the AI does *not* do is the proactive half: when `CanAssault()` returns false, `Invade()` simply continues to the next fleet rather than queuing sabotage missions to clear the shields. The reactive gate is wired; the proactive response is absent. Code label updated from IMPLEMENTED AND UNREACHABLE BY AI to PARTIALLY IMPLEMENTED.

**RULE-08-10 (bombardment target type) — IMPLEMENTED AND UNREACHABLE BY AI.** `bombardment_manager.gd` implements a `BombardmentMode` enum with all four variants — `MilitaryFacilities`, `CivilianFacilities`, `General`, and `DestroySystem`. The targeting logic is correct: military bombardment uses a 25% collateral modifier; civilian bombardment triggers the sector-wide −20 support shift confirmed in RULE-06-14 (`game_rules.json` Entry 173). `ai_manager.gd` never calls this manager and never passes a mode. The engine selects bombardment mode correctly when called; it is never called.

The implication for implementation priority: RULE-08-10 needs one call site. RULE-08-09 needs the proactive response — when `CanAssault()` returns false, queue sabotage missions targeting the shields — which is more complex than a call site but less complex than building the gate itself. Neither requires engine work. This is the same pattern found across the codebase: the engine is more capable than the AI driver allows it to appear.

---

## Ship-to-ship doctrine is unaudited

The guide prescribes two distinct tactical doctrines for ship-to-ship combat, one per faction. Neither has been verified in code because the tactical combat subsystem (`tactical_battle.gd`) has not been read in any prior analysis pass.

**Alliance doctrine (RULE-08-04):** Fighters attack enemy fighters first, only pivoting to capital ships once enemy fighters are "down or at least dramatically reduced." This is not a preference — the guide states it as the condition for any fighter effectiveness. An Alliance AI that sends its X-wings directly at Star Destroyers while TIE fighters are still active will lose both the fighters and the engagement. Phase 1 (fighters vs. fighters) must complete before Phase 2 (fighters vs. capital ships) begins. Before Phase 2: verify laser penetration against shields; if not penetrating, pull back.

**Imperial doctrine (RULE-08-05):** Mass capital ship fire on one target at a time, wearing it to hull damage before switching. Both factions share this rule; the Empire states it most explicitly. Fire concentration versus fire spread is a basic damage mechanic — spreading fire heals faster than concentrated fire kills. Damaged ships that lose shielding are repositioned to a recovery nav point (RULE-08-06), not abandoned.

**What this means for implementation:** Until the tactical combat AI is audited, the code label on RULE-08-04, RULE-08-05, and RULE-08-06 cannot be confirmed. They are listed NOT IMPLEMENTED based on the known structure of `ai_manager.gd`, not from reading the tactical managers directly. If the tactical AI has its own fighter-priority or fire-concentration logic, some of these may be PARTIALLY IMPLEMENTED or better. If it auto-resolves all battles identically regardless of composition, they are NOT IMPLEMENTED. The audit is required before implementation work begins on any tactical rule.

---

## The simulation asymmetry is a structural property

RULE-08-16 is the combat loop's only DEFEND rule. The guide states directly (L4648–4690): "simulating a battle often causes greater losses for your side than if you control the battle yourself." A player who manually controls their fleet in tactical combat will consistently outperform the auto-simulation result at equivalent fleet strength.

This is not a code fix. It is a structural asymmetry between a human controlling a tactical engagement and an AI auto-resolving it. The port runs a single combat engine (`tactical_battle.gd`) for both manual and auto-resolved battles — the guide's asymmetry is not explained by a difference in combat paths and has no identified mechanical cause in the current codebase. The AI cannot eliminate this gap. What it can do is account for the asymmetry in force sizing.

The consequence for Hard-tier design: the AI must maintain enough numerical superiority to absorb the human's tactical control advantage. How much superiority is required cannot be derived from the guide — it depends on the magnitude of the auto-simulation shortfall, which requires empirical measurement against a human player controlling their battles. This is the only rule in the combat loop where the implementation answer is "design parameter, not code," and it belongs in the difficulty document (10-difficulty-and-fairness.md) as a calibration note rather than in `ai_manager.gd` as a constant.

RULE-08-16 is a Medium/Hard discriminator. At Easy, the AI does not need to account for the player's tactical advantage — Easy is explicitly allowed to lose more efficiently than it could. At Medium, the AI plans with some margin for human skill. At Hard, the margin must be calibrated against the actual simulation asymmetry. The three tiers differ in whether this structural fact enters force-sizing at all, not in what information they have access to.

---

## Pre-combat espionage connects the fleet and missions loops

RULE-08-02 and RULE-08-03 are formally listed in the fleet loop and missions loop respectively, not the combat loop. They appear here because their function is combat preparation — they are Phase 1 and Phase 3 of the assault pipeline above. The cross-loop structure is intentional: executing the combat pipeline requires coordinating fleet movement, mission dispatch, and assault execution in sequence. No single loop can contain the full pipeline.

The Empire-specific sequencing is: espionage mission (missions loop) → fleet movement to target sector (fleet loop) → fighter sabotage missions (missions loop) → orbital engagement (combat loop) → bombardment (combat loop) → troop fleet arrival (fleet loop) → invasion (combat loop). An AI manager that processes loops independently and in parallel will break this sequence. The Dispatch model (01-architecture.md) must ensure that the combat-intent flag written by fleet loop planning is visible to mission-dispatch before the day's mission assignments are made.

This is not a new architectural requirement — it is an existing consequence of the per-day context snapshot (AR-5 resolution). At start of day, if the context records an attack-intent on system X, mission dispatch reads that context and prioritises espionage and sabotage on system X above other missions. The fleet moves on its daily clock. The five phases play out over multiple days, not in one dispatch pass.

---

## Target selection and the bombardment cap

RULE-07-04 (Medium, combat loop) is the target selection rule: given multiple potential attack targets, which does the AI prioritise? The guide's answer is not explicit, but the corpus rules collectively imply a priority order: systems that are already blockaded, systems with low garrison counts, systems that the AI can assault given current intelligence. The key principle from RULE-08-11 — abandon a target after 2–3 failed bombardments — implies the AI must maintain an abandonment list per target and have a fallback target ready. Without a target list, the AI will either repeat failed assaults or go idle when the first attempt fails.

Target selection is not an independent rule — it is the entry point for the entire pipeline. A target must be selected before espionage is ordered, before the fleet moves, before any of the five phases begin. Whatever data structure the AI uses for combat planning must hold the selected target from phase 1 through phase 5, potentially across multiple days. This is the most basic architectural requirement of the combat loop and is currently entirely absent.

---

## What the loop is not doing and why it matters

The combat loop has 16 rules. Of these: one is IMPLEMENTED AND UNREACHABLE BY AI (RULE-08-10), five are PARTIALLY IMPLEMENTED (RULE-08-09 — reactive gate present, proactive response absent; RULE-04-11, RULE-04-20, RULE-07-03, and RULE-04-19 — all concerning post-capture garrisoning), and ten are NOT IMPLEMENTED. The loop's single DEFEND rule (RULE-08-16) is also NOT IMPLEMENTED, though its implementation is a calibration parameter rather than a code function.

The partially implemented rules share a pattern: they all concern what happens *after* combat (garrisoning a captured system, installing a defender). The gap is in what happens *before* combat. The AI can partially handle the landing and the occupation. It cannot initiate the operation at all.

This is the most total gap in the corpus. The diplomacy loop is partially implemented; the economy loop has working infrastructure that reaches the AI. The combat loop's operational core — planning and executing an assault — is completely absent. The two rules closest to being usable (RULE-08-09, RULE-08-10) require only call sites, not engine work. The correct implementation order for the combat loop is: (1) wire the GenCore gate (call `CanAssault()`), (2) wire the bombardment mode (call `bombardment_manager.gd` with `MilitaryFacilities`), (3) build the five-phase pipeline trigger, (4) add target selection, (5) add the per-phase mission coordination, (6) add the tactical rules once the tactical AI is audited.

Steps 1 and 2 unlock the engine's existing capabilities. Steps 3–5 implement the strategy. Step 6 optimises the execution. Each step is additive and independently testable.

---

## Combat and the per-day budget

The daily budget in `ai_manager.gd` has three counters: `budget.Moves`, `budget.Missions`, and `budget.Ships`. Fleet movement and combat share the Moves counter — `MoveFleets()` checks and decrements it. `Invade()` checks `budget.Moves` at line :230 to gate troop loading, but the assault branch at line :216–228 returns before that check is reached. Assaults cost nothing. The per-day budget does not throttle combat. (Verified by R2D2 reading `ai_manager.gd` directly: no decrement of any counter appears in `Invade()`.)

One refinement on "unlimited": `ProcessDay` calls `Dispatch` twice with the same shared budget object. `Invade` in each pass attempts the first loaded fleet it finds and returns. So the effective cadence is approximately two free assault attempts per day — one per Dispatch pass — bounded by the number of fleets already in position with troops loaded. The assault frequency is bounded by logistics (loaded fleets available), not by budget.

This has two consequences for the combat loop:

First, the correct framing for Medium and Hard is what the AI *chooses* to fight, not how often it is *permitted* to fight. A permission limit that assaults escape has no grip on combat difficulty. The tier boundary in combat must be expressed in terms of target selection criteria, pipeline completeness, and the preconditions the AI is willing to verify — not a moves cap.

Second, fleet movement and combat compete for the same counter even though assaults do not spend it. An AI that uses its full Moves budget repositioning fleets cannot move more fleets the same day, but can still assault any system where a loaded fleet already sits. The pipeline matters: fleets positioned in advance do not compete with assaults for the daily budget. Fleets dispatched to assault position the same day they invade do compete, because the movement costs a Move.

Whether assaults should consume budget is an open design question (see below).

---

## Open questions

**Should assaults consume per-day budget?** `Invade()` in `ai_manager.gd:216–228` returns before reaching the `budget.Moves` decrement at `:230`. Assaults are currently approximately two free attempts per day — one per Dispatch pass — bounded by loaded fleets in position, not by budget. Whether the absence of a hard cap is intentional is unknown — nothing in the codebase or documentation states either way. If it is a gap, the fix is one decrement call; if it is deliberate (perhaps because the combat loop has its own pacing through the five-phase pipeline), no fix is needed. This is the highest-priority open design question in the combat loop because its answer determines whether the difficulty ladder has any leverage over combat frequency. Filed in 11-gaps.md for a design decision.

**Tactical combat AI not audited.** `tactical_battle.gd` has not been read. The code labels on RULE-08-01, RULE-08-04, RULE-08-05, and RULE-08-06 are inferred from `ai_manager.gd`'s known structure, not from the tactical subsystem itself. Before any tactical rule is implemented, this audit is required. It may reveal that some rules are already partially present, which would change implementation priority.

**Death Star logic (RULE-08-15).** The Death Star mechanic has not been audited. RULE-08-15 describes the trigger (system with ≥2 shields, no viable assault path) and the penalty (sector-wide loyalty loss on all systems, neutral and held). Whether `death_star_manager.gd` or equivalent models the loyalty penalty as the guide describes — and whether the AI can currently issue Death Star orders — is unknown. This is the Empire's only option against a fully fortified system and belongs in the Hard-tier audit.

**Simulation asymmetry magnitude.** RULE-08-16 identifies the structural gap but cannot quantify it without empirical measurement. The Hard-tier force-sizing parameter for combat (how much numerical superiority offsets the human's tactical control advantage) requires playtesting data. This is correctly deferred to 10-difficulty-and-fairness.md as a calibration note.

**Fleet separation for troop ships (RULE-08-07).** The guide requires a two-fleet structure for planetary assault: battle fleet first, troop fleet second. The fleet loop (04-fleet.md) has this as an open question — `BuildWarships()` has no fleet-role distinction. This rule will remain unimplementable until the fleet loop's role-allocation architecture is established. The combat loop depends on the fleet loop for this phase of the pipeline.
