# 10 — Difficulty and fairness

| | |
|---|---|
| **Status** | REVIEWED — R2D2 (rooms #158, #181) and Doof (room #168); circular-warrant correction applied |
| **Author** | Han |
| **Requested by** | TeeJ, room #27 — *"build in ways to make different levels of difficulty in the opponent"* |
| **Depends on** | `09-counter-exploit.md` (the threat model), `01a-opponent-model.md` (what Hard may infer) |

---

## 1. This is a departure, and it is labelled as one

**Difficulty in the original game does not change AI behaviour at all.** Four independent
sources:

| Source | Says |
|---|---|
| Prima guide, p.17 *(L502–505)* | *"The difficulty you choose determines how many resources and systems you start with versus what your opponent has. **The computer will act the same for all difficulty settings.**"* |
| `GAMEPLAY.md:3573`, from the game's manual | *"Difficulty is a starting-position handicap, not smarter AI."* Easy: four loyal systems each; Medium: opponent starts with more; Hard: a lot more |
| `ai_manager.gd:7` | *"Difficulty is not an AI dial."* |
| Prima guide *(L4524–4525)* | *"On medium or hard difficulty games, the Empire doesn't necessarily have an advantage in its infrastructure."* |

The guide contradicts itself once, on the same page as the first quote, describing
behavioural differences between levels. That dissent is recorded in `ch01` and not
resolved — but three sources against one flavour paragraph is where the weight sits.

**So behavioural tiers are ours.** Requested deliberately, and labelled as ours wherever
they appear. They are not a restoration of 1998 behaviour and must never be described as
one.

---

## 2. Two axes, and they govern different halves of the ladder

| Axis | What it is | Status |
|---|---|---|
| **1 — Handicap** | Starting systems, resources, facilities. `data/side_lottery.json`, SDPRTB.DAT entries 30/31 | **The original's. Untouched.** |
| **2 — Competence** | How well the AI plays | **New. Ours.** |

Axis 2 is built from two things that govern different segments of the ladder. Of the 23
DEFEND rules in the corpus: **10 Hard, 11 Medium, 1 All, 0 Easy-only** — 22 active, after RULE-02-13 was dropped as not implementable without cheating.

> ⚠ **What that count does and does not prove.** An earlier draft said *"counting settled
> which governs which segment."* That claim is too strong, and it is circular: **the tier
> on each rule is an input we assigned by judgment during corpus construction, not an
> independent measurement.** The count is largely a restatement of those judgments.
>
> What it **does** establish: the ladder is **non-degenerate** — 11 and 11 is a real split
> with usable population at both Medium and Hard, not a lopsided or empty one. That was
> worth checking and it could have come out badly.
>
> What it **does not** establish: that capability *must* govern Easy→Medium. That is an
> argument, and it has to stand on its own reasoning — which it does: a DEFEND rule is by
> definition about protecting your own position, and an Easy opponent is one that does not
> yet do that. The zero at Easy follows from those definitions rather than being discovered
> in the data.
>
> *(Reservation raised by R2D2, room #181. The distinction matters because this design was
> adopted partly on the strength of "the count settled it", and that was the wrong warrant.)*

- **Easy → Medium is CAPABILITY.** Per-day budgets, planning horizon, reaction latency,
  decision noise. Self-protection rules contribute almost nothing here *by construction* —
  an Easy opponent is one that does not yet look after its own position well.
- **Medium → Hard is SELF-PROTECTION plus INFERENCE.** 12 of those rules active at Medium,
  all 23 at Hard, and the inference channels that the Hard-only ones require.

> An earlier draft claimed the DEFEND corpus alone *was* the ladder. The count disproved
> it and the claim is withdrawn. The reasoning is kept because whoever revisits this will
> otherwise collapse it back to one axis.

### The tiering rule

**A self-protection rule belongs at All when omitting it makes the opponent look *broken*
rather than *beatable*. Everything else starts at Medium.**

The one All-tier DEFEND rule earns it: RULE-05-23 has the Alliance move its characters off
their known starting systems on day one. The Empire *begins* the game knowing where most
of them are, so an AI that leaves them parked gives away a victory condition on turn one.
No player reads that as a gentle opponent; they read it as a bug.

---

## 3. The fairness rule — non-negotiable at every tier

**Difficulty never buys information.** No tier lifts fog, reads the opponent's intel
table, or knows an unexplored system's contents. **A Hard AI is better at inferring, not
at observing.**

The corpus supplies the worked example that defines the standard *(Ch9 sidebar L5929–5946)*:

> *"If the Empire attacks one of your systems, **check the battle results. This gives you a
> good idea of the Imperial garrison's size without running an espionage mission.**"*

Hidden state, derived from an event the AI legitimately observed. No fog lifted, real
information gained.

**Every Hard-tier intelligence behaviour must be justifiable in that shape.** Three
channels qualify, and they are the *only* ones this design grants:

| Channel | Event observed | Inference | Rule |
|---|---|---|---|
| **Battle results** | a battle resolves at any system | garrison strength | RULE-09-03 |
| **System flips** | a Core neutral joins the enemy | an enemy diplomat is standing there | RULE-10-04 |
| **Logistics** | espionage reports a build queue's destination | the HQ's sector | RULE-10-01 ⚠ blocked on one render line |

If a proposed Hard behaviour cannot be written in that shape — *observed event → inferred
hidden state* — it is cheating, whatever the code looks like.

---

## 4. The three tiers, concretely

> ⚠ **Every number in this table is OURS and is a starting proposal, not a derived
> value.** The original supplies none of them — `ai_manager.gd:11–13` already flags its own
> caps as *"Per-day caps are OURS"*. These are meant to be tuned against play, and the
> table is the thing to tune.

| Lever | Easy | Medium | Hard |
|---|---|---|---|
| **Moves / day** | 1 *(current)* | 2 | 3 |
| **Missions / day** | 1 *(current)* | 2 | 3 |
| **Ships / day** | 1 *(current)* | 1 | 2 |
| **Planning horizon** | one day — no plan persists | a few days | game-phase; commits to an objective |
| **Reaction latency** | 3–5 days after an event | 1–2 days | next daily pass |
| **Decision noise** | often takes a lower-scored option | rarely | never |
| **Objective ordering** | none — pursues whatever is nearest | pursues the bottleneck | full ordering, incl. RULE-10-12 *(save the HQ for last)* |
| **DEFEND rules active** | **1** — RULE-05-23 only | **12** — All + Medium | **22** — all active |
| **Inference channels** | none | battle results, system flips | all three, incl. logistics |
| **Opponent model** *(`01a`)* | none | **layer 1** — own-exposure log | **layer 2** — reverse fog, informing *priorities only*. **Layer 3 cut** |
| **Threats countered** *(`09`)* | none | T1, T2, T3, T6, T7, T8 | + T4, T5. **T9 uncountered by design** |

> ⚠ **The budget lever does not currently reach combat.** `Budget` has three counters —
> `Moves`, `Missions`, `Ships` — and no fourth. `MoveFleets`, `LaunchMissions` and
> `BuildWarships` each decrement theirs. **`Invade()` decrements nothing.** Its only budget
> reference is a `budget.Moves <= 0` guard that sits *after* the assault loop; the assault
> branch resolves, prints and returns before reaching it.
>
> **What that means concretely.** `ProcessDay` creates one `Budget` and calls `Dispatch`
> **twice** with it, and `Dispatch` runs `BuildWarships → Invade → MoveFleets →
> LaunchMissions` — with **Invade second, before movement is charged**. Each `Invade`
> returns after its first resolved assault, so the AI gets **roughly two free assault
> attempts per day**, each against the first in-position loaded fleet it finds.
> *(Not "unlimited" — that was an overstatement in an earlier draft. Corrected after
> R2D2's verification, room #163.)*
>
> **So on Easy, a "one move per day" throttle governs fleet repositioning only.** The AI
> can spend its single shared move repositioning *and still make its ~2 assaults that day*.
> The Easy→Medium capability step has **no grip on the combat loop**, and the Medium/Hard
> combat boundary must be expressed as **what the AI chooses to fight** rather than how
> often it is permitted to. Logged as **D-1** in `11-gaps.md`. Not asserted as a bug — it
> may be deliberate — but it is a decision we make rather than inherit.

### What each tier should feel like

**Easy** — competent at the basics and careless with itself. ⚠ Note the honest ceiling: **it may still assault roughly twice a day regardless of its move cap**, because assaults are unbudgeted. Easy is not a slower opponent in combat; it is a less selective one. It builds, expands, runs
missions, and does not notice you dismantling it. The guide's tactics work. It should not
feel *broken*: it scatters its roster on day one, it does not hand you free abductions, and
it plays every operational loop. It simply does not look after its position.

**Medium** — looks after itself. Garrisons before uprisings rather than after. Runs
counter-intelligence on its own systems. Keeps its systems loyal rather than held by force,
which quietly removes the fuel for the destabilisation play. Reacts within a day or two.
The book still helps you, but the openings are smaller and close faster.

**Hard** — infers. It reads battle results you thought were private, notices when a neutral
flips and comes looking for the diplomat who did it, and — if the logistics render is ever
fixed — reads your freight to find your headquarters. It moves its own headquarters on a
timer *before* you threaten it, keeps a prepared fallback in another sector, and when its
search for your characters stalls it stops hunting and starts taking the ground you hide
on. **Nothing it knows is anything it could not have observed.**

---

## 5. What Hard cannot do, and why that is stated here

Two of the three threats that most distinguish Hard are **not currently deliverable**:

- **T5, logistics inference** — blocked on one unrendered field
  (`ConstructionTask.Destination`). Until surfaced, RULE-10-01, RULE-10-02 and RULE-10-18
  are all inert, and the Empire's only documented method of finding the Rebel HQ does not
  exist for either side.
- **T9, the bluff counter — RESOLVED BY DROPPING IT.** It needed layer 3, which has been
  cut. RULE-02-13 is removed from Hard and annotated as not implementable without cheating.
  **A player who bluffs well retains an edge at every tier.** That is a stated limitation,
  not an oversight — and it is the framework's one deliberate cut.

**Eight of the 23 DEFEND rules also depend on HQ relocation**, which does not exist in the
game at all. Hard's signature behaviour — moving the headquarters before it is threatened —
is currently unbuildable.

Stated here rather than discovered later: **Hard as specified is not fully reachable
today.** What is reachable is a genuinely stronger opponent across T1, T2, T3, T6, T7 and
T8, which is most of the ladder.

---

## 6. Head-to-head

Multiplayer uses a separate rule column — `Difficulty.Multiplayer`, `side_lottery.json`
`"mp"` — and the setup screen offers **no difficulty choice at all** *(GAMEPLAY.md:4492–4493)*.

**Open:** what tier an AI runs at when filling a multiplayer slot. Recommendation:
**Medium**, because Easy is deliberately careless and would be a poor stand-in for an
absent human, while Hard's signature behaviours are the ones currently blocked. Flagged in
`11-gaps.md`; not decided here.

---

## 7. How to verify a tier is honest

1. **Log every AI decision with its inputs.** A decision that cites state the AI could not
   legitimately observe is a fairness bug, regardless of the tier.
2. **Diff the tiers on information, not just behaviour.** Easy, Medium and Hard must read
   the *same* context object. Only the throttles, the active rule set, and the inference
   channels differ.
3. **Test the ladder with the book.** Chapters 9, 10 and 11 are a printed set of tactics;
   they should work on Easy and get progressively less effective. *That is evidence of
   competence, not the definition of it* — see the charter.
4. **Watch for the twitchy failure.** `01a` OM-1: the layer-2 reverse-fog estimate is
   deliberately pessimistic. An AI that assumes the enemy knows everything they could know
   may relocate its HQ constantly and read as nervous rather than careful. **If Hard looks
   twitchy, that is the first place to look.**

---

## Review

- [ ] Doof
- [ ] R2D2
- [ ] **TeeJ** — this is the document you asked for; the tier table in §4 is the thing to
      react to
