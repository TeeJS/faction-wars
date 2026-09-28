extends SceneTree
## Importing a Star Wars: Rebellion saved game (PROJECT.md tests 1, 2 and 4), on
## the player's own saves when the original is installed (they are not in the
## repo; without them this skips, exit 0):
##   1. the built game matches the save, system by system, fleet by fleet,
##      person by person, order by order - the same lines from both sides;
##   4. every object in the save is carried or named in the report;
##   2. Import Game -> load -> play a day -> Save -> load through GameManager
##      gives the same day and the same day hash.
## Its saves and art go to scratch folders.
##
##   .\tools\run-gd.ps1 tests/original_import.gd
##   .\tools\run-gd.ps1 tests/original_import.gd -- --dir=C:/path/to/SaveGame

const OriginalSave := preload("res://src/data/original_save.gd")
const OriginalImport := preload("res://src/game/original_import.gd")
const Art := preload("res://src/ui/artwork.gd")
const DEFAULT_DIR := "C:/Program Files (x86)/GOG Galaxy/Games/Star Wars - Rebellion/SaveGame"

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[original_import] ok   %s" % what)
	else:
		_fails += 1
		print("[original_import] FAIL %s" % what)


func _init() -> void:
	await process_frame
	var dir := DEFAULT_DIR
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dir="):
			dir = a.substr(6)
	var files: Array = []
	if DirAccess.dir_exists_absolute(dir):
		for f in DirAccess.get_files_at(dir):
			if f.to_upper().begins_with("SAVEGAME."):
				files.append("%s/%s" % [dir, f])
	if files.is_empty():
		print("[original_import] no saved games of the original at %s - skipped" % dir)
		quit(0)
		return
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = "user://test-original-import-art"
	SaveManager.Dir = "user://test-original-import-saves"
	_remove(SaveManager.Dir)
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()

	for path: String in files:
		_one(path)
	await _round_trip(files[0])

	_remove(SaveManager.Dir)
	print("[original_import] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


# ---- 1 and 4: the built game against the save ------------------------------------------

func _one(path: String) -> void:
	var f: String = path.get_file()
	var bytes := FileAccess.get_file_as_bytes(path)
	var g: Dictionary = OriginalSave.Read(bytes)
	var plan: Dictionary = OriginalImport.Plan(g)
	_check(plan["ok"], "%s: can be imported (%s)" % [f, plan["error"]])
	if not plan["ok"]:
		return
	var engine: StrategicTickManager = GameSession.start_from_original(bytes, OriginalImport.SeedOf(bytes))
	_check(engine != null, "%s: builds" % f)
	if engine == null:
		return
	var day: int = int(g["game"]["day"])
	_check(StrategicTickManager.Today == day + 1 and StrategicTickManager.Shown(StrategicTickManager.Today) == day,
		"%s: on the original's day (shown Day %d)" % [f, StrategicTickManager.Shown(StrategicTickManager.Today)])
	_check(GameSettings.PlayerFaction != null and GameSettings.PlayerFaction.Id == plan["side"], "%s: as %s" % [f, plan["side"]])
	_check(OriginalImport.LastUnaccounted.is_empty(), "%s: every object carried or reported (%s)" % [f, ", ".join(OriginalImport.LastUnaccounted)])

	var want := _dump_save(g)
	var got := _dump_game()
	var diff := 0
	for i in maxi(want.size(), got.size()):
		var a: String = want[i] if i < want.size() else "<none>"
		var b: String = got[i] if i < got.size() else "<none>"
		if a != b:
			diff += 1
			if diff <= 12:
				print("    save: %s\n    game: %s" % [a, b])
	_check(diff == 0, "%s: the game matches the save, %d lines (%d differ)" % [f, want.size(), diff])

	var h1 := GameSignature.ReplayHash(GameState.ActiveGalaxy)
	engine = GameSession.start_from_original(bytes, OriginalImport.SeedOf(bytes))
	_check(GameSignature.ReplayHash(GameState.ActiveGalaxy) == h1, "%s: the same file builds the same game" % f)
	for line in OriginalImport.LastReport:
		print("    | %s" % line)
	_sightings(g, f)
	if str(g["name"]) == "1" and day == 116:
		_spot_checks(engine)
	if str(g["name"]) == "start" and day == 5:
		_spot_checks_start()

	# It plays on: sixty days of this engine's rules on the imported state.
	var start: int = StrategicTickManager.Today
	for _i in 60:
		engine.AdvanceDay()
		if VictoryManager.IsOver():
			break
	_check(StrategicTickManager.Today > start, "%s: plays on (%d days, to Day %d)" % [f, StrategicTickManager.Today - start, StrategicTickManager.Shown(StrategicTickManager.Today)])


## The save, as lines: who holds each system; each fleet and its ships; where
## each person is and what they are doing; each order being built.
func _dump_save(g: Dictionary) -> Array:
	var lines: Array = []
	var objs: Dictionary = {}
	var parent: Dictionary = {}
	for e: Dictionary in OriginalSave.Walk(g["views"][0]):
		objs[OriginalSave.Key(e["o"])] = e["o"]
		parent[OriginalSave.Key(e["o"])] = e["parent"]
	var pack := FactionRegistry.Pack
	var planet_name := {}
	for pd in pack.Map.Planets:
		planet_name[pd.SourceId] = pd.DisplayName
	var char_id := {}
	for cd in pack.Characters:
		char_id[cd.SourceId] = cd.Id
	var system_of := func(k: int) -> String:
		var o: Dictionary = objs.get(k, {})
		while not o.is_empty() and not (int(o["class"]) in [0x90, 0x92]):
			o = parent[OriginalSave.Key(o)]
		return planet_name.get(int(o["template"]), "-") if not o.is_empty() else "-"
	var owner := func(o: Dictionary) -> String:
		var s := OriginalSave.Owner(int(o["control_kind"]))
		return "neutral" if s == "none" else s
	var completed := func(o: Dictionary) -> bool:
		return OriginalSave.Has(int(o["status"]), OriginalSave.BASE_STATUS, "completed")
	for k in objs:
		var o: Dictionary = objs[k]
		if int(o["class"]) in [0x90, 0x92]:
			lines.append("system %s %s support %d" % [planet_name[int(o["template"])], owner.call(o), int(o["loyalty"])])
	for k in objs:
		var o: Dictionary = objs[k]
		if int(o["class"]) != 0x08:
			continue
		var ships: Array = []
		for s: Dictionary in o["children"]:
			if int(s["class"]) in [0x14, 0x18] and completed.call(s):
				ships.append(str(s.get("name", "?")))
		if not ships.is_empty():
			var moving := OriginalSave.Has(int(o["status"]), OriginalSave.BASE_STATUS, "enroute")
			lines.append("fleet %s %s at %s%s: %s" % [str(o["name"]), owner.call(o), system_of.call(k), (" in %d days" % (int(o["eta"]) - int(g["game"]["day"]))) if moving else "", ", ".join(ships)])
	for k in objs:
		var o: Dictionary = objs[k]
		var c: int = int(o["class"])
		if not (c in [0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x38]):
			continue
		var p: Dictionary = parent[k]
		if int(p["class"]) == 0xf2:
			lines.append("person %s not recruited" % char_id[int(o["template"])])
			continue
		var cf: int = int(o["character_flags"])
		var captured := OriginalSave.Has(cf, OriginalSave.CHARACTER_FLAGS, "captured")
		lines.append("person %s at %s%s dip %d esp %d com %d lead %d force %d injury %d" % [char_id[int(o["template"])], system_of.call(k),
			" captured" if captured else "", int(o["base_diplomacy"]), int(o["base_espionage"]), int(o["base_combat"]),
			int(o["base_leadership"]), int(o["force"]), int(o["injury"])])
	for k in objs:
		var o: Dictionary = objs[k]
		if int(o["class"]) == 0xf3:
			lines.append("side %s raw %d refined %d" % [owner.call(o), int(o["raw_material"]), int(o["refined_material"])])
	for k in objs:
		var o: Dictionary = objs[k]
		if int(o["class"]) in [0xa0, 0xa2, 0xa4] and int(o["remaining_count"]) > 0:
			lines.append("order %s at %s x%d for %s" % [str(o["product_name"]), system_of.call(k), int(o["remaining_count"]), system_of.call(int(o["deployment_key"]))])
	lines.sort()
	return lines


## The built game, as the same lines.
func _dump_game() -> Array:
	var lines: Array = []
	var pack := FactionRegistry.Pack
	var planet_name := {}
	for pd in pack.Map.Planets:
		planet_name[pd.Id] = pd.DisplayName
	for p: Planet in GameState.AllPlanets():
		lines.append("system %s %s support %d" % [p.Name, p.ControllingFaction.Id, p.SupportFor(FactionRegistry.ById("alliance"))])
		for f: Fleet in p.OrbitingFleets:
			var ships: Array = []
			for s in f.Ships:
				ships.append(s.Name)
			lines.append("fleet %s %s at %s%s: %s" % [f.Name, f.Faction.Id, p.Name, (" in %d days" % f.DaysToDestination) if f.Status == Enums.Status.Enroute else "", ", ".join(ships)])
		for q in [p.BuildingQueue, p.ShipyardQueue, p.TrainingQueue]:
			var runs := {}
			var order: Array = []
			for t: ConstructionTask in q:
				var k := "%s|%s" % [t.DisplayName(), t.Destination.Name]
				if not runs.has(k):
					order.append(k)
				runs[k] = int(runs.get(k, 0)) + 1
			for k: String in order:
				var parts := k.split("|")
				lines.append("order %s at %s x%d for %s" % [parts[0], p.Name, runs[k], parts[1]])
	for f: Faction in FactionRegistry.Playable:
		lines.append("side %s raw %d refined %d" % [f.Id, Economy.For(f).RawMaterials, Economy.For(f).RefinedMaterials])
	for c: Character in GameState.ActiveRoster:
		if c.Attached == null:
			lines.append("person %s not recruited" % c.PackId)
			continue
		var where: Planet = c.Attached if c.Attached is Planet else (c.Attached as Fleet).Attached
		var mission: Mission = Lq.first_or_null(MissionManager._active, func(m): return m.Team.has(c))
		# A team in transit waits at home in this engine; the original files it
		# under its target.
		if mission != null and not mission.Arrived():
			where = mission.Target
		lines.append("person %s at %s%s dip %d esp %d com %d lead %d force %d injury %d" % [c.PackId, where.Name,
			" captured" if c.IsCaptured() else "", c.DiplomacyRating, c.EspionageRating, c.CombatRating,
			c.LeadershipRating, c.SpecialPowerLevel if c.IsKnownSpecialPowerUser or c.SpecialPowerLevel == 0 or not _latent(c) else 0, c.Injury])
	lines.sort()
	return lines


## Each side is shown its own copy of every world it does not hold, as the
## original shows it: who was seen there, how many regiments, how many
## facilities - counted off the save, not the importer.
func _sightings(g: Dictionary, f: String) -> void:
	var pack := FactionRegistry.Pack
	var world := {}
	for pd in pack.Map.Planets:
		for p: Planet in GameState.AllPlanets():
			if p.PackId == pd.Id:
				world[pd.SourceId] = p
	var person := {}
	for cd in pack.Characters:
		person[cd.SourceId] = cd.DisplayName
	var worlds := 0
	var wrong: Array = []
	for side in [[1, "alliance"], [2, "empire"]]:
		var viewer := FactionRegistry.ById(side[1])
		for e: Dictionary in OriginalSave.Walk(g["views"][side[0]]):
			var s: Dictionary = e["o"]
			var p: Planet = world.get(int(s["template"])) if int(s["class"]) in [0x90, 0x92] else null
			if p == null or p.ControllingFaction == viewer or not p.ExploredBy(viewer):
				continue
			worlds += 1
			var names: Array = []
			var regiments := 0
			var facilities := 0
			for k: Dictionary in s["children"]:
				var c: int = int(k["class"])
				if c >= 0x30 and c <= 0x38 and OriginalSave.Owner(int(k["control_kind"])) != side[1]:
					names.append(person.get(int(k["template"]), "?"))
				elif c == 0x10:
					regiments += 1
				elif c >= 0x20 and c <= 0x2d:
					facilities += 1
			names.sort()
			var seen: Array = IntelManager.SeenData(viewer, p, Enums.IntelSection.Characters).get("people", []).map(func(x): return str(x["name"]))
			seen.sort()
			var got_regiments: int = IntelManager.SeenData(viewer, p, Enums.IntelSection.Troopers).get("regiments", []).size()
			var got_facilities: int = IntelManager.View(viewer, p, Enums.IntelSection.ProductionFacilities).Lines.size() \
				+ IntelManager.View(viewer, p, Enums.IntelSection.DefensiveFacilities).Lines.size()
			if seen != names or got_regiments != regiments or got_facilities != facilities:
				wrong.append("%s's %s: people %s / %s, regiments %d / %d, facilities %d / %d" % [side[1], p.Name, str(seen), str(names), got_regiments, regiments, got_facilities, facilities])
	_check(worlds > 0 and wrong.is_empty(), "%s: each side is shown its own copy of the %d worlds it does not hold (%s)" % [f, worlds, "; ".join(wrong)])


## TeeJ's day-5 Empire save, against his screenshots of the original
## (2026-09-28): what the Empire is shown of three Alliance worlds.
func _spot_checks_start() -> void:
	var empire := FactionRegistry.ById("empire")
	var at := func(id: String) -> Planet:
		return Lq.first_or_null(GameState.AllPlanets(), func(p): return p.PackId == id)
	var named := func(ids: Array) -> Array:
		var out: Array = ids.map(func(id): return FactionRegistry.Pack.Characters.filter(func(cd): return cd.Id == id)[0].DisplayName)
		out.sort()
		return out
	var yavin: Planet = at.call("yavin")
	var people: Array = IntelManager.SeenData(empire, yavin, Enums.IntelSection.Characters).get("people", []).map(func(x): return str(x["name"]))
	people.sort()
	_check(people == named.call(["leia_organa", "luke_skywalker", "han_solo", "wedge_antilles", "chewbacca", "jan_dodonna"])
		and IntelManager.View(empire, yavin, Enums.IntelSection.SpecForces).Lines == ["Bothan Spies"],
		"Yavin: the Empire is shown Leia, Luke, Han, Wedge, Chewbacca, Dodonna and the Bothan Spies (%s)" % str(people))
	var umgul: Planet = at.call("umgul")
	var troops := IntelManager.View(empire, umgul, Enums.IntelSection.Troopers)
	_check(int(IntelManager.SeenData(empire, umgul, Enums.IntelSection.DefensiveFacilities).get("shields", 0)) == 2
		and troops.Known and troops.Lines.is_empty() and not umgul.Troopers().is_empty(),
		"Umgul: the Empire is shown two shields and no troops (the regiment there now unseen)")
	var chandrila: Planet = at.call("chandrila")
	var counts: Dictionary = IntelManager.SeenData(empire, chandrila, Enums.IntelSection.ProductionFacilities).get("counts", {})
	_check(IntelManager.View(empire, chandrila, Enums.IntelSection.Troopers).Lines.is_empty() and not chandrila.Troopers().is_empty()
		and int(counts.get("mine", 0)) == 2 and int(counts.get("refinery", 0)) == 5,
		"Chandrila: the Empire is shown 2 mines, 5 refineries and no troops (%s)" % str(counts))


## A latent user the original had not measured (the importer rolled its level).
func _latent(c: Character) -> bool:
	return not c.IsKnownSpecialPowerUser and c.SpecialPowerLevel > 0


## TeeJ's day-116 Alliance save: values read from the save by hand
## (tools/savegame/rebsave.py, 2026-09-27) rather than by the importer.
func _spot_checks(engine: StrategicTickManager) -> void:
	var person := func(id: String) -> Character:
		return Lq.first_or_null(GameState.ActiveRoster, func(c): return c.PackId == id)
	var chewie: Character = person.call("chewbacca")
	_check(chewie.IsCaptured() and chewie.CapturedBy.Id == "empire" and (chewie.Attached as Planet).PackId == "balmorra"
		and chewie.NextEscapeAttemptOn == 506, "Chewbacca: held by the Empire at Balmorra, next escape try on the original's day 505")
	var rescue: Mission = Lq.first_or_null(MissionManager._active, func(m): return m.Type == Enums.MissionType.Rescue)
	_check(rescue != null and rescue.TargetCharacter == chewie and rescue.Team.size() == 2 and rescue.Decoys.size() == 1
		and rescue.Decoys[0].PackId == "han_solo", "the rescue: Garm Bel Iblis, with Han Solo as the decoy, for Chewbacca")
	var rieekan: Mission = Lq.first_or_null(MissionManager._active, func(m): return m.Team.has(person.call("carlist_rieekan")))
	_check(rieekan != null and rieekan.Type == Enums.MissionType.Diplomacy and rieekan.Arrived() and rieekan.DaysOnStation == 4,
		"Rieekan: at work on Diplomacy at Sullust, next attempt on the original's day 121 (resolves on the 5th tick)")
	var leia: Character = person.call("leia_organa")
	var leia_m: Mission = Lq.first_or_null(MissionManager._active, func(m): return m.Team.has(leia))
	_check(leia_m != null and leia_m.DaysToTarget == 2 and leia.Status == Enums.Status.Enroute, "Leia: 2 days out from Drall on Diplomacy")
	var alliance := FactionRegistry.ById("alliance")
	_check(ResearchManager.Bank(alliance)[Enums.ResearchTrackKind.ShipDesign] == 12
		and ResearchManager.IsUnlockedUnit(alliance, MilitaryCatalog.ById("nebulon_b_frigate"))
		and not ResearchManager.IsUnlockedUnit(alliance, MilitaryCatalog.ById("mon_calamari_cruiser")),
		"Alliance ship research at order 1: the Nebulon-B, not yet the Mon Calamari cruiser")
	var empire := FactionRegistry.ById("empire")
	_check(Economy.For(alliance).RawMaterials == 1 and Economy.For(alliance).RefinedMaterials == 0
		and Economy.For(empire).RawMaterials == 0 and Economy.For(empire).RefinedMaterials == 12,
		"material on hand: Alliance 1 raw, 0 refined; Empire 0 raw, 12 refined")
	# The original's messages: its three open message windows, word for word.
	var msgs: Array = EventBus.VisibleMessages().filter(func(m): return m.Title != "Game imported")
	var titles: Array = msgs.map(func(m): return m.Title)
	_check(titles == ["Diplomacy Mission Report", "Ship Design Research Mission Report", "Guerrillas Deployed to Selonia"],
		"the original's three messages come across (%s)" % str(titles))
	if msgs.size() == 3:
		var dip: GameMessage = msgs[0]
		_check(dip.Body.begins_with("The diplomacy mission to Sullust had no effect") and dip.PendingMission != null
			and dip.PendingMission.Team.has(person.call("carlist_rieekan")) and dip.Category == Enums.MessageCategory.Missions,
			"the Sullust report asks to continue Rieekan's mission (Continue / Abort)")
		var dep: GameMessage = msgs[2]
		_check(dep.Category == Enums.MessageCategory.Defense and dep.AssociatedLocation is Planet and (dep.AssociatedLocation as Planet).PackId == "selonia"
			and dep.PendingMission == null, "the deployment notice is filed under Defense, at Selonia")
		_check(Lq.all(msgs, func(m): return StrategicTickManager.Shown(m.DayReceived) == 116 and not m.IsRead), "all three dated Day 116, unread")
	var screed: Character = person.call("screed")
	_check(screed.Rank == Enums.Rank.Admiral and screed.Commanding is Fleet and (screed.Commanding as Fleet).Name == "Fleet 6", "Screed: Admiral of Fleet 6")
	# Timing, run rather than reasoned: Rieekan's next attempt comes on the
	# original's day 121, and Leia reaches Drall on its day 118.
	var tried_on := -1
	var leia_in := -1
	for _i in 6:
		engine.AdvanceDay()
		if tried_on < 0 and rieekan != null and (rieekan.Attempts > 0 or rieekan.Finished or not MissionManager._active.has(rieekan)):
			tried_on = StrategicTickManager.Shown(StrategicTickManager.Today)
		if leia_in < 0 and leia_m != null and leia_m.Arrived():
			leia_in = StrategicTickManager.Shown(StrategicTickManager.Today)
	_check(tried_on == 121, "Rieekan's attempt comes on Day 121, as in the original (Day %d)" % tried_on)
	_check(leia_in == 118, "Leia reaches Drall on Day 118, her ETA in the original (Day %d)" % leia_in)


# ---- 2: import, load, a day, save, load ----------------------------------------------------

func _round_trip(path: String) -> void:
	var bytes := FileAccess.get_file_as_bytes(path)
	var r: Dictionary = SaveManager.Import(bytes, path.get_file())
	_check(r["ok"], "Import Game takes the original's file (%s)" % r["message"])
	if not r["ok"]:
		return
	var g: Dictionary = OriginalSave.Read(bytes)
	_check(r["name"] == str(g["name"]).strip_edges() or str(g["name"]).strip_edges().is_empty(), "under the name it was saved as in the original (\"%s\")" % r["name"])
	var entry: Dictionary = SaveManager.Games()[0]
	_check(entry["id"] == r["id"] and int(entry["day"]) == int(g["game"]["day"]) + 1, "on top of the list, on its day (%s)" % SaveManager.SavedLabel(entry))

	# Load it as the Saved Games screen does, play a day, save.
	var saved: Array = CommandLog.Read(SaveManager.GamePath(r["id"]))
	var engine: StrategicTickManager = Replayer.replay_entries(saved[0], saved[1], 1)
	CommandBus.Immediate = true
	_check(engine != null and StrategicTickManager.Today == int(g["game"]["day"]) + 1, "it loads on its day")
	if engine == null:
		return
	CommandLog.Open("user://test-original-import-gen.jsonl", CommandLog.Header())
	engine.AdvanceDay()
	CommandBus.day_done()
	var day_after: int = StrategicTickManager.Today
	var hash_after := GameSignature.ReplayHash(GameState.ActiveGalaxy)
	var id: String = SaveManager.Save("After a day")
	_check(not id.is_empty(), "saved after a day")
	var header: Dictionary = CommandLog.Read(SaveManager.GamePath(id))[0]
	_check(header.get("origin") is Dictionary, "the save carries the original's file")
	CommandLog.Reset()

	# Load it through GameManager, as the Load button does.
	GameSettings.PendingLoadPath = SaveManager.GamePath(id)
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 10:
		await process_frame
	_check(StrategicTickManager.Today == day_after, "loads on the day it was saved (%d, got %d)" % [day_after, StrategicTickManager.Today])
	_check(GameSignature.ReplayHash(GameState.ActiveGalaxy) == hash_after, "to the same state (day hash)")
	_check(not GameSettings.Origin.is_empty(), "and goes on carrying the original's file")
	main.queue_free()
	await process_frame
	CommandLog.Reset()
	DirAccess.remove_absolute("user://test-original-import-gen.jsonl")


static func _remove(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in DirAccess.get_directories_at(path):
		_remove("%s/%s" % [path, sub])
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute("%s/%s" % [path, file])
	DirAccess.remove_absolute(path)
