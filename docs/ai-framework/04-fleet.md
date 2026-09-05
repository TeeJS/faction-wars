# 04 — Fleet Loop Policy

| | |
|---|---|
| **Status** | REVIEWED — Han (room #170); open question answered |
| **Authors** | Doof (draft) |
| **Inputs** | `02-rule-corpus.md`; `manual/strategy-guide/analysis/ch04-building-fleets.md`; `manual/strategy-guide/analysis/ch07-acquiring-new-systems.md` |
| **Scope** | Policy argument for the fleet loop. Rule text lives in `02-rule-corpus.md`. This document argues how the rules fit together, what conflicts exist, and what the loop is trying to achieve. |

---

## What the fleet loop is for

The fleet loop converts economy output — ships built — into military outcomes: exploration, protection, conquest, and denial. Without the fleet loop functioning, every other loop stalls. Espionage missions require ships to carry agents. Assaults require troop transports and orbital fire support. HQ defense requires ships already in place. The diplomacy loop needs fleets to garrison newly won systems before they revolt.

The fleet loop is also the loop where the two factions diverge most sharply in doctrine. The economy loop's rules are largely symmetric between Empire and Alliance. The fleet loop is not. The guide is explicit that the factions have fundamentally different fleet compositions, different roles for the same ship classes, and different answers to the same strategic questions. An AI that treats fleet management identically for both sides is making a design error, not just a balance error.

---

## Five fleet roles exist; zero are distinct in code

The guide names five fleet roles (ch04 L2073–2078): explore, protect, transport, blockade, and battle. RULE-04-01 through RULE-04-10 collectively describe what each role requires in terms of composition, target priority, and success condition. They are not interchangeable. An exploration fleet needs a diplomat and troops but not firepower. A battle fleet needs capital ships and fighter support but not diplomats. A transport fleet needs capacity, not weapons.

AiManager currently treats all fleets identically. When a threat is detected, the nearest idle fleet is sent to it, regardless of what that fleet is carrying or what role it was assembled for. This is not just a priority problem — it is a role problem. The AI's exploration fleet, which contains a diplomat and two troop units, is the same object as its battle fleet, which should contain capital ships and fighter squadrons. When the exploration fleet gets sent to respond to a combat threat, it accomplishes nothing; when the battle fleet gets sent to explore an uninhabited system, the diplomat seat it lacks is not noticed until the system cannot be diplomatically secured.

The fleet loop's primary design task is making these five roles real. This does not require five separate fleet objects in the code — it requires a fleet role enum and a composition check at queue time (RULE-04-04): when a ship is built, the AI decides which fleet role it will fill before the ship leaves the shipyard. The current code builds ships without destinations.

---

## Faction doctrine diverges at every level

### Empire

The Empire's fleet doctrine is built around the Imperial Star Destroyer. The ISD is simultaneously the best exploration ship (carry troops, diplomat, commandos, and leadership characters), the backbone of the battle fleet, and the anchor of Coruscant's permanent garrison (RULE-04-07, RULE-04-12). This multi-role capacity is a design asset, not a flaw — the guide explicitly says "keep this fleet, and convert your other Star Destroyers into exploratory fleets" (ch04 L2205–2208), meaning the ISD fleet structure does not change as the game progresses; supplementary fleets are upgraded around it.

Empire battle fleet doctrine has a phase structure of its own. In the opening and mid-game, before the Interdictor-class cruiser is researched, the Empire keeps battle fleets deliberately small (RULE-04-13). A large armada sent against a small Alliance force will cause the Alliance to retreat to hyperspace — an expensive waste of ships that accomplished nothing. The counter is not more ships; it is smaller attack groups aimed at multiple targets simultaneously, narrowing the number of retreat vectors (RULE-04-15).

Once the Interdictor is researched, this constraint lifts entirely. The Interdictor's gravity wells prevent hyperspace escape, which changes the fundamental dynamics of every engagement. RULE-04-14 states the doctrine change explicitly: add at least one Interdictor to every battle fleet. At that point, fleet size matters again — go as large as possible, because the Alliance can no longer choose to avoid the fight.

This makes the Interdictor a doctrine switch, not just a ship. It is the clearest before/after event in the fleet loop. The data supports it: `data/military_units.json` has a `GravityWell` field on the Interdictor. BuildWarships() currently picks ships by maintenance cost, which means it will never prioritise the Interdictor even after R&D unlocks it. RULE-04-14 and RULE-04-16 are IMPLEMENTED AND UNREACHABLE BY AI — the data infrastructure exists, the build logic does not use it.

The permanent garrison at Coruscant (RULE-04-12) is a standing constraint on Empire fleet allocation. At least one capital ship is always assigned there. This is not a reactive rule — it is a pre-commitment that reduces the pool of ships available for battle and exploration. The current code responds to threats via MoveFleets() but does not maintain a permanent garrison assignment. The distinction matters: a reactive response might send the Coruscant ship elsewhere when a threat is detected elsewhere, which is exactly the wrong outcome.

### Alliance

The Alliance fleet doctrine is built around the fighter advantage. Alliance fighters are superior to TIE fighters in every operationally relevant way until the TIE Defender (data confirmed: X-wing LaserRating 8, Shield 5, Hyperdrive 60 vs TIE Fighter LaserRating 5, Shield 0, Hyperdrive 0). This advantage is not incidental — it is the Alliance's primary source of combat power, because the Alliance cannot match the Empire in capital ship tonnage.

The operational consequence is the escort carrier. RULE-04-19 says Alliance battle fleets should prioritise escort carriers over capital ships. Fighters that can project from a carrier can be superior to TIE fighters that cannot leave their mothership. The Alliance builds carriers to carry its best asset. The current code builds ships by cost and hull type without faction branching.

The fighter advantage does not last. The TIE Defender (ResearchOrder=8) is the first Imperial fighter with shields and hyperdrive, and it matches or exceeds Alliance fighters on raw stats. Before that research threshold, the Alliance should be exploiting the advantage aggressively. After it, the combat calculus changes. Neither the advantage nor its expiration is tracked by any current code.

HQ protection for the Alliance is a strategic problem, not just a garrison problem. RULE-04-09 and RULE-04-21 together establish the Alliance doctrine: move the HQ rather than defend it in place. The guide puts the expected window before discovery at 500 days (ch04 L2290–2291). The key asymmetry RULE-04-21 names is irreversibility — a captured character can be rescued, a lost HQ cannot. This asymmetry means the AI should accept a loyalty penalty from relocation before accepting any measurable risk of HQ capture. The AI currently has no HQ-move logic at all.

---

## Blockade is the most underrepresented capability

Blockade appears in three distinct strategic contexts across the corpus:

**Economic denial.** A blockaded system cannot export raw materials, cannot receive ships, and cannot launch missions. Blockading a system with multiple mines or a key shipyard damages the opponent's economy without requiring ground assault.

**Abduction setup.** A blockade prevents a target character from moving off a system before an abduction mission arrives. Without blockade, a well-placed character with a fast ship can simply leave before the mission team arrives. RULE-05-22 describes this combination: locate the enemy victory-condition character, blockade the system, then launch the abduction mission.

**Character pinning.** A specific finding from the corpus (RULE-05-22): blockade to pin a character before striking at them. This is the same mechanism as abduction setup, applied to any high-value target.

All three of these use cases are blocked by the same gap: the AI never initiates a blockade. AiManager reads `BlockadeManager.BlockaderOf()` — the query side of the blockade system — but never calls the initiation side. This is a single code path that unlocks three categories of strategic play. BlockadeManager's interface needs to be read to confirm whether an initiation method is exposed; the analysis has not verified this (open question below).

The consequence of this gap is not just that the AI misses one tactical option. It means the AI cannot close the kill chain that leads to its primary victory condition. Both the Empire's victory condition (capturing Luke Skywalker or Mon Mothma) and the Alliance's victory condition (capturing Palpatine or Vader) are achieved via abduction, which is most reliably set up via blockade. An AI that cannot blockade is an AI that cannot reliably pursue its own victory.

---

## Fleet-size calibration is a defend rule, not just a do rule

RULE-04-15 and RULE-04-16 are the fleet loop's most explicit DO/DEFEND pair. RULE-04-15 (Medium) says the Empire AI must detect when its own fleet will cause the Alliance player to retreat rather than fight and respond by splitting into smaller attack groups. RULE-04-16 (Hard) says if the retreat pattern persists, build Interdictors and attack on multiple fronts simultaneously.

These rules are structurally different from most DO rules. They are not triggered by the AI's own state — they are triggered by the opponent's behaviour. The AI needs to observe that the player is retreating from fleet engagements rather than fighting, and draw a tactical conclusion from that observation: the fleet is too large to force a fight.

The current code has no retreat-avoidance logic. MoveFleets() sends the nearest fleet to the nearest threat, regardless of the size ratio between the AI's fleet and the enemy's. An Empire AI that assembles a fleet large enough to destroy anything the Alliance can field will watch the Alliance player escape every time, gaining nothing from the military investment, until the Interdictor becomes available. This is one of the more visible ways the current AI fails to look like a competent opponent — it masses force that accomplishes nothing.

The detection question is what makes these rules Medium and Hard rather than All. Detecting that a single retreat happened is easy. Detecting that retreating is the player's consistent pattern across multiple engagements, and that this pattern is a response to the AI's fleet size rather than a coincidence, requires multi-turn observation. This is the inference cost the tier assignment reflects.

---

## HQ protection creates a priority conflict with fleet assignment

RULE-04-10 establishes the protective fleet priority order: HQ first, multi-shipyard systems second, multi-CY systems third. RULE-04-08 establishes that transport fleets are valuable for garrisoning multiple systems at once when a new sector is acquired. Both rules require dedicated ships that are not available for battle fleets.

The conflict is allocation. Every ship assigned as a permanent Coruscant guard (Empire), an HQ escort (Alliance), or a loaded transport is a ship that cannot go into the battle fleet. The current code has no allocation layer — it treats ships as interchangeable and assigns the nearest one to whatever threat is loudest. The result is that high-priority permanent assignments (HQ guard, Coruscant) get raided whenever a closer threat appears, which means they are not truly permanent.

The fleet loop policy must establish role allocation before mission assignment, not after. The sequence should be: (1) assign ships to permanent protective roles, marking them as committed; (2) assign remaining ships to transport roles where needed; (3) from what remains, compose battle fleets. The current code does step 3 only, with no committed pool concept.

This is not a complex data structure — it is a fleet status field: Committed-Protective, Committed-Transport, Available-Battle, Available-Explore. The absence of that field is why the current code produces behaviours that look incoherent: the AI will strip its HQ guard to respond to a peripheral threat.

---

## Ship production is one ship per day from one yard

BuildWarships() picks the planet with the most shipyards and queues one ship. All other idle shipyards in the entire galaxy are ignored. This violates RULE-03-09 (all idle shipyards should produce), RULE-04-02 (all idle shipyards should produce with fighter priority), and RULE-04-05 (at least one shipyard should produce fighters if all are building capital ships).

The productive surface area of the economy is proportional to the number of active shipyards, and the current code treats all but one of them as not existing. This is the widest single gap between current implementation and intended behaviour in the fleet loop.

The fix is straightforward in structure: iterate all shipyards, not just the largest-planet one, and queue a ship at each idle yard that maintenance allows. The policy question is what to queue at each one. The fighter-priority rule (RULE-04-03, RULE-04-05) means the first shipyard in each sector should produce fighter squadrons until every system in that sector has defensive fighters. Capital ship production follows. The faction branch matters here: Alliance sectors should prioritise escort carrier + fighter combinations (RULE-04-19); Empire sectors should produce capital ships with fighter supplements.

Neither the fighter-first rule nor the faction branch is currently encoded. BuildWarships() picks by maintenance cost, which will never produce a fighter squadron under any circumstances — the current build filter explicitly passes only CapitalShip type (gap G-04-C in the ch04 analysis).

---

## The Interdictor is the fleet loop's clearest implementation-map item

The case for the Interdictor as the first targeted implementation in the fleet loop:

- The trigger is clean: R&D unlocks it. One discrete event, well-defined.
- The doctrine change is complete: before Interdictor, small fleets and retreat-avoidance; after Interdictor, large fleets and gravity-well denial.
- The data infrastructure exists: `data/military_units.json` has a `GravityWell` field.
- The rules are specific: RULE-04-14 says add one to every battle fleet; RULE-04-16 says build them as highest priority when the player is retreating.
- The code path is IMPLEMENTED AND UNREACHABLE BY AI — the field exists, BuildWarships() just does not use it.

What "unreachable by AI" means here is that the gravity well data is available for combat resolution, but the AI build logic has no path to select the Interdictor specifically. Connecting those two things requires BuildWarships() to check `GravityWell` as a selection criterion after the R&D unlock event, and fleet composition logic to track which battle fleets already contain an Interdictor. Neither exists. Both are narrow additions to existing systems, not new systems.

---

## The fighter comparison changes what the Alliance builds

The ch04 analysis confirms data from `military_units.json` that the guide states directionally but does not quantify. TIE Fighters lack shields and hyperdrive; X-wings have both. TIE Interceptors match X-wings on LaserRating (8) but still lack shields and hyperdrive — a meaningful operational disadvantage. TIE Defenders (ResearchOrder=8) are the first TIEs with shields and hyperdrive, and they have the highest LaserRating (10) of any fighter.

One finding the guide does not acknowledge: B-wings (ResearchOrder=5) beat TIE Defenders on shields (9 vs 5) and torpedoes (12 vs 10). The guide implies parity arrives with TIE Defender; the data suggests the Alliance retains an advantage in heavy fighter capability even at that point.

The operational consequence for the fleet loop: the Alliance's fighter advantage is not symmetric across the game. It is largest in the early game, narrows with TIE Interceptor (mid-game), and never fully closes on the capital-ship-killing axis (B-wing vs TIE Defender). An Alliance AI building to this advantage should prioritise escort carriers and B-wing production more heavily than the guide's prose suggests. The data supports a stronger fighter-doctrine conclusion than the text does.

This has no confirmed code implementation. Neither faction's fleet composition reflects fighter type research order, fighter stats, or the faction asymmetry in fighter capability.

---

## Open questions

**Does BlockadeManager expose an initiation method?** The analysis confirms AiManager reads `BlockadeManager.BlockaderOf()` but does not confirm whether an initiation method exists in that manager. If the initiation method is absent, blockade is NOT IMPLEMENTED in the engine sense. If it exists and the AI simply never calls it, it is IMPLEMENTED AND UNREACHABLE BY AI. The distinction matters for implementation cost: the first case requires engine work, the second requires only a new call site in AiManager.

**Budget contention (AR-4) — DECIDED.** The architecture resolution (01-architecture.md, room #149): Reactions reprioritise, they do not spend. An event may write to context and reorder what the next daily pass does; it may not consume budget itself. All spending stays in the single per-day Dispatch pass. This resolves the fleet-loop consequence cleanly: a fleet move ordered by a Reaction is queued for the next daily pass at elevated priority, never executed mid-day. The daily loop's outcome depends only on start-of-day context plus deterministic context writes — no contention, no divergence surface. AR-5 resolves with it: the context object is a per-day snapshot, because nothing acts mid-day. The falsifier: if any rule is found that genuinely requires acting between daily passes, AR-4 reopens and option A (a separate interrupt reserve) is the fallback.

**Does Alliance fighter superiority affect any combat calculation?** The data confirms the stat advantage. Whether `fleet_battle_manager.gd` actually uses `LaserRating`, `Shield`, and `Hyperdrive` in combat resolution — and whether the AI's fleet selection logic accounts for the enemy's fighter capability — has not been verified. If combat resolution uses these stats, the Alliance's early-game fighter advantage is real and the AI should be building toward it. If the stats are present but unused in combat, the guide's fighter-doctrine advice has no mechanical grounding.
