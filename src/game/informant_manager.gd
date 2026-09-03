class_name InformantManager
extends RefCounted
## backend/InformantManager.cs - INFORMANTS, INFORMTB.DAT (table id 42), manual
## p104: free intelligence, unprompted, partial; unrest leaks more of it. A direct
## row lookup by key = rand(0..entry 178) + entry 177; codes 1, 2 and 7 are drawn
## and deliberately not reproduced (see the source header).

static var _next_tip: Dictionary = {}   # faction id -> day


static func Reset() -> void:
	_next_tip.clear()


static func ProcessDay(galaxy: Array, day: int, rng: Prng) -> void:
	if galaxy == null:
		return
	for listener in FactionRegistry.Playable:
		if not _next_tip.has(listener.Id):
			_next_tip[listener.Id] = day + Schedule(listener, rng)
			continue
		if day < _next_tip[listener.Id]:
			continue
		_next_tip[listener.Id] = day + Schedule(listener, rng)
		var target := PickSystem(galaxy, listener, rng)
		if target == null:
			continue
		Deliver(listener, target, day, rng)


static func Schedule(f: Faction, rng: Prng) -> int:
	return max(1, RuleManager.Roll(RuleId.InformantFrequencyBase, RuleId.InformantFrequencySpread, rng, f))


## "Informants on ENEMY systems"; a system in uprising is drawn FIRST (⚠ ours).
static func PickSystem(galaxy: Array, listener: Faction, rng: Prng) -> Planet:
	var neutral_id: String = FactionRegistry.Neutral.Id if FactionRegistry.Neutral != null else ""
	var enemy := []
	for s in galaxy:
		for p in s.Planets:
			if p.IsInhabited and p.ControllingFaction != null and p.ControllingFaction != listener and p.ControllingFaction.Id != neutral_id:
				enemy.append(p)
	if enemy.is_empty():
		return null
	var restive := Lq.where(enemy, func(p): return p.IsInUprising)
	var pool := restive if not restive.is_empty() else enemy
	return pool[rng.NextMax(pool.size())]


static func Deliver(listener: Faction, target: Planet, day: int, rng: Prng) -> void:
	var key := RuleManager.Roll(RuleId.InformantEventIndexBase, RuleId.InformantEventIndexSpread, rng, listener)
	var code := MissionTableManager.Row(MissionTableManager.Informants, key)
	if code < 0:
		return
	var cats := CategoriesFor(code)
	print("[Informants] %s: key %d -> code %d on %s -> %s." % [listener.DisplayName, key, code, target.Name,
		"nothing usable" if cats.is_empty() else Lq.join(Lq.select(cats, func(c): return JsonUtil.enum_name(Enums.IntelCategory, c)))])
	if cats.is_empty():
		return
	IntelManager.Capture(listener, target, day, cats)
	if not GameSettings.IsHuman(listener):
		return
	var lines := 0
	for s in IntelManager.AllSections:
		if cats.has(IntelManager.CategoryOf(s)):
			lines += IntelManager.View(listener, target, s).Lines.size()
	var pretty := Lq.select(cats, func(c): return "  - %s" % Pretty(c))
	var msg := GameMessage.new("Word from %s" % target.Name,
		"An informant on %s has passed us what they could:\n\n%s\n\n%s The System Defenses window will show it, dated today - it will not update itself as things change there.%s" % [
			target.Name, "\n".join(pretty),
			"They report nothing of that kind on the system." if lines == 0 else "%d item%s noted." % [lines, "" if lines == 1 else "s"],
			"\n\nThe system is in revolt, which is why we are hearing from it." if target.IsInUprising else ""],
		Enums.MessageCategory.Missions, day, target)
	msg.Type = Enums.MessageType.InformantReport
	EventBus.Tell(listener, msg)


## The decoded jump table (0x50E18C).
static func CategoriesFor(code: int) -> Array:
	match code:
		3: return [Enums.IntelCategory.MilitaryUnits, Enums.IntelCategory.DefensiveFacilities]
		4: return [Enums.IntelCategory.Characters, Enums.IntelCategory.ProductionFacilities]
		8: return IntelManager.EspionageCategories
		9: return [Enums.IntelCategory.SpecForces]
		10: return IntelManager.EspionageCategories
	return []


static func Pretty(c: int) -> String:
	match c:
		Enums.IntelCategory.SystemStatus:         return "the state of the system"
		Enums.IntelCategory.MilitaryUnits:        return "troops, fighters and ships"
		Enums.IntelCategory.DefensiveFacilities:  return "shields and orbital batteries"
		Enums.IntelCategory.ProductionFacilities: return "mines, refineries and yards"
		Enums.IntelCategory.SpecForces:           return "special forces present"
		Enums.IntelCategory.Characters:           return "who is on the system"
		Enums.IntelCategory.Manufacturing:        return "what is being built"
	return JsonUtil.enum_name(Enums.IntelCategory, c)
