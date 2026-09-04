# 08 — The victory layer

| | |
|---|---|
| **Status** | REVIEWED — Doof (room #166); count reconciled; V-2 audit closed |
| **Author** | Han |
| **Loop** | `victory` — **22 rules** by the corpus's first-listed-loop convention, the objective layer of `01-architecture.md`. One further rule, **RULE-10-10**, is cross-referenced here: its loop is `economy + victory` and `02-rule-corpus.md` files it under Economy |
| **Existence** | This document was missing from the original set. Victory carried 23 rules and had no home until R2D2 caught it (room #117) |

Victory is not a loop like the other five. Economy, fleet, missions, diplomacy and combat
are things the AI *does* on a clock. Victory is what they are **for**, and what arbitrates
between them when they compete.

---

## 1. The conditions

| | Alliance | Empire |
|---|---|---|
| 1 | Capture **Coruscant** | **Destroy the Rebel headquarters** |
| 2 | Capture **Emperor Palpatine** | Capture **Luke Skywalker** |
| 3 | Capture **Darth Vader** | Capture **Mon Mothma** |

All three must be met *(GAMEPLAY.md:3043–3049)*. Under **Headquarters-Only Victory**,
conditions 2 and 3 are dropped and only the headquarters remains
*(GAMEPLAY.md:4480–4482)*.

**RULE-01-01 — hold the set as a declared list, not hardcoded checks.** Read it from
setup; evaluate each condition separately. GAMEPLAY.md:3598 already argues for this.

⚠ **Capture is not enough — "you must capture *and hold*"** *(GAMEPLAY.md:3056)*. That
turns two of the three conditions into a **holding problem**, which is why RULE-05-02
(prison doctrine) sits in this loop and not in missions.

⚠ **Two of three conditions per side are character captures, and the only mission that
achieves them is absent from the AI's selection.** `MissionType.Abduction` is not in
`Preferred()` (`ai_manager.gd:334–337`). **As the code stands the AI cannot pursue
two-thirds of its own win conditions** — the single most consequential finding in the
corpus (RULE-05-01, gap G-05-1).

### The asymmetry that shapes everything

Under **HQ-Only**, the Alliance *begins knowing where the Imperial headquarters is*
(RULE-01-03, guide L524–531) — Coruscant does not move and is not hidden. The Empire must
still **find** a headquarters concealed somewhere in the Rim.

**So the two sides are not playing mirrored games.** The Empire's condition 1 is a search
problem; the Alliance's is a siege problem. Build one search behaviour for the Empire, not
a shared one.

---

## 2. Why it is a plan and not a checklist

The corpus is explicit that **the order of pursuit matters**, and in a counter-intuitive
direction.

> **RULE-10-12 — save the headquarters for last.** *"Taking out Rebel headquarters is the
> easiest victory condition to meet, so you can save it for last. Instead, fire up your
> fleets and start decimating Alliance systems. Although this won't do a lot for your
> public relations, it pays off in other ways: foremost, it reduces the number of Rebel
> systems for those all-important characters to hide on."* *(Ch10 L6915–6919)*

Deliberately deferring the *achievable* objective because pursuing the others makes it
easier is a **dependency between conditions**. A list of booleans checked at end of turn
cannot express it. Neither can a priority list — the ordering is conditional on progress.

The same logic arrives from the other direction in **RULE-11-04** and **RULE-11-15**: when
the search for the enemy's characters is not converging, stop searching and **shrink the
space they can hide in** by taking territory — especially neutral systems, which is where
the guide tells players to hide them *(Ch11 L7192–7198, L7363–7369)*.

### The bottleneck

The objective layer holds one piece of state the rest of the AI reads: **which condition
is currently blocked, and on what.**

| Bottleneck | What the loops should be serving |
|---|---|
| HQ location unknown *(Empire)* | Recon and espionage toward the Rim; probe-droid production (RULE-11-14); logistics inference (RULE-10-01) |
| HQ located, not yet reduced | Blockade to pin, then bombard/assault (RULE-02-05) |
| Characters unlocated | Espionage breadth; territory denial when it stalls (RULE-11-04) |
| Characters located, not captured | Abduction, with a blockade first (RULE-05-22); never invade before attempting (RULE-10-08) |
| Character captured, not held | Prison hardening or hyperspace custody (RULE-05-02) |
| Own character captured | **Rescue** — "bend most of your efforts" (RULE-05-19) |

This is what `01-architecture.md`'s arbitration layer scores against.

---

## 3. The two kill chains

Both sides have an **ordered** endgame. They are structurally the same shape — pin,
soften, capture — which is corroboration in itself: neither chapter was written with the
other in view.

### Imperial — against the Rebel HQ *(RULE-02-05)*

1. **Recon** unexplored Rim systems — recon is Special-Forces-only, so this means
   **probe droids** (RULE-05-05, RULE-11-14).
2. **Persistent espionage** — and the highest-value read is not the target system but
   **where its production is being shipped** (RULE-10-01).
3. **Blockade the HQ system** — *to stop it relocating*. Not economic. `GAMEPLAY.md:3078–3087`
   is explicit that this is the step that pins the target.
4. **Bombard and assault**, or destroy with a Death Star.

> *"Only through espionage and reconnaissance can the Imperial player discover where the
> Rebel headquarters is hiding"* — guide L717–722. A closed list of two methods.

### Alliance — against Coruscant *(RULE-09-13)*

1. **Smaller fleets blockade the other Imperial systems in the sector**, to prevent
   retaliation.
2. **Main fleet carries characters** — loaded before it departs.
3. **Blockade Coruscant** once local Imperial fleets are engaged. *"Your fleet can't be
   too big at this point."*
4. **Sabotage ground troops *and* defensive batteries** before any assault.
5. **Capture Palpatine before the assault begins**, if he is present.
6. Expect **escape** — high leadership gives "a good chance they'll escape to another
   Imperial system."

**Both chains put the capture attempt before the invasion.** RULE-10-08 states it for the
Empire — *"under no circumstances should you attempt to bombard and take over the system
before attempting abductions"* — and RULE-09-13 step 5 for the Alliance. Independent
statements of the same ordering, which raises confidence in the underlying mechanic.

---

## 4. The pivot: the headquarters can move

Seven independent passages describe it *(Ch2 L673–687, Ch4 L2289–2291, Ch9 L5743–5745 and
L6126–6141, Ch11 L7180–7186 and L7187–7191, Ch10 L6907–6913)*. The manual documents the
HQ's own **Move / Confirmed Move** menu *(GAMEPLAY.md:2996–2998)* and prices the loyalty
cost — a small drop on the system it left *(GAMEPLAY.md:1018, manual p090)*.

**It is the single mechanic that turns the Empire's first condition from a lottery into a
race.** Without it: find it, kill it, done. With it, the Empire must find it *and reach it
before it moves*, and the Alliance has a real defence to play.

Three tiers of behaviour, and they form a clean ladder on one mechanic:

| Tier | Behaviour | Needs |
|---|---|---|
| **Easy** | never moves | — |
| **Medium** | **RULE-09-04** — moves when an enemy fleet is observed in the HQ's sector | a fleet-in-sector check. **No opponent model** |
| **Hard** | **RULE-11-01** — rotates every few game weeks on a timer, threatened or not; plus **RULE-11-02**, a prepared fallback system in another sector, built out in advance | commitment of production to a contingency that may never be used |

Supporting: **RULE-09-05** — site the HQ on a system with high facility potential, and
spend that potential on **defensive batteries, not production**; garrison massively.
**RULE-10-13** — the Empire must *expect* relocation and re-enter the search loop rather
than treat a failed strike as a dead end.

> ⚠ **NOT IMPLEMENTED — the one genuinely missing game mechanic in the whole corpus.**
> No relocation code exists anywhere in `src/game`; the HQ is placed by
> `day_zero_generator.gd:53` and thereafter can only be destroyed
> (`assault_manager.gd:161`, `bombardment_manager.gd:195`). Consequently
> `blockade_manager.gd` has no pinning effect either — there is nothing to pin.
>
> **Every rule in this section is written and marked NOT IMPLEMENTED, per TeeJ's option
> (b) (room #40).** They cost nothing to hold and they keep the design honest.

---

## 5. The Death Star — an optional accelerant

The Empire may pursue victory through a Death Star. The guide is clear it is **optional**
— *"Whether or not you build a Death Star, the Imperial endgame tends to follow a
particular sequence"* — and it is expensive.

| | |
|---|---|
| **Build time** | >6 game years with 1 shipyard; **~9 months with 10** on the same system. Advanced shipyards are **2× faster** (RULE-10-10) |
| **Maintenance** | **600** for the station alone — confirmed three ways: Ch10 prose, Appendix B, and `military_units.json`. **850–900** stocked, *unverified* |
| **Vulnerability** | *"only really vulnerable to assault by individual starfighters"* — keep it full of TIEs |
| **Concealment** | **RULE-10-02** — once the site is self-sufficient, **stop shipping to it**; "no espionage evidence remains of what you do there" |
| **Its one weakness** | **RULE-05-21** — while under construction, the Alliance's counter is to sabotage **the shipyard**, because *"the Death Star must be completed before you can sabotage it directly"* (RULE-05-20). **Death Star shields on the producing system are the Empire's only defence** — *"while these are operational, the Death Star is immune to Rebel assault"* |

**Use it as a support weapon, not a planet-killer** (RULE-10-11). Its *presence* raises
Imperial support across its sector and makes Rebel-held systems likelier to revolt
(`GAMEPLAY.md:1015`) — so park it and run diplomacy and invasions underneath it. The
effect is transient and ends when it leaves. Destroying a planet costs support
**galaxy-wide** (`GAMEPLAY.md:1016`) — a priced trade-off, with one stated exception: a
strongly held Rebel HQ, where destruction *"will completely eliminate the need to chase
the headquarters through the galaxy."*

---

## 6. Rule index — the victory loop

| Tier | Rule | Class | What it does |
|---|---|---|---|
| All | RULE-01-01 | DO | Victory as a declared list |
| All | RULE-01-02 | DO | Locating the Rebel HQ is a first-class objective |
| All | RULE-01-03 | DO | HQ-Only changes the set; Alliance starts knowing Coruscant |
| All | RULE-02-05 | DO | The Imperial kill chain |
| All | RULE-05-01 | DO | Abduction is a victory condition, not a raid |
| All | RULE-09-13 | DO | The Coruscant kill chain |
| All | RULE-11-14 | DO | Probe droids for the HQ hunt |
| Medium | RULE-05-02 | DO | Hold what you capture |
| Medium | RULE-05-19 | DO | Rescue |
| Medium | RULE-05-21 | DEFEND | Shield the Death Star's yard |
| Medium | RULE-09-04 | DO | HQ relocation — reactive trigger |
| Medium | RULE-09-05 | DO | HQ site selection |
| Medium | RULE-09-14 | DO | Endgame search priors |
| Medium | RULE-10-10 *(x-ref)* | DO | The Death Star programme — loop `economy + victory`, **counted under Economy** |
| Medium | RULE-10-13 | DO | Expect the HQ to move |
| Hard | RULE-02-04 | DO | HQ relocation under suspicion |
| Hard | RULE-05-20 | DO | Hit the yard, not the station |
| Hard | RULE-10-01 | DO | Find the HQ by its logistics trail |
| Hard | RULE-10-12 | DO | Save the HQ for last |
| Hard | RULE-11-01 | DO | Prophylactic HQ rotation |
| Hard | RULE-11-02 | DO | Prepared fallback system |
| Hard | RULE-11-04 | DEFEND | Shrink the hiding space |
| Hard | RULE-11-15 | DEFEND | Deny the neutral sanctuaries |

7 All · 7 Medium · 8 Hard · 3 DEFEND = **22**, plus RULE-10-10 cross-referenced from Economy.

---

## 7. Open questions

| # | Question | What would settle it |
|---|---|---|
| **V-1** | **Is HQ relocation in scope to build?** It is the one missing mechanic, it is confirmed seven times, and eight rules here depend on it | TeeJ's call. Currently: rules written, marked NOT IMPLEMENTED |
| **V-2** | **Can the Empire find the HQ at all?** RULE-10-01 needs espionage to report construction **destinations**. **AUDIT COMPLETE — the answer is one render string.** See below | **TeeJ's call**: it is a change to shipped UI behaviour. Not ours to make |
| **V-3** | How is "the bottleneck" computed, and how often does it change? | `01-architecture.md` arbitration design |
| **V-4** | Is the 850–900 stocked Death Star maintenance figure right? | Derive from an actual loadout; the 600 base is confirmed |
| **V-5** | Does `victory_manager.gd` model conditions as a declared list, or as hardcoded checks? **Not audited** | Read it |

---

### V-2 in full — the audit result

**The destination field is live, not vestigial.** `ConstructionTask.Destination` is
populated at queue time (`planet.gd:342`, `:406`, alongside
`TransportDays = DeploymentDaysTo(destination)`), drives delivery on completion
(`planet.gd:742–746`), is read by the production agent (`agent_droid.gd:135,138`), and is
even printed to the console — *"built, en route to %s - %dd."*

It is absent from exactly one place: the string the intel panel builds.
`intel_manager.gd` `DescribeTask()` returns `"%s (%s, %d%% complete)"`, where the middle
field is the **queue's name** — "construction", "shipyard", "training" — not the
destination. The Manufacturing section calls it three times and passes the queue name
each time.

So the gap between *"the Empire has no principled way to find the Rebel HQ"* and
*"the Empire's primary win condition is reachable"* is **one appended field in one
format string**. No architecture work, no new model, no new data.

Four rules go live the moment it is surfaced: **RULE-10-01** (Empire reads the freight to
find the HQ), **RULE-10-02** (Empire hides the Death Star by cutting its freight),
**RULE-10-18** (Alliance protects the HQ by making its sector self-sufficient), and this
document's V-2.

> ⚠ **It is a change to shipped UI behaviour and affects the human player identically** —
> a player reading the espionage panel today cannot see where enemy production is headed
> either, though the manual and the guide both say they should. **`src/` is not touched
> by this phase.** Reported for TeeJ's decision.

*Found independently twice: by this document's V-2, and by R2D2's ch10 third-read
(room #134), which supplied the exact fix. Verified again here — the concern that the
field might be declared-but-unused does not hold.*

---

## Review

- [ ] Doof
- [ ] R2D2
