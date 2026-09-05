# 05 — The missions loop

| | |
|---|---|
| **Status** | REVIEWED — Doof (room #166); count reconciled to corpus convention |
| **Author** | Han |
| **Loop** | `missions` — **45 rules** by the corpus's first-listed-loop convention, the largest in the corpus. **11 DEFEND**, also the most of any loop. One further rule, **RULE-09-01**, is cross-referenced here: its loop is `fleet + missions` and `02-rule-corpus.md` files it under Fleet |
| **Depends on** | `01-architecture.md` (action selection), `01a-opponent-model.md` (context) |

This is where the original AI is weakest and where a human beats it. It is also the loop
with the deepest gap between what the engine supports and what the AI reaches.

---

## 1. The argument: missions are an economy, not a menu

Every other loop spends **materials**. This loop spends **people**, and people behave
differently from refined ore in three ways the corpus states explicitly.

**They appreciate.** *"Each time the character is successful in a mission, his or her
skills can improve. Special Forces cannot improve, regardless of the number of successes
they have."* (RULE-05-03, Ch5 sidebar L2685–2704.) A character used well becomes a better
character. Nothing else in the game does that.

**They are irreplaceable.** *"You can replace military units, but not characters."*
(Ch5 L2934–2936.) There are **30 recruitable characters per side** and no way to make
more.

**They are the win condition.** Two of three victory conditions per side are character
captures. The opponent's characters are targets; our own are liabilities to be protected
(RULE-05-18, RULE-09-12, RULE-05-17).

So a mission assignment is never just *"can this unit perform this mission"* — which is
precisely what `MissionManager.PerformableBy()` answers and what `ai_manager.gd:314` asks.
It is four questions at once:

| Question | Rule |
|---|---|
| Will it succeed? | skill match — the corpus names the governing statistic per mission type |
| What do we stake? | RULE-05-03 — send **units, not characters**, wherever a unit will do |
| What does it grow? | RULE-05-03 — success improves the character |
| What does it expose? | RULE-05-18, RULE-09-12 — a mission puts a character somewhere the enemy may be looking |

**That is the whole argument of this document.** The rest is how it decomposes.

---

## 2. The three sub-loops

The 45 rules are not one activity. They fall into three, with different clocks and
different failure modes.

### 2a. Intelligence — the loop that feeds every other loop

Espionage and reconnaissance are not missions the AI runs *when it has nothing better to
do*. They are the **input** to everything else.

- **RULE-02-01** — intel has an age. Three refresh mechanisms only: recon mission,
  espionage mission, **a fleet blockading the system**. Everything else decays.
- **RULE-02-02** — intel is *layered*, not binary: structures may be known while
  characters, units and fighters are not.
- **RULE-05-05** — ★ **recon is Special-Forces-only.** Longprobe Y-wings and probe droids.
  *"Characters can't conduct reconnaissance missions."* A hard legality constraint, and an
  audit item: `Reconnaissance` is offered per-agent at `ai_manager.gd:336`.
- **RULE-10-16** — run espionage on systems you are **already blockading**; character
  movements are the highest-value thing those missions return.
- **RULE-09-11** — **disperse the network.** Never concentrate Bothans on one system; one
  attack should not cost the whole spy network.
- **RULE-09-10** — never park a mission unit. *"Even if you have information on every
  Imperial system in the galaxy, keep them running espionage missions."*

> **The code is better here than the guide promised.** Ch9 says a successful espionage
> mission reveals the target *"as well as another"* system. `mission_manager.gd`
> `LeakExtraSystems()` rolls a count from `EspionageRevealFloor`/`Spread` — a *higher*
> floor and spread when the target is a capital — and charts that many unexplored systems.
> The mechanic exists and **exceeds** the guide's claim.
> *(Audited by R2D2, room #150; verified independently here.)*

### 2b. Offence — the chain, not the mission

No offensive mission in this corpus stands alone. Every one of them is a **step**.

**The Alliance chain** (RULE-09-02, from Ch9 L5868–5875):
> espionage finds a system with *few troops and close to switching sides* → **infiltrators
> sabotage the garrison** → as the garrison falls, **guerrillas incite an uprising** →
> the system flips.

**RULE-05-15 supplies the mechanism** the chain runs on: *"For each military unit in place
on the system, the Rebels or Empire must influence a larger percentage of the
population."* Garrison size raises the uprising threshold. **That is why sabotage precedes
incitement** — it is not sequencing preference, it is the arithmetic.

And the mechanism is **confirmed in code**: `planet.gd` returns 0 production while
`IsInUprising`, and `UpdateGarrisonState()` flips `ControllingFaction` to Neutral when an
uprising runs with no garrison left *(R2D2, room #150)*. The chain works as documented.

**The Imperial chain** (RULE-11-07, RULE-10-06): espionage locates production →
**sabotage the construction yards first**, shipyards second → *"the first 50–100 days
should be spent getting your SpecForces into Rebel Alliance systems"* (RULE-10-05).

**The two scoring rules that make sabotage tractable:**
- **RULE-10-05** — value is **inverse to the target's redundancy**. *"Taking out a
  construction yard when the Alliance controls only two cuts their ability to produce
  facilities in half. Taking out a construction yard when the Alliance controls 10 hurts,
  but not nearly as much."*
- **RULE-05-09** — the guide states expected value outright: *"weigh the potential cost to
  you of letting your enemy succeed in building a given ship or structure to determine if
  it's worth taking the chance. If you have doubts, pick another target."*

Together they are a complete target-value function, written in the source book.

**RULE-05-08 — the sabotage dilemma, and the reason this loop needs an intent.** Sabotaging
production hampers expansion — *"however, if you plan to assault that system, destroying
these facilities prevents you from acquiring them should you conquer"* it. **The AI must
know whether it intends to take a system or attrit it before it chooses targets.** If the
intent is capture: hit starfighters, troops, batteries. If attrition: hit production,
refineries and mines *"until the system is devoid of facilities."*

### 2c. Protection — the loop's DEFEND half

Eleven DEFEND rules, more than any other loop, and under the charter's framing they are
**competence about looking after your own position**, not anti-player measures.

- **RULE-05-06** — espionage on *your own* systems is counter-intelligence: it detects
  enemy missions and lets you attempt to stop them. **The AI never targets its own systems
  with anything** (`ai_manager.gd:317`).
- **RULE-05-07** — command ranks *(admiral, general, commander)*, combined with espionage
  rating, *"improve your chances for finding and stopping enemy missions on your systems
  or against your fleets."* Every valuable system and fleet should have one.
- **RULE-07-07** — monitor your own garrisons and reinforce *before* an uprising, not
  after. The counter to 2b's chain is to break its cheapest link.
- **RULE-09-12**, **RULE-05-17**, **RULE-05-18** — protect what the enemy is hunting:
  victory-condition characters, and the **researchers and diplomats** the Empire is told to
  assassinate because *"Rebel diplomats and researchers are impossible to replace."*
- **RULE-05-23** *(All tier)* — scatter the roster on day one, because the Empire begins
  the game knowing where most Rebel characters are.

---

## 3. Where the loop meets the architecture

Missions is the loop that most needs the `01-architecture.md` shape, and it is a useful
test of it.

| Architecture stage | What missions puts there |
|---|---|
| **Context** | Intel age and layer (RULE-02-01/02); own-exposure log (RULE-05-18, 05-23) |
| **Objectives** | The bottleneck decides whether espionage is looking for *the HQ*, *a diplomat*, or *a sabotage target*. Today it looks for nothing in particular |
| **Action selection** | `CandidateAction.asset_risk` is where RULE-05-03 lives; `expected_value` is where RULE-05-09 and RULE-10-05 live |
| **Reactions** | Six of the 27 message kinds fire missions rules directly — `CharacterCaptured` → rescue, `Uprising` → RULE-06-12, `SystemControl` → RULE-10-04, `GarrisonWarning` → RULE-07-07, `MissionFailed` → exposure |

**RULE-10-04 is the loop's showcase inference.** A Core neutral flipping to the Alliance
is *evidence a diplomat is standing there* — *"the chances are good that Leia will still
be on the system"* — so blockade, run espionage, attempt abduction. One observed event,
one inference, one chain of actions. It needs the reactions stage and nothing more.

---

## 4. What the code does today

| | |
|---|---|
| **Mission types reachable** | **6 of 15.** `Preferred()` (`ai_manager.gd:334–337`) lists Diplomacy, InciteUprising, Espionage, Reconnaissance, Recruitment, SubdueUprising |
| **Unreachable** | Abduction, Assassination, Rescue, Sabotage, DeathStarSabotage, JediTraining, and all three Research types |
| **Team size** | Always 1. `ai_manager.gd:312` builds `team = [agent]` |
| **Decoys** | Never passed, though `Launch` takes them |
| **Targets** | `Neutral + TheirsWeak + TheirsStrong + Unexplored`, first match wins (`:317`, `:320`). Own systems never targeted |
| **Skill matching** | None |
| **Intel** | `IntelManager` is faithful and **never read by the AI** |

**The engine is not the problem.** `MissionManager.Launch` (`mission_manager.gd:487`)
takes `team: Array`, `decoys`, `victim` and `saboteur_target`. The AI passes four
arguments of seven and a single-element team. Most of this loop is
**IMPLEMENTED AND UNREACHABLE BY THE AI** — a wiring job, not a build.

---

## 5. The three highest-value fixes, in order

1. **Add the missing mission types to selection.** Abduction alone unblocks two-thirds of
   every victory condition. Rescue unblocks the only recovery from losing one.
2. **Let the AI target its own systems.** One change to the target list turns on
   counter-intelligence (RULE-05-06), own-system diplomacy (`06-diplomacy.md`), and
   garrison pre-emption (RULE-07-07) — three DEFEND rules at once.
3. **Read `IntelManager`.** The staleness model is built, faithful and unused. Every
   intelligence rule in §2a depends on it and none of them need it written first.

None of the three is a redesign. All three are narrow.

---

## 6. Rule index

**All (11):** RULE-02-01, RULE-02-02, RULE-05-04, RULE-05-05, RULE-05-23 *(DEFEND)*,
RULE-07-08, RULE-09-08, RULE-10-06, RULE-10-15, RULE-11-07, RULE-11-09

**Medium (22):** RULE-05-06 *(D)*, RULE-05-07 *(D)*, RULE-05-09, RULE-05-12, RULE-05-13,
RULE-05-15, RULE-05-17 *(D)*, RULE-05-22, RULE-07-06, RULE-07-07 *(D)*, RULE-08-03,
RULE-09-02 *(D)*, RULE-09-10, RULE-09-11, RULE-09-12 *(D)*, RULE-10-04, RULE-10-05,
RULE-10-07, RULE-10-08, RULE-10-16, RULE-11-05 *(D)*, RULE-11-06

**Hard (12):** RULE-02-12, RULE-05-03, RULE-05-08, RULE-05-10, RULE-05-14,
RULE-05-18 *(D)*, RULE-06-11, RULE-06-12, RULE-06-13 *(D)*, RULE-09-03, RULE-10-09,
RULE-11-03

**Cross-referenced (1):** RULE-09-01 *(DEFEND, Hard)* — loop `fleet + missions`, filed
under Fleet in `02-rule-corpus.md`. Discussed in §2b and `09-counter-exploit.md` T1
because the destabilisation play is run *with missions*; counted once, under Fleet

*Victory-loop mission rules (abduction, rescue, the kill chains) live in `08-victory.md`.*

---

## 7. Open questions

| # | Question | What would settle it |
|---|---|---|
| **M-1** | **Is `Reconnaissance` being offered to characters?** RULE-05-05 says only Longprobe Y-wings and probe droids may run it; `Preferred()` is evaluated per free *agent* | Read `MissionManager.PerformableBy()` |
| **M-2** | How does the AI decide **capture vs attrit** for a system, which RULE-05-08 requires *before* target selection? | Objectives layer — it is a bottleneck question |
| **M-3** | Do characters actually **improve on success**? If not, RULE-05-03's whole economy is absent and asset-risk scoring loses half its meaning | Audit the mission-resolution path |
| **M-4** | Is there a **prisoner model** — capture, rescue, prison hardening, prisoner-on-ship? | Audit `captivity_manager.gd` |
| **M-5** | RULE-05-07 says command ranks suppress enemy missions. Is rank modelled in mission resolution at all? | Audit `force_manager.gd` and the resolution path |

---

## Review

- [ ] Doof
- [ ] R2D2
