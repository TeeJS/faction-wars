# 14 — The built-in AI reads what it saw, never the live enemy world

Status: **built, tested, gated.** Branch `builtin-fog-legal-main` (off `main`).

This is the first deliberate change to what the built-in AI *decides* since the
framework rebuild. The soak day hashes move on purpose; the gate is re-baselined in
the same change (`tools\soak-gate.ps1`, `tests/fixtures/gate/`).

## What was wrong (the code)

`IntelManager.Knows()` / `Planet.ExploredBy()` answer "we saw this once." Eight AI
reads went on from there to the **live** world — today's owner, support, facilities,
hulls and people on a world last scouted 200 days ago. A human player only ever sees
the dated snapshot the Defense / Economy / Fleet windows render. So the AI was
playing with information the rules do not grant it.

The fix routes every one of those reads through `IntelManager.Facts()` →
`IntelFacts`: live for a world we hold, the dated sighting otherwise, nothing if
never seen.

| # | Site | Read live | Now reads |
|---|---|---|---|
| 1 | `ai_context.gd` `Build` | `ControllingFaction`, `SupportFor(owner)` → Neutral / TheirsWeak / TheirsStrong | `Facts.owner_id`, `support_for(owner)` |
| 2 | `ai_context.gd` `SeenSupportFor` | `p.SupportFor` | the sighting; −1 never seen |
| 3 | `ai_action_selection.gd` `_best_enemy_target_character` | roster + `Attached`, gated by `Knows(Characters)` on wherever they stand **today** | only a person the sighting **names** on that world (`_enemy_target_characters` + `_sighted`) |
| 4 | `_best_sabotage_target` | `p.Facilities` live; defences gated by *Production* intel | a facility only while the sighting shows one of its kind unclaimed (`_sabotage_targets` + `IntelFacts.facilities_of`) |
| 5 | `_seen_defending_ships` | today's hulls | `Facts.hostile_ships`; −1 never seen |
| 6 | `_estimate_success` | `MissionManager.SuccessPercent` over live support + live garrison | `_fog_estimate` — the same score (`MissionManager.ScoreFor`, REBEXE 0x55C680) over the sighting. A victim's own rating stays live (no sighting of it exists) |
| 7 | `ai_objectives.gd` `_rebel_hq_known` | `HasHeadquarters()` behind `ExploredBy` | the freshest sighting that shows the building on a world seen as theirs |
| 8 | `ai_objectives.gd` `_target_located` | as #3 | as #3 (`AIActionSelection._sighted`) |

`AIContext.Facts(p)` is the one way a stage reads a world that is not ours (cached
per context).

**One new category rule (OURS):** a world charted but whose status we have never seen
(an espionage leak charts a system and nothing more; a world we lost has no fresh
sighting either) now goes in `Unexplored` — owner unknown, a world to go and look at.
Before, a live-neutral one was a diplomacy target by live read and a live-enemy one
was in no list at all.

**Not changed:** `_best_rescue_target` — our own captive's location. The human
Personnel Finder shows own characters live, so this is parity, not a leak.

## Where it came from

The fog-of-war engine layer — `intel_facts.gd` and `IntelManager.Sighting` /
`Collect` / `Facts` — was written on the now-abandoned `jev-brain` branch (its
phase-1 commit). It is self-contained (no dependency on that branch's Officer/Jev
apparatus), so it is lifted here whole; the Officer brain, the Jev network client and
the assault/bombardment estimators from that branch are **not** brought over. The
`_estimate_success` fix, which on `jev-brain` delegated to an Officer file, is a
self-contained `_fog_estimate` here.

## What it did to the built-in AI (measured on `main`, before → after)

| Run | Abductions launched | Captured | Espionage | Fleet departures |
|---|---|---|---|---|
| 12345 Standard Medium 200 d | 10 → **0** | 3 → 0 | 28 → 36 | 100 → 83 |
| 777 Large Hard 300 d | 11 → **0** | 3 → 0 | 61 → 81 | 175 → 162 |

**Why abductions went to zero — probed on clean `main`** (seed 12345 Medium, 200 d):
the old gate offered 72 abduction candidate-days, and **all 72 were an enemy agent ON
A MISSION on one of OUR OWN worlds** — an undetected spy, which the Personnel tab
already refuses to show a human. Not one was a person legitimately sighted on an enemy
world. Every capture the built-in AI ever made rode on that leak. The fair route
works (`tests/ai_missions.gd`, `tests/ai_fog.gd`) but the built-in never opens it: it
sends espionage to the *nearest* enemy world, not to where leaders live.

## Gate

| | |
|---|---|
| `tools\soak-gate.ps1` | 4 soaks vs `tests/fixtures/gate/*.log`: 12345 Standard 200 d × Easy/Medium/Hard, 777 Large Hard 300 d. **Green: 201/201 ×3, 301/301.** `-Rebaseline` rewrites them |
| First divergence vs pre-fix `main` (expected) | day 10 / 28 / 6 (12345 Easy / Medium / Hard), day 29 (777) |
| `tests/ai_fog.gd` | **28 checks** — each read: take a sighting, change the world behind it, the AI still believes the sighting; look again, it believes the new one |
| `tests/intel_facts.gd` | **31 checks** — the `IntelFacts` engine layer (frozen after capture, −1 never seen, live for our own worlds) |
| Also green | `ai_objectives`, `ai_missions`, `ai_reactions`, `ai_tiers`, `sabotage_targets`, `enemy_intel_targeting`, `onmission_fog`, `inbound_fog`, `ui_compile` |

## Honest ceiling

- **The built-in AI is now fair and weaker at the victory condition**: 0 captures in
  both measured games. That is the true strength of its espionage targeting, which the
  leak had hidden.
- **Stricter than the manual in the Core.** THE GAME (manual p069, `GAMEPLAY.md` "The
  intelligence model", single-source): controller and popular support on **Core**
  systems are "always up to date"; only the Rim goes stale. THE CODE: I found nothing
  implementing this (not read-in-full — not a claim of absence); `IntelFacts` treats
  every world that is not ours as a dated sighting. Right home: `IntelManager.Sighting`,
  so every reader inherits it.
- **The human UI still leaks what the AI no longer reads** (the code): `planet_window.gd`
  shows live holder, support, uprising and the full facility list for any explored
  world; `personnel_finder.gd` has leak #3. Until fixed, the AI sees *less* than the
  player. Filed as its own task.
- **An engine defect, left alone:** `MissionManager.Resolve`'s Abduction branch does
  not check the victim is still at the target, so an order against a stale address
  would seize them wherever they are. That is why #3 offers a person only where the
  sighting names them **and** they still stand.
