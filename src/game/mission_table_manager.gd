class_name MissionTableManager
extends RefCounted
## backend/MissionTableManager.cs - THE MISSION OUTCOME TABLES (data/mission_tables.json,
## from the *MSTB.DAT and friends). Each table is a STEP FUNCTION: ascending
## thresholds, each carrying the value that applies from that threshold up.

## THE TABLE IDS ARE PACK DATA (SCHEMA.md section 9). These were the original
## .DAT filenames; the pack names each table for what it DOES and keeps the
## filename as `source_file`. The comment carries the id the original registers
## the table by at REBEXE.EXE 0x58B420.
const Diplomacy          := "diplomacy"            # id 20
const Rescue             := "rescue"               # id 21
const Sabotage           := "sabotage"             # id 22
const Espionage          := "espionage"            # id 23
const Recruitment        := "recruitment"          # id 24
const Abduction          := "abduction"            # id 25
const InciteUprising     := "incite_uprising"      # id 26
const SuperweaponSabotage := "death_star_sabotage" # id 27 - the PACK's flavour
const SubdueUprising     := "subdue_uprising"      # id 28
const Assassination      := "assassination"        # id 29

## NOT MISSION TYPES - the contests a mission passes THROUGH.
const Foil               := "foil"                 # id 12
const Decoy              := "decoy"                # id 10
const TroopDecoy         := "troop_decoy"          # id 11
const Evasion            := "evasion"              # id 13
const Escape             := "escape"               # id 44

## Not a contest either - an EVENT CODE lookup. See InformantManager.
const Informants         := "informants"           # id 42

static var _tables: Dictionary = {}   # name -> MissionTableData


static func IsLoaded() -> bool:
	return _tables.size() > 0


static func LoadFromPack(pack: PackLoader.LoadedPack) -> void:
	_tables.clear()
	if pack == null:
		push_error("[MissionTableManager] no pack loaded!")
		return
	_tables = pack.MissionTables
	var rows := 0
	for t in _tables.values():
		rows += (t as PackDefs.MissionTableDef).Entries.size()
	print("Successfully loaded %d mission tables (%d rows) from the pack." % [_tables.size(), rows])


## The step lookup: the value for the highest threshold the score clears; below
## the first threshold, the first entry's value stands. -1 when the table is
## missing entirely.
static func Lookup(table: Variant, score: int) -> int:
	if table == null or not _tables.has(table):
		return -1
	var t: PackDefs.MissionTableDef = _tables[table]
	if t.Entries == null or t.Entries.is_empty():
		return -1
	var value: int = t.Entries[0].Value
	for e in t.Entries:
		if score >= e.Threshold:
			value = e.Value
	return value


static func Has(table: Variant) -> bool:
	return table != null and _tables.has(table)


## THE OTHER READER: a row looked up BY KEY against the threshold column
## (INFORMTB). -1 when the table or the row is missing.
static func Row(table: Variant, key: int) -> int:
	if table == null or not _tables.has(table):
		return -1
	var t: PackDefs.MissionTableDef = _tables[table]
	if t.Entries == null:
		return -1
	for e in t.Entries:
		if e.Threshold == key:
			return e.Value
	return -1
