class_name EntityIndex
extends RefCounted
## Resolves the ids a Command carries to live objects, by scanning the galaxy
## and roster (docs/m1-plan.md section 1). A scan is microseconds and keeps no
## bookkeeping that could drift between clients.


static func planet(name: String) -> Planet:
	if name.is_empty():
		return null
	return Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool: return p.Name == name)


static func planets(names: Array) -> Array:
	var out: Array = []
	for n in names:
		var p := planet(str(n))
		if p != null:
			out.append(p)
	return out


static func character(name: String) -> Character:
	if name.is_empty():
		return null
	return Lq.first_or_null(GameState.ActiveRoster, func(c: Character) -> bool: return c.Name == name)


static func characters(names: Array) -> Array:
	var out: Array = []
	for n in names:
		var c := character(str(n))
		if c != null:
			out.append(c)
	return out


## Fleets are named by their serial ("… Fleet_0004"), unique per game.
static func fleet(name: String) -> Fleet:
	if name.is_empty():
		return null
	for p in GameState.AllPlanets():
		for f in p.OrbitingFleets:
			if f.Name == name:
				return f
	return null


static func fleets(names: Array) -> Array:
	var out: Array = []
	for n in names:
		var f := fleet(str(n))
		if f != null:
			out.append(f)
	return out


static func unit(serial: int) -> Unit:
	if serial <= 0:
		return null
	for p in GameState.AllPlanets():
		for u in p.Garrison:
			if u.Serial == serial:
				return u
		for u in p.FighterSquadrons:
			if u.Serial == serial:
				return u
		for u in p.SpecForces():
			if u.Serial == serial:
				return u
		for f in p.OrbitingFleets:
			for s in f.Ships:
				if s.Serial == serial:
					return s
				for h in s.Hangar:
					if h.Serial == serial:
						return h
	for c in GameState.ActiveRoster:
		if c.Serial == serial:
			return c
	return null


static func units(serials: Array) -> Array:
	var out: Array = []
	for s in serials:
		var u := unit(int(s))
		if u != null:
			out.append(u)
	return out


static func facility(serial: int) -> Facility:
	if serial <= 0:
		return null
	for p in GameState.AllPlanets():
		for f in p.Facilities:
			if f.Serial == serial:
				return f
	return null


static func mission(serial: int) -> Mission:
	if serial <= 0:
		return null
	return Lq.first_or_null(MissionManager.Active(), func(m: Mission) -> bool: return m.Serial == serial)


static func message(serial: int) -> GameMessage:
	if serial <= 0:
		return null
	return Lq.first_or_null(EventBus.MessageLog, func(m: GameMessage) -> bool: return m.Serial == serial)


static func messages(serials: Array) -> Array:
	var out: Array = []
	for s in serials:
		var m := message(int(s))
		if m != null:
			out.append(m)
	return out


## A pending battle, by the world it is over and the two fleet names.
static func battle(where: String, ours: String, theirs: String) -> FleetBattleManager.BattleReport:
	for r in FleetBattleManager.AwaitingOrders():
		if r.Where.Name == where and r.Ours.Name == ours and r.Theirs.Name == theirs:
			return r
	return null


## Whatever the mission system accepts as a sabotage object: a facility or a unit.
static func target_object(args: Dictionary) -> Variant:
	if args.has("facility"):
		return facility(int(args["facility"]))
	if args.has("unit"):
		return unit(int(args["unit"]))
	return null


# --- the other direction: ids for the UI to put in a command ---

static func ids_of_units(list: Array) -> Array:
	var out: Array = []
	for u in list:
		out.append(u.Serial)
	return out


static func names_of(list: Array) -> Array:
	var out: Array = []
	for x in list:
		out.append(x.Name)
	return out


static func ids_of_messages(list: Array) -> Array:
	var out: Array = []
	for m in list:
		out.append(m.Serial)
	return out
