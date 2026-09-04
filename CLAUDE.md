# Working rules for this repo

Non-negotiable. These override default behaviour.

---

## 0. THE RULE AND THE IMPLEMENTATION BOTH MATCH THE MANUAL

**This overrides every other rule in this file, and every instinct you have about
what would be simpler, cleaner or faster.**

The manual describes two things about every feature, and **both are the spec**:

| | |
|---|---|
| **The rule** | what happens — costs, times, thresholds, who may do what |
| **The implementation** | how the player does it — the window, its fields by name, the controls, the gesture, the confirmation, the icon |

You do not get to take the first and invent the second. A window the manual
describes is **part of the feature**, not a follow-up, not phase 2, not a TODO.

### Before writing a single line of code

1. Find every manual passage for the feature.
2. **Write down the interface it specifies** — the window's name, every field by
   the manual's own wording, every control, and the gesture that opens it.
3. Build to that list.

If you catch yourself building the mechanic and deciding the screen afterwards,
you have already broken this rule. Go back to step 2.

### After building, before saying it is done

**Re-open the manual passage and check off every element it names against what
you actually shipped.** Not from memory — re-read it.

This step exists because the intention above is not enough on its own. The
failure mode is specific and it repeats: you search the manual for the MECHANIC,
find it, and stop reading — while the window is described in the next paragraph
of the same page. p045 was read for build costs and times, quoted in a commit
message, and the Build Selection window sitting on that page was never built.

The user finds these instantly, because they search for the missing thing by
name. You will find them just as fast if you go back and look. The only reason
they get shipped is that nobody looked again.

If an element the passage names is absent, it is not done — either build it or
ask, per the section below.

### If you cannot match it

**Stop and ask. Every time.** Say exactly which part you cannot reproduce and
why. Do not:

- ship a different interface and mention it afterwards
- file the missing parts as a TODO and build the rest
- decide a field is cosmetic and drop it
- substitute a list where the manual says crosshairs, a button where it says a
  menu, or a tab where it says a window

Getting approval costs one question. Not getting it costs the user having to
find it, describe it, and make you build it twice.

### How this rule was earned

Every one of these came from the same paragraph the implementation was already
built from:

| Manual says | What was shipped |
|---|---|
| Build Selection window: item picker, both costs, **Best Time To Completion**, **Best Time To Deployment**, **Number to build** (p045) | a scrolling wall of everything buildable with a Build button per row, and the two time readouts filed as a TODO |
| Destination is picked with **targeting crosshairs on the map** (p044) | a dialog listing planet names |
| Mission icon right-click offers **Encyclopedia, Status, Abort** (p109) | icon and window built, menu skipped — a mission could not be aborted at all |
| A unit's menu is Move, Confirmed Move, **Mission**, Encyclopedia, Status, Retire (p045) | Mission missing, so a recon craft could not be given its only job |
| The window reports agents **and decoys separately** (p109) | the decoy tab was never populated |

In each case the correct answer was in a passage already read, already quoted in
the commit message. The failure is never missing information. It is treating the
interface as a detail.

---

## 1. Do not ask for guidance you can find yourself

**Only ask the user a question when you have exhausted the available resources
and the answer genuinely is not in them.**

Before asking anything about how the game works, you must have checked:

| Source | Where |
|---|---|
| Original binary tables | `GData/*.DAT` in the installed game, via `data/parse_*.py` |
| In-game Encyclopedia text | `ENCYTEXT.DLL` — greppable off disk, no need to launch |
| UI strings | `TEXTSTRA.DLL` |
| Rules constants | `data/game_rules.json` |
| Manual page scans | `manual/pages/`, digested in `GAMEPLAY.md` |
| Prior findings | `ECONOMY-NOTES.md`, `GAMEPLAY.md`, `manual/ILLUSTRATIONS.md` |
| Existing project conventions | the code already in this repo |
| Community reverse-engineering | Steam app 441550, swrebellion.net — corroboration only |
| Measurement | run the original and observe |

Use the **`research-game-rules`** skill. It exists precisely so this runs
automatically.

**Presenting options is asking.** Offering "A, B or C" where one option is
"go research it" is the same failure as asking outright — go and research it.
Do not offer a menu of guesses.

**When you genuinely must ask**, state which sources you checked and what each
one failed to yield. A question without that list is not acceptable.

## 1a. ⚠ ASK BEFORE ANY REVERSE ENGINEERING

**Disassembling `REBEXE.EXE` or any shipped DLL requires the user's explicit
approval, every time.** So does launching a sub-agent that will. Do not start,
do not "just check one address", do not treat a previous session's approval as
standing.

**And search for prior work before you even propose it.** Known starting points:

| Source | What it has |
|---|---|
| ★ [`tdimino/open-rebellion`](https://github.com/tdimino/open-rebellion) | **A FULL GHIDRA DECOMPILATION OF `REBEXE.EXE` — 22,741 functions — with published notes.** Combat call chains, a decoded bombardment formula, and a `.DAT` dumper covering 51 of 51 files. **Check this before anything else.** ⚠ `ghidra/notes/*` are findings about the binary; `docs/mechanics/*` are that project's own reimplementation choices — do not conflate them. |
| [`TheArchitect2018/Deep-Dive-into-SW-Rebellion-PC-Game-Internals`](https://github.com/TheArchitect2018/Deep-Dive-into-SW-Rebellion-PC-Game-Internals/wiki) | the **GData file formats** — GNPRTB, SDPRTB, the IntTable files, StartData, SaveGame. Its *main* repo also carries `initial_game_seeding_logic/`, a JS reimplementation of day-zero seeding. |
| [`lvisintini/SWRebellionEditor`](https://github.com/lvisintini/SWRebellionEditor) | Python struct definitions — **the only editor that models `MISSNSD.DAT`**. |
| [`MetasharpNet/StarWarsRebellionEditor.NET`](https://github.com/MetasharpNet/StarWarsRebellionEditor.NET) | the community editor; 24 `.DAT` files with full column names. Source of our 213 GNPRTB parameter names. |
| swrebellion.net threads [282](https://swrebellion.net/forums/topic/282-mechanics-inside-rebellion/), [9639](https://swrebellion.net/forums/topic/9639-mechanics-inside-rebellion-part-ii), [4009](https://swrebellion.net/forums/topic/4009-savegame-hex-editing-format/) | record layouts; GNPRTB/SDPRTB; **savegame format, ~50% mapped** |

**`COMMUNITY-DIFF.md` records what has already been diffed and tested.** Read it
before repeating any of it.

**Why this rule exists.** Disassembly is slow, expensive, and easy to get wrong —
one mis-aligned decode already produced a published wrong reading in this
project, and it took a second pass to catch. It is also the class of work most
likely to have been done already by somebody else. Whether it is worth spending
on is the user's call, not an implementation detail.

**What to do instead:** when a rule is missing from the manual, the tables and
`GAMEPLAY.md`, say so plainly, say that the binary would settle it, and **stop
and ask**. That is not a failure to be thorough — it is the rule.

## 2. Never invent a game mechanic

If the sources do not state a rule, **say so and stop**. Do not substitute a
plausible-sounding rule. Flagging an invention is not permission to ship it.

A missing feature is better than a fabricated rule: the missing feature is
visible, the fabricated rule looks deliberate and gets built on.

## 3. Always label game behaviour vs code state

Every statement about behaviour is one of two things, and must say which:

- **The game** — how *Star Wars: Rebellion* works. Needs a source citation.
- **The code** — what this implementation does, including bugs and gaps. Needs a
  file and line.

Never make the reader infer which. When contrasting them, use a table with the
columns *How the game works* and *What the code does*. Mark gaps explicitly as
**not implemented**.

## 4. Get explicit approval before editing

Discussion, screenshots, questions and complaints are **not** approval. A user
describing correct behaviour is a bug report, not a specification to go build.

## 5. Report confidence, always

- **Confirmed** — two independent sources agree, or a prediction matched a
  measurement. Cite both.
- **Single-source** — name it, and say what would corroborate it.
- **Unknown** — say so, say what would settle it, and stop.

That scale is for claims about **the game**. Claims about **the code** get rule 5a.

## 5a. Claims about the code

Rule 3 says label game vs code. This says how much you must have read before
you are allowed to write the code half down.

### A NEGATIVE CLAIM REQUIRES READING THE FILE, NOT GREPPING IT

*"X does not exist." "X is never called." "X is unused." "The AI has no Y."*

Positive claims are self-checking — you cite the thing you found. **Negative
claims are not.** A grep that returns nothing is not evidence of absence; it is
evidence about your search term.

Before writing any negative claim about code:

1. **Read the file's header comment.** This repo's files say what they do in the
   first five lines. More than one wrong claim here was contradicted by a header
   ten lines above the function being read.
2. **Read the whole function**, not the lines around the match.
3. **Grep at least two different terms**, including the domain word and the
   likely identifier.
4. **Check whether another path does the job.** A thing absent from one manager
   is often present in the one that calls it.

### Verify in a different step from finding

**Do not write a finding down in the same step you found it.** Find, then verify,
then write. The gap between those is where every error below got in.

This costs one extra tool call and it is the cheapest rule in this file.

### Mark how deep you read

Every code claim carries one of these, the way game claims carry a confidence:

| | |
|---|---|
| **read-in-full** | the whole function and its file header |
| **spot-checked** | the matched lines and their immediate context |
| **inferred** | from structure or naming, not read |

**A negative claim may only be `read-in-full`.** If it is not, do not write it.

### Nobody is in a hurry

There is no deadline in this repo. If several agents are working, **do not pace
off each other** — another agent filing a document is not a signal that you are
behind. Publishing a finding to a room does not make it true, and agreement from
other agents is not verification.

### How this rule was earned

Three wrong claims in one session, all negative, all from greps:

| Claimed | Actually |
|---|---|
| *"There is no two, no three, no count of any kind on that page"* | The numbers were there. The read had been truncated by `head`, and the grep used "round" where the guide says "bombardments" |
| *"Strategic auto-resolve ignores shields, unlike tactical"* | `fleet_battle_manager` **runs the tactical engine**. Its header says so on line 4. The function read was a UI display figure, not the resolver |
| *"The AI never calls `CanAssault()`"* | It calls it at `ai_manager.gd:224` |

The second propagated into two framework documents and to the user before it was
caught. The cost of retracting a published claim is far higher than the cost of
one more read.

## 6. Never kill the running game

Build with `dotnet build` and stop. **Never** `Stop-Process` the game or relaunch
it — the user tests by playing, and restarting destroys the state they were
mid-way through investigating.

Godot compiles the C# on launch, so a rebuild is live the next time *they* start
it. Reading `$env:TEMP\scr-run.log` observes without interfering.

## 7. Build the whole feature the manual describes, including its UI

Before implementing anything, read what GAMEPLAY.md and manual/ILLUSTRATIONS.md
already say about it - the manual was read cover to cover so this would not
depend on the user. If the manual documents a window, a confirmation, an icon or
a readout, that is PART OF THE FEATURE, not a follow-up.

Shipping the mechanic and waiting to be told the interface is missing wastes the
research and makes the user the tester of record for things already written down.

Check first:
  GAMEPLAY.md                 the rules, per-page citations, and the UI the
                              manual specifies for each system
  manual/ILLUSTRATIONS.md     which figure shows the window you need to build

## 8. Be brief and structured

Tables over prose. Lead with the answer. Long explanations are where rules and
code state get conflated and where guesses hide.

---

## Repo facts

- **This is the GDScript port** of `sol-conflict-revolution` (the source, Godot
  4.7.1 mono/C#, at `D:\Github\sol-conflict-revolution`). See `HANDOFF.md`.
- **Engine:** Godot 4.7.1 **non-Mono** (GDScript). **Not yet downloaded** as of
  2026-09-02 - only the mono build exists at
  `D:\Downloads\Godot_v4.7.1-stable_mono_win64\`. The mono editor opens GDScript
  projects, so steps 0-1A can use it; the non-Mono build plus its web export
  templates are needed before step 1B's web export. Launch via a `run-game` skill
  for this repo once one exists - the WinGet `godot` shim on PATH does not work.
- **Remotes:** this repo's own. The source repo's `origin`/`upstream` rules do not
  apply here; changes to the source (e.g. HANDOFF step 0b) go on its
  `tschmitz-dev` branch with TeeJ's separate go-ahead.
- **In this repo, copied from the source (HANDOFF §6 step 0):** `data/*.json`
  (the shipping form of the `.DAT` tables - JSON is the contract; the Python
  parsers stay in the source), `GAMEPLAY.md`, `manual/ILLUSTRATIONS.md`. Each
  copied doc starts with `<!-- last synced from sol-conflict-revolution commit
  <sha> -->` - **check that line before trusting it**, and re-sync from the source
  when it moves.
- **Not in this repo at all:** `*.DAT`, `ENCYTEXT.DLL`/`TEXTSTRA.DLL`,
  `manual/Manual.pdf`, `manual/pages/` (171 MB). All of those live only in the
  source repo / the installed game; rule 1's source table still applies, read
  them there.
- **Page numbers:** always say "PDF pN" or "manual pN". The offset varies 0–3.
- The original game runs windowed via the **"SW - Rebellion Window Mode"** Start
  menu entry. Computer-use **cannot drive it** - input is accepted and ignored -
  but screenshots work.
