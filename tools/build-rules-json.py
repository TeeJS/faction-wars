#!/usr/bin/env python3
"""Build packs/<pack>/rules.json and setup.json.

SCHEMA.md section 8. A TRANSFORM, not an extractor. Re-runnable.

rules.json   game_rules.json, moved. Rows keep their integer EntryId - SCHEMA
             section 12 Q6 decided that, and rule_id.gd remains the way engine
             code names a rule. This is the one place a number legitimately
             survives into pack data.

setup.json   the side lottery and the day-zero logistics tables.

THE LOGISTICS TABLE IDS ARE DERIVED FROM USE, NOT GUESSED. Unlike the mission
tables these carry no `description`, so the names come from what actually reads
them: factions.json's own `seed` block already names each one's ROLE per side
(hq_facilities, hq_garrison, fleet, procedural_fleet), and DayZeroGenerator
picks SYFCCRTB vs SYFCRMTB by whether the world is core or rim. Each mapping
below cites that. The build FAILS if factions.json stops referring to one.

Usage:
    python tools/build-rules-json.py            # write both pack files
    python tools/build-rules-json.py --verify   # check only, write nothing
"""

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RULES_IN = ROOT / "data" / "game_rules.json"
LOTTERY_IN = ROOT / "data" / "side_lottery.json"
LOGISTICS_IN = ROOT / "data" / "day_zero_logistics.json"
FACTIONS = ROOT / "packs" / "star-wars-rebellion" / "factions.json"
DAY_ZERO = ROOT / "src" / "game" / "day_zero_generator.gd"
RULES_OUT = ROOT / "packs" / "star-wars-rebellion" / "rules.json"
SETUP_OUT = ROOT / "packs" / "star-wars-rebellion" / "setup.json"

# .DAT filename -> role id, each justified by the thing that reads it.
LOGISTICS_IDS = {
    # DayZeroGenerator: `"SYFCCRTB.DAT" if is_core else "SYFCRMTB.DAT"`.
    "SYFCCRTB.DAT": "core_system_facilities",
    "SYFCRMTB.DAT": "rim_system_facilities",
    # factions.json seed.hq_facilities
    "FACLHQTB.DAT": "alliance_hq_facilities",
    "FACLCRTB.DAT": "empire_hq_facilities",
    # factions.json seed.hq_garrison
    "CMUNHQTB.DAT": "alliance_hq_garrison",
    "CMUNCRTB.DAT": "empire_hq_garrison",
    # factions.json seed.fleet
    "CMUNAFTB.DAT": "alliance_fleet",
    "CMUNEFTB.DAT": "empire_fleet",
    # factions.json seed.procedural_fleet
    "CMUNALTB.DAT": "alliance_procedural_fleet",
    "CMUNEMTB.DAT": "empire_procedural_fleet",
    # factions.json starting_planets[].garrison
    "CMUNYVTB.DAT": "alliance_start_garrison",
}

# Which GNPRTB entries bound a table's FIXED LIST, as rule entry ids.
#
# DayZeroGenerator.FixedListRange used to decide this by matching the .DAT
# FILENAME - `if type.contains("CMUNHQTB")`. Renaming the tables silently broke
# every one of those branches: the seeding fell through to the random-band path
# and day zero came out different, with no error. The pairing is pack data, so
# it moves here. Transcribed from rule_id.gd (entries 84-97); a table with no
# fixed list simply omits it.
FIXED_RANGES = {
    "CMUNYVTB.DAT": [84, 85],   # RuleId.SeedYavin{First,Max}
    "CMUNHQTB.DAT": [86, 87],   # SeedAllianceHq
    "CMUNCRTB.DAT": [88, 89],   # SeedCoruscant
    "CMUNAFTB.DAT": [90, 91],   # SeedAllianceFleet
    "CMUNEFTB.DAT": [92, 93],   # SeedEmpireFleet
    "FACLHQTB.DAT": [94, 95],   # SeedHqFacilities
    "FACLCRTB.DAT": [96, 97],   # SeedCoruscantFacilities
}


def load(path: Path):
    with path.open(encoding="utf-8") as fh:
        return json.load(fh)


def check_fixed_ranges_match_engine(problems: list) -> None:
    """FIXED_RANGES is transcribed from rule_id.gd. Fail if those constants move."""
    rid = (ROOT / "src" / "game" / "rule_id.gd")
    if not rid.exists():
        problems.append("rule_id.gd missing; cannot verify the seed ranges")
        return
    text = rid.read_text(encoding="utf-8")
    import re as _re
    want = {
        "SeedYavinFirst": 84, "SeedYavinMax": 85,
        "SeedAllianceHqFirst": 86, "SeedAllianceHqMax": 87,
        "SeedCoruscantFirst": 88, "SeedCoruscantMax": 89,
        "SeedAllianceFleetFirst": 90, "SeedAllianceFleetMax": 91,
        "SeedEmpireFleetFirst": 92, "SeedEmpireFleetMax": 93,
        "SeedHqFacilitiesFirst": 94, "SeedHqFacilitiesMax": 95,
        "SeedCoruscantFacilitiesFirst": 96, "SeedCoruscantFacilitiesMax": 97,
    }
    for const, value in want.items():
        m = _re.search(r"const\s+" + const + r"\s*:=\s*(\d+)", text)
        if m is None:
            problems.append(f"rule_id.gd no longer declares {const}")
        elif int(m.group(1)) != value:
            problems.append(
                f"rule_id.{const} is {m.group(1)}, this script says {value}")


def check_ids_are_used(problems: list) -> None:
    """Every id must be justified by something that actually reads the table."""
    factions = load(FACTIONS)["factions"]
    referenced = set()
    for f in factions:
        for v in (f.get("seed") or {}).values():
            referenced.add(v)
        for sp in f.get("starting_planets") or []:
            if sp.get("garrison"):
                referenced.add(sp["garrison"])

    day_zero = DAY_ZERO.read_text(encoding="utf-8") if DAY_ZERO.exists() else ""
    for name, rid in LOGISTICS_IDS.items():
        new_id_used = rid in referenced
        old_name_used = name in referenced or f'"{name}"' in day_zero or f'"{rid}"' in day_zero
        if not (new_id_used or old_name_used):
            problems.append(
                f"logistics table '{name}' -> '{rid}': nothing references it. "
                "The id must be derived from a real use, not invented.")


def build_setup(problems: list):
    logistics = load(LOGISTICS_IN)
    for name in logistics:
        if name not in LOGISTICS_IDS:
            problems.append(f"logistics table '{name}' has no role id")
    for name in LOGISTICS_IDS:
        if name not in logistics:
            problems.append(f"'{name}' is named here but not in the data")

    tables = {}
    for name, t in logistics.items():
        rid = LOGISTICS_IDS.get(name)
        if rid is None:
            continue
        entry = dict(t)
        entry["source_file"] = name
        if name in FIXED_RANGES:
            entry["fixed_range"] = FIXED_RANGES[name]
        tables[rid] = entry

    return {"side_lottery": load(LOTTERY_IN), "logistics": tables}


def main() -> int:
    verify_only = "--verify" in sys.argv
    problems: list = []

    check_ids_are_used(problems)
    check_fixed_ranges_match_engine(problems)
    rules = load(RULES_IN)
    setup = build_setup(problems)

    if problems:
        print(f"[rules.json] {len(problems)} problem(s):")
        for p in problems:
            print(f"  {p}")
        return 1

    print(f"  rules:        {len(rules)} entries (integer EntryId kept - Q6)")
    print(f"  side lottery: {len(setup['side_lottery'])} entries")
    print(f"  logistics:    {len(setup['logistics'])} tables, all named from use")

    if verify_only:
        if not RULES_OUT.exists() or not SETUP_OUT.exists():
            print("[rules.json] --verify: not written yet")
            return 1
        if load(RULES_OUT) == rules and load(SETUP_OUT) == setup:
            print("[rules.json] --verify: up to date")
            return 0
        print("[rules.json] --verify: STALE - re-run without --verify")
        return 1

    for path, doc in ((RULES_OUT, rules), (SETUP_OUT, setup)):
        with path.open("w", encoding="utf-8", newline="\n") as fh:
            json.dump(doc, fh, indent=2)
            fh.write("\n")
        print(f"[rules.json] wrote {path.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
