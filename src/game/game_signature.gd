class_name GameSignature
extends RefCounted
## backend/GameSignature.cs - a cheap fingerprint of everything the UI can show
## about a subject, derived from the DATA. Byte-for-byte the source's format:
## it is also the replay comparator (HANDOFF step 0b/2), so the C# and GDScript
## strings must be identical.

## The GID's active mode label, mirrored here because For(Sector) includes it.
## The source reads Gid.ActiveMode, whose default is the first mode of the first
## category, "Popular Support". The galaxy map (step 3) sets it.
static var GidLabel: String = "Popular Support"


static func ForPlanet(p: Planet) -> String:
	if p == null:
		return ""
	var sb := PackedStringArray()
	sb.append(p.Name)
	sb.append(":")
	sb.append(p.ControllingFaction.Id if p.ControllingFaction != null else "-")
	sb.append(":")
	for f in FactionRegistry.Playable:   # one chart bit per side, in pack order
		sb.append("1" if p.ExploredBy(f) else "0")
	sb.append("1" if p.IsInUprising else "0")
	sb.append(":")

	for f in FactionRegistry.Playable:
		sb.append(str(p.SupportFor(f)))
		sb.append(",")
	sb.append(":")

	for f in p.Facilities:
		sb.append(str(int(f.Type)))
		sb.append(".")
		sb.append(str(f.Tier))
		sb.append(",")
	sb.append(":")

	_queue(sb, p.BuildingQueue)
	_queue(sb, p.ShipyardQueue)
	_queue(sb, p.TrainingQueue)

	sb.append(str(p.Garrison.size()))
	sb.append(",")
	sb.append(str(p.FighterSquadrons.size()))
	sb.append(",")
	sb.append(str(p.OrbitingFleets.size()))
	sb.append(":")

	for u in p.SpecForces():
		sb.append(u.Name)
		sb.append(".")
		sb.append(JsonUtil.enum_name(Enums.Status, u.Status))
		sb.append(".")
		sb.append(str(u.DaysToDestination))
		sb.append(",")
	sb.append(":")

	for fl in p.OrbitingFleets:
		sb.append(fl.Name)
		sb.append(".")
		sb.append(JsonUtil.enum_name(Enums.Status, fl.Status))
		sb.append(",")
	sb.append(":")

	for c in GameState.ActiveRoster:
		if c.Attached == p or c.Destination == p:
			sb.append(c.Name)
			sb.append(".")
			sb.append(JsonUtil.enum_name(Enums.Status, c.Status))
			sb.append(".")
			sb.append(str(c.DaysToDestination))
			sb.append(".")
			sb.append(JsonUtil.enum_name(Enums.Rank, c.Rank))
			sb.append(".")
			sb.append("i" if c.IsInjured() else "-")
			sb.append("t" if c.TraitorRevealed else "-")
			sb.append(c.CapturedBy.Id if c.CapturedBy != null else "-")
			sb.append(",")
	sb.append(":")

	for m in MissionManager.Active():
		if m.Target == p:
			sb.append(JsonUtil.enum_name(Enums.MissionType, m.Type))
			sb.append(".")
			sb.append(str(m.DaysToTarget))
			sb.append(".")
			sb.append(str(m.Attempts))
			sb.append(".")
			sb.append("1" if m.Finished else "0")
			sb.append(",")

	return "".join(sb)


static func _queue(sb: PackedStringArray, q: Array) -> void:
	sb.append(str(q.size()))
	sb.append(",")
	for t in q:
		sb.append(str(t.Progress))
		sb.append("/")
		sb.append(str(t.TotalWork))
		sb.append(",")
	sb.append(":")


static func ForSector(s: Sector) -> String:
	if s == null:
		return ""
	var sb := PackedStringArray()
	sb.append(GidLabel)
	sb.append("|")
	for p in s.Planets:
		sb.append(ForPlanet(p))
		sb.append("|")
	return "".join(sb)


static func ForCharacter(c: Character) -> String:
	if c == null:
		return ""
	var where: String
	if c.Attached is Planet:
		where = (c.Attached as Planet).Name
	elif c.Attached != null:
		where = str(c.Attached)   # a Fleet prints as "Fleet", as C# ToString does
	else:
		where = "-"
	var dest := (c.Destination as Planet).Name if c.Destination is Planet else "-"
	return "%s.%s.%s.%d.%s.%s" % [c.Name, JsonUtil.enum_name(Enums.Status, c.Status), JsonUtil.enum_name(Enums.Rank, c.Rank), c.DaysToDestination, where, dest]


static func ForMessages() -> String:
	return "%d.%d" % [EventBus.MessageLog.size(), EventBus.UnreadTotal()]


## The per-day replay hash the source's --replay-log writes: SHA-256 over
## GameSignature of every sector and character plus the message count.
static func ReplayText(galaxy: Array) -> String:
	var sb := PackedStringArray()
	for s in galaxy:
		sb.append(ForSector(s))
	for c in GameState.ActiveRoster:
		sb.append(ForCharacter(c))
	sb.append(str(EventBus.MessageLog.size()))
	return "".join(sb)


static func ReplayHash(galaxy: Array) -> String:
	return ReplayText(galaxy).sha256_text().to_upper()
