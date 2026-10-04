extends SceneTree
## THE WWII MISSION PICTURES AND THE STAND-IN (tools/look/make_ww2_missions.py;
## TeeJ, 2026-10-03: "create 14 WWII mission plates", "a generic 1940's
## wartime image to use when no other exists"). One pack per process:
##
##   .\tools\run-gd.ps1 tests/ww2_mission_pictures.gd -- --pack=ww2
##   .\tools\run-gd.ps1 tests/ww2_mission_pictures.gd -- --pack=star-wars-rebellion
##
## WWII: every mission has its 400 x 200 picture, for either side; the pack's
## stand-in is 400 x 200 and fills a slot that has nothing of its own; the
## Encyclopedia's mission page shows the mission's picture. Star Wars (no art
## imported): no stand-in, so an empty slot stays empty, as before.

const Art := preload("res://src/ui/artwork.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[ww2_mission_pictures] ok   %s" % what)
	else:
		_fails += 1
		print("[ww2_mission_pictures] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = "user://test-ww2-mission-pictures-none"
	FactionRegistry.EnsureLoaded()
	var pack: PackLoader.LoadedPack = FactionRegistry.Pack
	var id := FactionRegistry.LoadedId()

	if id != "ww2":
		_check(Art.Placeholder() == null, "%s: no stand-in" % id)
		_check(Art.OrPlaceholder(null) == null, "%s: an empty slot stays empty" % id)
		_done()
		return

	var missing: Array = []
	for m in pack.Missions:
		if m.Id.begins_with("unnamed"):
			continue
		for f in FactionRegistry.Playable:
			var pic: Texture2D = Art.MissionPicture(m.Id, f.ArtSkin)
			if pic == null or pic.get_size() != Vector2(400, 200):
				missing.append("%s/%s" % [m.Id, f.Id])
	_check(missing.is_empty(), "every mission has its 400 x 200 picture, for either side (%s)" % str(missing))

	var stand_in: Texture2D = Art.Placeholder()
	_check(stand_in != null and stand_in.get_size() == Vector2(400, 200), "the stand-in is the pack's 400 x 200 picture")
	_check(Art.OrPlaceholder(null) == stand_in, "an empty slot shows the stand-in")
	var own: Texture2D = Art.MissionPicture("diplomacy", "allies")
	_check(Art.OrPlaceholder(own) == own, "a slot with its own picture keeps it")

	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	GameSettings.PlayerFaction = FactionRegistry.Playable[0]
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 8:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	ui.OpenEncyclopedia("missions", "sabotage")
	for _i in 3:
		await process_frame
	var w: EncyclopediaWindow = ui._openWindows.get("Encyclopedia")
	var shown: Node = w._picture.get_node_or_null("Picture") if w != null else null
	_check(w != null and w._picture.visible and shown != null, "the Encyclopedia's mission page shows the mission's picture")
	_done()


func _done() -> void:
	print("[ww2_mission_pictures] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
