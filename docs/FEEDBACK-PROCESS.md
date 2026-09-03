# How a tester's feedback report is processed

TeeJ's flow (room AM-LFGGG3LVQSSJGXSP7P7JE9Q745 #188, 2026-09-03). It gates
every fix that comes from a report on his review of a plan.

| Step | Who | What |
|---|---|---|
| 1 | a tester | submits a note from the game's feedback box ("Provide feedback" on the Cockpit). The relay stores it with the day, seed, settings, client facts and the tester's session log: `POST /feedback`. |
| 2 | TeeJ | opens a feedback-processing session. |
| 3 | Claude | reads the listing (`GET /feedback`), pulls the log (`GET /feedback/<id>.jsonl`), replays it (`tests/replay.gd`) to the day the tester saw, and **suggests a plan** for a fix. No code is touched. |
| 4 | TeeJ | reviews the plan: **approves**, **revises**, or **rejects**. |
| 5 | Claude | rejected: work on that suggestion stops. Revised: the plan is revised and resubmitted (back to 4). Approved: the fix is implemented, gated, and pushed. |
| 6 | TeeJ | tests the fix and declares it **fixed** or **still broken**. |
| 7 | Claude | fixed: the report's files move to the `completed` folder (`POST /feedback/<id>/complete` moves `<id>.json` and `<id>.jsonl` into `feedback/completed/`; the listing then hides it, `GET /feedback?all=1` shows everything). Still broken: a new plan, back to 4. |

Reports live on the box under `/mnt/user/appdata/wars-relay/data/feedback/`;
the relay serves them at `https://wars.schmitzplex.com/feedback`.
