class_name AgentDroid
extends RefCounted
## backend/AgentDroid.cs - THE AGENT DROID'S TWO AUTOMATIONS, manual p088 and p128.
## C-3PO for the Alliance, IMP-22 for the Empire. Both OFF by default. They never
## move a unit, never attack, never make a strategic choice: they place build
## orders in an order the manual writes down.

static var _manage_production: Dictionary = {}   # faction id -> bool
static var _manage_garrisons: Dictionary = {}


static func Reset() -> void:
	_manage_production.clear()
	_manage_garrisons.clear()


static func ManagingProduction(f: Faction) -> bool:
	return f != null and _manage_production.get(f.Id, false)


static func ManagingGarrisons(f: Faction) -> bool:
	return f != null and _manage_garrisons.get(f.Id, false)


static func SetManageProduction(f: Faction, on: bool) -> void:
	if f == null:
		return
	_manage_production[f.Id] = on
	print("[Agent] %s: Manage Production %s." % [f.DisplayName, "ON" if on else "off"])


static func SetManageGarrisons(f: Faction, on: bool) -> void:
	if f == null:
		return
	_manage_garrisons[f.Id] = on
	print("[Agent] %s: Manage Garrisons %s." % [f.DisplayName, "ON" if on else "off"])


## The agent's own name, for the menu and the messages it files - the pack's
## (factions.json `agent_name`; C-3PO and IMP-22 in the Star Wars pack).
static func NameFor(f: Faction) -> String:
	if f != null and not f.AgentName.is_empty():
		return f.AgentName
	return "Agent"


static func ProcessDay(galaxy: Array, day: int) -> void:
	if galaxy == null:
		return
	for f in FactionRegistry.Playable:
		if ManagingProduction(f):
			RunProduction(galaxy, f, day)
		if ManagingGarrisons(f):
			RunGarrisons(galaxy, f, day)


## MANAGE PRODUCTION - manual p088: mines and refineries only, into open slots,
## nearest the construction yards first, kept in balance galaxy-wide, never scrap.
static func RunProduction(galaxy: Array, f: Faction, _day: int) -> void:
	var all := GameState.AllPlanets()
	var yards := Lq.where(all, func(p): return p.ControllingFaction == f and p.ConstructionYards() > 0)
	if yards.is_empty():
		return
	var held := Lq.where(all, func(p): return p.ControllingFaction == f)
	var ours := Lq.order_by(held, func(p):
		var best := 0x7FFFFFFF
		for y in yards:
			best = min(best, y.DeploymentDaysTo(p))
		return best)

	var mines := Lq.sum(ours, func(p): return p.Mines())
	var refineries := Lq.sum(ours, func(p): return p.Refineries())

	for p in ours:
		if not p.HasIdleConstructionYards():
			continue
		var want_mine: bool = mines <= refineries and p.FreeMineSlots() > 0
		var type := "mine" if want_mine else "refinery"
		if not p.TryQueueFacility(type, 1, p).ok:
			continue
		if want_mine:
			mines += 1
		else:
			refineries += 1
		print("[Agent] %s ordered a %s on %s (mines %d / refineries %d)." % [NameFor(f), Facility.NameOf(type), p.Name, mines, refineries])


## MANAGE GARRISONS - manual p128's numbered priority list, as a sort. Builds
## troops, never moves them. One order a day.
static func RunGarrisons(galaxy: Array, f: Faction, _day: int) -> void:
	var ours := Lq.where(GameState.AllPlanets(), func(p): return p.ControllingFaction == f)
	if ours.is_empty():
		return

	# The cheapest trooper regiment this side can train. ⚠ That choice is ours.
	var troopers := Lq.where(MilitaryCatalog.All(), func(u): return u.Kind == "troop" and MilitaryCatalog.CanBeBuiltBy(u, f))
	var sorted := Lq.order_by(troopers, func(u): return u.ConstructionCost)
	if sorted.is_empty():
		return
	var trooper: PackDefs.UnitDef = sorted[0]

	var rows := []
	for p in ours:
		var short: int = p.GarrisonRequirement() - p.TrooperRegiments()
		var rioting: bool = p.IsInUprising
		var bare: bool = p.TrooperRegiments() == 0
		var industry: int = p.Shipyards() + p.TrainingFacilities() + p.ConstructionYards()
		if rioting or bare or short > 0 or industry > 0:
			rows.append({ "planet": p, "short": short, "rioting": rioting, "bare": bare, "industry": industry })
	var needy := Lq.order_by(rows, func(x): return [1 if x.rioting else 0, 1 if x.bare else 0, x.short, x.industry], true)

	for x in needy:
		var p: Planet = x.planet
		# ⚠ "STRONGER DEFENSE" HAS NO NUMBER: one regiment above the requirement
		# per producing facility is ours.
		var want: int = max(1, p.GarrisonRequirement()) + x.industry
		if p.TrooperRegiments() + Pending(p) >= want:
			continue
		var free := Lq.where(ours, func(q): return q.HasIdleTroopTraining())
		var factories := Lq.order_by(free, func(q): return q.DeploymentDaysTo(p))
		if factories.is_empty():
			return   # nothing free anywhere; try again tomorrow
		var factory: Planet = factories[0]
		if not factory.TryQueueUnit(trooper, p).ok:
			return
		print("[Agent] %s ordered a %s from %s for %s (%d/%d%s)." % [NameFor(f), trooper.DisplayName, factory.Name, p.Name, p.TrooperRegiments(), want, ", IN UPRISING" if x.rioting else ""])
		return   # one order a day


## Regiments already ordered and aimed at this world but not standing on it yet:
## still being trained, or built and in transit (see the source for the soak bug).
static func Pending(destination: Planet) -> int:
	var worlds := GameState.AllPlanets()
	var queued := 0
	var flying := 0
	for p in worlds:
		for t in p.TrainingQueue:
			if t.Destination == destination and t.UnitRule != null and t.UnitRule.Kind == "troop":
				queued += 1
		for t in p.InTransit():
			if t.Destination == destination and t.UnitRule != null and t.UnitRule.Kind == "troop":
				flying += 1
	return queued + flying
