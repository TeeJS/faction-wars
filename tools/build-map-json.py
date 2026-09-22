#!/usr/bin/env python3
"""Build packs/<pack>/map.json from the SOURCE repo's data/sectors_data.json + data/planets_data.json.

The legacy data/*.json folder left this repo on 2026-09-22; the extractors and
their output live in sol-conflict-revolution (override with SCR_SOURCE).

SCHEMA.md section 4. This is a TRANSFORM, not an extractor: the .DAT parsers live
in the source repo and produce data/*.json; this folds two of those into the pack
file. Re-runnable and deterministic - re-run it after any regeneration of the two
inputs, or the pack silently goes stale (PROJECT.md risk 3).

Emits nothing the inputs do not contain. The two derived fields are:

  min_size     which galaxy size first includes a sector. Currently TWENTY LITERAL
               SECTOR NAMES in src/game/galaxy_factory.gd:14-25 - the table below
               is transcribed from there, and moving it into the pack is the point
               of the exercise. Verified against that file by --verify.

  intel_tier   SCHEMA.md section 4: "live" for Core, "presence" for Rim, and
               GalaxyRing 1 is Core. Marked [later]; nothing reads it yet.

Usage:
    python tools/build-map-json.py            # write the pack file
    python tools/build-map-json.py --verify   # check only, write nothing
"""

import os
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE_DATA = Path(os.environ.get("SCR_SOURCE", r"D:\Github\sol-conflict-revolution")) / "data"
SECTORS_IN = SOURCE_DATA / "sectors_data.json"
PLANETS_IN = SOURCE_DATA / "planets_data.json"
GALAXY_FACTORY = ROOT / "src" / "game" / "galaxy_factory.gd"
MAP_OUT = ROOT / "packs" / "star-wars-rebellion" / "map.json"

# Transcribed from galaxy_factory.gd:14-25. Cumulative: standard is in every size.
SIZE_MEMBERSHIP = {
    "standard": ["Corellian", "Sesswenna", "Sluis", "Calaron", "Churba",
                 "Dufilvan", "Mayagil", "Moddell", "Orus", "Sumitra"],
    "large":    ["Farfin", "Glythe", "Jospro", "Kanchen", "Quelli"],
    "huge":     ["Dolomar", "Fakir", "Abrion", "Atrivis", "Xappyh"],
}


def slug(name: str) -> str:
    """Display name -> lower_snake_case id (SCHEMA.md section 1)."""
    return re.sub(r"[^a-z0-9]+", "_", name.lower()).strip("_")


def load(path: Path):
    with path.open(encoding="utf-8") as fh:
        return json.load(fh)


def check_membership_matches_engine(problems: list) -> None:
    """The size table above is a copy. Fail loudly if the engine's has moved."""
    if not GALAXY_FACTORY.exists():
        problems.append(f"{GALAXY_FACTORY}: missing; cannot verify the size table")
        return
    source = GALAXY_FACTORY.read_text(encoding="utf-8")
    for size, names in SIZE_MEMBERSHIP.items():
        for n in names:
            if f'"{n}"' not in source:
                problems.append(
                    f"size table: '{n}' ({size}) is not in galaxy_factory.gd - "
                    "the engine's list has changed, re-transcribe it")


def build(problems: list):
    sectors_in = load(SECTORS_IN)
    planets_in = load(PLANETS_IN)

    size_of = {}
    for size, names in SIZE_MEMBERSHIP.items():
        for n in names:
            if n in size_of:
                problems.append(f"size table: '{n}' listed twice")
            size_of[n] = size

    by_source_id = {}
    sectors_out = []
    seen_ids = {}
    for s in sectors_in:
        sid = slug(s["Name"])
        if sid in seen_ids:
            problems.append(f"sector id collision: '{sid}' from '{s['Name']}'")
        seen_ids[sid] = True

        if s["Name"] not in size_of:
            problems.append(
                f"sector '{s['Name']}' is in no galaxy size - it would never "
                "appear in a game")

        by_source_id[s["SectorId"]] = sid
        sectors_out.append({
            "id": sid,
            "display_name": s["Name"],
            "ring": s["GalaxyRing"],
            "starts_neutral": s["StartsNeutral"],
            "map": {"x": s["MapCenterX"], "y": s["MapCenterY"]},
            "min_size": size_of.get(s["Name"]),
            # [later] - nothing reads this yet. SCHEMA.md section 4.
            "intel_tier": "live" if s["GalaxyRing"] == 1 else "presence",
            "source_id": s["SectorId"],
            "string_id": s["StringId"],
        })

    planets_out = []
    seen_ids = {}
    for p in planets_in:
        pid = slug(p["Name"])
        if pid in seen_ids:
            problems.append(f"planet id collision: '{pid}' from '{p['Name']}'")
        seen_ids[pid] = True

        sector_id = by_source_id.get(p["SectorId"])
        if sector_id is None:
            problems.append(
                f"planet '{p['Name']}' references SectorId {p['SectorId']}, "
                "which no sector declares")
            continue

        planets_out.append({
            "id": pid,
            "display_name": p["Name"],
            "sector": sector_id,
            "starts_inhabited": p["StartsInhabited"],
            "map": {"x": p["MapX"], "y": p["MapY"]},
            "artwork_id": p["ArtworkId"],
            "source_id": p["PlanetId"],
            "string_id": p["StringId"],
        })

    return {"sectors": sectors_out, "planets": planets_out}


def report(doc, sectors_in, planets_in) -> None:
    print(f"  sectors: {len(doc['sectors'])} (in: {len(sectors_in)})")
    print(f"  planets: {len(doc['planets'])} (in: {len(planets_in)})")
    running = 0
    for size in ("standard", "large", "huge"):
        running += sum(1 for s in doc["sectors"] if s["min_size"] == size)
        worlds = sum(1 for p in doc["planets"]
                     if next(x for x in doc["sectors"] if x["id"] == p["sector"])
                     ["min_size"] in _upto(size))
        print(f"  {size:<9} {running:>2} sectors, {worlds:>3} planets")


def _upto(size):
    order = ["standard", "large", "huge"]
    return order[:order.index(size) + 1]


def main() -> int:
    verify_only = "--verify" in sys.argv
    problems: list = []

    check_membership_matches_engine(problems)
    doc = build(problems)

    sectors_in = load(SECTORS_IN)
    planets_in = load(PLANETS_IN)

    if len(doc["sectors"]) != len(sectors_in):
        problems.append(
            f"sector count {len(doc['sectors'])} != input {len(sectors_in)}")
    if len(doc["planets"]) != len(planets_in):
        problems.append(
            f"planet count {len(doc['planets'])} != input {len(planets_in)}")

    if problems:
        print(f"[map.json] {len(problems)} problem(s):")
        for p in problems:
            print(f"  {p}")
        return 1

    report(doc, sectors_in, planets_in)

    if verify_only:
        if not MAP_OUT.exists():
            print("[map.json] --verify: not written yet")
            return 1
        current = load(MAP_OUT)
        if current == doc:
            print("[map.json] --verify: up to date")
            return 0
        print("[map.json] --verify: STALE - re-run without --verify")
        return 1

    MAP_OUT.parent.mkdir(parents=True, exist_ok=True)
    with MAP_OUT.open("w", encoding="utf-8", newline="\n") as fh:
        json.dump(doc, fh, indent=2)
        fh.write("\n")
    print(f"[map.json] wrote {MAP_OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
