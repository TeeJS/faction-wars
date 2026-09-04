# 01a — The opponent-knowledge model

| | |
|---|---|
| **Status** | REVIEWED — R2D2 (room #174). Layers 1–2 specified; **layer 3 remains undesigned** |
| **Author** | Han · needs review |
| **Why separate** | `01-architecture.md` is a document of answers. Burying an undesigned prerequisite inside it means the next reader takes it as designed. *(Doof's argument, room #103.)* |

---

## The problem, stated once

A large part of the corpus asks the AI to act on **what the enemy knows about it**.
Not what the enemy *has* — what the enemy has *seen*.

The AI currently has no representation of this at all. `IntelManager` models what **we**
know about **them**, faithfully and with staleness (`intel_manager.gd:3–6`). There is no
counterpart for what **they** know about **us**.

> **Scope note.** This document designs **AI internals**, not game mechanics. Nothing
> here invents a rule about how *Star Wars: Rebellion* works — the constraint from the
> charter is that the AI may only reason from state it could legitimately observe, and
> everything below is built to respect that.

---

## The evidence: which rules need it

Fourteen rules across **six of the twelve chapters** turned out to depend on this.
The demand was not designed in — it emerged independently, chapter by chapter, from
different authors reading different parts of the guide.

| Rule | Ch | Class | Tier | What it needs to know |
|---|---|---|---|---|
| **RULE-05-23** | 05 | DEFEND | **All** | The Empire *starts* knowing where most Rebel characters are — so move them |
| RULE-09-12 | 09 | DEFEND | Medium | Whether a mission would expose a victory-condition character |
| RULE-11-06 | 11 | DO | Medium | That a parked ship or character accumulates exposure |
| RULE-01-07 | 01 | DO | Hard | "Treat *being located* as a cost" |
| RULE-01-09 | 01 | DEFEND | Hard | That our own search for a hidden opponent is not converging |
| RULE-02-04 | 02 | DO | Hard | Whether the enemy has learned where the HQ is |
| RULE-02-13 | 02 | DEFEND | Hard | That the enemy's picture of *us* is also aged, and can be exploited |
| RULE-05-14 | 05 | DO | Hard | Whether a Force-training site has been observed |
| RULE-05-18 | 05 | DEFEND | Hard | Whether a system holding a victory character is being watched |
| RULE-10-02 | 10 | DEFEND | Hard | Whether our logistics have revealed the Death Star site |
| RULE-10-18 | 10 | DEFEND | Hard | Whether our logistics have revealed the HQ sector |
| RULE-11-03 | 11 | DO | Hard | That the opponent *will not spend espionage on neutral systems* |
| RULE-11-15 | 11 | DEFEND | Hard | That our search has failed, so the sanctuary must be denied instead |
| RULE-11-01 | 11 | DO | Hard | *(marginal — timer-based rotation needs no model; listed because its **reactive** sibling RULE-09-04 does)* |

**Thirteen of these are genuine dependencies; one — RULE-11-01 — is marginal.** The count matters because
earlier drafts of the framework said "three chapters" and then "four" — both were
undercounts made from memory rather than measurement.

---

## The key realisation: it is not one model, it is three layers

The rules do not all need the same thing. Sorting them by *what they actually require*
turns one undesigned problem into three, of which **two are tractable now**.

### Layer 1 — Own exposure log *(needs no model of the enemy at all)*

**Question answered:** *"Has something happened to me here that implies I was seen?"*

The AI does not need to simulate the opponent to answer this. It only needs to record
**events that happened to its own assets** — all of which it observes directly and
legitimately:

| Event | What it implies |
|---|---|
| An enemy espionage or sabotage mission **detected** on our system | They were looking here. Counter-intelligence provides this — RULE-05-06, and `GAMEPLAY.md:1967` confirms own-system espionage detects enemy missions |
| An enemy fleet **arrives in orbit**, blockades, or bombards | They know this system matters |
| A battle resolves at our system | They have current information about it |
| One of our characters is **abducted or assassinated** | They knew that character was there |
| A mission of ours is **foiled** | They were watching for it |

Store, per own system: **the day of the last such event, and its kind.** That is the same
shape as `IntelSnapshot` — a per-object, per-category timestamp — pointed at ourselves.

**Unlocks immediately:** RULE-05-18, RULE-05-23, RULE-09-12, RULE-11-06, RULE-05-14, and
the *reactive* half of HQ relocation (RULE-09-04, whose trigger is literally "an Imperial
fleet is observed in the sector containing the HQ").

**Cost:** low. It is a log of things the AI already sees.

### Layer 2 — Reverse fog *(a model of what the enemy could have observed)*

**Question answered:** *"Could they know this, whether or not I saw them find out?"*

The elegant part: **the AI already contains a fog model, and it can be run from the other
side.** The rules governing what *we* can see of *them* are symmetric — recon and
espionage yield categories, a blockading fleet yields a refresh, proximity reveals. Apply
those same rules to the opponent's known assets against our own, and the output is an
**upper bound on enemy knowledge**: not what they *do* know, but what they *could* know.

This is deliberately pessimistic. The AI assumes the enemy has learned anything they had
the opportunity to learn. That is safe in the right direction — it makes the AI
appropriately cautious rather than mysteriously prescient — and it **cannot leak hidden
state**, because it is computed entirely from the AI's own legitimate observations of
enemy positions and its own activity.

**Unlocks:** RULE-02-04 (has the HQ been observed?), RULE-10-02 and RULE-10-18 (has our
freight been observable to anyone?), RULE-01-07 (accumulated exposure as a cost term).

**Cost:** moderate. It reuses `IntelManager`'s category and refresh rules rather than
inventing new ones.

> ⚠ **The obvious wrong turn.** It would be far easier to answer layer 2 by *reading the
> opponent's actual intel table*. That is cheating — the AI would know precisely what the
> enemy knows, which no player can do — and it violates the charter's fairness rule
> outright. The upper-bound estimate exists specifically so the tempting shortcut is not
> needed.

### Layer 3 — Belief and intent *(DROPPED — see below)*

**Question answered:** *"What does the opponent believe, what will they do about it, and
can I act on the gap between their belief and the truth?"*

This is the layer the corpus demands and this framework **cannot yet specify**.

**Only one rule actually needs it.** Two of the three originally listed here were
misclassified, and reclassifying them collapses the problem:

- **RULE-11-03 — reclassified, does NOT need layer 3.** Its trigger is *"Mon Mothma or
  Luke is idle"* and its action is *"keep them in the Rim running diplomatic missions on
  neutral systems."* Both are **own-state**. The guide's *rationale* mentions opponent
  behaviour, but executing the rule needs only a **standing placement heuristic** — prefer
  neutral systems for victory characters — plus the static fact of which of our characters
  are the enemy's win conditions. **Implementable without layer 3.**
- **RULE-11-15 and RULE-01-09 — reclassified, do NOT need layer 3.** The trigger is
  *"victory-condition characters unlocated for a sustained period"* — that is **tracking
  our own search's effectiveness**, not modelling the opponent's beliefs. An AI can know
  its own search is failing without any theory of what the enemy thinks.
  **Implementable without layer 3.**
- **RULE-02-13 — genuinely needs it, and is therefore DROPPED.** Countering a bluff means
  holding a belief about the *enemy's belief about us*. There is no honest way to do that
  without either reading their state — which is cheating — or hand-tuning a heuristic that
  merely looks like reasoning. **RULE-02-13 is removed from the Hard tier and annotated as
  not implementable without cheating.**

**Decision: layer 3 is not built.** With two of its three dependants reclassified, it
would exist to serve exactly one rule, and that rule cannot be served honestly. Carrying an
undesigned layer into implementation to support a single unimplementable rule is worse than
dropping the rule.

**This is the framework's one deliberate cut**, and it is recorded as a decision rather
than left as an open question that looks like it merely needs more time.

---

## What this changes about the framework

1. **The prerequisite is smaller than it looked.** Six of the twelve dependent rules need
   only **layer 1**, which is a log. The framework was treating "opponent-knowledge
   model" as one large undesigned blocker; most of the dependent rules clear on the
   cheapest layer.
2. **RULE-05-23 is All-tier and needs only layer 1.** Good — the charter's tiering rule
   says a self-protection rule sits at All when omitting it makes the opponent look
   broken. It would have been incoherent to require the deepest machinery for the
   shallowest tier.
3. **Layer 3 is cut.** Reclassifying two rules left it serving one rule that cannot be
   served honestly, so that rule is dropped instead. **The framework now has no undesigned
   dependency** — everything remaining is either specified or is explicitly a gap in the
   *game*.

---

## Open questions

| # | Question | What would settle it |
|---|---|---|
| **OM-1** | ~~Is the layer-2 upper bound too pessimistic?~~ **RESOLVED.** The bound is fine; the **response threshold** was the problem. **Layer 2 informs long-horizon decisions only** — counter-intelligence priority, character routing, where to spend espionage. **It never triggers an immediate costly action.** Those stay on **layer-1 confirmed events**: an enemy fleet actually observed in the HQ's sector relocates the HQ; a pessimistic estimate that they *might* know does not. That separation removes the twitchiness without weakening the estimate *(Doof, on review)* | Closed |
| **OM-2** | ~~Does layer 3 have a defensible design?~~ **RESOLVED — cut.** Two of its three dependants were misclassified and do not need it; the third (RULE-02-13) cannot be served without cheating and is dropped from Hard *(Doof, on review)* | Closed |
| **OM-3** | Should layer 1 be shared with the player-facing UI? A human player has no "who has been watching me" summary either | Product decision. Note the parallel with `ConstructionTask.Destination` — another case where the data exists and no one surfaces it |
| **OM-4** | Does `IntelManager` expose enough to run layer 2 without new plumbing? | Audit `intel_manager.gd` `Capture()` / `CategoryOf()` against the reverse direction |

---

## Review

- [ ] Doof
- [ ] R2D2
