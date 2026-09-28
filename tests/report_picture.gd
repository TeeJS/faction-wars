extends SceneTree
## The Diplomacy Mission Report's picture as the original draws it (TeeJ,
## 2026-09-28: "make it work like the original does"): its scene - STRATEGY
## 1044, windows/message.1044 (an exporter 2.6.4 set: report.diplomacy) - with the reporting agent's Encyclopedia
## picture laid over it, the side's crest and gradient left out (pack.json
## `report_backdrop`, filled from the picture's edges). With stand-in art:
##   - where the backdrop reaches from the edge, the scene shows;
##   - the figure shows, and a backdrop colour enclosed by it stays;
##   - a Diplomacy report carries its scene, and the message window draws it;
##   - without the scene, the character's picture as before;
##   - with the character's report figure (the original's own cut-out): the
##     figure over the scene, and nothing of the Encyclopedia picture.
##
##   .\tools\run-gd.ps1 tests/report_picture.gd

const Art := preload("res://src/ui/artwork.gd")
const ArtRoot := "user://test-report-picture-art"

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[report_picture] ok   %s" % what)
	else:
		_fails += 1
		print("[report_picture] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = ArtRoot
	_remove(ArtRoot)
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSession.new_game("alliance", Enums.Difficulty.Medium, Enums.GalaxySize.Standard, 4243)
	var us: Faction = GameSettings.PlayerFaction
	var m: PackDefs.PackManifest = FactionRegistry.Pack.Manifest
	_check(m.ReportBackdrop.has("alliance") and m.ReportBackdrop.has("empire"), "the pack names both sides' backdrop colours")
	var agent: Character = Lq.first_or_null(GameState.ActiveRoster, func(c: Character) -> bool: return c.Faction == us and c.Status != Enums.Status.Dead)
	var target: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool: return FactionRegistry.OrderOf(p.ControllingFaction) < 0 and p.IsInhabited)

	# Without the scene: the character's picture as before (none here), no composite.
	_check(MessageWindow.ReportPicture("message.1044", agent) == null, "no scene imported: no composite")

	# Stand-ins: a red scene; the agent's picture a backdrop colour all round a
	# white figure that encloses a square of the same backdrop colour.
	var set_dir := "%s/%s" % [ArtRoot, m.ArtSets[0]]
	DirAccess.make_dir_recursive_absolute(set_dir + "/windows")
	DirAccess.make_dir_recursive_absolute(set_dir + "/characters")
	var scene := Image.create(400, 200, false, Image.FORMAT_RGBA8)
	scene.fill(Color(1, 0, 0))
	scene.save_png(set_dir + "/windows/report.diplomacy.png")
	var back := Color.html("#" + str(m.ReportBackdrop["alliance"][0]))
	var face := Image.create(400, 200, false, Image.FORMAT_RGBA8)
	face.fill(back)
	face.fill_rect(Rect2i(250, 40, 100, 160), Color.WHITE)
	face.fill_rect(Rect2i(280, 80, 20, 20), back)   # enclosed by the figure
	face.save_png("%s/characters/%s.png" % [set_dir, agent.PackId])
	Art.Reset()
	MessageWindow._reportPictures.clear()

	var pic: Texture2D = MessageWindow.ReportPicture("message.1044", agent)
	_check(pic != null, "with the scene and the picture: a composite")
	if pic != null:
		var img: Image = pic.get_image()
		_check(img.get_pixel(5, 5).is_equal_approx(Color(1, 0, 0)), "the backdrop at the edge: the scene shows")
		_check(img.get_pixel(120, 150).is_equal_approx(Color(1, 0, 0)), "the backdrop reached from the edge: the scene shows")
		_check(img.get_pixel(260, 60).is_equal_approx(Color.WHITE), "the figure shows")
		_check(img.get_pixel(290, 90).is_equal_approx(back), "a backdrop colour the figure encloses stays")

	# A Diplomacy report carries its scene; the message window draws the composite.
	if target != null and agent != null:
		var mission := Mission.new()
		mission.Type = Enums.MissionType.Diplomacy
		mission.Faction = us
		mission.Target = target
		mission.HomeBase = target
		mission.Team.append(agent)
		mission.Attempts = 1
		mission.DaysToTarget = 0
		var before := EventBus.MessageLog.size()
		MissionManager.Resolve(mission, AlwaysMaxPrng.new(), 1)
		var msg: GameMessage = EventBus.MessageLog[EventBus.MessageLog.size() - 1] if EventBus.MessageLog.size() > before else null
		_check(msg != null and msg.Scene == "message.1044", "the Diplomacy report carries its scene (STRATEGY 1044) (%s)" % (msg.Scene if msg != null else "none"))
		_check(msg != null and MessageWindow.MessagePicture(msg) == pic, "the message window shows the composite for it")

	# With the character's report figure (exporter 2.6.5): the figure, cut out by
	# hand, over the scene - not the Encyclopedia picture filled from its edges.
	var figure := Image.create(400, 200, false, Image.FORMAT_RGBA8)
	figure.fill(Color(0, 0, 0, 0))
	figure.fill_rect(Rect2i(20, 20, 40, 40), Color(0, 0, 0))   # black, as dark as a backdrop
	figure.save_png("%s/characters/%s.report.png" % [set_dir, agent.PackId])
	Art.Reset()
	MessageWindow._reportPictures.clear()
	var cut: Texture2D = MessageWindow.ReportPicture("message.1044", agent)
	_check(cut != null, "with the report figure: a composite")
	if cut != null:
		var img: Image = cut.get_image()
		_check(img.get_pixel(30, 30).is_equal_approx(Color(0, 0, 0)), "the figure shows, even in the backdrop's own colour")
		_check(img.get_pixel(260, 60).is_equal_approx(Color(1, 0, 0)), "where the figure is cut away the scene shows, not the Encyclopedia picture")

	_remove(ArtRoot)
	Art.IgnoreProjectFolder = false
	Art.UserArtRoot = "user://art"
	Art.Reset()
	print("[report_picture] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


class AlwaysMaxPrng extends Prng:
	func NextRange(_min_value: int, max_value: int) -> int: return max_value - 1
	func NextMax(max_value: int) -> int: return max_value - 1


static func _remove(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in DirAccess.get_directories_at(path):
		_remove("%s/%s" % [path, sub])
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute("%s/%s" % [path, file])
	DirAccess.remove_absolute(path)
