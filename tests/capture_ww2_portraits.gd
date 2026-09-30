extends SceneTree
## THE WWII PERSONNEL PICTURES IN THE GAME (tools/look/make_ww2_portraits.py):
## a fresh WWII game and the windows that show a character's picture, each the
## whole screen. Needs a window (NOT --headless), like tests/capture_look.gd:
##
##   Godot_console.exe --path . --resolution 1440x850 -s tests/capture_ww2_portraits.gd -- `
##       --out=C:/tmp/ww2/portraits --pack=ww2 --faction=axis --record=user://capture-portraits.jsonl
##
## writes <out>_ency.png (the Encyclopedia at a character), _status.png (a
## character's status window), _status_generic.png (one with the drawn
## stand-in), _personnel.png (the Personnel Finder), _defense.png (the
## Defense window at the character's system: its personnel, with their
## miniatures) and _message.png (a message naming a character). --record= is REQUIRED, so the player's
## user://last-session.jsonl is untouched. No art set is read.

const Art := preload("res://src/ui/artwork.gd")
const MoviesLib := preload("res://src/ui/movies.gd")


func _init() -> void:
	await process_frame
	if _arg("--record=", "").is_empty():
		push_error("[capture_ww2_portraits] pass --record=user://<file>.jsonl so the player's session log is untouched")
		quit(2)
		return
	var out := _arg("--out=", "user://ww2-portraits").trim_suffix(".png")
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = "user://test-capture-portraits-none"
	MoviesLib.UserRoot = "user://test-capture-portraits-none"
	MoviesLib.LaunchPlayed = true
	FactionRegistry.EnsureLoaded()
	if not FactionRegistry.IsLoaded():
		push_error("[capture_ww2_portraits] no pack loaded - pass --pack=ww2")
		quit(3)
		return
	var ok := true

	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	GameSettings.HQOnlyVictory = false
	GameSettings.PlayerFaction = FactionRegistry.ById(_arg("--faction=", FactionRegistry.Playable[0].Id))
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 12:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	var us: Faction = GameSettings.PlayerFaction
	var home: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool: return p.ControllingFaction == us)
	var ours: Array = GameState.ActiveRoster.filter(func(c: Character) -> bool: return c.Faction == us)
	var who: Character = Lq.first_or_null(ours, func(c: Character) -> bool: return not c.IsMajor)
	if who == null:
		who = ours[0] if not ours.is_empty() else null
	# The stand-in: a character of ours whose record has `generic`.
	var people: Dictionary = (JsonUtil.parse("res://tools/look/ww2_portraits.json") as Dictionary).get("people", {})
	var stand_in: Character = Lq.first_or_null(GameState.ActiveRoster, func(c: Character) -> bool: return (people.get(c.PackId, {}) as Dictionary).has("generic"))

	var shots := [
		["ency", func() -> void: ui.OpenEncyclopedia("characters", who.PackId)],
		["status", func() -> void: ui.OpenCharacterStatusWindow(who)],
		["status_generic", func() -> void: ui.OpenCharacterStatusWindow(stand_in)],
		["personnel", func() -> void: ui.OpenPersonnelFinder()],
		["defense", func() -> void: ui.OnDefenseClicked(who.Attached)],
		["message", func() -> void:
			EventBus.Tell(us, GameMessage.new("%s reports" % who.Name, "The mission team has reached its destination and begun work.",
				Enums.MessageCategory.Missions, StrategicTickManager.Today, home, who))
			ui.OnMessageIndexClicked("Missions")],
	]
	for s in shots:
		ui.CloseAllWindows()
		for _i in 3:
			await process_frame
		(s[1] as Callable).call()
		for _i in 6:
			await process_frame
		ok = _shot(out, str(s[0])) and ok
	print("[capture_ww2_portraits] %s (%s), stand-in %s" % [who.Name, who.PackId, stand_in.Name if stand_in != null else "none"])
	quit(0 if ok else 1)


func _shot(out: String, what: String) -> bool:
	var path := "%s_%s.png" % [out, what]
	var img: Image = root.get_viewport().get_texture().get_image()
	var err := img.save_png(path)
	print("[capture_ww2_portraits] %s %s -> %s" % [what, str(img.get_size()), path if err == OK else ("error %d" % err)])
	return err == OK


func _arg(prefix: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return default
