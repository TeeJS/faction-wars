#!/usr/bin/env python3
"""Build packs/<pack>/missions.json and mission_tables.json.

SCHEMA.md section 9. A TRANSFORM, not an extractor. Re-runnable.

Two things this fixes, both decided in SCHEMA section 12:

  Q1  SpecForces are listed by DISPLAY NAME in the raw table ("Bothan Spies").
      They become unit ids, resolved against units.json - and the build FAILS
      if any name does not resolve, so a rename cannot quietly orphan one.

  Q2  mission_tables.json is keyed by original .DAT filename. Keys become role
      ids naming what the table DOES, with `source_file` kept alongside so the
      link back to the extraction survives without being load-bearing.

THE TABLE NAMES ARE NOT GUESSED. Every table carries its own `description`,
and sixteen of them already have a readable constant in
src/game/mission_table_manager.gd with the id the original registers them by.
TABLE_IDS below is transcribed from that file; the four tables it does not name
take their id from the description, quoted in the comment.

Usage:
    python tools/build-missions-json.py            # write both pack files
    python tools/build-missions-json.py --verify   # check only, write nothing
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MISSIONS_IN = ROOT / "data" / "missions.json"
TABLES_IN = ROOT / "data" / "mission_tables.json"
UNITS = ROOT / "packs" / "star-wars-rebellion" / "units.json"
FACTIONS = ROOT / "packs" / "star-wars-rebellion" / "factions.json"
TABLE_MANAGER = ROOT / "src" / "game" / "mission_table_manager.gd"
MISSIONS_OUT = ROOT / "packs" / "star-wars-rebellion" / "missions.json"
TABLES_OUT = ROOT / "packs" / "star-wars-rebellion" / "mission_tables.json"

# .DAT filename -> role id. The first sixteen are MissionTableManager's own
# constant names, lower_snake_cased; the last four have no constant and are
# named from the table's `description` field, quoted.
TABLE_IDS = {
    "DIPLMSTB.DAT": "diplomacy",            # MissionTableManager.Diplomacy
    "RESCMSTB.DAT": "rescue",               # .Rescue
    "SBTGMSTB.DAT": "sabotage",             # .Sabotage
    "ESPIMSTB.DAT": "espionage",            # .Espionage
    "RCRTMSTB.DAT": "recruitment",          # .Recruitment
    "ABDCMSTB.DAT": "abduction",            # .Abduction
    "INCTMSTB.DAT": "incite_uprising",      # .InciteUprising
    "DSSBMSTB.DAT": "death_star_sabotage",  # .DeathStarSabotage
    "SUBDMSTB.DAT": "subdue_uprising",      # .SubdueUprising
    "ASSNMSTB.DAT": "assassination",        # .Assassination
    "FOILTB.DAT":   "foil",                 # .Foil
    "FDECOYTB.DAT": "decoy",                # .Decoy
    "TDECOYTB.DAT": "troop_decoy",          # .TroopDecoy
    "RLEVADTB.DAT": "evasion",              # .Evasion
    "ESCAPETB.DAT": "escape",               # .Escape
    "INFORMTB.DAT": "informants",           # .Informants
    # No constant in the engine. Named from the table's own description:
    "CSCRHTTB.DAT": "character_search",     # "Character search / hit table"
    "RESRCTB.DAT":  "resource_event",       # "Resource event table"
    "UPRIS1TB.DAT": "uprising_start",       # "Uprising start probability %"
    "UPRIS2TB.DAT": "uprising_end",         # "Uprising end / subdue probability %"
}

FLAGS = {
    "CanContinue": "can_continue", "Scripted": "scripted",
    "ReturnOnAbort": "return_on_abort",
    "TargetKnownRequired": "target_known_required",
    "AbortOnBlockade": "abort_on_blockade",
    "CanEscape": "can_escape", "CanKill": "can_kill",
}
TARGETS = {"TargetFriendly": "friendly", "TargetNeutral": "neutral",
           "TargetHostile": "hostile"}


def slug(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", name.lower()).strip("_")


def load(path: Path):
    with path.open(encoding="utf-8") as fh:
        return json.load(fh)


def check_table_ids_match_engine(tables, problems: list) -> None:
    """TABLE_IDS must cover every table in the data, and the sixteen taken from
    MissionTableManager must still be declared there."""
    for name in tables:
        if name not in TABLE_IDS:
            problems.append(f"table '{name}' has no role id - name it from its description")
    for name in TABLE_IDS:
        if name not in tables:
            problems.append(f"table '{name}' is named here but not in the data")
    if not TABLE_MANAGER.exists():
        problems.append(f"{TABLE_MANAGER}: missing; cannot check the constants")
        return
    declared = set(re.findall(r'"([A-Z0-9]+\.DAT)"', TABLE_MANAGER.read_text(encoding="utf-8")))
    for name in declared:
        if name not in TABLE_IDS:
            problems.append(
                f"MissionTableManager names '{name}' but this script does not")


def build_tables(tables, problems: list):
    out = {}
    for name, t in tables.items():
        tid = TABLE_IDS.get(name)
        if tid is None:
            continue
        if tid in out:
            problems.append(f"table role id '{tid}' used twice")
        out[tid] = {
            "source_file": name,
            "description": t.get("description", ""),
            "entries": t.get("entries", []),
        }
    return {"tables": out}


def build_missions(rows, problems: list):
    faction_ids = {f["id"] for f in load(FACTIONS)["factions"]}
    unit_by_name = {u["display_name"]: u["id"] for u in load(UNITS)["units"]}

    out = []
    seen = {}
    for r in rows:
        # The four "Unnamed 0x.." rows keep a stable id from their MISSNSD id;
        # they are real rows the table ships and are not dropped.
        base = slug(r["Name"]) if not r["Name"].startswith("Unnamed") \
            else "unnamed_%02x" % r["MissionId"]
        mid = base
        if mid in seen:
            problems.append(f"mission id collision: '{mid}' from '{r['Name']}'")
        seen[mid] = True

        available = [f for f, col in (("alliance", "Alliance"), ("empire", "Empire"))
                     if r.get(col)]
        for f in available:
            if f not in faction_ids:
                problems.append(f"'{r['Name']}': '{f}' is not a declared faction")

        spec = []
        for n in r.get("SpecForces") or []:
            uid = unit_by_name.get(n)
            if uid is None:
                problems.append(
                    f"'{r['Name']}': SpecForce '{n}' matches no unit in units.json")
                continue
            spec.append(uid)

        entry = {
            "id": mid,
            "display_name": r["Name"],
            "available_to": available,
            "spec_forces": spec,
            "length": {"base": r.get("LengthBase", 0),
                       "spread": r.get("LengthSpread", 0)},
            "flags": {v: bool(r.get(k)) for k, v in FLAGS.items()},
            "targets": {v: bool(r.get(k)) for k, v in TARGETS.items()},
            "source_id": r["MissionId"],
            "source_family_id": r.get("FamilyId", 0),
            "string_id": r.get("StringId", 0),
            "spec_force_mask": r.get("SpecForceMask", 0),
        }
        # The undecoded columns are carried verbatim rather than dropped: a pack
        # author never sets them, but throwing them away loses extraction data.
        unknown = {k: r[k] for k in r if k.startswith("Unknown")}
        if unknown:
            entry["unknown_columns"] = unknown
        out.append(entry)
    return {"missions": out}


def check_every_column_is_carried(rows, problems: list) -> None:
    accounted = ({"MissionId", "Name", "FamilyId", "StringId", "Alliance", "Empire",
                  "SpecForceMask", "SpecForces", "LengthBase", "LengthSpread"}
                 | set(FLAGS) | set(TARGETS))
    seen = set()
    for r in rows:
        seen |= set(r.keys())
    for col in sorted(seen - accounted):
        if col.startswith("Unknown"):
            continue
        problems.append(f"mission column '{col}' is carried nowhere")


def main() -> int:
    verify_only = "--verify" in sys.argv
    problems: list = []
    rows = load(MISSIONS_IN)
    tables = load(TABLES_IN)

    check_every_column_is_carried(rows, problems)
    check_table_ids_match_engine(tables, problems)
    tables_doc = build_tables(tables, problems)
    missions_doc = build_missions(rows, problems)

    if len(missions_doc["missions"]) != len(rows):
        problems.append(f"mission count != input {len(rows)}")
    if len(tables_doc["tables"]) != len(tables):
        problems.append(f"table count != input {len(tables)}")

    if problems:
        print(f"[missions.json] {len(problems)} problem(s):")
        for p in problems:
            print(f"  {p}")
        return 1

    both = sum(1 for m in missions_doc["missions"] if len(m["available_to"]) == 2)
    one = sum(1 for m in missions_doc["missions"] if len(m["available_to"]) == 1)
    none_ = sum(1 for m in missions_doc["missions"] if not m["available_to"])
    print(f"  missions: {len(missions_doc['missions'])}  "
          f"both sides={both}  one side={one}  neither={none_}")
    print(f"  tables:   {len(tables_doc['tables'])}, all named")

    if verify_only:
        if not MISSIONS_OUT.exists() or not TABLES_OUT.exists():
            print("[missions.json] --verify: not written yet")
            return 1
        if load(MISSIONS_OUT) == missions_doc and load(TABLES_OUT) == tables_doc:
            print("[missions.json] --verify: up to date")
            return 0
        print("[missions.json] --verify: STALE - re-run without --verify")
        return 1

    for path, doc in ((MISSIONS_OUT, missions_doc), (TABLES_OUT, tables_doc)):
        with path.open("w", encoding="utf-8", newline="\n") as fh:
            json.dump(doc, fh, indent=2)
            fh.write("\n")
        print(f"[missions.json] wrote {path.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
