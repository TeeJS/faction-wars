#!/usr/bin/env python3
"""Build packs/<pack>/facilities.json from the two data/ facility tables.

SCHEMA.md section 5. This file REPLACES Enums.FacilityType: the engine must ask
what a facility DOES, never what it is called.

A TRANSFORM, not an extractor. Re-runnable; re-run after any regeneration of the
inputs or the pack silently goes stale (PROJECT.md risk 3).

ROLES ARE DERIVED FROM WHAT THE CODE DOES, not from the names. Each assignment
below cites the behaviour it stands for:

  headquarters       family 32; FacilityCatalog.BuildableBy excludes it
  extracts_raw       Mine; Planet.FreeMineSlots / RawMaterialsFrom
  refines            Refinery
  produces_unit      Shipyard; Planet.ProcessQueueItem's ship producer
  produces_troop     Training Facility; the troop producer
  produces_facility  Construction Yard; Planet.BestProducerRate
  planet_defense     EXACTLY BombardmentManager.IsMilitary - families 34-37
  disable            Ion Cannon: BombardmentManager DISABLES a ship rather than
                     destroying it, and BlockadeManager.WithdrawPercent returns
                     100 when one is present
  anti_ship          Turbolaser Battery: shoots a random ship to damage it
  shield             Planetary Shield

  ! Death Star Shield (family 37) gets planet_defense ONLY. It counts as
    military, but Enums.FacilityType records "protects the Death Star only, no
    bombardment shield" and its ShieldStrength is 0, so giving it `shield`
    would be a behaviour change dressed up as a data move.

Usage:
    python tools/build-facilities-json.py            # write the pack file
    python tools/build-facilities-json.py --verify   # check only, write nothing
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PRODUCTION_IN = ROOT / "data" / "production_facilities.json"
DEFENSIVE_IN = ROOT / "data" / "defensive_facilities.json"
FACTIONS = ROOT / "packs" / "star-wars-rebellion" / "factions.json"
OUT = ROOT / "packs" / "star-wars-rebellion" / "facilities.json"

# family id -> (family slug, roles). The family ids are the original binary's;
# every one present in the data tables must be mapped here, which is checked.
FAMILIES = {
    32: ("headquarters", ["headquarters"]),
    34: ("ion_cannon", ["planet_defense", "disable"]),
    35: ("turbolaser_battery", ["planet_defense", "anti_ship"]),
    36: ("planetary_shield", ["planet_defense", "shield"]),
    37: ("death_star_shield", ["planet_defense"]),
    40: ("shipyard", ["produces_unit"]),
    41: ("training_facility", ["produces_troop"]),
    42: ("construction_yard", ["produces_facility"]),
    44: ("mine", ["extracts_raw"]),
    45: ("refinery", ["refines"]),
}

# SCHEMA.md section 5. The loader rejects anything outside this set so a typo
# cannot silently create an inert facility.
V1_ROLES = {"headquarters", "extracts_raw", "refines", "produces_unit",
            "produces_troop", "produces_facility", "planet_defense", "shield",
            "disable", "anti_ship"}

# Column -> stat key. EXPLICIT, not slug()-derived: slug() lowercases without
# splitting camelCase, so "ProcessingRate" became "processingrate" and every
# consumer silently fell through to its default. The mine and refinery rates
# read 4 instead of 5 and nothing failed - it just played differently.
STATS = {
    "BombardmentDefense": "bombardment_defense",
    "ProcessingRate": "processing_rate",
    "WeaponRating": "weapon_rating",
    "ShieldStrength": "shield_strength",
}


def slug(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", name.lower()).strip("_")


def load(path: Path):
    with path.open(encoding="utf-8") as fh:
        return json.load(fh)


def check_families_cover_the_data(problems: list) -> None:
    """FAMILIES must cover exactly the family ids the two tables contain.

    This used to compare against FacilityCatalog.Families in the engine. That
    table is GONE - the pack is the catalog now - so the check points at the
    DATA instead: a family the tables carry but this script does not map would
    be dropped silently, and one mapped here but absent from the tables is dead.
    """
    present = set()
    for path in (PRODUCTION_IN, DEFENSIVE_IN):
        for r in load(path):
            present.add(r["FamilyId"])
    for f in sorted(present - set(FAMILIES)):
        problems.append(f"family {f} is in the data tables but has no role mapping here")
    for f in sorted(set(FAMILIES) - present):
        problems.append(f"family {f} is mapped here but no longer in the data tables")


def build(problems: list):
    faction_ids = {f["id"] for f in load(FACTIONS)["factions"]}

    out = []
    seen = {}
    for path in (PRODUCTION_IN, DEFENSIVE_IN):
        for r in load(path):
            fam = r["FamilyId"]
            if fam not in FAMILIES:
                problems.append(f"'{r['Name']}': family {fam} has no role mapping")
                continue
            family_slug, roles = FAMILIES[fam]

            for role in roles:
                if role not in V1_ROLES:
                    problems.append(f"'{r['Name']}': role '{role}' is not in the v1 role set")

            fid = slug(r["Name"])
            if fid in seen:
                problems.append(f"facility id collision: '{fid}' from '{r['Name']}'")
            seen[fid] = True

            for who in r["BuildableBy"]:
                if who not in faction_ids:
                    problems.append(
                        f"'{r['Name']}': buildable_by '{who}' is not a declared faction")

            stats = {v: r[k] for k, v in STATS.items() if k in r and r[k] is not None}

            out.append({
                "id": fid,
                "display_name": r["Name"],
                "family": family_slug,
                "tier": r["Tier"],
                "roles": roles,
                "buildable_by": r["BuildableBy"],
                "construction_cost": r["ConstructionCost"],
                "maintenance_cost": r["MaintenanceCost"],
                "research_order": r.get("ResearchOrder", 0),
                "research_cost": r.get("ResearchCost", 0),
                "stats": stats,
                "source_family_id": fam,
                "source_id": r["Id"],
            })

    # Every family must have a tier 1: the catalog indexes on (family, tier) and
    # BuildableBy only ever offers tier 1.
    by_family = {}
    for f in out:
        by_family.setdefault(f["family"], set()).add(f["tier"])
    for fam_slug, tiers in sorted(by_family.items()):
        if 1 not in tiers:
            problems.append(f"family '{fam_slug}' has no tier 1 entry")

    return {"facilities": out}


def main() -> int:
    verify_only = "--verify" in sys.argv
    problems: list = []

    check_families_cover_the_data(problems)
    doc = build(problems)

    n_in = len(load(PRODUCTION_IN)) + len(load(DEFENSIVE_IN))
    if len(doc["facilities"]) != n_in:
        problems.append(f"facility count {len(doc['facilities'])} != input {n_in}")

    if problems:
        print(f"[facilities.json] {len(problems)} problem(s):")
        for p in problems:
            print(f"  {p}")
        return 1

    print(f"  facilities: {len(doc['facilities'])} across "
          f"{len({f['family'] for f in doc['facilities']})} families")
    for role in sorted(V1_ROLES):
        names = [f["id"] for f in doc["facilities"] if role in f["roles"]]
        print(f"  {role:<18} {len(names)}  {', '.join(names)}")

    if verify_only:
        if not OUT.exists():
            print("[facilities.json] --verify: not written yet")
            return 1
        if load(OUT) == doc:
            print("[facilities.json] --verify: up to date")
            return 0
        print("[facilities.json] --verify: STALE - re-run without --verify")
        return 1

    OUT.parent.mkdir(parents=True, exist_ok=True)
    with OUT.open("w", encoding="utf-8", newline="\n") as fh:
        json.dump(doc, fh, indent=2)
        fh.write("\n")
    print(f"[facilities.json] wrote {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
