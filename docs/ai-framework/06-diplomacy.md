# 06 — Diplomacy loop: policy

| | |
|---|---|
| **Status** | REVIEWED — Han (room #172); RULE-06-14 resolved and un-flagged |
| **Authors** | Doof (draft) |
| **Inputs** | `ch06-diplomacy.md`, `ch07-acquiring-new-systems.md`; rule corpus §Diplomacy (RULE-06-01 through RULE-06-14, plus RULE-07-05, RULE-07-13, RULE-07-14) |
| **Scope** | Policy argument for the diplomacy operational loop. Rule text lives in `02-rule-corpus.md`. Code citations are read-only per charter §Scope |

---

## What the diplomacy loop is actually for

The guide is unambiguous on the economics: a diplomatically acquired system arrives with roughly 60% popular support, preserves its existing facilities intact, requires no assault force, and demands a smaller garrison than a force-taken world from day one (ch06 L3689–3695, L3880–3888). At 100% support the garrison requirement drops to zero — troops that would otherwise be pinned to peacekeeping duty can be redeployed or used for the next conquest. The guide phrases this as a mathematical fact, not a preference: diplomacy is cheaper to hold.

Force, by contrast, always costs more than its up-front price. A system taken by a thin invasion force triggers an uprising automatically (ch07 L4183–4184). Uprising doubles the garrison requirement (confirmed three sources: `data/game_rules.json` EntryId 150; manual p127; ch06 L3976–3978). While the system burns, mines stop producing, refineries go idle, and the AI loses access to the build menus (ch07 L4193–4196). And the guide states twice — in ch06 and again in ch07 — that military aggression shifts loyalty across the entire sector against the attacker (ch06 L3720–3722, ch07 L4087–4098). The diplomacy loop is the mechanism by which the AI avoids paying those costs repeatedly.

This is asymmetric by faction. The Alliance has more diplomats, higher initial loyalty on neutral systems, and a strategic culture the guide explicitly calls diplomatic-primary (ch07 L4396–4401). The Empire has fewer diplomats and an implicit preference for force that the guide treats as a liability, not an advantage: "The Empire must often put down its blasters and deal with a potential source of raw and refined materials on equal diplomatic terms" (ch06 L3679–3686). Both factions benefit from diplomacy; the Alliance is better resourced to exploit it and the Empire is structurally obligated to compensate.

---

## Diplomacy versus force is a routing decision

The current AI defaults to fleet dispatch for any acquisition target. This is not a conservative choice — it is a structural error. The guide's routing logic is clear: prefer diplomacy for neutral systems, prefer force (or force-assisted uprisings) for enemy-held systems with few troops and unfavorable garrison ratios (RULE-07-05, RULE-07-06).

These are different targets with different tools. A neutral system has no defensive garrison to fight through, preserves its facilities if taken diplomatically, and carries no uprising risk if loyalty is already near the threshold. An enemy-held system cannot be reached by diplomacy at all — the guide flatly prohibits it (ch06 L3745–3746). The correct tool for an enemy-held system with low troop count and favorable local loyalty is sabotage to depress the garrison below the uprising threshold, then an uprising mission — not a fleet (RULE-07-06).

The AI making this routing decision correctly requires knowing three things per target: is the system neutral or enemy-held? If enemy-held, what is the troop count and what is the local loyalty? The first is already accessible; the second and third are fog-of-war constrained (see Open Questions below). Where the AI cannot observe troop count, it cannot safely route to the sabotage-uprising path and should default to diplomatic or fleet options based on what it does know.

What the AI must not do is route all acquisition through fleet dispatch regardless of target type. That approach leaves the diplomacy queue empty, the bolster queue nonexistent, and the routing decision unmade.

---

## Three targets, not one

The diplomacy loop handles three distinct target types, and the AI currently recognises only one of them.

**Neutral systems** are the obvious case. RULE-06-01 and RULE-06-06 describe these: prefer diplomacy, rank by existing facilities (mines, refineries, construction yards especially), send the best diplomats to the most contested targets. This is partially implemented — `ai_manager.gd` puts `Diplomacy` first in `Preferred()` and targets neutrals — but the ranking is absent and the result is an undifferentiated list.

**Own force-captured systems with low loyalty** are not currently diplomatic targets at all. RULE-07-14 describes the obligation: when the AI takes a system by force, loyalty is low, and garrison troops are tied up holding it, a diplomat sent immediately begins raising loyalty toward the 75–80% security target. As loyalty rises, the garrison requirement falls, and those troops become available for the next operation. The guide makes the mechanism explicit (ch06 L3860–3866, L3880–3888): the relationship between loyalty and garrison is not linear — raising loyalty from 60% to 80% frees more troops than any equivalent military investment. RULE-06-04 (consolidate after acquisition) and RULE-06-02 (run both diplomatic queues) together describe this as a standing obligation, not an optional refinement. Neither is implemented.

**Enemy-held systems where loyalty already favors the AI** are diplomacy-adjacent but belong to the missions loop — inciting an uprising is a missions action, not a diplomacy action (RULE-06-11, RULE-06-12). The diplomacy loop hands off to the missions loop here. What the diplomacy loop contributes is the precondition read: does local loyalty favor the AI? That check informs both the routing decision above and the uprising targeting in missions.

The AI currently passes only neutral systems into the diplomatic target list. The own-system loyalty repair queue (RULE-07-14) is entirely absent, and the precondition read for uprising targeting is not connected to the missions loop.

---

## The Empire's diplomat scarcity is a strategic constraint

The guide states the Empire's diplomatic position in one sentence: "Make sure Imperial diplomats are always on missions to help offset the Alliance's diplomatic advantage" (ch07 L4395–4401). This is RULE-07-13, and it is not merely an efficiency suggestion — it is a standing correction for a structural disadvantage. The Empire starts with fewer diplomatic characters than the Alliance. Every idle Empire diplomat is a compounding loss.

`ai_manager.gd` puts `Diplomacy` first in `Preferred()`, which is correct, but it treats the Empire's diplomat pool the same as the Alliance's. The Alliance can afford to leave a diplomat idle occasionally; its pool is deeper and its neutral-system base loyalty is higher. The Empire cannot. A design that applies the same mission-dispatch logic to both factions ignores the constraint the guide explicitly names.

The consequence is visible in how the loop degrades under load. When the AI has multiple objectives competing for character assignments — uprisings to quell, espionage to run, military operations needing leadership characters — the Empire's limited diplomats get pulled into the general character pool and lose their diplomatic work. The Alliance can absorb this; the Empire cannot recover from it without deliberate tracking of diplomat availability as a separate resource.

---

## Two implemented rules that do not reach the AI

**RULE-06-05 (multi-agent mission teams)** is one of the cleanest examples in the corpus of the *implemented and unreachable* category. `MissionManager.Launch` accepts a `team: Array` parameter; the player path at `command_applier.gd:100` uses it; `ai_manager.gd:312` builds `team = [agent]` and always passes a single agent. The guide's concentrated-versus-spread variance decision — team on one critical target for high expected gain, several solo missions for reliability (ch06 L3788–3810) — is a Hard-tier discriminator the engine already supports. The AI driver never reaches it. Gap G-06-1 confirms: fix the driver, not the engine.

The impact on diplomacy is higher than on other loops because the spread-versus-concentrate decision is most consequential where targets are contested and time pressure is highest. A Hard-tier AI that can correctly choose to concentrate two diplomats on a contested Core system versus spreading them across two lower-value neutrals is playing a meaningfully different game than one that always sends one.

**RULE-06-08 (SubdueUprising misordering)** is the corpus's single `IMPLEMENTED BUT MISORDERED` record. `SubdueUprising` is present in `Preferred()` at `ai_manager.gd:336`; it simply runs last, after Recruitment and everything else. The guide says uprisings must be handled "immediately" and that leaving one running costs "your garrisons, the facilities, and the raw and refined materials" (ch06 L3970–3974). A static preference order cannot express urgency — urgency is a property of the situation, not the mission type. An uprising on a system the AI has just spent three rounds diplomatically raising to 75% loyalty undoes that work in days. The fix is not to move `SubdueUprising` up the static list; it is to give the uprising-response its own interrupt pass that runs before the preference list is consulted. Gap G-06-3 records this.

---

## Loyalty is running state

The AI currently treats a diplomatically acquired system as a completed task. Loyalty is not completed — it is a value that shifts continuously under military pressure, character presence, and elapsed time. The guide's diplomacy chapter describes loyalty maintenance as an ongoing loop: even a successfully converted system at 80% can erode under attack, and the guide explicitly instructs the player to "keep the mission running a few more times" after a diplomatic conversion (ch06 sidebar L3861–3882).

RULE-06-04 formalises this as a trigger on system acquisition — run follow-up missions immediately. RULE-06-03 formalises the target values — 60% is the post-conversion floor, 75–80% is the security target, 100% is the point where the garrison is fully released. Neither rule is implemented. The AI converts a system and moves on; loyalty decays; the system eventually requires garrison reinforcement or, worse, uprisings begin on territory the AI nominally controls.

The loyalty-as-running-state framing also connects the diplomacy loop to the fleet loop. RULE-06-14 records that force carries a sector-wide loyalty penalty (ch06 L3720–3722, ch07 L4087–4098), but this rule is flagged as unverified — the manual's loyalty table does not list it and `loyalty_manager.gd` has not been audited. The potential connection is significant: if the penalty is real, every fleet dispatch the Alliance AI makes has a diplomatic cost in the same sector. The two loops would not be independent. That connection cannot be designed until RULE-06-14 is either confirmed or ruled out (see Open Questions).

What can be designed now is the post-acquisition consolidation loop (RULE-06-04) and the bolster queue (RULE-06-02). These require only that the AI knows the loyalty value of systems it controls, which is not a fog-of-war question — a faction knows its own systems' loyalty.

---

## What the loop is not doing and why it matters

The rule corpus records 16 diplomacy-loop rules. Of these: one is `IMPLEMENTED BUT MISORDERED` (RULE-06-08), one is `IMPLEMENTED AND UNREACHABLE BY AI` (RULE-06-05), four are `PARTIALLY IMPLEMENTED` (RULE-01-08, RULE-06-01, RULE-07-05, RULE-07-13), and ten are `NOT IMPLEMENTED`. The two all-tier rules that are most structurally important — RULE-06-02 (two queues: convert and bolster) and RULE-06-04 (consolidate after acquisition) — are both absent, and they are the rules that make the others coherent.

Without RULE-06-02, the AI has a convert queue and no bolster queue. Without RULE-06-04, conversions are never consolidated. The rules that describe *how to run diplomacy well* (RULE-06-03, RULE-06-05, RULE-06-06, RULE-06-07) presuppose a working two-queue structure and a consolidation pass. Building those refinements before the structural rules are in place would be premature. The implementation order implied by the policy argument is: RULE-06-02 and RULE-06-04 first, then the targeting and prioritisation rules, then the Hard-tier concentration decision.

---

## Open questions

**RULE-06-14 (force carries a sector-wide support penalty) — CONFIRMED, scope narrower than guide claims.** Han's audit (room #172) found `bombardment_manager.gd:210-213`: when `CivilianLoss` fires, it reads `RuleId.OrbitalStrikeSupportShift` (game_rules.json Entry 173 = −20) and calls `p.ShiftSupport(attacker, shift)` for every `SectorPeer` of the target. Sector-wide, −20, fires automatically on civilian bombardment.

The prior citation `loyalty_manager.gd` was incorrect — that file handles character loyalty and treachery (manual p094), not planetary support. Corrected.

Do-not-build flag removed. The scope is narrower than the guide claims: the specific −20 attacker penalty applies to civilian bombardment. Assault and blockade carry their own support effects (`blockade_manager.gd:112`) but not this attacker penalty. Generic force takeover: unverified.

The cross-loop feedback point now stands confirmed. An Imperial AI that bombards civilian targets pays a diplomatic cost in sector-wide support, making the fleet and diplomacy loops coupled in at least one direction. `01-architecture.md` should record this. The richer picture: Han's audit found the full support system — blockade, civilian bombardment, diplomacy missions, uprisings, smuggling, and an internal planet.gd shifter — none of which are documented together in any current framework document. The support system is more complex than any individual rule record assumes.

**The diplomatic character pool per faction.** The guide states the Empire has fewer diplomats than the Alliance (RULE-06-10, RULE-07-13) and that every Empire diplomat must stay on mission continuously. The precise starting counts — how many characters have diplomatic skill on each side, and whether that count changes through recruitment — are not established in this corpus. The AI cannot correctly throttle its diplomat pool without knowing its size. This is a data question answerable from `data/major_characters.json`.

**Fog-of-war and enemy system loyalty.** The routing decision between diplomacy, uprising, and force requires knowing the target system's current loyalty value. For AI-controlled systems this is unambiguous. For neutral systems it is plausibly observable (neutral systems have no fog). For enemy-held systems the loyalty value may be hidden, which would limit the uprising-routing path (RULE-07-06) to systems where the AI has fresh intelligence. The fog-of-war rules for loyalty observation are not established in this corpus and are a prerequisite for implementing the routing decision correctly at Hard tier.
