# 02 — Rule Corpus

| | |
|---|---|
| **Status** | REVIEWED — R2D2 (room #174/#178); label and count corrections applied |
| **Authors** | Doof (assembly), Han (parser verification) |
| **Source** | All 12 ch01–ch12 analysis files; 180 rule records |
| **Note** | Full rule text lives in the source analysis files. This document is a navigational index. Links are by rule ID. |

---

## How to read this table

**Loop sections:** economy · fleet · missions · diplomacy · combat · victory · meta  
**Sort order within each section:** Tier (All → Easy → Medium → Hard), then Rule ID.  
**Code labels:** five categories established in 00-charter.md §"What is actually broken":
- `NOT IMPLEMENTED` — genuinely absent from the game
- `IMPLEMENTED AND UNREACHABLE BY AI` — engine supports it; AI driver never calls it
- `IMPLEMENTED BUT MISORDERED` — AI does it, at the wrong priority
- `NOT SURFACED` — modelled in data, never exposed in UI
- `PARTIALLY IMPLEMENTED` — partially covered by existing code
- `CONFIRMED` — correctly implemented and reachable

---

## Economy loop (31 rules)

| Rule ID | Class | Tier | Code label | Brief trigger |
|---|---|---|---|---|
| RULE-03-01 | DO | All | NOT IMPLEMENTED | game start; sector where AI controls a system but has no CY in that sector |
| RULE-03-02 | DO | All | NOT IMPLEMENTED | AI acquires control of first planet in a sector with no AI-controlled CY |
| RULE-03-03 | DO | All | NOT IMPLEMENTED | any construction yard is idle (no build queued) |
| RULE-03-05 | DO | All | NOT IMPLEMENTED | mines_count != refineries_count (galaxy-wide totals) |
| RULE-03-06 | DO | All | NOT IMPLEMENTED | raw_materials_unrefined > threshold |
| RULE-03-07 | DO | All | NOT IMPLEMENTED | game start, days_elapsed < 100 |
| RULE-03-10 | DO | All | NOT IMPLEMENTED | sector has no AI-controlled training center |
| RULE-03-14 | DO | All | PARTIALLY IMPLEMENTED | game start |
| RULE-05-16 | DO | All | NOT IMPLEMENTED | an uprising begins, on either side's system |
| RULE-07-01 | DO | All | NOT IMPLEMENTED | AI controls fewer systems than opponent OR AI production rate is lower |
| RULE-09-09 | DO | All | NOT IMPLEMENTED | opening |
| RULE-11-08 | DO | All | NOT IMPLEMENTED | playing Empire, opening |
| RULE-02-08 | DO | Medium | NOT IMPLEMENTED | choosing which neutral or uninhabited system to pursue |
| RULE-02-14 | DO | Medium | NOT IMPLEMENTED | considering any expansion target |
| RULE-03-04 | DO | Medium | NOT IMPLEMENTED | AI needs to build a facility for sector X and has CYs in multiple sectors |
| RULE-03-11 | DO | Medium | NOT IMPLEMENTED | AI is deciding which planet to receive a new facility |
| RULE-03-13 | DO | Medium | NOT IMPLEMENTED | advanced version of a standard production facility becomes available (R&D) |
| RULE-03-15 | DEFEND | Medium | NOT IMPLEMENTED | player captures one of the AI's systems |
| RULE-05-11 | DO | Medium | IMPLEMENTED AND UNREACHABLE BY AI | the AI recruits a character with research skill |
| RULE-07-02 | DO | Medium | NOT IMPLEMENTED | AI is selecting which neutral or uninhabited system to target next |
| RULE-07-12 | DO | Medium | NOT IMPLEMENTED | AI encounters an uninhabited system to evaluate for colonisation |
| RULE-08-14 | DO | Medium | NOT IMPLEMENTED | AI is building planetary defenses |
| RULE-09-07 | DO | Medium | NOT IMPLEMENTED | an uninhabited system is available |
| RULE-10-10 | DO | Medium | NOT IMPLEMENTED | playing Empire; a Rim sector is secured |
| RULE-11-11 | DO | Medium | NOT IMPLEMENTED | opening, fast game |
| RULE-11-12 | DO | Medium | NOT IMPLEMENTED | CY, shipyard and training coverage is satisfactory |
| RULE-11-13 | DO | Medium | NOT IMPLEMENTED | playing Alliance; a research-capable character is free |
| RULE-03-12 | DO | Hard | NOT IMPLEMENTED | sector has 3+ CYs AND a system holds only 1 CY AND a better use exists for that slot |
| RULE-03-16 | DO | Hard | NOT IMPLEMENTED | AI has stable infrastructure in core sectors AND outer-rim uninhabited systems exist |
| RULE-10-02 | DEFEND | Hard | NOT IMPLEMENTED | playing Empire; Death Star construction under way in a Rim sector |
| RULE-10-18 | DEFEND | Hard | NOT SURFACED | playing Alliance; construction output is being shipped to the HQ system |

---

## Fleet loop (41 rules)

| Rule ID | Class | Tier | Code label | Brief trigger |
|---|---|---|---|---|
| RULE-01-05 | DO | All | NOT IMPLEMENTED | playing Empire; a system is Rebel-controlled |
| RULE-02-06 | DO | All | NOT IMPLEMENTED | an exploratory fleet exists and the galaxy is not fully surveyed |
| RULE-02-09 | DO | All | NOT IMPLEMENTED | an uninhabited system is found and judged worth holding |
| RULE-02-11 | DO | All | NOT IMPLEMENTED | game start |
| RULE-03-08 | DO | All | NOT IMPLEMENTED | sector has no AI-controlled shipyard |
| RULE-03-09 | DO | All | PARTIALLY IMPLEMENTED | any shipyard is idle AND maintenance allows cheapest buildable ship |
| RULE-03-18 | DO | All | NOT IMPLEMENTED | a sector the AI controls has no fleet |
| RULE-04-01 | DO | All | NOT IMPLEMENTED | more than half of AI-controlled systems in a sector have no shipyard |
| RULE-04-02 | DO | All | PARTIALLY IMPLEMENTED | any shipyard is idle |
| RULE-04-03 | DO | All | NOT IMPLEMENTED | any AI-controlled system in sector has no fighter squadron groups |
| RULE-04-05 | DO | All | NOT IMPLEMENTED | all shipyards in a sector are building capital ships |
| RULE-04-06 | DO | All | NOT IMPLEMENTED | Alliance: new game start OR first exploratory fleet being assembled |
| RULE-04-07 | DO | All | NOT IMPLEMENTED | Empire: new game start OR first exploratory fleet being assembled |
| RULE-04-09 | DO | All | NOT IMPLEMENTED | Alliance HQ system is under threat (enemy fleet in orbit or approaching) |
| RULE-04-10 | DO | All | PARTIALLY IMPLEMENTED | AI has idle fleet not assigned as protective |
| RULE-04-12 | DO | All | PARTIALLY IMPLEMENTED | Empire: Coruscant has no capital ship in orbit |
| RULE-04-21 | DO | All | NOT IMPLEMENTED | Alliance AI is weighing risk to HQ against risk to characters or other systems |
| RULE-07-09 | DO | All | NOT IMPLEMENTED | AI is assembling or dispatching a fleet to an unexplored sector |
| RULE-07-11 | DO | All | NOT IMPLEMENTED | Alliance: game start |
| RULE-07-15 | DO | All | NOT IMPLEMENTED | Empire AI at game start |
| RULE-10-14 | DO | All | NOT IMPLEMENTED | taking an Alliance system |
| RULE-11-10 | DO | All | NOT IMPLEMENTED | playing Empire, opening |
| RULE-01-06 | DO | Medium | NOT IMPLEMENTED | playing Alliance; local force ratio favours the Alliance |
| RULE-02-07 | DO | Medium | NOT IMPLEMENTED | galaxy fully surveyed once |
| RULE-03-17 | DO | Medium | NOT IMPLEMENTED | AI has at least 1 shipyard in every sector it controls |
| RULE-04-04 | DO | Medium | NOT IMPLEMENTED | AI queues a new ship for construction |
| RULE-04-08 | DO | Medium | NOT IMPLEMENTED | AI acquires 3+ systems in a new sector simultaneously |
| RULE-04-13 | DO | Medium | NOT IMPLEMENTED | Empire: assembling or sending a battle fleet against an Alliance system |
| RULE-04-14 | DO | Medium | NOT IMPLEMENTED | Empire: Interdictor-class cruiser becomes buildable |
| RULE-04-15 | DEFEND | Medium | NOT IMPLEMENTED | player (Alliance) has small fleet; AI (Empire) is sending a large armada |
| RULE-04-17 | DO | Medium | NOT IMPLEMENTED | new fighter type becomes available |
| RULE-06-10 | DO | Medium | NOT IMPLEMENTED | planning an invasion of a neutral or enemy system |
| RULE-07-10 | DO | Medium | NOT IMPLEMENTED | large fleet arrives in a sector with multiple unexplored systems |
| RULE-08-02 | DO | Medium | NOT IMPLEMENTED | Empire AI is considering a blockade or attack on an Alliance system |
| RULE-08-07 | DO | Medium | NOT IMPLEMENTED | Empire AI is preparing a planetary assault |
| RULE-08-08 | DO | Medium | NOT IMPLEMENTED | ships in an active fleet have sustained hull or shield damage |
| RULE-01-07 | DO | Hard | NOT IMPLEMENTED | either faction; always |
| RULE-04-16 | DEFEND | Hard | NOT IMPLEMENTED | player (Alliance) consistently retreats from combat |
| RULE-04-18 | DO | Hard | NOT IMPLEMENTED | newer ship design makes existing ship class obsolete |
| RULE-09-01 | DEFEND | Hard | NOT IMPLEMENTED | playing Empire; large Alliance fleet blockading in a Core sector far from Coruscant |
| RULE-10-11 | DO | Hard | NOT IMPLEMENTED | a Death Star is active |

---

## Missions loop (45 rules)

| Rule ID | Class | Tier | Code label | Brief trigger |
|---|---|---|---|---|
| RULE-02-01 | DO | All | NOT IMPLEMENTED | always |
| RULE-02-02 | DO | All | NOT IMPLEMENTED | evaluating what is known about a system |
| RULE-05-04 | DO | All | NOT IMPLEMENTED | a major character is idle on a friendly system |
| RULE-05-05 | DO | All | NOT IMPLEMENTED | the AI wants reconnaissance |
| RULE-05-23 | DEFEND | All | NOT IMPLEMENTED | playing Alliance; game start |
| RULE-07-08 | DO | All | PARTIALLY IMPLEMENTED | any AI-controlled system enters uprising state |
| RULE-09-08 | DO | All | NOT IMPLEMENTED | playing Alliance, game start |
| RULE-10-06 | DO | All | NOT IMPLEMENTED | a sabotage campaign against a system is under way |
| RULE-10-15 | DO | All | NOT IMPLEMENTED | assigning an espionage mission |
| RULE-11-07 | DO | All | NOT IMPLEMENTED | opening phase |
| RULE-11-09 | DO | All | NOT IMPLEMENTED | game start |
| RULE-05-06 | DEFEND | Medium | NOT IMPLEMENTED | the AI holds a high-value system |
| RULE-05-07 | DEFEND | Medium | NOT IMPLEMENTED | a character is idle and a held system or fleet is valuable |
| RULE-05-09 | DO | Medium | NOT IMPLEMENTED | selecting a sabotage target |
| RULE-05-12 | DO | Medium | NOT IMPLEMENTED | deciding where to station a character |
| RULE-05-13 | DO | Medium | NOT IMPLEMENTED | planning character movement |
| RULE-05-15 | DO | Medium | NOT IMPLEMENTED | considering inciting an uprising |
| RULE-05-17 | DEFEND | Medium | NOT IMPLEMENTED | playing Alliance against an Imperial opponent with assassination capability |
| RULE-05-22 | DO | Medium | NOT IMPLEMENTED | an enemy victory-condition character is located on a blockadeable system |
| RULE-07-06 | DO | Medium | PARTIALLY IMPLEMENTED | enemy-held system has troop_count < 6 AND local_loyalty > 50% for AI |
| RULE-07-07 | DEFEND | Medium | NOT IMPLEMENTED | AI garrison on a controlled system falls below 6 troops |
| RULE-08-03 | DO | Medium | NOT IMPLEMENTED | Empire AI has target identified and espionage data showing fighters present |
| RULE-09-02 | DEFEND | Medium | NOT IMPLEMENTED | playing Empire; a held system has low support and a small garrison |
| RULE-09-10 | DO | Medium | NOT IMPLEMENTED | any character, Special Forces unit or Longprobe is idle |
| RULE-09-11 | DO | Medium | NOT IMPLEMENTED | building or stationing Special Forces |
| RULE-09-12 | DEFEND | Medium | NOT IMPLEMENTED | playing Empire; assigning Palpatine or Vader to a mission on lightly held system |
| RULE-10-04 | DO | Medium | NOT IMPLEMENTED | playing Empire; a Core neutral converts to the Alliance |
| RULE-10-05 | DO | Medium | NOT IMPLEMENTED | choosing a sabotage target |
| RULE-10-07 | DO | Medium | NOT IMPLEMENTED | an enemy character is located and targetable |
| RULE-10-08 | DO | Medium | NOT IMPLEMENTED | a victory-condition character is located on a system the AI intends to take |
| RULE-10-16 | DO | Medium | NOT IMPLEMENTED | the AI is blockading a system |
| RULE-11-05 | DEFEND | Medium | NOT IMPLEMENTED | a character is not assigned to a fleet, and a held system has heavy production |
| RULE-11-06 | DO | Medium | NOT IMPLEMENTED | a character or fleet has no active task at its current location |
| RULE-02-12 | DO | Hard | NOT IMPLEMENTED | playing Alliance |
| RULE-05-03 | DO | Hard | NOT IMPLEMENTED | choosing who runs a mission |
| RULE-05-08 | DO | Hard | IMPLEMENTED AND UNREACHABLE BY AI | choosing sabotage target on system the AI may later want to capture |
| RULE-05-10 | DO | Hard | IMPLEMENTED AND UNREACHABLE BY AI | a difficult mission is being launched against a well-defended system |
| RULE-05-14 | DO | Hard | NOT IMPLEMENTED | playing either side with a Force-capable trainer available |
| RULE-05-18 | DEFEND | Hard | IMPLEMENTED AND UNREACHABLE BY AI | a victory-condition character is stationed on a system where enemy has intel |
| RULE-06-11 | DO | Hard | NOT IMPLEMENTED | an enemy system with popular opinion favouring the AI's side |
| RULE-06-12 | DO | Hard | NOT IMPLEMENTED | an uprising is running on an enemy system |
| RULE-06-13 | DEFEND | Hard | NOT IMPLEMENTED | an uprising starts on an AI-held system |
| RULE-09-03 | DO | Hard | NOT IMPLEMENTED | a battle resolves at any system, won or lost |
| RULE-10-09 | DO | Hard | NOT IMPLEMENTED | playing Empire, mid-game, holding the initiative over weak Alliance Core systems |
| RULE-11-03 | DO | Hard | NOT IMPLEMENTED | playing Alliance; Mon Mothma or Luke is idle |

---

## Diplomacy loop (16 rules)

| Rule ID | Class | Tier | Code label | Brief trigger |
|---|---|---|---|---|
| RULE-01-08 | DO | All | PARTIALLY IMPLEMENTED | either faction; a system is allied to neither side |
| RULE-06-01 | DO | All | PARTIALLY IMPLEMENTED | a neutral system is a candidate for acquisition |
| RULE-06-02 | DO | All | NOT IMPLEMENTED | always |
| RULE-06-04 | DO | All | NOT IMPLEMENTED | a system changes to the AI's control |
| RULE-06-08 | DO | All | IMPLEMENTED BUT MISORDERED | a held system is in revolt |
| RULE-06-09 | DO | All | NOT IMPLEMENTED | any AI-held system enters revolt |
| RULE-07-05 | DO | All | PARTIALLY IMPLEMENTED | AI is deciding how to acquire a neutral system |
| RULE-07-13 | DO | All | PARTIALLY IMPLEMENTED | Empire: any character with diplomatic skill is AwaitingOrders |
| RULE-02-10 | DO | Medium | NOT IMPLEMENTED | the AI takes its first system in a new sector |
| RULE-06-03 | DO | Medium | NOT IMPLEMENTED | a held system's support is below target |
| RULE-06-06 | DO | Medium | NOT IMPLEMENTED | ranking neutral systems |
| RULE-06-07 | DO | Medium | NOT IMPLEMENTED | entering or taking a first system in a new sector |
| RULE-06-14 | DO | Medium | PARTIALLY IMPLEMENTED | choosing between diplomatic and military acquisition (civilian bombardment penalty confirmed; generic force unverified) |
| RULE-07-14 | DO | Medium | NOT IMPLEMENTED | AI captures a system by force AND loyalty to AI side is low |
| RULE-10-03 | DEFEND | Medium | NOT IMPLEMENTED | playing Empire; holding systems whose support is below the threshold |
| RULE-06-05 | DO | Hard | IMPLEMENTED AND UNREACHABLE BY AI | committing diplomatic effort to a target |

---

## Combat loop (16 rules)

| Rule ID | Class | Tier | Code label | Brief trigger |
|---|---|---|---|---|
| RULE-04-11 | DO | All | PARTIALLY IMPLEMENTED | AI is about to execute a planetary assault |
| RULE-04-19 | DO | All | NOT IMPLEMENTED | Alliance: assembling a battle fleet |
| RULE-04-20 | DO | All | PARTIALLY IMPLEMENTED | AI has just taken control of a planet |
| RULE-07-03 | DO | All | PARTIALLY IMPLEMENTED | AI is about to invade a system, OR has just captured one |
| RULE-08-01 | DO | All | NOT IMPLEMENTED | any fleet engagement is about to begin |
| RULE-08-04 | DO | All | NOT IMPLEMENTED | Alliance in tactical ship-to-ship combat |
| RULE-08-05 | DO | All | NOT IMPLEMENTED | capital ships in tactical combat |
| RULE-08-09 | DO | All | PARTIALLY IMPLEMENTED | AI is preparing to assault a system (gate respected; proactive shield-clearing absent) |
| RULE-08-10 | DO | All | IMPLEMENTED AND UNREACHABLE BY AI | AI is conducting planetary bombardment |
| RULE-08-13 | DO | All | NOT IMPLEMENTED | AI is planning how many troops to send in an invasion |
| RULE-07-04 | DO | Medium | NOT IMPLEMENTED | AI is selecting the next enemy system to attack |
| RULE-08-06 | DO | Medium | NOT IMPLEMENTED | one of the AI's capital ships has lost shielding during battle |
| RULE-08-11 | DO | Medium | NOT IMPLEMENTED | AI has bombarded a system and it is not yet viable for assault |
| RULE-08-12 | DO | Medium | NOT IMPLEMENTED | AI is composing an invasion force |
| RULE-08-15 | DO | Hard | NOT IMPLEMENTED | Empire AI faces a system with 2+ GenCore shields and no viable assault path |
| RULE-08-16 | DEFEND | Hard | NOT IMPLEMENTED | player controls their fleet manually in a tactical battle |

---

## Victory loop (22 rules)

| Rule ID | Class | Tier | Code label | Brief trigger |
|---|---|---|---|---|
| RULE-01-01 | DO | All | NOT IMPLEMENTED | always |
| RULE-01-02 | DO | All | NOT IMPLEMENTED | playing Empire, Rebel HQ location unknown |
| RULE-01-03 | DO | All | NOT IMPLEMENTED | HQ-Only Victory option is on |
| RULE-02-05 | DO | All | NOT IMPLEMENTED | playing Empire |
| RULE-05-01 | DO | All | IMPLEMENTED AND UNREACHABLE BY AI | playing either side; a target victory character's location is known |
| RULE-09-13 | DO | All | NOT IMPLEMENTED | playing Alliance; sufficient fleet strength |
| RULE-11-14 | DO | All | NOT IMPLEMENTED | playing Empire; Rebel HQ unlocated |
| RULE-05-02 | DO | Medium | IMPLEMENTED AND UNREACHABLE BY AI | the AI captures a victory-condition character |
| RULE-05-19 | DO | Medium | IMPLEMENTED AND UNREACHABLE BY AI | one of the AI's victory-condition characters is captured |
| RULE-05-21 | DEFEND | Medium | NOT IMPLEMENTED | playing Empire; Death Star construction begins |
| RULE-09-04 | DO | Medium | NOT IMPLEMENTED | playing Alliance; an Imperial fleet is observed in the HQ's sector |
| RULE-09-05 | DO | Medium | NOT IMPLEMENTED | playing Alliance; choosing or developing an HQ system |
| RULE-09-14 | DO | Medium | NOT IMPLEMENTED | playing Alliance; hunting Palpatine or Vader |
| RULE-10-13 | DO | Medium | NOT IMPLEMENTED | playing Empire; the AI's approach to the HQ becomes apparent |
| RULE-02-04 | DO | Hard | NOT IMPLEMENTED | playing Alliance; evidence suggests the HQ system is known to the Empire |
| RULE-05-20 | DO | Hard | IMPLEMENTED AND UNREACHABLE BY AI | playing Alliance; a Death Star under construction is located |
| RULE-10-01 | DO | Hard | NOT SURFACED | playing Empire; an espionage mission on an Alliance system succeeds |
| RULE-10-12 | DO | Hard | NOT IMPLEMENTED | playing Empire; endgame, HQ located or locatable |
| RULE-11-01 | DO | Hard | NOT IMPLEMENTED | playing Alliance; several held systems in one Rim sector; no threat required |
| RULE-11-02 | DO | Hard | NOT IMPLEMENTED | playing Alliance, mid-game |
| RULE-11-04 | DEFEND | Hard | NOT IMPLEMENTED | playing Empire; the search for Mon Mothma / Luke is not converging |
| RULE-11-15 | DEFEND | Hard | NOT IMPLEMENTED | playing Empire; victory-condition characters unlocated for sustained period |

---

## Meta loop (9 rules)

| Rule ID | Class | Tier | Code label | Brief trigger |
|---|---|---|---|---|
| RULE-01-04 | DO | All | NOT IMPLEMENTED | game setup |
| RULE-02-03 | DO | All | NOT IMPLEMENTED | game start |
| RULE-09-15 | DO | All | NOT IMPLEMENTED | always |
| RULE-10-17 | DO | All | NOT IMPLEMENTED | playing Empire, always |
| RULE-12-01 | DO | All | CONFIRMED | any AI decision that prices a ship's upkeep |
| RULE-12-02 | DO | All | CONFIRMED | implementing any rule that names a facility |
| RULE-09-06 | DO | Medium | NOT IMPLEMENTED | playing Alliance, opening/mid |
| RULE-01-09 | DEFEND | Hard | NOT IMPLEMENTED | playing Empire against a human Alliance |
| RULE-02-13 | DEFEND | Hard | NOT IMPLEMENTED | always |

---

## Summary counts

| Loop | DO | DEFEND | Total |
|---|---|---|---|
| Economy | 28 | 3 | 31 |
| Fleet | 38 | 3 | 41 |
| Missions | 35 | 10 | 45 |
| Diplomacy | 15 | 1 | 16 |
| Combat | 15 | 1 | 16 |
| Victory | 19 | 3 | 22 |
| Meta | 7 | 2 | 9 |
| **Total** | **157** | **23** | **180** |

| Tier | Count |
|---|---|
| All | 76 |
| Easy | 0 |
| Medium | 70 |
| Hard | 34 |

| Code label | Count |
|---|---|
| NOT IMPLEMENTED | 149 |
| IMPLEMENTED AND UNREACHABLE BY AI | 10 |
| IMPLEMENTED BUT MISORDERED | 1 |
| NOT SURFACED | 2 |
| PARTIALLY IMPLEMENTED | 16 |
| CONFIRMED | 2 |
