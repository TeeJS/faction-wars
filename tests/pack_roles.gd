extends SceneTree
## Roles and behaviours (SCHEMA.md sections 6, 7, 9): the story parts, day-zero
## placement, the superweapon and the garrison troop are read off the pack, and
## the mission catalog joins engine behaviours to pack rows by `behaviour`.
## Every check here used to be a name literal in engine code.
##
##   Godot_console.exe --headless --path . -s tests/pack_roles.gd

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("  FAIL %s" % what)


func _init() -> void:
	await process_frame
	var engine: StrategicTickManager = GameSession.new_game("alliance", Enums.Difficulty.Medium, Enums.GalaxySize.Standard, 12345)
	_check(engine != null, "a game starts")

	# --- the story parts, by role ---
	var parts := {"pilgrim": "Luke Skywalker", "heir": "Leia Organa", "dark_lord": "Darth Vader",
		"dark_master": "Emperor Palpatine", "smuggler": "Han Solo", "companion": "Chewbacca"}
	for role in parts:
		var c := StoryManager.WhoHas(role)
		_check(c != null and c.Name == parts[role], "%s is %s (got %s)" % [role, parts[role], c.Name if c != null else "nobody"])

	# --- day-zero placement, by role ---
	var alliance := FactionRegistry.Playable[0]
	var empire := FactionRegistry.Playable[1]
	var first_id: String = alliance.StartingPlanets[0].Planet
	for c in GameState.ActiveRoster:
		if c.HasRole("starts_at_first_world"):
			_check(c.Attached is Planet and (c.Attached as Planet).PackId == first_id, "%s starts on the first world (%s)" % [c.Name, c.Attached.Name if c.Attached != null else "nowhere"])
			_check(c.Status == Enums.Status.AwaitingOrders, "%s is awaiting orders" % c.Name)
		if c.HasRole("starts_at_hq") and c.Faction == empire:
			_check(c.Attached is Planet and (c.Attached as Planet).PackId == empire.Hq.Planet, "%s starts at the fixed HQ (%s)" % [c.Name, c.Attached.Name if c.Attached != null else "nowhere"])
		if c.HasRole("starts_at_random_holding"):
			var where: Location = c.Attached
			var held := false
			if where is Planet:
				held = (where as Planet).ControllingFaction == empire
			elif where is Fleet:
				held = (where as Fleet).Faction == empire
			_check(held, "%s starts on an Imperial holding (%s)" % [c.Name, where.Name if where != null else "nowhere"])

	# --- the units, by role ---
	var ds: PackDefs.UnitDef = MilitaryCatalog.ById("death_star")
	var st: PackDefs.UnitDef = MilitaryCatalog.ById("stormtrooper_regiment")
	_check(ds != null and ds.Roles.has("superweapon"), "the Death Star is the superweapon")
	_check(st != null and st.Roles.has("garrison_troop"), "the Stormtrooper Regiment is the garrison troop")
	if ds != null:
		var u: Unit = MilitaryCatalog.Create(ds, empire, null)
		_check(u.HasRole("superweapon"), "a built Death Star answers HasRole(superweapon)")
		var r := MissionManager.CanSabotage(alliance, u, null)
		_check(not r.ok and r.error.contains("Death Star Sabotage"), "plain Sabotage refuses it and names the pack's mission (%s)" % r.error)

	# --- behaviours join engine types to pack rows ---
	var joins := {Enums.MissionType.SuperweaponSabotage: "death_star_sabotage",
		Enums.MissionType.SpecialPowerTraining: "jedi_training",
		Enums.MissionType.Diplomacy: "diplomacy", Enums.MissionType.Assassination: "assassination"}
	for type in joins:
		var d := MissionCatalog.DefFor(type)
		_check(d != null and d.Id == joins[type], "%s -> %s (got %s)" % [MissionCatalog.BehaviourName(type), joins[type], d.Id if d != null else "none"])
	_check(MissionCatalog.ByBehaviour("dagobah") != null and MissionCatalog.ByBehaviour("dagobah").Id == "dagobah", "dagobah stay is found by behaviour")
	_check(MissionCatalog.ByBehaviour("palace") != null, "palace stay is found by behaviour")
	_check(MissionCatalog.KnownBehaviours().has("superweapon_sabotage") and MissionCatalog.KnownBehaviours().has("incite_uprising"), "behaviour names are the enum members in snake_case")

	# --- mission tables follow the mission id ---
	var tables := {Enums.MissionType.Diplomacy: "diplomacy", Enums.MissionType.Rescue: "rescue",
		Enums.MissionType.Sabotage: "sabotage", Enums.MissionType.SuperweaponSabotage: "death_star_sabotage",
		Enums.MissionType.Espionage: "espionage", Enums.MissionType.Recruitment: "recruitment",
		Enums.MissionType.Abduction: "abduction", Enums.MissionType.InciteUprising: "incite_uprising",
		Enums.MissionType.SubdueUprising: "subdue_uprising", Enums.MissionType.Assassination: "assassination"}
	for type in tables:
		_check(MissionManager.TableFor(type) == tables[type], "table for %s is %s (got %s)" % [MissionCatalog.BehaviourName(type), tables[type], str(MissionManager.TableFor(type))])
	for type in [Enums.MissionType.Reconnaissance, Enums.MissionType.ShipDesignResearch, Enums.MissionType.SpecialPowerTraining]:
		_check(MissionManager.TableFor(type) == null, "%s rolls on no table" % MissionCatalog.BehaviourName(type))

	# --- HQ sabotage follows hq.kind (manual p108) ---
	var hidden_hq: Planet = null
	var fixed_hq: Planet = null
	for p in GameState.AllPlanets():
		for f in p.Facilities:
			if f.HasRole("headquarters"):
				if p.ControllingFaction == alliance and hidden_hq == null:
					hidden_hq = p
				elif p.ControllingFaction == empire and fixed_hq == null:
					fixed_hq = p
	_check(hidden_hq != null and fixed_hq != null, "both headquarters stand on day zero")
	if hidden_hq != null and fixed_hq != null:
		var hidden_fac: Facility = Lq.first_or_null(hidden_hq.Facilities, func(f): return f.HasRole("headquarters"))
		var fixed_fac: Facility = Lq.first_or_null(fixed_hq.Facilities, func(f): return f.HasRole("headquarters"))
		_check(MissionManager.CanSabotage(empire, hidden_fac, hidden_hq).ok, "the hidden (Alliance) HQ can be sabotaged")
		var r2 := MissionManager.CanSabotage(alliance, fixed_fac, fixed_hq)
		_check(not r2.ok, "the fixed (Imperial) HQ cannot (%s)" % r2.error)

	# --- the Emperor cannot be trained ---
	var emperor := StoryManager.WhoHas("dark_master")
	if emperor != null:
		_check(not MissionManager.CanBeSpecialPowerStudent(emperor), "the dark_master is not a student")

	# --- the economy's facilities, by role (BACKLOG #37) ---
	_check(FacilityCatalog.FamilyForRole("extracts_raw") == "mine", "the extractor is the mine (got '%s')" % FacilityCatalog.FamilyForRole("extracts_raw"))
	_check(FacilityCatalog.FamilyForRole("refines") == "refinery", "the refiner is the refinery (got '%s')" % FacilityCatalog.FamilyForRole("refines"))
	_check(FacilityCatalog.FamilyForRole("produces_unit") == "shipyard", "the unit producer is the shipyard")
	_check(FacilityCatalog.ProcessingRateForRole("extracts_raw") == FacilityCatalog.ProcessingRate("mine"), "the extractor's rate is the mine's")
	_check(FacilityCatalog.ProcessingRateForRole("refines") == FacilityCatalog.ProcessingRate("refinery"), "the refiner's rate is the refinery's")
	_check(FacilityCatalog.FamilyForRole("no_such_role").is_empty(), "an unknown role has no family")
	_check(IntelManager._producer_word("produces_unit", "x") == "orbital shipyard", "the intel queue word is 'orbital shipyard' (the original's name, TEXTSTRA 8448)")
	_check(IntelManager._producer_word("produces_troop", "x") == "training facility", "the intel queue word is 'training facility'")

	print("[pack_roles] %d checks, %d failed: %s" % [_checks, _fails, "PASS" if _fails == 0 else "FAIL"])
	quit(1 if _fails > 0 else 0)
