# schmitz-wars — status, missing features, backlog & known bugs

The single tracker for outstanding work. Sections: **Status** (done / in
progress), **Missing Features** (the manual describes it, it isn't built),
**Backlog** (lower-priority, not blocking play), **Known Bugs** (confirmed,
unfixed), **Non-issues** (investigated, no change). Started 2026-09-05 in the
agent-room dev session; keep it current as items move.

Every merge below was verified headless on **Godot 4.7.1** (the project's
target) before landing.

---

## Status — done this session (merged)

| # | Item | PR |
|---|------|----|
| 1 | Comms "Go To" opens the associated planet's Defenses window | #8 |
| 2a | Fog: hide enemy personnel on a mission (OnMission) on a world you hold | #11 |
| — | Hotfix: #2a multi-line predicate broke parsing on Godot 4.7.1 | #14 |
| 2b | Defender notified on enemy mission foil / sabotage success (fog-blind) | #15 |
| 5 | "All Messages" at the top of the left-column category menu | #16 |
| 6 (A) | Single-player **Save** + six-slot Game Options screen | #17 |
| 6 (B) | Single-player **Load** — start-menu Load Game + GameManager replay | #22 |
| 7 | Keyboard shortcuts — all mappable strategic ones (F1/F2/F5/F6, Alt+I/O/0/W/G/U, Alt+1-9) | #20 #23 |
| 8 | Fix MenuButton `pressed` double-connect log spam | #18 |
| — | `schmitz-wars-dev` skill (workflow + context-MCP + handoff template) | #9 #10 #12 #13 |
| — | `BACKLOG.md` tracker | #19 |

## Status — in progress

*None — all approved work is merged.* What remains is under **Missing Features**
(new screens) and **Backlog** below; those need TeeJ's go before they start.

---

## Missing Features

The manual/original has these; the port does not yet. (New screens needed.)

| # | Feature | Source / note |
|---|---------|---------------|
| 9 | **F3** Fleet/Ship Finder window | no fleet finder exists (only Personnel + Planet finders) |
| 10 | **F4** Troop Finder window | no troop finder exists |
| 11 | **F7** Encyclopedia window | no Encyclopedia window exists at all |
| 12 | **Alt+B / Alt+T / Alt+F** build ships / troops / installations screens | no standalone build/manufacturing window |
| — | Other window-checklist gaps | see `docs/window-checklists.md` (Missing/Partial rows) — e.g. portrait art placeholders, modal-vs-nonmodal chrome |

## Backlog (lower priority, not blocking play)

| Item | Note |
|------|------|
| **Ctrl+Tab** cycle windows, **PgUp/PgDn** scroll, **Arrows** browse, global **Enter/Esc** | navigation polish, not wired |
| **Alt+M** Mission / **Alt+S** Status for the *selected* unit | needs a global "selected unit" concept — verify it exists first, else it's a no-op |
| "(captured)" label on a held enemy character in the Personnel tab | polish (see #4) |
| `SaveManager.Save` atomicity — write the index before the slot file (or temp-then-rename) so a crash mid-save can't desync them | minor robustness |

## Known Bugs (confirmed, unfixed)

*None currently open.* Every bug found this session was fixed and verified
(fog leaks #2a, defender-notice gap #2b, the 4.7.1 parse break, the MenuButton
double-connect). New confirmed bugs go here with a repro + file:line.

## Non-issues (investigated, no change)

| # | Item | Verdict |
|---|------|---------|
| 4 | Kidnapped enemy shown on your Personnel tab | **Working as intended** — a captured enemy is *your* prisoner on *your* world (`Attached` = the holding world); you legitimately see your own captives. #2a's OnMission-only scope was correct; also hiding Kidnapped would be a regression. |

---

## Keyboard-shortcut audit (Steam guide + code trace)

**Done:** Alt+P (pause), Alt++/− (speed), Alt+H (objectives), Alt+O/Alt+0 (overview),
F1→Game Options, F2→System Finder, F5→Character Finder, F6/Alt+I→Message index,
Alt+W→close all, Alt+G/Alt+U→toggle Manage Garrisons/Production, Alt+1..9→Galaxy
Display modes. (PRs #20, #23.)
**Missing screen (backlog #9-#12):** F3, F4, F7, Alt+B/T/F.
**Skip:** Alt+Y (MP), Alt+V (R2-D2 sounds), Alt+A (tips), Alt+F4 (OS). Tactical
shortcuts (`tactical_view.gd`) — separate audit.

## Process notes

- Verify every change **headless on Godot 4.7.1** before merge (4.5.1 missed the
  #2a parse break). New `class_name` files need a `--import` before a headless
  test can reference them.
- One branch + one PR per issue; the chair is the sole committer/pusher/merger.
  See `.claude/skills/schmitz-wars-dev`. Related ledgers: `docs/window-checklists.md`
  (per-window manual-vs-port), `docs/BACKPORT-LOG.md`, `HANDOFF.md`.
