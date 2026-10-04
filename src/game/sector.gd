class_name Sector
extends RefCounted
## backend/Sector.cs

var SectorId: int
var Name: String
var GalaxyRing: int
var StartsNeutral: bool
## Charted for every side at day zero, whatever the ring (map.json
## `starts_explored`). Read by day zero only; a world's chart is its own after.
var StartsExplored: bool
var MapX: int
var MapY: int
var MinX: float
var MaxX: float
var MinY: float
var MaxY: float

var Planets: Array[Planet] = []
