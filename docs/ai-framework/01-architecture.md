# 01 — Architecture

| | |
|---|---|
| **Status** | REVIEWED — R2D2 (room #141) and Doof (room #197); four structural corrections applied |
| **Author** | Han |
| **Depends on** | `00-charter.md` (approved), `01a-opponent-model.md` |
| **Scope** | Design only. No code changes. |

---

## What the AI is today

One entry point. `strategic_tick_manager.gd:154` calls
`AiManager.ProcessDay(_galaxy, CurrentDay, rng)` once per day, and that is the whole
surface. `ai_manager.gd` contains **no event subscriptions at all** — no `EventBus`, no
`connect`, no signal handler.

Inside `ProcessDay` the shape is: categorise the galaxy (`Evaluate`), then `Dispatch`
twice against a per-day budget of `1` move, `1` mission, `1` ship. Mission selection runs
through `Preferred()` — a hardcoded list of six mission types filtered against what the
agent can perform.

It is coherent, small, and honest about its own limits: the code's own comments flag
"Per-day caps are OURS" and "⚠ THE ORDER IS OURS (argued, not picked)".

---

## The problem: the corpus does not run on a daily clock

Every rule in the corpus carries a `Clock` field. Counted across all 180:

| Clock | Rules | Does the AI have it? |
|---|---|---|
| **on-event** | **84** | ❌ **No mechanism whatsoever** |
| per-day | 49 | ✅ This is `ProcessDay` |
| game-phase | 41 | ❌ No notion of game phase exists |
| per-N-days / per-tick / always | 6 | ❌ |

**The largest category of rules in the corpus — 84 of 180, more than the other two
combined — is triggered by events, and the AI has no event loop.**

That single fact explains most of the behavioural gaps found during analysis. An uprising
starts and the AI cannot respond to *the uprising*; it can only notice, on some later
daily tick, that a system's state has changed. A character is captured and no rescue is
considered. A neutral system flips to the enemy and the inference it licenses — that an
enemy diplomat is standing there — is never drawn.

---

## The event stream already exists, and the AI is not subscribed

This is the cleanest *implemented and unreachable* finding in the project.

`EventBus` already broadcasts a typed, **faction-addressed** message stream.
`Enums.MessageType` (`enums.gd:57–84`) defines **27 message kinds**, and
`EventBus.Tell(audience, message)` (`event_bus.gd:53`) routes each to the side it
concerns. Subscription is a callback append: `EventBus.OnMessageReceived`.

The message kinds map almost one-to-one onto the corpus's own triggers:

| Message kind | Rules it would fire |
|---|---|
| **TacticalAfterActionReport** | **RULE-09-03** — infer garrison strength from battle results. *This is the charter's worked example of fog-legal inference, and its trigger is already broadcast* |
| **Uprising** | RULE-06-09 (respond immediately), RULE-06-12 (an uprising is an attack window), RULE-09-01 (the destabilisation play) |
| **SystemControl** | RULE-10-04 (a flip is evidence of a diplomat), RULE-06-04 (consolidate after acquisition) |
| **CharacterCaptured** | **RULE-05-19 (rescue)**, RULE-05-02 (hold what you capture) |
| **MissionFailed** / **MissionReport** | Layer-1 exposure (`01a`): a foiled mission means someone was watching |
| **Blockade** | RULE-02-01 (intel refresh), RULE-05-22 (pin before striking) |
| **GarrisonWarning** | RULE-09-02 (break the sabotage → uprising chain before it starts) |
| **PlanetDestroyed** | RULE-10-11 (galaxy-wide loyalty consequence) |
| **MaintenanceShortfall** | economy policy |
| **ResearchReport** | RULE-05-11 (research is top priority when available) |
| **UnitArrival**, **PersonnelArrive** | Layer-1 exposure |
| **CharacterHealth** | RULE-10-07 (assassination wounds rather than kills) |

**Nothing needs to be built to generate these.** They are produced today, addressed to a
faction today, and thrown away as far as the AI is concerned.

---

## The proposed shape

**Three acting stages and one shared context object they all read.**

> *Revised after R2D2's review (room #141) and Doof's refinement (room #143). The first
> draft had four layers split by the rules' `Clock` field. That was splitting by **when a
> rule fires**, not by **what kind of decision it is** — and two of the four turned out
> not to be separate decisions at all. What changed and why is at the end of this section.*

```
   ┌───────────────────────────────────────────────────────────┐
   │  CONTEXT          world · intel · own-exposure · opponent │  read by all
   │  read-only to every stage. Specified in 01a.              │  (writes: Reactions)
   └───────────────────────────────────────────────────────────┘
                    ▲            ▲            ▲
                    │            │            │  every stage reads
   ┌────────────────┴───┐  ┌─────┴────────┐  ┌┴──────────────────┐
   │  OBJECTIVES        │  │  ACTION      │  │  REACTIONS        │
   │  what we are for   │─▶│  SELECTION   │◀─│  events that      │
   │  victory as a plan │  │  propose,    │  │  interrupt        │
   │  the bottleneck    │  │  score, pick │  │  EventBus         │
   │  game-phase · 41   │  │  per-day · 49│  │  on-event · 84    │
   └────────────────────┘  └──────────────┘  └───────────────────┘
                                  │
                                  ▼  spends the shared per-day budget
```

### Context — the shared reader

Not a stage. It does not decide anything. It is the **state every stage queries**:

| Holds | Source |
|---|---|
| The galaxy as we see it | `GalaxyView` — already exists (`ai_manager.gd:22–33`) |
| What we know of them, and how stale | `IntelManager` — already exists and is faithful, and the AI never reads it |
| **What they may know of us** | **Does not exist.** Specified in `01a-opponent-model.md` |

**Naming it is the point.** Thirteen rules across six chapters — RULE-01-07, RULE-02-04,
RULE-05-18, RULE-05-23 among them — are unimplementable at any tier today because they
*read* something nothing currently *writes*. Leaving the reader unnamed made `01a` look
like a floating open question; naming it makes the architecture complete **before** `01a`
is answered, and gives `01a` a precise job: specify what the object holds, not add a
stage. *(Doof's framing, room #143.)*

> **Why this is three stages and not two.** Loops and Arbitration collapsed because they
> shared a clock and no rule belonged to one and not the other. **Objectives does not have
> that problem:** it is **stateful across days** — what are we trying to achieve, what is
> the bottleneck — while Action Selection is **stateless per-day** — score, pick, spend.
> Different clocks, different questions, and the corpus tags them differently (41
> `game-phase` rules against 49 `per-day`). *(Doof, on review.)*

### Objectives — what we are for

Victory conditions as **a plan, not a checklist**. RULE-10-12 tells the Empire to *save
the headquarters for last* — the easiest condition — because pursuing the other two first
shrinks the space its targets can hide in. That is a **dependency between conditions**,
which a list of booleans cannot express and a fixed priority order cannot either, because
the ordering is conditional on progress.

Output: the declared condition set (RULE-01-01), an ordering over it, and **the current
bottleneck** — a weight that action selection reads. Detailed in `08-victory.md`.

### Action selection — propose, score, pick

**One stage, not two.** The first draft split this into "loops that bid" and "arbitration
that selects". There is no rule that belongs to one and not the other, both run on the
same clock, and a producer/consumer pair inside one step is not a layer boundary.

What survives from that split is a **data contract**, which is worth keeping explicit
because it is where the five operational policies plug in:

```
CandidateAction {
    action          what to do
    loop            which policy proposed it (economy · fleet · missions · diplomacy · combat)
    objective_fit   how much it advances the current bottleneck
    expected_value  p_success × objective_gain          — priced on the TARGET (added)
    asset_risk      p_loss × replacement_cost           — priced on the ACTOR (subtracted)
    urgency         situational, not type-based
    justification   why, in text, so a decision can be explained
}
```

The five operational policies (`03`–`07`) each produce candidates. Selection scores them
against the objective weight and spends the budget. That replaces `Preferred()` — a fixed
list of six mission types, identical for both factions in every phase, to which **six
separate findings trace** (unexplored last, one global order, subdue-uprising last,
sabotage absent, abduction absent, nine of fifteen types unreachable). It is one design
decision with many symptoms; patching the list addresses none of them.

**`expected_value` and `asset_risk` are not double-counting.** They price different
objects: expected value is about the **target** — what we gain if this works — while asset
risk is about the **actor** — what we lose if it does not. A cheap unit attacking a
high-value target and a valuable character attacking a low-value one can score identically
on one term and oppositely on the other. Expected value is added to the score; asset risk
is subtracted. *(Definitions tightened by Doof on review; they must stay separable, because
the economy and fleet policies bid on the first and the missions policy bids on both.)*

The corpus supplies the scoring terms directly: expected value is stated outright for
sabotage — *"weigh the potential cost to you of letting your enemy succeed in building a
given ship or structure"* (RULE-05-09), priced inversely to the target's redundancy
(RULE-10-05); asset risk is RULE-05-03, characters improve with success and Special Forces
never do.

### Reactions — the event loop

Subscribe to `EventBus`, filter to messages addressed to this faction. An event either
**writes to context** — including the layer-1 exposure log from `01a` — or raises an
**interrupt** that pre-empts the day's plan.

Not every event interrupts. An uprising on our own system must be handled "immediately"
(RULE-06-09) because it halts production and can flip the system; a research report merely
updates what is buildable. The interrupt set should be small and justified rule by rule.

> **What changed from the first draft, and why.** Loops and Arbitration were folded into
> one stage because no rule distinguished them. Context was promoted from an unnamed
> assumption to the thing the diagram is built around, because thirteen rules read it and
> nothing writes it. And AR-1 was rescoped — see below; the hazard is not the one the
> first draft named.

## What this fixes, traced

| Finding | Where it lands |
|---|---|
| 9 of 15 mission types unreachable | **Action selection** — scoring runs over *all* legal actions, not a list |
| Sabotage and abduction absent | **Action selection** |
| Single-agent teams, no decoys | **Action selection** — the `Launch` signature already takes both (`mission_manager.gd:487`) |
| `Unexplored` targeted last | **Objectives set the weight; action selection applies it.** The bottleneck says "find the HQ"; exploration candidates score high against it. *Two stages, and the first draft filed this under Objectives alone — which was the error R2D2's point 2 caught* |
| `SubdueUprising` last, no urgency | **Reactions raise the interrupt; action selection honours it.** Urgency is situational, so it cannot live in a static list |
| No response to captures, flips, battles | **Reactions** |
| No game-phase awareness | **Objectives** |
| No opponent-knowledge model | **Context** — the object itself, specified in `01a`. Reactions *write* to it; every stage *reads* it. It is not owned by Reactions |

---

## Constraints this must respect

1. **The fog rule.** No stage reads state the AI could not legitimately observe — and
   that constraint lands on the **context object**, which is why `01a` matters. Reactions
   are the *reason* this is affordable: they give the AI real information from events it
   is genuinely entitled to (`00-charter.md`, "The fairness rule").
2. **Determinism.** `ProcessDay` takes a `Prng`; the game is lockstep-replayable
   (`src/command/replayer.gd`, `src/net/lockstep_session.gd`). The hazard is **not**
   event delivery order — `EventBus` is a deterministic in-process stream. It is
   **budget contention** between reactions and the daily loop, which is AR-4 and is
   blocking for implementation.
3. **Neutrals are never acted on.** `ai_manager.gd:3` records this as sourced from the
   binary. Unchanged.
4. **No new game mechanics.** The architecture rearranges what the AI does with existing
   systems. The one genuinely missing mechanic — HQ relocation — stays a flagged gap.

---

## Open questions

| # | Question | What would settle it |
|---|---|---|
| **AR-1** | ~~Do events arrive in the same order between clients?~~ **WITHDRAWN — wrong hazard.** `EventBus` is a deterministic in-process stream; delivery order is guaranteed by construction. Merged into AR-4, which is the real question *(R2D2, room #141)* | — |
| **AR-4** | **★ DECIDED — reactions reprioritise, they do not spend.** An event may write to context and reorder what the next daily pass does; it may not consume budget itself. All spending stays in the single per-day pass. **Reason:** the day is the game's atomic decision unit for both sides — `strategic_tick_manager.gd:29` `AdvanceDay()` is the only strategic clock and there is no sub-day action path for the player either. A reaction's job is to make the *next* pass correct, not to act between passes. This **dissolves** the contention hazard rather than managing it: with no mid-day spend, the daily outcome depends only on start-of-day state plus deterministic context writes. **Falsifier:** if any rule genuinely requires acting between daily passes, this is wrong and we go to a separate interrupt reserve. Every "urgent" rule checked (RULE-06-09, RULE-05-22, RULE-10-08) turns out to be about **sequence**, not intra-day timing | Decided. Reopen only on a counter-example |
| **AR-2** | Which events are **interrupts** and which merely write to context? | Rule by rule, from the `Clock` field and the urgency wording in the corpus |
| **AR-3** | One shared scorer with per-loop terms, or a scorer per loop? | Try one shared scorer first — a per-loop scorer is harder to tune and harder to explain, and `CandidateAction` already carries the per-loop terms |
| **AR-5** | **★ RESOLVED by AR-4.** The context object is a **per-day snapshot**. Nothing acts mid-day, so nothing can observe a half-updated context | Closed |

---

## Review

- [ ] Doof
- [ ] R2D2
