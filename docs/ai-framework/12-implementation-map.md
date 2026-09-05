# 12 — Implementation map

| | |
|---|---|
| **Status** | REVIEWED — R2D2 (room #174) and Doof (room #168); CanAssault correction applied |
| **Author** | Han |
| **Purpose** | Rule → code, sorted by the four labels; and the **reverse index**, code → the rules that govern it |
| **Scope** | Design only. Nothing here has been implemented; `src/` is untouched |

Two directions, because two different people need this document. Someone implementing a
rule needs *rule → where*. Someone **opening a file to change it** needs *file → what
governs this*, and that direction is the one that stops a well-meant edit from quietly
breaking a documented behaviour.

---

## 1. The four labels, and why the distinction is the whole point

| Label | Meaning | Work |
|---|---|---|
| **NOT IMPLEMENTED** | The AI has no logic for it. The game system underneath works | **Build** |
| **IMPLEMENTED AND UNREACHABLE BY THE AI** | The engine supports it; the AI never calls it | **Wire** |
| **IMPLEMENTED BUT MISORDERED** | The AI does it, at the wrong priority, and urgency cannot interrupt | **Reorder** |
| **NOT SURFACED** | Modelled in the data, never exposed | **Render** |

Early in this project everything was being labelled *not implemented*. That would have
scoped a wiring job as a rewrite. **Roughly a dozen of the highest-value rules are
"wire", two are "render", and the single most consequential fix in the corpus is one
appended field in one format string.**

---

## 2. Work order — highest value first

Ordered by *rules unblocked per unit of work*, not by tier.

> ⚠ **An earlier draft of §2.6 asserted `CanAssault()` was never called. That was wrong**
> — it is called at `ai_manager.gd:224`. Corrected below. The error came from claiming a
> negative about code that had not been read in full.

### 2.1 — Render `ConstructionTask.Destination` · **NOT SURFACED**

`intel_manager.gd` `DescribeTask()` returns `"%s (%s, %d%% complete)"` where the middle
field is the queue's **name**. `ConstructionTask.Destination` is live — populated at
`planet.gd:342`/`:406`, drives delivery at `:742–746`, read by `agent_droid.gd:135,138`,
printed to the console.

**Unblocks:** RULE-10-01 *(the Empire's only documented method of finding the Rebel HQ)*,
RULE-10-02, RULE-10-18, `08-victory.md` V-2.
**Cost:** one appended field.
⚠ **Changes shipped UI behaviour and affects the human player.** TeeJ's call, not ours.

### 2.2 — Let the AI target its own systems · **NOT IMPLEMENTED**

`ai_manager.gd:317` builds `targets = Neutral + TheirsWeak + TheirsStrong + Unexplored`.
Own systems appear nowhere.

**Unblocks three DEFEND rules at once:** RULE-05-06 *(counter-intelligence — the keystone
of threat T3; without it RULE-05-18 has no trigger)*, RULE-06-02 *(bolster own systems, the
other half of diplomacy)*, RULE-07-07 *(garrison pre-emption)*.
**Cost:** one target-list change.

### 2.3 — Reach the missing mission types · **IMPLEMENTED AND UNREACHABLE**

`Preferred()` (`ai_manager.gd:334–337`) lists six of the fifteen in `enums.gd:35–51`.
Absent: **Abduction, Assassination, Rescue, Sabotage, DeathStarSabotage, JediTraining**, and
all three Research types.

**Unblocks:** RULE-05-01 *(abduction — two of three victory conditions per side)*,
RULE-05-19 *(rescue — the only recovery from losing one)*, RULE-05-20, RULE-10-06,
RULE-11-07, RULE-05-11.
⚠ **Do not fix by extending the list** — that is symptom six of one design decision. See
`01-architecture.md`.

### 2.4 — Read `IntelManager` · **IMPLEMENTED AND UNREACHABLE**

Built, faithful, never read by the AI. *"The model is staleness, not concealment"*
(`intel_manager.gd:3–6`).
**Unblocks:** RULE-02-01, RULE-02-02, RULE-02-07, RULE-02-13, and every rule that reasons
about what we know and how old it is.

### 2.5 — Pass teams, decoys, victims and sabotage targets · **IMPLEMENTED AND UNREACHABLE**

`MissionManager.Launch` (`mission_manager.gd:487`) takes
`(type, team: Array, from, target, decoys, victim, saboteur_target)`.
The AI passes **four of seven** and `team = [agent]` (`:312`); `:321` also refuses a second
mission on the same target.
**Unblocks:** RULE-06-05 *(concentrate-or-spread)*, RULE-05-10 *(decoys)*, and the target
selection half of RULE-05-08 and RULE-10-06.

### 2.6 — Call `BombardmentMode`; act on the shield gate · **ONE UNREACHABLE, ONE PARTIAL**

⚠ *Corrected. An earlier draft said the AI calls neither. It calls one of them.*

**`CanAssault()` IS called** — `ai_manager.gd:224`,
`if not AssaultManager.CanAssault(f, target).ok: continue`. The AI **respects** the shield
gate (RULE-08-09) and never attempts a blocked assault. What it never does is **act** on a
blocked result: it skips to the next fleet rather than queuing bombardment or sabotage to
clear the shields. So the rule is **PARTIALLY IMPLEMENTED** — reactive half wired,
proactive half absent — not unreachable.

**`bombardment_manager`'s mode variants are genuinely uncalled.** RULE-08-10 needs **one
call site**, not two. *(Corrected by R2D2, room #174.)*

### 2.7 — Objective-driven selection · **NOT IMPLEMENTED**

Replace `Preferred()` with scoring against the current bottleneck. **This is the
structural item**, and 2.3 and 2.5 should land inside it rather than as patches.

### 2.8 — Subscribe to `EventBus` · **NOT IMPLEMENTED**

**84 of 180 rules are `on-event` and the AI has no event loop.** The stream exists,
faction-addressed, with a callback hook (`event_bus.gd:53`). Governed by the AR-4
decision: reactions **reprioritise, they do not spend**.

### 2.9 — HQ relocation · **NOT IMPLEMENTED (game-level)**

The only genuinely missing *mechanic*. Eight DEFEND rules depend on it. **Scope decision
for TeeJ** — `11-gaps.md` §1.1, question V-1.

---

## 3. Reverse index — open a file, see what governs it

Built mechanically from the `Code:` field of every rule record. **56 of 180 rules name a
code file**; the rest describe behaviour with no current home, which is itself the finding.

### `ai_manager.gd` — **43 rules**

Every other file in this index is in single digits. **The AI driver is where the work is,
and it is one 338-line file.**

| Area | Rules |
|---|---|
| Mission selection — `Preferred()` `:334–337`, targets `:317`, team `:312` | RULE-05-01, 05-10, 05-19, 05-20, 06-05, 06-08, 09-10, 10-06, 11-07 and others |
| Galaxy evaluation — `Evaluate()` `:22–33`, `:66–67` | RULE-01-02, 02-06, 02-08, 10-09 |
| Fleet movement — `MoveFleets()` | RULE-01-06, 01-07, 02-06, 11-06 |
| Invasion — `Invade()` `:216–260` | RULE-06-10, 10-14, and **D-1**, the unbudgeted-assault question |
| Production — `BuildWarships()` | RULE-03-09, 04-*, 10-15 |
| Budgets — `:11–13` | the Easy→Medium difficulty lever (`10-difficulty-and-fairness.md`) |

### Everything else

| File | Rules | What it governs |
|---|---|---|
| `intel_manager.gd` | 4 | RULE-02-01 *(staleness)*, RULE-05-18, **RULE-10-01 and RULE-10-18 — both blocked on `DescribeTask()`** |
| `enums.gd` | 4 | `MissionType` — RULE-05-01, 05-11, 05-19, 05-20. Nine of fifteen unreachable |
| `research_manager.gd` | 2 | RULE-05-11, RULE-11-13 — no research mission in `Preferred()` |
| `planet.gd` | — | `GarrisonRequirement()` `:450`, `BestProducerRate()` `:180`, uprising production halt. **Load-bearing for the support-driven garrison model that resolves three apparent guide contradictions** |
| `victory_manager.gd` | 1 | RULE-01-01. **Unaudited** — declared list or hardcoded? |
| `captivity_manager.gd` | 1 | RULE-05-02. **Unaudited** — prisoner model |
| `assault_manager.gd` | 1 | RULE-08-09. **`CanAssault()` is called** from `ai_manager.gd:224` — the gate is respected; the proactive shield-clearing response is what is missing |
| `bombardment_manager.gd` | 1 | RULE-08-10. Modes exist, uncalled |
| `force_manager.gd` | 1 | RULE-11-05. **Unaudited** — do ranks suppress missions? |
| `mission_manager.gd` | 1 | RULE-06-05 — the `Launch` signature |
| `loyalty_manager.gd` | 1 | RULE-06-14 — ⚠ **do not build**; the guide's sector loyalty penalty for force is uncorroborated |
| `command_applier.gd` | 1 | RULE-05-10 — the player path that already passes decoys |
| `agent_droid.gd` | 1 | RULE-03-01 — production management, largely a black box to the AI |
| `military_catalog.gd` | 1 | RULE-12-01 — **use data maintenance, never the guide's** for researched hulls |
| `facility_catalog.gd` | 1 | RULE-12-02 — the name mapping |
| `game_rules.json` | — | EntryId **150** uprising ×2, EntryId **151** shields-to-block-assault = 2 |

---

## 4. Before you change `ai_manager.gd`

Four things the corpus establishes about that file, which are not obvious from reading it:

1. **Its own comments are trustworthy and load-bearing.** *"Per-day caps are OURS"*,
   *"⚠ THE ORDER IS OURS (argued, not picked)"*, *"Difficulty is not an AI dial"*, *"the AI
   does NOT see through fog"*. Each is sourced and each constrains the design.
2. **`Preferred()` is not a list to extend.** Six findings trace to it.
3. **`Invade()` spends no budget** (D-1). Assaults are free — approximately two per day, bounded by loaded fleets in position, not by budget. See `10-difficulty-and-fairness.md` §4 note.
4. **Neutral entities are never acted on** (`:3`) — sourced from the binary. Unchanged.

---

## 5. What this map does *not* cover

- **Tactical combat.** `fleet_battle_manager.gd` and the tactical layer are **unaudited**
  and out of scope. RULE-08-04, 08-05 and 08-06 have uncertain code status.
- **`AgentDroid`.** The AI delegates production and garrison management to it
  (`ai_manager.gd:48–51`) and it is largely unexamined. Several economy rules may already
  be partly handled there.
- **Anything in `11-gaps.md` §1.4** — six claims the corpus makes that nobody has checked
  against code.

---

## Review

- [ ] Doof
- [ ] R2D2
