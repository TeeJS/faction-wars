# 00 — Charter: a better AI opponent for *Star Wars: Rebellion*

| | |
|---|---|
| **Status** | **APPROVED** — goal, anti-goals and success criteria signed off by TeeJ, room #122. Backup resolved. Downstream documents may proceed |
| **Authors** | Han (draft), Doof and R2D2 (review) |
| **Inputs** | `manual/strategy-guide/analysis/ch01`–`ch12` — 12 files, **180 rule records**, every file author-plus-reviewer |
| **Scope** | **Design documents only.** No code changes. `src/` is not touched by this phase |

---

## The five questions

*Per the working directives, a charter answers these before any work proceeds.*

### 1. What is the one thing this must do?

**Give the player an opponent that plays the game the way the strategy guide says a
strong player plays it — competently, across every loop of the game, including the parts
of the game the current AI cannot reach at all — with three difficulty tiers that differ
in how well it plays, never in what it knows.**

> *One word changed from the sentence approved in room #113: "all four of its loops"
> → "every loop of the game". The corpus tags **seven** distinct loops, not four, so the
> number was simply wrong and made success criterion 1 unverifiable. The meaning is
> unchanged. Flagged rather than silently edited. (Caught by R2D2, room #117.)*

The guide is being used as a **template for good play**. It happens to be the best
available one: an expert's complete account of how to play this specific game well,
written by someone with access to the developers.

> ⚠ **A corrected framing, recorded because the error is instructive.** An earlier draft
> made the goal *"when I use the tactics in the Prima guide against a Hard opponent, they
> should stop working."* That is a different objective wearing the same clothes, and it
> is wrong. Building an AI to defeat *the book* is overfitting to one 1998 document —
> you would get an opponent oddly good at resisting the nine things Steve Honeywell
> wrote down and mediocre at everything else, which a player who never read the guide
> would find stupid.
>
> The error came from the guide being two things at once: a description of **good play**
> (the DO rules) and a description of **how to beat the 1998 computer** (the DEFEND
> rules). The second half is the more surprising one, and it was allowed to become the
> headline. The first half is the job. *(Caught by TeeJ, room #111.)*

### 2. What would be wrong if we shipped "working" software without it?

An AI that runs, produces no errors, and is **not an opponent**. Specifically, the
three failures the analysis found, any one of which makes the game hollow:

- **It cannot win.** Two of three victory conditions per side are character captures,
  achieved by abduction. `MissionType.Abduction` is absent from the AI's mission
  selection (`ai_manager.gd:334–337`). Nine of fifteen mission types are unreachable.
- **It cannot see the point of its own actions.** The Empire's first victory condition
  requires finding a hidden headquarters in the Rim; the AI targets unexplored systems
  **last** (`ai_manager.gd:317`, first-match at `:320`).
- **It does not look after its own position.** A player who knows the game beats it the
  same way at every tier — not because the AI counters nothing, but because it does
  nothing worth countering.

### 3. What is explicitly off-limits as a workaround?

These are anti-goals. Proposing any of them is a signal that the design has failed,
not a shortcut to it.

| Off-limits | Why |
|---|---|
| **Difficulty that buys information.** No tier lifts fog, reads the opponent's queues, or knows an unexplored system's contents | `ai_manager.gd:5–6` states the AI does not see through fog. An AI that wins by peeking is not hard, it is broken, and the player feels it without being able to prove it. **A Hard AI gets better at inferring, never at seeing** — see §"The fairness rule" |
| **Difficulty as a stat multiplier** on the AI's units or economy | The original varies **starting position**, not runtime numbers. Handicap and competence are separate axes and stay separate |
| **Inventing a mechanic** to make a rule implementable | Repo rule. A missing feature is visible; a fabricated rule looks deliberate and gets built on |
| **Hardcoding the guide's round numbers** where the game holds a real model | The guide says "six troop regiments"; `planet.gd:450` derives the requirement from the support shortfall. The guide's numbers are heuristics for humans |
| **Scoping a wiring job as a rewrite** | Most gaps are *implemented and unreachable*, not missing. See §"What is actually broken" |
| **Treating the Prima guide as authoritative over the game** | It is a 1998 book about a patched game. Source hierarchy below |

### 4. Deployment target and backup location

- **Target:** design documents in `docs/ai-framework/`. This directory **is tracked by
  git**; the analysis corpus in `manual/` **is not** (`.gitignore` excludes all of
  `manual/` as copyrighted).
- ✅ **RESOLVED (TeeJ, room #122): mirror it.** Location chosen:
  **`D:\Github\_backups\schmitz-wars-analysis\<YYYY-MM-DD_HHMM>\`** — a timestamped
  snapshot of all 12 analyses plus `prima-appendix-tables.md`. First mirror taken
  **2026-09-04 15:03**, 420 KB.

  **Why outside the repo rather than into a tracked directory.** The obvious fix —
  move the analysis somewhere git tracks — would break the repo's own standing rule.
  `.gitignore` excludes `manual/` with the comment *"Manual scans, PDFs and digests are
  copyrighted - never commit any of it."* These analyses quote the guide extensively and
  are digests in exactly that sense. Committing them to satisfy a backup requirement
  would trade a recoverable risk for a policy breach, so the mirror sits **outside the
  repository altogether**, where `git clean -xdf` cannot reach it and no copyrighted
  digest enters version control.

  Re-run before any significant corpus change:
  ```
  STAMP=$(date +%Y-%m-%d_%H%M)
  mkdir -p "/d/Github/_backups/schmitz-wars-analysis/$STAMP"
  cp manual/strategy-guide/analysis/*.md manual/strategy-guide/prima-appendix-tables.md \
     "/d/Github/_backups/schmitz-wars-analysis/$STAMP"/
  ```

### 5. How will we verify it is done?

Success criteria, testable, in order of how much they matter:

1. **The AI plays all five operational loops the way the corpus describes** — economy,
   fleet, missions, diplomacy, combat — driven by the **victory** objective layer that
   arbitrates between them. Measured rule by rule against `02-rule-corpus.md`, not by
   overall impression. See §"The canonical loop set" for what the seven loops are.
2. **The AI can reach every mission type its victory conditions require.** Concretely:
   abduction is launchable, and a full-victory game is winnable by the AI in principle.
3. **Every rule in `02-rule-corpus.md` is either implemented, or listed in
   `11-gaps.md` with a stated reason.** No rule silently disappears between analysis
   and implementation.
4. **The three tiers differ measurably in how well the AI plays, and not at all in what
   it knows.** An audit of the AI's decisions shows no use of state it could not
   legitimately observe.
5. **Every claim in these documents carries a citation** — a guide line range, a
   `GAMEPLAY.md` line, a data field, or a `file:line`. Uncited claims are defects.

**A useful test, not a goal.** If the AI plays competently, most of the openings the
guide teaches players to exploit are simply not there any more — so the book's exploits
should get less effective as the tier rises. That is worth measuring, because Chapters
9, 10 and 11 hand us a ready-made test plan. But it is **evidence of competence, not the
definition of it**, and designing toward it directly produces the overfitted opponent
described in §1.

---

## The source hierarchy

Established during analysis and **proven** once, in full, against a real disagreement.
Higher wins; lower sources are recorded, not discarded.

| Rank | Source | Standing |
|---|---|---|
| 1 | **`data/*.json`** — the shipped `.DAT` tables | Highest. It is what the game actually runs on |
| 2 | **`GAMEPLAY.md`** — the game's own manual, digested | Authoritative on rules and UI |
| 3 | **`src/`** — this port's code | Authoritative on *what the code does*, which is a different claim from *how the game works* |
| 4 | **Prima's Official Strategy Guide** | A 1998 book by an expert player about a since-patched game. Rich, and wrong in places |

**The worked example — the GenCore threshold.** The Prima guide *(L5525–5527)* says
"if there are **more than two** GenCores, you can't assault the system. **One or less**
shield, and you can" — which leaves exactly two undefined. The manual *(p123)* says
"at least two planetary shields" greys the option out. `data/game_rules.json` EntryId
**151**, "Required Shield Generators to Prevent Assault", is **2**.
`assault_manager.gd:33` blocks at `shields >= 2`. **The bottom three agree and the top
one is wrong** — the guide dropped a boundary. This is the ladder working, and it is
why every load-bearing number gets walked down it.

**Corollary, measured.** Of 147 appendix values checked against the data, **140 match
exactly**. All 8 mismatches are the maintenance cost of ships with `ResearchOrder > 0`;
every starting hull matches. The guide is accurate except in one systematic place —
which is precisely why it must be checked rather than trusted or dismissed.

---

## What is actually broken

The analysis began by assuming the port was full of holes. It is not. Findings are
sorted into four labels, and **they are four different jobs of four different sizes**:

| Label | Meaning | What we found |
|---|---|---|
| **NOT IMPLEMENTED** | Genuinely absent from the game | **HQ relocation** — seven guide passages, the manual documents its Move/Confirmed Move menu (`GAMEPLAY.md:2996–2998`) and prices its loyalty cost (`:1018`), and no relocation code exists in `src/game`. Also the HQ-**search** objective as a goal tracker. **That is the whole list.** |
| **IMPLEMENTED AND UNREACHABLE BY THE AI** | The engine supports it; the AI driver never calls it | The large majority. `MissionManager.Launch` *(mission_manager.gd:487)* takes `team: Array`, `decoys`, `victim` and `saboteur_target`; the AI passes a single agent and nothing else. Nine of fifteen mission types. The entire `IntelManager` staleness model |
| **IMPLEMENTED BUT MISORDERED** | The AI does it, at the wrong priority, with no way for urgency to interrupt | `SubdueUprising` last in a static list; `Unexplored` last in the target list; one fixed preference order for both factions in every phase |
| **NOT SURFACED** | Modelled in the data, never exposed in the UI | `ConstructionTask.Destination` — the field the Empire's entire HQ-finding method depends on *(Ch10 L6625–6657)* — exists with the comment "Where this is being delivered", and `intel_manager.gd:184–189` renders the queue's **name** in its place. **This affects the human player too**: it is a fidelity gap against the original, not an AI gap |

**The honest one-line summary: the port is sound and the opponent is blind.** The work
is concentrated in two thin layers — the AI driver and the intel renderer.

---

## The fairness rule

**Difficulty never buys information.** Every tier sees exactly what the fog allows.
A Hard AI is better at **inference**, not at **observation**.

This is not a slogan; the corpus contains the worked example that defines it.
**RULE-09-03**, from the guide's own sidebar *(Ch9 L5929–5946)*:

> "IF THE EMPIRE ATTACKS ONE OF YOUR SYSTEMS, **CHECK THE BATTLE RESULTS. THIS GIVES YOU
> A GOOD IDEA OF THE IMPERIAL GARRISON'S SIZE WITHOUT RUNNING AN ESPIONAGE MISSION.**"

Hidden state, derived from an event the AI legitimately observed. No fog lifted, real
information gained. **Every Hard-tier intelligence behaviour must be justifiable in that
shape.** If it cannot be — if the AI simply *knows* something — it is cheating, whatever
the code looks like.

Two further examples the corpus found, both fog-legal: a Core system flipping to the
Alliance is evidence of a diplomat's location *(Ch10 L6506–6528)*; and construction
output bound for an unfamiliar Rim system is evidence of the Rebel HQ's sector
*(Ch10 L6625–6657)* — currently blocked by the NOT SURFACED item above.

---

## Difficulty: two axes, and which half each governs

**Difficulty in the original game does not change AI behaviour at all.** Four sources
agree: Prima p17 *(L502–505)* — "THE COMPUTER WILL ACT THE SAME FOR ALL DIFFICULTY
SETTINGS"; `GAMEPLAY.md:3573` — "a starting-position handicap, not smarter AI";
`ai_manager.gd:7` — "Difficulty is not an AI dial"; and Prima *(L4524–4525)* — "on
medium or hard difficulty games, the Empire doesn't necessarily have an advantage in
its infrastructure."

**Behavioural tiers are therefore OURS — a deliberate departure, requested by TeeJ
(room #27), and labelled as ours wherever they appear.** They are not a restoration of
1998 behaviour and must never be described as one.

| Axis | What it is | Status |
|---|---|---|
| **1 — Handicap** | Starting systems, resources, facilities. `data/side_lottery.json`, SDPRTB.DAT entries 30/31 | **The original's. Untouched.** |
| **2 — Competence** | How well the AI plays | **New. Ours.** |

**Axis 2 is built from capability throttles and self-protection rules, and they govern
different segments of the ladder.** ⚠ *An earlier draft said this was "settled by counting,
not by argument." That was wrong — the tier on each rule was assigned by judgment, so the
count restates those judgments rather than testing them. It establishes that the ladder is
non-degenerate; the segment argument stands on its own reasoning, set out in
`10-difficulty-and-fairness.md` §2. (R2D2, room #181.)*
Across all 12 files — **180 rule records**, of which **23 are DEFEND**:

| Tier | DEFEND records |
|---|---|
| **Hard** | 11 |
| **Medium** | 11 |
| **All** | **1** — RULE-05-23 |
| **Easy only** | 0 |

**The single All-tier exception is the useful part.** RULE-05-23 says the Alliance moves
its characters off their known starting systems on day one. It sits at All because
skipping it does not make the AI *weak*, it makes it **broken** — the Empire begins the
game knowing where most Rebel characters are *(Ch5 L2795–2805)*, so an AI that leaves
them parked hands away a victory condition for free on turn one.

That gives the tiering rule its boundary condition, which the earlier draft lacked:

> **A self-protection rule belongs at All when omitting it makes the opponent look
> broken rather than beatable.** Everything else starts at Medium.

- **Easy → Medium is separated by CAPABILITY** — per-day budgets
  (`MovesPerDay`/`MissionsPerDay`/`ShipsPerDay`, all currently `1`, and flagged in the
  code itself as "Per-day caps are OURS"), planning horizon, reaction latency, decision
  noise. **DEFEND contributes nothing here, by construction:** DEFEND rules are the
  rules about *looking after your own position*, and an Easy opponent is one that does
  not yet do that well.
- **Medium → Hard is separated by DEFEND** — 11 of those self-protection rules active at
  Medium, all 22 at Hard, plus the deeper inference they require.

> **What a DEFEND rule actually is, under the corrected framing of §1.** Not an
> anti-player countermeasure — a **competence rule about protecting your own position**.
> "Don't leave a victory-condition character where it can be abducted" is not spite, it
> is a strong player looking after their pieces. "Don't hold systems by force when you
> could hold them by loyalty" is the Empire chapter's own advice for playing *well*
> (Ch10 L6564–6568). Every DEFEND record in the corpus survives that reading, and
> several are clearer for it.

An earlier draft of this design claimed the DEFEND corpus alone *was* the ladder. The
count showed otherwise and the claim is withdrawn. Recorded because the reasoning
matters more than the conclusion.

---

## Non-goals

- Reimplementing game systems that already work. See the four labels.
- Changing the original's difficulty handicap.
- Tactical (real-time battle) AI. `fleet_battle_manager.gd` and the tactical layer are
  **not audited** by this corpus and are out of scope unless TeeJ says otherwise.
- Multiplayer AI behaviour. Head-to-head uses a separate rule column
  (`Difficulty.Multiplayer`) with **no difficulty setting at all** — what tier an AI
  runs at when filling an MP slot is an open question, logged in `11-gaps.md`.

---

## Document set

| Doc | Contents |
|---|---|
| **00-charter.md** | this |
| **01-architecture.md** | loops, clocks, budget, arbitration; replacing the static mission-preference list with objective-driven selection |
| **01a-opponent-model.md** | **the largest open question.** Three chapters independently require the AI to reason about what the *opponent* knows about it (RULE-01-07, RULE-02-04, RULE-05-18). Held as its own document so it stays visibly undesigned rather than being read as answered |
| **02-rule-corpus.md** | the consolidated, deduplicated rule table across all 12 analyses |
| **03**–**07** | policy per **operational loop**: economy, fleet, missions, diplomacy, combat |
| **08-victory.md** | the **objective layer** — victory conditions as a plan, their ordering, and the kill chains both sides run |
| **09-counter-exploit.md** | every DEFEND rule — self-protection, gathered in one place |
| **10-difficulty-and-fairness.md** | the two axes above, as concrete switch settings per tier |
| **11-gaps.md** | open questions and what would settle each |
| **12-implementation-map.md** | rule → code, sorted by the four labels; **and the reverse index**, code → the rules governing it |

### The canonical loop set

The corpus tags **seven** loops. They are not all the same kind of thing, and conflating
them is what made the earlier "four loops" wording unverifiable:

| Loop | Rules | Kind | Home |
|---|---|---|---|
| **missions** | 46 | operational | `05-missions.md` |
| **fleet** | 43 | operational | `04-fleet.md` |
| **economy** | 34 | operational | `03-economy.md` |
| **diplomacy** | 19 | operational | `06-diplomacy.md` |
| **combat** | 17 | operational | `07-combat.md` |
| **victory** | 23 | **objective layer** — sets what the operational loops are *for*, and arbitrates between them | **`08-victory.md`** |
| **meta** | 8 | **cross-cutting disposition** — standing asymmetries such as "time favours the Alliance" and "information binds the Empire" | this charter + `10-difficulty-and-fairness.md` |

*(**Convention:** `02-rule-corpus.md` files each rule under its **first-listed** loop, so every rule is counted exactly once and the seven sections sum to 180. **Nine rules carry a compound tag** such as `fleet + combat`; a policy document may cross-reference one into its own section, marked as such, without counting it twice. The table above uses the first-listed convention.)*

**Victory gets its own document.** It carries 23 rules — the fourth largest loop, and the
one that drives every other — and an earlier draft of this set gave it no home at all.
The policy documents were renumbered to make room while nothing had yet been written, so
the change cost nothing. *(Raised by R2D2, room #117; endorsed by Doof, room #119.)*

---

## Sign-off

- [x] **TeeJ** — approved the goal, the anti-goals and the success criteria, and
      resolved the backup question, room #122.
- [x] Han — draft
- [ ] Doof — review
- [ ] R2D2 — review
