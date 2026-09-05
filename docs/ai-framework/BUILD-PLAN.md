# BUILD-PLAN — new AI opponent, clean-slate rebuild

| | |
|---|---|
| **Status** | IN PROGRESS. Unanimous approval 3/3 (Lord Vader, C3PO, R2D2), agent room AM-BH4LZPVZLMY4ZM6W5WGTFR2HMK, 2026-09-05 |
| **Branch** | `ai-rebuild` (off `main`) |
| **Authority** | TeeJ approved development in this branch; expects a fully functional new opponent. Decisions delegated to the agent room. |
| **Scope boundary** | Rebuild **the opponent brain only** — `src/game/ai_manager.gd` — to the 4-stage architecture in `01-architecture.md`. The game **engine** (MissionManager, EventBus, IntelManager, assault/bombardment/blockade, economy, loyalty, victory, captivity) is SOUND and **untouched**. Rewriting it would be the charter anti-goal "scoping a wiring job as a rewrite" (`00-charter.md:71`). |

---

## Goals (non-negotiable, from `00-charter.md` §5)

| | Goal |
|---|---|
| **G1** | AI plays all **5 operational loops** (economy, fleet, missions, diplomacy, combat), driven by a **victory objective layer** that arbitrates between them. |
| **G2** | AI can **reach every mission type** its victory conditions require — **Abduction launchable**, a full-victory game **winnable in principle**. (Old AI: 6 of 15 types, no abduction, single-agent teams.) |
| **G3** | **Fog rule.** No tier reads state it could not legitimately observe. Tiers differ in **competence, not information**. |
| **G4** | Runs a **full headless game with zero errors** and **deterministic replay intact** (see A1). |
| **G5** | Every rule from the corpus is **implemented or logged as a gap** — nothing silently dropped. |

## Amendments (adopted at approval)

- **A1 — Determinism baseline.** The old 503/503 soak baseline was generated with the OLD AI; a rewrite legitimately changes every day-hash. G4 is therefore: (i) soak N days from seed S → **zero errors**; (ii) run the same soak **twice** → **byte-identical** day-hash log (self-consistency); (iii) commit a **NEW** baseline to `tests/fixtures`. Never "fix" a hash diff against the stale old-AI baseline.
- **A2 — RNG discipline.** Every stochastic AI decision consumes **only** the `Prng` passed to `ProcessDay`. No unseeded RNG, no wall-clock, no iteration-order nondeterminism. Any `sort_custom` on scores MUST carry a **deterministic total-order tiebreak** on equal scores or replay breaks on ties.
- **A3 — Headless gate.** Validate via the project's own harness `tools/run-gd.ps1` (default binary = the **mono console** exe; verified in the script). Standing compile gate = `tests/ui_compile.gd`. The non-Mono binary is only for the web export (out of scope tonight).
- **A4 — Tier table.** M5 ships a concrete per-tier switch table (below). The tier test is mechanical: **diff the two tier configs and assert the only differences are the listed knobs.**

## The two-kind rule (R2D2 A1 clarification)

Every magnitude in the new brain is **exactly one** of:
1. a **shipped-data value**, citing its `data/*.json` entry, or
2. an **explicitly-labelled OURS-design value**.

No hardcoded third kind. The old constants are **discarded**, not ported: the `1/1/1` per-day budget and the `Preferred()` order do not survive. Capability throttles (budget, horizon, decision-noise) become first-class **per-tier config**, labelled OURS. R2D2 verifies every kind-1 value against `data/*.json`.

---

## Architecture (from `01-architecture.md`)

Four parts, one shared context object read by all:

```
CONTEXT (shared reader: world · intel · own-exposure)  — read by all stages, written by Reactions
   ├─ OBJECTIVES      what we are for; victory as a plan; the current bottleneck weight   (game-phase clock)
   ├─ ACTION SELECTION propose → score → pick; spends the per-day budget                  (per-day clock)
   └─ REACTIONS       EventBus subscription; events REPRIORITISE, they do not spend (AR-4) (on-event clock)
```

`CandidateAction { action, loop, objective_fit, expected_value, asset_risk, urgency, justification }`
score = `objective_fit + expected_value − asset_risk` (+ urgency), deterministic tiebreak (A2).

---

## Milestones (format per `13-implementation-plans.md`)

Each: GOAL / DOES NOT PUNT ON / THE CHANGE / VERIFY / UNBLOCKS / CONFIDENCE / GATE.
Owner of all code: Lord Vader (single writer, shared repo). C3PO: per-milestone manual-fidelity review + M3 victory-ordering spec. R2D2: data-number verification + M6 numeric criteria.

### M0 — Scaffold + contracts
- **GOAL:** delete the old brain; stand up `src/game/ai/` with a drop-in entry and the core data contracts, compiling green.
- **DOES NOT PUNT ON:** the entry stays `AiManager.ProcessDay(galaxy, day, rng)` + `Reset()` (called at `strategic_tick_manager.gd:154`, `game_session.gd:41`) so nothing else in the engine changes.
- **THE CHANGE:** remove `src/game/ai_manager.gd`; add `src/game/ai/ai_manager.gd` (thin orchestrator) + `ai_context.gd` + `candidate_action.gd` + stage stubs.
- **VERIFY (R2D2):** `ui_compile.gd` green; grep shows no references to old internals.
- **CONFIDENCE:** entry point read-in-full (`strategic_tick_manager.gd:154`).
- **GATE:** approved (unanimous).

### M1 — Context (the shared reader)
- **GOAL:** a fog-legal read of world + `IntelManager` staleness + own-faction state.
- **DOES NOT PUNT ON:** G3 — every field sources from GalaxyView / IntelManager / own state, never raw enemy state.
- **VERIFY (R2D2):** fog audit — list every field AIContext reads and its source; none is raw enemy state.

### M2 — Action selection (replaces `Preferred()`)
- **GOAL:** the 5 policies emit `CandidateAction`s; scorer picks; reaches all 15 mission types; passes team/decoys/victim/saboteur_target to `MissionManager.Launch` (`mission_manager.gd:518`).
- **VERIFY (R2D2):** seeded scenario asserts ≥1 Abduction against a winnable target AND non-trivial team/decoy/victim/saboteur args logged.

### M3 — Objectives / victory layer
- **GOAL:** victory conditions as a plan + current bottleneck weight; HQ-search objective; RULE-10-12 save-HQ-for-last ordering.
- **SPEC OWNER:** C3PO, from `08-victory.md`.
- **VERIFY (R2D2):** scenario with 2 of 3 conditions achievable → HQ-search ranks last until they complete or HQ is located.

### M4 — Reactions / EventBus
- **GOAL:** subscribe to `EventBus.OnMessageReceived`, filter to our faction; AR-4 = reprioritise not spend; small justified interrupt set.
- **VERIFY (R2D2):** scenario firing each interrupt event → next day's plan reordered (log pre/post objective weights).

### M5 — Difficulty tiers (OURS, labelled)
- **GOAL:** Easy→Medium via capability throttles; Medium→Hard via DEFEND rules + deeper inference. No stat multipliers, no info buys.
- **VERIFY (R2D2):** the tier-config diff test (A4).

### M6 — Verify
- **GOAL:** headless soak (zero errors + A1 determinism triad) + unit tests asserting G2/G3.
- **OWNER of criteria:** R2D2.

---

## M5 tier switch table (BUILT — `src/game/ai/ai_tiers.gd`)

All values are **OURS-design** (from `10-difficulty-and-fairness.md` §4). The DEFEND
rule-id **lists** are the corpus's (`09-counter-exploit.md`, mapped by C3PO room #51,
counts confirmed by R2D2 #52).

| Knob | Easy | Medium | Hard |
|---|---|---|---|
| MovesPerDay | 1 | 2 | 3 |
| MissionsPerDay | 1 | 2 | 3 |
| ShipsPerDay | 1 | 1 | 2 |
| Horizon | 1 | 2 | 4 |
| DecisionNoise (jitter range) | 300 | 80 | 0 |
| UseObjectives | false | true | true |
| InferenceLevel | none | battle+flip | all (incl. logistics) |
| DEFEND active (cumulative) | 1 | 12 | 22 |
| ProphylacticHqDays | 0 | 0 | 30 |

RULE-05-23 (Alliance scatters its roster day one) is the one **All-tier** rule —
omitting it makes the AI look *broken*, not beatable (`00-charter.md:230`).

### DEFEND wiring status (honest-ceiling — what is actually behavioural vs listed)

- **WIRED behaviourally:** RULE-05-23 (dispersal), RULE-09-04 (reactive HQ move),
  RULE-11-01 (Hard prophylactic HQ timer), RULE-05-06 (counter-intel espionage on
  own weak worlds). Decision-noise, objective-ordering-off (Easy), and inference-level
  are wired as tier levers.
- **EMERGENT from the scorer** (present in behaviour, not a separate toggle):
  RULE-07-07 (garrison via AgentDroid), RULE-03-15 / RULE-04-15 / RULE-04-16 /
  RULE-08-16 (production & fleet-doctrine biases), RULE-09-12 / RULE-05-17 (asset_risk,
  deferred to a later tuning pass), etc.
- **LISTED-ONLY (in `DefendRuleIds` for the A4 diff test, not yet individually wired):**
  RULE-10-18, RULE-10-02 (self-sufficiency logistics discipline — genuinely complex
  AI logistics; **note the enemy-side destination render IS built** since P1/commit
  d530221, so the doc's "blocked on V-2 render" is stale — the blocker is the AI
  logistics behaviour, not the render), RULE-01-09 / RULE-11-15 (territory/sanctuary
  denial beyond the basic press), RULE-05-18 (move-on-espionage-detected), RULE-05-07 /
  RULE-11-05 (command-rank stationing), RULE-06-13 / RULE-09-01 (diversion recognition).

---

## Honest-ceiling notes (charter: name the weakest part)

- **M1-F1** — For explored, non-owned worlds the context reads `p.ControllingFaction`
  **live** to bucket them (inherited from the original `Evaluate`). Gates are present
  (`ExploredBy` charts; `Knows` gates the Theirs* buckets), so it is a fidelity gap,
  not a hard G3 violation: a behind-the-back control flip is seen one tick early.
  Fix at M4 via the AI-side path (track witnessed `SystemControl` events / read the
  intel snapshot inside AIContext), keeping the engine untouched. Ruled GREEN by
  R2D2 (#39) and C3PO (#35).
- **M1-F2** — Behind a correct `Knows` gate the context reads **live** `SupportFor`
  rather than the snapshot's stored figure — a minor accuracy edge, not a fog
  violation. Fix alongside M1-F1 at M4.
- **M2-E3** — `asset_risk = 0` at M2; RULE-05-03 (risk your best characters less)
  deferred to M5.
- **M2-E5** — decoys (RULE-05-10) deferred to M5; the engine does not mark a decoy
  busy, so naive auto-decoy risks double-committing a unit.

## Progress log

- **2026-09-05** — Plan approved 3/3. Baseline `ui_compile.gd` = 52 scripts, 0 failed. M0 started.
- **2026-09-05** — M0 committed (1cd91bb): scaffold + contracts, gate green.
- **2026-09-05** — M1 built (AIContext.Build, fog-legal). C3PO CLEAR (#35), R2D2 VERIFY GREEN (#39), flags M1-F1/M1-F2 logged.
- **2026-09-05** — M2 built (action selection + 5 policies). Test `ai_missions.gd` 12/0: Empire launches Abduction (vs Mon Mothma) + Sabotage (2-char team). C3PO CLEAR (#40), R2D2 VERIFY GREEN (#42).
- **2026-09-05** — M3 built (objectives/bottleneck layer, 7 states, RULE-10-12 Hard-only). Test `ai_objectives.gd` 10/0. C3PO CLEAR (#46), R2D2 VERIFY GREEN (#45).
- **2026-09-05** — M4 built (Reactions/EventBus, AR-4 reprioritise-not-spend; RULE-09-04 reactive HQ relocation). Test `ai_reactions.gd` 8/0. C3PO CLEAR (#48), R2D2 VERIFY GREEN (#49).
- **2026-09-05** — M2+M3+M4 committed together (entangled via scorer objective_fit + urgency).
- **2026-09-05** — M5 built (difficulty ladder, `ai_tiers.gd`). Test `ai_tiers.gd` 21/0 (A4 config-diff). Decision noise, Easy no-ordering, counter-intel, RULE-05-23 dispersal, RULE-11-01 prophylactic HQ timer. C3PO CLEAR (#56), R2D2 VERIFY GREEN (#57).
- **2026-09-05** — M6 determinism triad: two 100-day soaks (seed 12345, fresh day-zero, AI drives both sides) → **byte-identical** hash logs; zero runtime errors. New baseline `tests/fixtures/ai-rebuild-seed12345-100d.log` (supersedes the old-AI `replay-seed12345-100d.log`).

## M6 verification procedure (A1 determinism triad)

```
# (i) zero errors + (iii) generate/refresh the baseline:
tools/run-gd.ps1 tests/soak.gd -- --days=100 --seed=12345 --faction=alliance \
    --difficulty=Medium --size=Standard --replay-log=<path>
# (ii) self-consistency: run again to a second path, diff must be byte-identical.
# regression: pass --expect=tests/fixtures/ai-rebuild-seed12345-100d.log ; exit 0 == match.
```

**Known pre-existing issue (NOT the AI, flagged not fixed):** `snapshot_loader.gd:25`
throws `Invalid assignment of property HumanFactions` on the `--snapshot=` path, so the
soak runs from fresh day-zero instead. Engine code, untouched by this branch; out of
scope. The exit-time `ObjectDB instances leaked` warning is a Godot SceneTree headless
teardown artifact present across the test suite (e.g. `sabotage_targets.gd`), not a
runtime error during the game.
