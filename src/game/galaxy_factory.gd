class_name GalaxyFactory
extends RefCounted
## backend/GalaxyFactory.cs - the map, from the loaded pack's map.json, trimmed
## to the sectors the chosen galaxy size uses.
##
## The size membership used to be TWENTY LITERAL SECTOR NAMES in this file - the
## engine knew which Star Wars sectors a "standard" galaxy contained. It is pack
## data now: each sector declares the smallest size it appears in (SCHEMA.md
## section 4), and sizes are cumulative.


## Sizes rank by their position in pack.json's setup.galaxy_sizes, and
## Enums.GalaxySize indexes that same list. The coupling is deliberate and
## checked below: the enum is still engine-side, so a pack that offers a
## different NUMBER of sizes is a later phase, not this one.
static func _rank_of(size_id: String, sizes: Array[String]) -> int:
	return sizes.find(size_id)


static func LoadFromPack(pack: PackLoader.LoadedPack, size: int) -> Array[Sector]:
	var out: Array[Sector] = []
	if pack == null or pack.Map == null:
		push_error("CRITICAL: the loaded pack has no map.json!")
		return out

	var sizes: Array[String] = pack.Manifest.Setup.GalaxySizes if pack.Manifest.Setup != null else []
	if sizes.is_empty():
		push_error("CRITICAL: pack.json declares no setup.galaxy_sizes!")
		return out
	if size < 0 or size >= sizes.size():
		push_error("CRITICAL: galaxy size %d is outside the %d sizes the pack offers (%s)." % [size, sizes.size(), ", ".join(sizes)])
		return out
	var want := size

	# Sectors in FILE ORDER - day zero walks the galaxy in this order and
	# consumes the PRNG as it goes, so the order is part of the simulation.
	var sector_map: Dictionary = {}   # pack sector id -> Sector
	for sd in pack.Map.Sectors:
		if _rank_of(sd.MinSize, sizes) > want:
			continue
		var s := Sector.new()
		s.SectorId = sd.SourceId
		s.Name = sd.DisplayName
		s.GalaxyRing = sd.Ring
		s.StartsNeutral = sd.StartsNeutral
		s.MapX = sd.MapX
		s.MapY = sd.MapY
		sector_map[sd.Id] = s

	for pd in pack.Map.Planets:
		if not sector_map.has(pd.Sector):
			continue
		var p := Planet.new()
		p.Name = pd.DisplayName
		p.StartsInhabited = pd.StartsInhabited
		p.IsInhabited = pd.StartsInhabited
		p.MapX = float(pd.MapX)
		p.MapY = float(pd.MapY)
		# The source does NOT set Planet.SectorId here; mirrored exactly (it is
		# what BombardmentManager.SectorPeers reads, so the omission is behaviour).
		sector_map[pd.Sector].Planets.append(p)

	for s in sector_map.values():
		out.append(s)
	return out
