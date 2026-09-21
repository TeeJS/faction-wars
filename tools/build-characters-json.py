#!/usr/bin/env python3
"""Build packs/<pack>/characters.json from the two data/ character tables.

SCHEMA.md section 7. A TRANSFORM, not an extractor - the .DAT parsers live in the
source repo. Re-runnable and deterministic; re-run after any regeneration of the
inputs or the pack silently goes stale (PROJECT.md risk 3).

Majors come first, then minors, because GameSession.load_roster builds the roster
in that order and day zero walks it consuming the PRNG as it goes. The `is_major`
flag replaces the two-file split.

Reshaping, all of it mechanical (SCHEMA.md section 7):

  Faction      "Alliance" -> "alliance". The raw tables are TITLE CASE while the
               pack is lower case; FactionRegistry.ById folds case to paper over
               exactly this, and re-keying removes the need for the fold.
  ratings      the eight XxxBase/XxxVar pairs become {base, var} entries.
  can_command  the three CanBeXxx booleans become a list.
  special_power  the Jedi block, renamed per section 12 Q5.

Usage:
    python tools/build-characters-json.py            # write the pack file
    python tools/build-characters-json.py --verify   # check only, write nothing
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MAJOR_IN = ROOT / "data" / "major_characters.json"
MINOR_IN = ROOT / "data" / "minor_characters.json"
OUT = ROOT / "packs" / "star-wars-rebellion" / "characters.json"
FACTIONS = ROOT / "packs" / "star-wars-rebellion" / "factions.json"

RATINGS = [
    ("diplomacy", "Diplomacy"),
    ("espionage", "Espionage"),
    ("combat", "Combat"),
    ("leadership", "Leadership"),
    ("loyalty", "Loyalty"),
    ("ship_research", "ShipResearch"),
    ("troop_research", "TroopResearch"),
    ("facility_research", "FacilityResearch"),
]

COMMANDS = [("admiral", "CanBeAdmiral"),
            ("commander", "CanBeCommander"),
            ("general", "CanBeGeneral")]


def slug(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", name.lower()).strip("_")


def load(path: Path):
    with path.open(encoding="utf-8") as fh:
        return json.load(fh)


def build(problems: list):
    faction_ids = {f["id"] for f in load(FACTIONS)["factions"]}

    out = []
    seen = {}
    for rows, is_major in ((load(MAJOR_IN), True), (load(MINOR_IN), False)):
        for c in rows:
            cid = slug(c["Name"])
            if cid in seen:
                problems.append(f"character id collision: '{cid}' from '{c['Name']}'")
            seen[cid] = True

            faction = c["Faction"].lower()
            if faction not in faction_ids:
                problems.append(
                    f"character '{c['Name']}': faction '{c['Faction']}' is not "
                    f"declared in factions.json ({', '.join(sorted(faction_ids))})")

            entry = {
                "id": cid,
                "display_name": c["Name"],
                "faction": faction,
                "is_major": is_major,
                "ratings": {k: {"base": c[f"{p}Base"], "var": c[f"{p}Var"]}
                            for k, p in RATINGS},
                "can_command": [k for k, col in COMMANDS if c[col]],
                "wont_betray": c["WontBetray"],
                "special_power": {
                    "probability": c["JediProbability"],
                    "is_known_user": c["IsKnownJedi"],
                    "level": {"base": c["JediLevelBase"], "var": c["JediLevelVar"]},
                    "can_train": c["CanTrainJedi"],
                },
                "source_id": c["Id"],
                "string_id": c["StringId"],
            }
            out.append(entry)
    return {"characters": out}


def check_victory_targets(doc, problems: list) -> None:
    """SCHEMA rule 3: factions.json names characters it must capture."""
    names = {c["display_name"] for c in doc["characters"]}
    for f in load(FACTIONS)["factions"]:
        for n in (f.get("victory") or {}).get("capture_characters", []):
            if n not in names:
                problems.append(
                    f"factions.json[{f['id']}]: victory target '{n}' is not a character")


def main() -> int:
    verify_only = "--verify" in sys.argv
    problems: list = []

    doc = build(problems)
    check_victory_targets(doc, problems)

    n_in = len(load(MAJOR_IN)) + len(load(MINOR_IN))
    if len(doc["characters"]) != n_in:
        problems.append(f"character count {len(doc['characters'])} != input {n_in}")

    if problems:
        print(f"[characters.json] {len(problems)} problem(s):")
        for p in problems:
            print(f"  {p}")
        return 1

    majors = sum(1 for c in doc["characters"] if c["is_major"])
    print(f"  characters: {len(doc['characters'])} ({majors} major, "
          f"{len(doc['characters']) - majors} minor)")
    by_faction = {}
    for c in doc["characters"]:
        by_faction[c["faction"]] = by_faction.get(c["faction"], 0) + 1
    for k in sorted(by_faction):
        print(f"  {k:<10} {by_faction[k]}")

    if verify_only:
        if not OUT.exists():
            print("[characters.json] --verify: not written yet")
            return 1
        if load(OUT) == doc:
            print("[characters.json] --verify: up to date")
            return 0
        print("[characters.json] --verify: STALE - re-run without --verify")
        return 1

    OUT.parent.mkdir(parents=True, exist_ok=True)
    with OUT.open("w", encoding="utf-8", newline="\n") as fh:
        json.dump(doc, fh, indent=2)
        fh.write("\n")
    print(f"[characters.json] wrote {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
