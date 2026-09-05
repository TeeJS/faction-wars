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

## M5 tier switch table (skeleton — filled at M5 with R2D2's verified numbers)

All values are **OURS-design** unless a `data/*.json` entry is cited.

| Knob | Easy | Medium | Hard | Kind / source |
|---|---|---|---|---|
| MovesPerDay | TBD | TBD | TBD | OURS |
| MissionsPerDay | TBD | TBD | TBD | OURS |
| ShipsPerDay | TBD | TBD | TBD | OURS |
| Planning horizon | TBD | TBD | TBD | OURS |
| Decision noise | TBD | TBD | TBD | OURS |
| DEFEND rules active | none | 11 (list ids) | all 22 (list ids) | corpus `09-counter-exploit.md` |
| Inference depth | shallow | medium | deep (fog-legal only) | OURS |

The one **All-tier** self-protection rule is RULE-05-23 (Alliance moves characters off known starts day one) — active at every tier, because omitting it makes the AI look *broken*, not beatable (`00-charter.md:230`).

---

## Progress log

- **2026-09-05** — Plan approved 3/3. Baseline `ui_compile.gd` = 52 scripts, 0 failed. M0 started.
