class_name UprisingTable
extends RefCounted
## backend/UprisingTable.cs - UPRIS1TB.DAT, the shipped "uprising start" table:
## a threshold -> value step lookup fed by the 1-10 roll of entries 175/176.
## Only "0 means nothing happens" is used; what 1 and 2 mean is NOT known.

static var _start: Array = []   # [[threshold, value], ...] ascending


static func IsLoaded() -> bool:
	return _start.size() > 0


## From the pack. UPRIS1TB is one of the mission outcome tables (SCHEMA.md
## section 9, id `uprising_start`); data/uprising_start.json was a byte-identical
## second copy of it, so there is no separate uprising.json - the pack already
## carries the table once.
static func LoadFromPack(pack: PackLoader.LoadedPack) -> void:
	_start.clear()
	if pack == null or not pack.MissionTables.has("uprising_start"):
		push_error("[Rules] the pack declares no 'uprising_start' table!")
		return
	var table: PackDefs.MissionTableDef = pack.MissionTables["uprising_start"]
	for e in Lq.order_by(table.Entries, func(e): return e.Threshold):
		_start.append([e.Threshold, e.Value])
	var parts := []
	for r in _start:
		parts.append("%d->%d" % [r[0], r[1]])
	print("[Rules] Uprising start table: %d rows, %s" % [_start.size(), ", ".join(parts)])


## The row with the greatest threshold at or below the roll; 0 below the lowest
## threshold and with no table at all - no uprising.
static func StartOutcome(roll: int) -> int:
	var outcome := 0
	for r in _start:
		if roll < r[0]:
			break
		outcome = r[1]
	return outcome
