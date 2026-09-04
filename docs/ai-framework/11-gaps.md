# 11 — Gaps and open questions

| | |
|---|---|
| **Status** | REVIEWED — Doof (room #168); count corrected |
| **Author** | Han |
| **Sources** | 103 gap entries across the 12 chapter analyses, plus the design questions raised in `01`, `01a`, `05`, `08`, `10` |

> **Read §1 first if you are TeeJ.** It answers the specific request from room #136 —
> *"if you find areas of the game not implemented, keep a list of them"* — and it is
> **much shorter than the 103 raw gap entries**, because almost all of those are AI-driver
> gaps in game systems that work.

---

## 1. Game-level gaps — what is missing from the game itself

**Confirmed missing. Two items.**

### 1.1 HQ relocation — NOT IMPLEMENTED

The Alliance headquarters can be moved. Seven independent guide passages describe it
*(Ch2 L673–687, Ch4 L2289–2291, Ch9 L5743–5745 and L6126–6141, Ch11 L7180–7186 and
L7187–7191, Ch10 L6907–6913)*. The game's own manual documents the HQ's **Move /
Confirmed Move** menu *(GAMEPLAY.md:2996–2998, Fig. 3.82)* and prices the cost — a small
loyalty drop on the system it left *(GAMEPLAY.md:1018, manual p090)*.

**No relocation path exists in `src/game`.** The HQ is placed by
`day_zero_generator.gd:53` and thereafter can only be destroyed
(`assault_manager.gd:161`, `bombardment_manager.gd:195`).

**Knock-on:** `blockade_manager.gd` has no pinning effect either, because there is nothing
to pin — and the manual is explicit that the blockade step in the Imperial kill chain
exists *to stop the HQ relocating* (`GAMEPLAY.md:3078–3087`).

**Why it matters beyond the AI:** without it the Empire's first victory condition is a
lottery — find it, kill it. With it, it becomes a race, and the Alliance has a real defence
to play. **Eight of the 23 DEFEND rules depend on it**, including the signature Hard-tier
behaviour.

### 1.2 Construction destinations not shown — NOT SURFACED

`ConstructionTask.Destination` is **live**: populated at queue time (`planet.gd:342`,
`:406`), it drives delivery on completion (`planet.gd:742–746`), is read by the production
agent (`agent_droid.gd:135,138`), and is printed to the console.

It is absent from exactly one place: `intel_manager.gd` `DescribeTask()` returns
`"%s (%s, %d%% complete)"`, where the middle field is the **queue's name** —
"construction", "shipyard", "training" — not the destination.

**This affects the human player identically.** The manual and the guide both say espionage
reveals where production is headed *(Ch10 L6625–6634)*; the panel does not show it. And it
is the **only concrete method the guide gives the Empire for finding the Rebel HQ**
*(Ch10 L6652–6657)*.

Fixing it is one appended field in one format string. Four rules go live: RULE-10-01,
RULE-10-02, RULE-10-18, and `08-victory.md` V-2.

---

### 1.3 Previously suspected, now **confirmed implemented** — closed

Four items were on this list as *unaudited candidates* and came off it. Recorded so nobody
re-raises them:

| Was suspected missing | Audit result |
|---|---|
| Uprisings halt production | ✅ **Implemented** — `planet.gd` returns 0 production while `IsInUprising` |
| A system flips when its garrison is destroyed | ✅ **Implemented** — `UpdateGarrisonState()` sets `ControllingFaction` to Neutral and fires `OnControlChanged` |
| Espionage reveals more than the target system | ✅ **Implemented, and exceeds the guide.** `mission_manager.gd` `LeakExtraSystems()` rolls a count from `EspionageRevealFloor`/`Spread` — with **separate, higher** `EspionageRevealCoruscantFloor`/`Spread` when the target is a capital — and charts that many unexplored systems |
| Intel staleness model | ✅ **Implemented and faithful** — `intel_manager.gd:3–6`. The AI simply never reads it |
| Sector-wide support penalty for force | ✅ **Implemented, scope narrower than guide claims.** `bombardment_manager.gd:210-213`: civilian bombardment fires `CivilianSectorSupportShift(attacker)` = `game_rules.json` Entry 173 = -20 to all `SectorPeers`. Assault and blockade have separate effects; this attacker penalty is civilian-bombardment-only. RULE-06-14 prior citation (`loyalty_manager.gd`) was wrong — that file is character loyalty/treachery. Corrected. |

*(Audits by R2D2, rooms #150/#153; Han room #172; independently verified.)*

**Newly documented: the full support system.** Han's audit (room #172) found all planetary support shifters in one pass: `blockade_manager.gd:112` (blockade matching/mismatched), `bombardment_manager.gd:213` (civilian bombardment), `mission_manager.gd:839/864/878` (diplomacy gain, uprising swing), `smuggling_manager.gd:44` (smuggling), and `planet.gd:497` (internal). These are more numerous and cross-loop than any individual rule record documents. No rule in the corpus captures the full set; they are a gap in the analysis, not the code.

### 1.4 Still unaudited — candidates, not findings

| Question | Where to look |
|---|---|
| Can characters **escape during an assault**, gated on leadership? *(Ch9 L6317–6320)* | `captivity_manager.gd`, the assault path |
| Do **command ranks** affect enemy mission success? *(Ch5 L3589–3593)* | `force_manager.gd`, mission resolution |
| Do characters **improve on mission success**? *(Ch5 sidebar L2685–2704)* | mission resolution |
| Is there a **prisoner model** — capture, rescue, prison hardening, prisoner-on-ship? | `captivity_manager.gd` |
| Is `Reconnaissance` offered to **characters**, which RULE-05-05 says is illegal? | `MissionManager.PerformableBy()` |
| Does `victory_manager.gd` model conditions as a **declared list** or hardcoded checks? | `victory_manager.gd` |

**None of these is claimed as a gap.** They are places the corpus makes a claim and nobody
has checked the code. Four such candidates have already turned out to be implemented.

---

## 2. AI-driver gaps — the bulk of the work

103 gap entries across the analyses, sorted by the four labels. Detail and per-rule mapping
live in `12-implementation-map.md`; this is the shape.

| Label | Meaning | Scale |
|---|---|---|
| **NOT IMPLEMENTED** | The AI has no logic for it, though the game system works | ~150 rules. The bulk |
| **IMPLEMENTED AND UNREACHABLE BY THE AI** | The engine supports it; the AI never calls it | ~12 rules, but disproportionately important |
| **IMPLEMENTED BUT MISORDERED** | The AI does it, at the wrong priority, with no way for urgency to interrupt | 1 (RULE-06-08) |
| **NOT SURFACED** | Modelled in data, never exposed | 2 |

### The unreachable set is the priority, because it is wiring rather than building

`MissionManager.Launch` (`mission_manager.gd:487`) takes
`(type, team: Array, from, target, decoys, victim, saboteur_target)`.
**The AI passes four of seven, and a single-element team.**

- **9 of 15 mission types cannot be selected** — Abduction, Assassination, Rescue,
  Sabotage, DeathStarSabotage, JediTraining and all three Research types are absent from
  `Preferred()` (`ai_manager.gd:334–337`).
  **Two of three victory conditions per side are character captures, and abduction is the
  mission that achieves them.**
- **Teams and decoys** are supported by the engine and never used.
- **`IntelManager`** is built, faithful and never read by the AI.
- **The AI never targets its own systems** (`ai_manager.gd:317`), which blocks
  counter-intelligence, own-system diplomacy and garrison pre-emption together.

### One design decision, six symptoms

`Preferred()` is a fixed list of six mission types, identical for both factions in every
phase. Six separate findings trace to it: unexplored targeted last, one global order,
subdue-uprising last, sabotage absent, abduction absent, nine types unreachable.
**Patching the list addresses none of them** — see `01-architecture.md`.

---

## 3. Open design questions

Ours to answer, not the game's.

| # | Question | Status |
|---|---|---|
| **AR-4** | How reactions and the daily loop share one budget | ✅ **Decided** — reactions reprioritise, they do not spend. The day is the game's atomic unit. Falsifier recorded |
| **AR-5** | Per-day context snapshot or live object | ✅ **Resolved by AR-4** — snapshot |
| **AR-1** | Event ordering under lockstep | ✅ **Withdrawn** — wrong hazard; `EventBus` is deterministic by construction |
| **AR-2** | Which events interrupt vs merely write to context | Open. Rule by rule |
| **AR-3** | One shared scorer or one per loop | Open. Try shared first |
| **OM-1** | ★ Is the layer-2 reverse-fog bound **too pessimistic to be useful**? An AI assuming the enemy knows everything they could know may relocate its HQ constantly and read as twitchy | **Open, and the most likely source of a bad-feeling Hard tier** |
| **OM-2** | Does layer 3 (belief and intent) have a defensible design at all? | **Open. Cutting it is a legitimate answer** — the three rules that need it would be dropped from Hard rather than faked |
| **OM-3** | Should the own-exposure log be surfaced to the player too? | Open. Product question |
| **OM-4** | Does `IntelManager` expose enough to run layer 2 without new plumbing? | Open. Audit |
| **V-1** | Is HQ relocation in scope to build? | **TeeJ's call.** Currently: rules written, marked NOT IMPLEMENTED |
| **V-3** | How is "the bottleneck" computed, and how often does it change? | Open |
| **M-2** | How does the AI decide **capture vs attrit** before choosing sabotage targets? | Open. RULE-05-08 requires it |
| **MP-1** | What tier does an AI run at in a multiplayer slot? Head-to-head has no difficulty setting | Open. Recommendation: Medium |
| **D-1** | ★ **Should assaults consume budget?** `Invade()` checks `budget.Moves` and never decrements it; the assault branch returns at `ai_manager.gd:228` before the check. **Combat is currently unbudgeted.** `Dispatch` runs `BuildWarships → Invade → MoveFleets → LaunchMissions` and is called twice per day against one shared `Budget`, so the AI gets **~2 free assault attempts per day** — with `Invade` running *before* movement is charged. The per-day caps, the primary Easy→Medium lever in `10-difficulty-and-fairness.md`, have **no grip on combat** | **Open, and it determines whether the difficulty ladder reaches the combat loop at all.** Not asserted as a bug; may be deliberate |

---

## 4. Numbers we could not verify

Recorded so nobody treats them as settled.

| Figure | Source | Status |
|---|---|---|
| **850–900** total Death Star maintenance, stocked | Ch10 L6855–6857 | **Unverified.** The station's own **600** is confirmed three ways; the stocked total depends on loadout |
| **60–90 days** Force training | Ch5 L3081–3082 | Single-source, no code to check against |
| Guide **maintenance costs for researched hulls** | Appendix B | **Wrong.** 8 of 8 researched hulls differ from `military_units.json`; every starting hull matches. **Use the data** |
| Guide's **"more than two GenCores"** assault threshold | Ch8 L5525–5527 | **Wrong — off by one.** `game_rules.json` EntryId 151 = **2**, manual p123 and `assault_manager.gd:33` agree |
| Guide: advanced CYs and shipyards are **weaker** vs bombardment | Ch5 L3283–3287 | **Wrong for that clause.** Advanced CY bombDef 3→**4**, Advanced Shipyard 2→**2**. The same passage is **correct** about batteries and shields |
| **5–15** garrison maintenance | Ch7 L4423–4424 | Correct, but it is a **whole-garrison** figure. Per-regiment is **1–8**; no regiment costs 15 |
| **≈60% / 75–80% / 100%** support ladder | Ch6 L3880–3888 | Single-source. Mechanically consistent with `planet.gd:450` but the figures themselves are unverified |

---

## 5. What is *not* a gap

Three things worth recording because they were suspected and turned out sound:

1. **The intel model.** `IntelManager` implements staleness faithfully — *"the model is
   staleness, not concealment"* — with per-category snapshots and separate espionage and
   reconnaissance category sets. It is not missing; it is unused.
2. **The mission system.** Teams, decoys, abduction victims and sabotage targets are all
   live parameters. The AI driver is the narrow part.
3. **The appendix data.** 140 of 147 guide values match the shipped tables exactly. The
   guide is accurate except in one systematic place, and the data is trustworthy.

**The honest summary of the whole audit: the port is sound and the opponent is blind.**

---

## Review

- [ ] Doof
- [ ] R2D2
