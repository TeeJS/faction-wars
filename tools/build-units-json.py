#!/usr/bin/env python3
"""Build packs/<pack>/weapons.json and units.json from data/military_units.json.

SCHEMA.md sections 6 and its "Weapons are a Phase 3 vocabulary item" subsection.
A TRANSFORM, not an extractor. Re-runnable.

WEAPONS ARE THEIR OWN FILE because they are a small shared vocabulary many units
reference, exactly like facilities. Their ROLES are measured from the engine, not
invented - each is cited in WEAPONS below.

Two reshapes of the unit table:

  weapons   the 12 per-arc columns plus 3 ranges collapse into a map keyed by
            weapon id. A weapon with nothing in any arc is OMITTED, not zeroed.
            Torpedoes have no arcs and appear only on the five fighters that
            carry them - the raw rows do not share a key set, and absence is
            the encoding (SCHEMA section 6).

  stats     the remaining numeric columns, snake_cased EXPLICITLY. slug() would
            lowercase "FighterCapacity" to "fightercapacity" without splitting
            it - the bug that made every facility stat read its default.

Usage:
    python tools/build-units-json.py            # write both pack files
    python tools/build-units-json.py --verify   # check only, write nothing
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
UNITS_IN = ROOT / "data" / "military_units.json"
FACTIONS = ROOT / "packs" / "star-wars-rebellion" / "factions.json"
UNITS_OUT = ROOT / "packs" / "star-wars-rebellion" / "units.json"
WEAPONS_OUT = ROOT / "packs" / "star-wars-rebellion" / "weapons.json"

ARCS = ["Fore", "Aft", "Starboard", "Port"]

# weapon id -> (display name, column prefix, range column, roles, has arcs).
# ROLES ARE MEASURED, each from a cited call site:
#   no_fighter_effect        TacticalBattle.PowerOf adds the ion arc only when
#                            `not against_fighters` (tactical_battle.gd:213), and
#                            FleetBattleManager.PowerOf mirrors it (:90)
#   fighter_accuracy_scaled  Power multiplies turbolaser and laser by `acc` when
#                            firing at fighters, and ion by nothing (:429-450)
#   requires_shields_down    the torpedo term needs ShieldFraction(target) <= 0
#   squadron_only            ...and self_u.IsSquadron() (:453)
WEAPONS = {
    "turbolaser": ("Turbolaser", "Turbolaser", "TurbolaserRange",
                   ["fighter_accuracy_scaled"], True),
    "ion_cannon": ("Ion Cannon", "IonCannon", "IonCannonRange",
                   ["no_fighter_effect"], True),
    "laser":      ("Laser", "Laser", "LaserRange",
                   ["fighter_accuracy_scaled"], True),
    "torpedo":    ("Torpedo", "Torpedoes", "TorpedoRange",
                   ["no_fighter_effect", "requires_shields_down", "squadron_only"],
                   False),
}

V1_WEAPON_ROLES = {"fighter_accuracy_scaled", "no_fighter_effect",
                   "requires_shields_down", "squadron_only"}

# "Type" column -> pack kind id. Which PRODUCER and which queue a unit uses is
# engine structure, so this stays a small closed set for now; SCHEMA section 6
# does not ask for it to open.
KINDS = {"CapitalShip": "capital_ship", "Fighter": "fighter",
         "Troop": "troop", "SpecForce": "spec_force"}

# Column -> stat key. EXPLICIT, never slug()-derived.
STATS = {
    "Detection": "detection", "Shield": "shield", "Sublight": "sublight",
    "Maneuverability": "maneuverability", "Hyperdrive": "hyperdrive",
    "HyperdriveDamaged": "hyperdrive_damaged", "Hull": "hull",
    "TractorPower": "tractor_power", "TractorRange": "tractor_range",
    "GravityWell": "gravity_well", "InterdictionStrength": "interdiction_strength",
    "Bombardment": "bombardment", "DamageControl": "damage_control",
    "WeaponRecharge": "weapon_recharge", "ShieldRecharge": "shield_recharge",
    "FighterCapacity": "fighter_capacity", "TroopCapacity": "troop_capacity",
}

# Derived columns: each is exactly the sum of its four arcs in all 57 rows, so
# they are NOT carried. Recorded here so the omission is deliberate, not missed.
DERIVED = ["Turbolaser", "IonCannon", "LaserRating"]


def slug(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", name.lower()).strip("_")


def load(path: Path):
    with path.open(encoding="utf-8") as fh:
        return json.load(fh)


def check_derived_columns(rows, problems: list) -> None:
    """The summary columns must stay exactly the sum of their arcs, or dropping
    them changes behaviour. Re-checked on every build."""
    for r in rows:
        for summary, wid in (("Turbolaser", "turbolaser"),
                             ("IonCannon", "ion_cannon"),
                             ("LaserRating", "laser")):
            prefix = WEAPONS[wid][1]
            total = sum(r.get(prefix + a) or 0 for a in ARCS)
            got = r.get(summary)
            if got is None:
                if total:
                    problems.append(
                        f"'{r['Name']}': {summary} is null but its arcs sum to {total}")
            elif got != total:
                problems.append(
                    f"'{r['Name']}': {summary} is {got} but its arcs sum to {total} "
                    "- the summary is no longer derived, so it cannot be dropped")


def build_weapons(rows, problems: list):
    out = []
    for wid, (name, prefix, range_col, roles, has_arcs) in WEAPONS.items():
        for role in roles:
            if role not in V1_WEAPON_ROLES:
                problems.append(f"weapon '{wid}': role '{role}' is not in the v1 set")
        used = any((r.get(prefix + a) if has_arcs else r.get(prefix)) for a in
                   (ARCS if has_arcs else [""]) for r in rows)
        if not used:
            problems.append(f"weapon '{wid}' is declared but no unit carries it")
        ranges = {r.get(range_col) for r in rows if r.get(range_col)}
        out.append({
            "id": wid,
            "display_name": name,
            "roles": roles,
            "arcs": has_arcs,
            # Range is PER UNIT in the table, so it lives on the unit's weapon
            # entry; this is the set the pack actually uses, for reference only.
            "observed_ranges": sorted(ranges),
        })
    return {"weapons": out}


def build_units(rows, problems: list):
    faction_ids = {f["id"] for f in load(FACTIONS)["factions"]}
    out = []
    seen = {}
    for r in rows:
        uid = slug(r["Name"])
        if uid in seen:
            # The tables repeat a name per tier; MilitaryCatalog.BuildableAt
            # already de-duplicates by name. Keep both rows, disambiguate the id.
            seen[uid] += 1
            uid = f"{uid}_{seen[uid]}"
        else:
            seen[uid] = 1

        kind = KINDS.get(r["Type"])
        if kind is None:
            problems.append(f"'{r['Name']}': unknown Type '{r['Type']}'")

        for who in r.get("BuildableBy") or []:
            if who not in faction_ids:
                problems.append(
                    f"'{r['Name']}': buildable_by '{who}' is not a declared faction")

        weapons = {}
        for wid, (_n, prefix, range_col, _roles, has_arcs) in WEAPONS.items():
            if has_arcs:
                arcs = {a.lower(): (r.get(prefix + a) or 0) for a in ARCS}
                if not any(arcs.values()):
                    continue
                entry = {"arcs": arcs}
            else:
                amount = r.get(prefix) or 0
                if not amount:
                    continue
                entry = {"amount": amount}
            rng = r.get(range_col)
            if rng:
                entry["range"] = rng
            weapons[wid] = entry

        stats = {v: r[k] for k, v in STATS.items() if r.get(k) is not None}

        out.append({
            "id": uid,
            "display_name": r["Name"],
            "kind": kind,
            "buildable_by": r.get("BuildableBy") or [],
            "construction_cost": r["ConstructionCost"],
            "maintenance_cost": r["MaintenanceCost"],
            "research_order": r.get("ResearchOrder", 0),
            "research_cost": r.get("ResearchCost", 0),
            "weapons": weapons,
            "stats": stats,
            "source_family_id": r["FamilyId"],
            "source_id": r["Id"],
            "string_id": r.get("StringId", 0),
        })
    return {"units": out}


def main() -> int:
    verify_only = "--verify" in sys.argv
    problems: list = []
    rows = load(UNITS_IN)

    check_derived_columns(rows, problems)
    weapons = build_weapons(rows, problems)
    units = build_units(rows, problems)

    if len(units["units"]) != len(rows):
        problems.append(f"unit count {len(units['units'])} != input {len(rows)}")

    if problems:
        print(f"[units.json] {len(problems)} problem(s):")
        for p in problems:
            print(f"  {p}")
        return 1

    kinds = {}
    for u in units["units"]:
        kinds[u["kind"]] = kinds.get(u["kind"], 0) + 1
    print(f"  units: {len(units['units'])}  " +
          "  ".join(f"{k}={v}" for k, v in sorted(kinds.items())))
    for w in weapons["weapons"]:
        n = sum(1 for u in units["units"] if w["id"] in u["weapons"])
        print(f"  {w['id']:<12} {n:>2} units  roles={','.join(w['roles'])}")
    print(f"  dropped as derived: {', '.join(DERIVED)}")

    if verify_only:
        if not UNITS_OUT.exists() or not WEAPONS_OUT.exists():
            print("[units.json] --verify: not written yet")
            return 1
        if load(UNITS_OUT) == units and load(WEAPONS_OUT) == weapons:
            print("[units.json] --verify: up to date")
            return 0
        print("[units.json] --verify: STALE - re-run without --verify")
        return 1

    for path, doc in ((WEAPONS_OUT, weapons), (UNITS_OUT, units)):
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("w", encoding="utf-8", newline="\n") as fh:
            json.dump(doc, fh, indent=2)
            fh.write("\n")
        print(f"[units.json] wrote {path.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
