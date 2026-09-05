# 13 — Implementation plans (game-level gaps)

| | |
|---|---|
| **Status** | **COMPLETE.** P1, P3b, P4 BUILT (inspection-verified, GDScript validates at load). P3a and P3c CLOSED as non-gaps (the original has neither a discrete rank-detection term nor capture-on-assault; verified against the disassembly / measured behavior). P2 is not a standalone game gap — it folds into the §2.7 AI-driver rework. All game-level gaps from `11-gaps.md` §1 are resolved. |
| **Author** | Lord Vader (agent room AM-S6L77) |
| **Scope** | The 5 confirmed game-level gaps + D3, from `11-gaps.md` §1 and the room audit. Plans only; each BUILD is gated on TeeJ's explicit approval. AI-driver wiring (`12-implementation-map.md` §2) is separate. |
| **Order** | P1 (cheapest) → P4 (HQ, built LAST per TeeJ). |

> ⚠ **Rule 2 flags.** Several plans need a numeric magnitude (a loyalty drop, a
> skill increment) that the manual states only qualitatively ("a small drop",
> "skills can improve"). Where the number is not yet found in a shipped source it
> is marked **FLAG: magnitude unknown** — that value must come from `GData/*.DAT`
> or `game_rules.json`, or be measured, **before** the build. Never invent it.

---

## P1 — Render `ConstructionTask.Destination` in the intel panel · D2 · NOT SURFACED

**GOAL:** espionage reveals where enemy production is headed — the Empire's only
documented method of finding the Rebel HQ. Restores manual/guide behaviour that
the panel currently drops.
**DOES NOT PUNT ON:** the human sees it too — faithful (espionage aids whoever
runs it), not a workaround.

**THE CHANGE (one file):** `src/game/intel_manager.gd`
- `DescribeTask()` (:204-212) returns `"%s (%s, %d%% complete)" % [what, where, pct]`.
  Append a **guarded** destination:
  - shipping elsewhere → `"%s (%s -> %s, %d%% complete)"` — e.g. `X-Wing (shipyard -> Sullust, 42% complete)`
  - building in place → unchanged `"%s (%s, %d%% complete)"`
- **Guard:** show destination only when `t.Destination != null` **and**
  `t.Destination != <building planet>`. (`planet.gd` `FinishConstruction` already
  distinguishes `Destination != self`.)
- The 3 `Render()` call-sites (:186/:188/:190) have the planet in scope — compute
  the guarded dest string there and pass it in (one optional param on `DescribeTask`).

**VERIFY:** (1) ship at A bound for B → panel shows `-> B`; (2) facility built in
place → unchanged, no arrow; (3) null Destination → no NPE. `dotnet build`; do not
relaunch (rule 6).
**UNBLOCKS:** RULE-10-01, 10-02, 10-18, `08-victory.md` V-2.
**CONFIDENCE:** code CONFIRMED read-in-full (C3P0 + Vader, `intel_manager.gd:204-212`);
game claim CONFIRMED (prima `:6630` + manual espionage-as-intel).
**GATE:** changes shipped UI + aids the human → **build waits on TeeJ's explicit approval.**

---

## P2 — Make combat cadence intentional via selection · D3 · behaviour fix

**GOAL:** combat difficulty scales by **what** the AI chooses to fight (target
selection + objective ordering), matching the real-time original — which has **no
action economy** (manual p020; `game_rules.json` has no assault-cadence entry;
both confirmed in room). Remove the incidental "~2 free assaults/day".
**DOES NOT PUNT ON:** difficulty must still reach combat — it does so through
selection, not by inventing a cap the game never had.

**THE CHANGE:** `src/game/ai_manager.gd` `Invade()` (:213-252) + `Dispatch()` (:107)
- Root cause (C3P0 + Vader, read-in-full): `Invade()` returns after its **first**
  resolved assault (:228), and `Dispatch` runs twice/day → ~2/day. It is a
  control-flow accident, not a designed number.
- **Determination (research-settled, do NOT add a 4th budget counter):** fold
  assault selection into the **objective-driven selection** rework
  (`12-implementation-map.md` §2.7) so which/how-many assaults happen per pass is
  decided by the current bottleneck and tier, not by a blind early-return.

**DEPENDENCY — surface this honestly:** P2 is **not a standalone patch.** It lands
inside §2.7 (objective-driven selection), the structural AI item. Sequenced with
that work, not before it.
**VERIFY:** with selection in place — Easy fights nearest / less selectively; Hard
fights the bottleneck; assault count is a *consequence* of chosen targets.
**CONFIDENCE:** settled 3 ways — manual (real-time), data (no entry, R2D2
read-in-full), code (accident, C3P0 + Vader).
**GATE:** AI behaviour change, part of the §2.7 build. Approval + sequencing.

---

## P3 — The three confirmed mission/character gaps

Three separate builds. **Each carries a magnitude risk** — the guide states the
behaviour, not the number.

### P3a — Command ranks improve enemy-mission detection · U-2 · CONFIRMED gap
**GOAL:** ranked characters (Commander/General/Admiral), with espionage rating,
improve a side's chance of **finding and stopping enemy missions** on its systems
and fleets (Prima L3592-3596; manual p055 / `GAMEPLAY.md:851-868`).
**THE CHANGE:** `src/game/mission_manager.gd` detection/score pipeline — add a
defender term for ranked characters present. C3P0 (read-in-full) found no rank
modifier in the current pipeline.
**REFRAMED — likely NOT a buildable gap (resolved from existing disassembly).**
The foil/detection formula was already reverse-engineered in
`sol-conflict-revolution/DISASSEMBLY-NOTES.md` ("Foiling and decoys" / "Foiling:
WIRED"). Foil contest `0x55E470` (FOILTB), formula:
`foilScore = mean(team espionage) − mission[+0x1C4] − field14(decoy subset) −
pct(defenderEspionage, 35% [e70]) + 1 [e65]`, then FOILTB → foil %. The character
rating slots are Espionage/Diplomacy/Combat/Leadership/Force — **no command-rank
slot, no discrete rank→detection term.** Detection is **espionage-driven**; the
manual's "command ranks improve detection" is realized indirectly (ranked
characters defend, and their espionage rating feeds the score), not via a separate
additive magnitude. So the original has no rank-detection constant to restore, and
building one would **invent** a mechanic (rule 2).
**CAVEAT (rule 5):** ~90% recovered — two terms omitted, and an outer per-defender
loop "very likely exists and was not found." Strong single-source (project's own
disassembly), not absolute.
**GATE:** reclassify to "no discrete rank-detection term in the original." A
rank-detection bonus would be a NEW design choice (ours) — separate TeeJ decision,
not part of this gap fix.

### P3b — Characters improve skills on mission success · U-3 · CONFIRMED gap
**GOAL:** each successful mission, a character's relevant skill can improve;
Special Forces cannot (Prima L2688-2703; `GAMEPLAY.md:1312`).
**THE CHANGE:** extend the existing `AwardForceForSuccess()` pattern to a general
per-success skill increment (espionage mission → +espionage, etc.), gated to
Characters (not SpecForces). Death Star Sabotage already grants +1 (entries
122/123) — that is the shape.
**MAGNITUDE — FOUND, flag cleared (C3P0, `gnprtb_globals.json` read-in-full):**
entries **#112-#127** carry per-mission skill-gain values ("Espionage success:
Espionage points gain", "Research success: Research points gain", etc.). These are
**shipped parameters that already exist**; `mission_manager.gd` simply does not
read them (confirmed in C3P0's code read). So P3b is **wire the existing DAT
values**, not invent a number. This is the strongest of the three P3 items.
**GATE:** approval. No magnitude research outstanding.

### P3c — Capture enemy characters during an assault · U-1 · CLOSED — NON-GAP (port already correct)
**Resolved by read-in-full, no build.** The guide's "you may capture them during
the assault" (Prima L6316-6319) is **single-source and contradicts the measured
shipped behavior.** When a world falls to an assault, the original **relocates**
the losing side's personnel (characters + SpecForces) to the nearest friendly
world — "they do not stay" (`GAMEPLAY.md:610-641`, confirmed by measurement). They
are **not captured**; capturing enemy leaders is done by **Abduction missions**
(`GAMEPLAY.md:1628, 3056-3060`), not the assault.
**The port already implements this correctly:** `assault_manager.gd:154` →
`MilitaryCatalog.OnControlChanged` (`:160-222`) evicts them to `NearestHeldBy()`.
So there is nothing to build; a capture-on-assault step would **invent** a
mechanic (rule 2) and contradict the confirmed relocation. Same class as the
blockade-flight capture (`SET-PIECES-AND-TABLES.md:468`, "stated 3× in the manual,
NOT in the binary").
**Separate candidate (NOT this item):** a prisoner is not freed when their
prison-world is recaptured by their own side (C3P0). Distinct scenario — flag on
its own if TeeJ wants it checked.

---

## P4 — HQ relocation · D1 · NOT IMPLEMENTED · **BUILD LAST**

TeeJ ruled D1 **YES** — plan now, build after **all** analysis (done) and on
approval. The mechanic **and its manual-specified UI are both the feature** (rule 0).

**GOAL:** the Alliance can relocate its HQ, so the Empire's first victory condition
becomes a **race** rather than a lottery, and the 8 DEFEND rules + the Hard-tier
signature behaviour become buildable.
**DOES NOT PUNT ON:** the **interface** — the manual's HQ menu and drag gesture are
part of P4, not a phase 2.

**THE MANUAL SPEC (verified read-in-full, `GAMEPLAY.md`):**
- **Gesture** (`:2996-2998`, Fig 3.82): drag the HQ icon onto a new system, **or**
  right-click the HQ → menu is exactly **{Move, Confirmed Move, Encyclopedia, Status}**.
- **Cost** (`:1018` / manual p090): a **small loyalty drop on the system it left**.
- **Blockade pin** (`:3077-3087`): a blockade on the HQ system **prevents**
  relocation — "it pins the target so it cannot move."
- Supporting: TIP to bring troops/fighters/personnel to the new site (`:3000-3001`).

**THE CHANGE (multiple files — sub-tasked):**
1. **Command:** add `move_hq` / `confirmed_move_hq` to `command_applier.gd` `Kinds[]`,
   mirroring the existing `move_*` commands. C3P0 (read-in-full) confirmed no HQ
   command exists today.
2. **Relocation logic:** move the `Headquarters` facility from the old seat to the
   new system and update the `hq_of` structure that `day_zero_generator.gd:53`
   populates. One-way destruction paths (`assault_manager.gd`,
   `bombardment_manager.gd`) stay; add the move path.
3. **Cost:** apply the small loyalty drop to the **left** system via the existing
   support-shift machinery. **FLAG: magnitude GENUINELY UNKNOWN.** C3P0 read
   `gnprtb_globals.json` (213) and R2D2 read `game_rules.json` (211) in full — 424
   entries, **no HQ-relocation loyalty cost exists**. Generic loyalty params (#47
   "Loyalty Shift: Random Spread", #48 "Loyalty Shift: Base Amount") exist but are
   not HQ-specific; #81/#82/#174 are HQ *presence* shifts, not a *move* cost.
   **Resolution (skill hierarchy, DAT tier now exhausted):** next try **ENCYTEXT.DLL**
   (the in-game Encyclopedia, source repo / installed game — `grep -aoE` per the
   research skill); if silent there, **measure in-game** (tier 5 — observe loyalty
   before/after a relocation in the original) **before P4 ships**, or TeeJ picks a
   value. Do **not** invent one, and do not silently reuse #48 as if it were the HQ
   figure. P4 is last, so this does not block the earlier plans.
4. **Blockade pin:** give `blockade_manager.gd` HQ awareness — reject `move_hq`
   when the HQ system is blockaded. C3P0 (read-in-full) confirmed it has none today.
5. **UI:** the HQ right-click menu **{Move, Confirmed Move, Encyclopedia, Status}**
   and the drag-to-relocate gesture. **Pre-step:** locate where facility/unit
   context menus and map drag are handled (not yet read) and build to match Fig 3.82.
6. **AI use** (the 8 DEFEND rules — Hard moves HQ on a timer, keeps a fallback
   sector) is **AI-framework work, separate from this mechanic** — P4 delivers the
   mechanic + UI the AI (and the human) then use.

**VERIFY:** open the HQ world's Planet Data window → right-click the Headquarters
row → the four-item menu; Move/Confirmed Move → crosshair → pick a held world → HQ
relocates, old world takes the loyalty drop; a blockade on the HQ world refuses the
move; the Empire can no longer only "find and kill" — the HQ can flee.

**✅ BUILT (inspection-verified, GDScript validates at load):**
- Command: `command_applier.gd` `move_hq` (Kinds + arm → `OrderManager.MoveHeadquarters`).
- Mechanic: `order_manager.gd` `MoveHeadquarters(faction, dest)` — `Hq.Movable` gate,
  runtime seat scan, **blockade pin** (`BlockadeManager.IsBlockaded`), moves the HQ
  facility, re-conceals the new seat, applies the loyalty drop.
- Loyalty: `rule_id.gd` `AllianceHqSupportShift := 174`, applied as `-entry174` to the
  departed world. ⚠ **INFERRED** (manual gives "small drop" qualitatively; entry 174 is
  the shipped HQ support magnitude) — measurement would confirm. New-seat boost
  deliberately omitted (manual states only the departure drop).
- UI: `planet_window.gd` renders the player's own movable HQ as a right-click menu row
  **{Move, Confirmed Move, Encyclopedia, Status}** (Fig 3.82 contents verbatim), using
  the existing `UIManager` crosshair. Menu adapted to a window row per the port's own
  convention (its unit menu, also a manual right-click, lives in a window) — chosen by
  TeeJ over building new map-facility interaction. Encyclopedia/Status are stubs, as
  they are for every facility in the port today; Move and Confirmed Move both
  target-and-fire, matching the port's unused unit-menu confirm flag.
**CONFIDENCE:** mechanic + interface CONFIRMED from manual (Vader, read-in-full);
code absence CONFIRMED (C3P0, read-in-full). Loyalty magnitude = inferred flag.

---

## Build sequence (proposed)

1. **P1** — one guarded field. Cheapest, highest fidelity. Gate: shipped-UI approval.
2. **P3a/P3b/P3c** — after each clears its magnitude/corroboration FLAG.
3. **P2** — inside the §2.7 objective-selection rework (not before it).
4. **P4** — HQ relocation + UI, last, sub-tasked.

Nothing here is built until TeeJ approves the specific plan.
