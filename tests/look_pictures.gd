extends SceneTree
## A LOOK'S PICTURES FILL THEIR SPACE (TeeJ, 2026-09-30, the WWII windows).
## One pack per process:
##
##   .\tools\run-gd.ps1 tests/look_pictures.gd -- --pack=ww2 --seed=12345
##
## - A facility's Status window: its picture fills its box ("it would be nice
##   if the pictures filled up the space without black bars") - the box is the
##   picture's shape, the picture the Encyclopedia plate, drawn smaller.
## A pack without a look has nothing to check.

const Art := preload("res://src/ui/artwork.gd")
const StandIns := preload("res://src/ui/art_standins.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[look_pictures] ok   %s" % what)
	else:
		_fails += 1
		print("[look_pictures] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = "user://test-look-pictures-none"
	StandIns.Enabled = false
	FactionRegistry.EnsureLoaded()
	if not Look.Active():
		print("[look_pictures] %s has no look: nothing to check" % FactionRegistry.LoadedId())
		quit(0)
		return

	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	GameSettings.PlayerFaction = FactionRegistry.Playable[0]
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 8:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	var us: Faction = GameSettings.PlayerFaction

	# A FACILITY'S STATUS: one of every family the side has, each filling its box.
	var seen := {}
	for p in GameState.AllPlanets():
		if p.ControllingFaction != us:
			continue
		for fac in p.Facilities:
			if fac.Def == null or seen.has(fac.Family()):
				continue
			seen[fac.Family()] = true
			ui.CloseAllWindows()
			for _i in 2:
				await process_frame
			ui.OpenDefenseFacilityStatusWindow(fac)
			for _i in 3:
				await process_frame
			var w: Node = Lq.first_or_null(ui._openWindows.values(), func(x) -> bool: return x is DefenseFacilityStatusWindow)
			var box: Control = (w.get_node("%IconLabel") as Control).get_parent() if w != null else null
			var pic: TextureRect = box.get_node_or_null("Picture") if box != null else null
			var want: Texture2D = Art.Picture("facilities", fac.Def.Id)
			if want == null:
				want = Art.Portrait("facilities", fac.Def.Id)
			if want == null:
				continue
			var tex_ratio: float = float(want.get_width()) / want.get_height()
			var box_ratio: float = box.size.x / box.size.y if box != null and box.size.y > 0 else 0.0
			_check(pic != null and pic.texture == want and absf(box_ratio - tex_ratio) < 0.02 and box.size.y <= DefenseFacilityStatusWindow.BoxH + 0.5,
				"%s Status: the picture fills its box (%s, picture %.2f:1, box %.2f:1)" % [fac.Name(), str(box.size) if box != null else "none", tex_ratio, box_ratio])

	print("[look_pictures] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
