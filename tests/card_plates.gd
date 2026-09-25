extends SceneTree
## The grey plate under a card's picture (TeeJ, 2026-09-24, against the
## original's Manufacturing and System Defenses pages): a person's and a
## regiment's card stand on it; a facility's and a fighter squadron's
## picture stands straight on the page ("not showing a clear background like
## they should be"). A unit on its way keeps its own state plate either way.
## Writes and removes its own test art.
##
##   .\tools\run-gd.ps1 tests/card_plates.gd

const Art := preload("res://src/ui/artwork.gd")
const OUI := preload("res://src/ui/original_ui.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[card_plates] ok   %s" % what)
	else:
		_fails += 1
		print("[card_plates] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = "user://test-card-plates-art"
	FactionRegistry.EnsureLoaded("star-wars-rebellion")
	var dir := "%s/%s/windows" % [Art.UserArtRoot, FactionRegistry.Pack.Manifest.ArtSets[0]]
	DirAccess.make_dir_recursive_absolute(dir)
	for w in ["card_plate", "card_enroute"]:
		var img := Image.create(61, 25, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.4, 0.4, 0.45))
		img.save_png("%s/%s.png" % [dir, w])
	Art.Reset()

	var plated := Button.new()
	OUI.Card(plated, "Luke Skywalker", null, Color.WHITE, Color.RED)
	_check(plated.get_node_or_null("Plate") != null, "a card is plated by default (a person, a regiment)")
	var bare := Button.new()
	OUI.Card(bare, "Training Facility", null, Color.WHITE, Color.RED, "", null, false)
	_check(bare.get_node_or_null("Plate") == null, "a facility's or a fighter's card has no plate")
	_check((plated.get_node("Name") as Label).visible, "a card's name shows under its picture by default")
	var unnamed := Button.new()
	OUI.Card(unnamed, "Mine", null, Color.WHITE, Color.RED, "", null, false, false)
	_check(not (unnamed.get_node("Name") as Label).visible, "a Manufacturing card has no name under its picture (the original's)")
	unnamed.free()
	var moving := Button.new()
	OUI.Card(moving, "X-wing", null, Color.WHITE, Color.RED, "enroute", null, false)
	_check(moving.get_node_or_null("Plate") != null, "... but one on its way keeps its hyperspace plate")
	var list := VBoxContainer.new()
	var s := OUI.StaticCard(list, "TIE Fighter", null, Color.WHITE, "", "", false)
	_check(s.get_node_or_null("Plate") == null, "a static card can go without the plate too")

	# Which units the Defenses window plates: regiments yes, squadrons no.
	var fighter := ""
	var troop := ""
	for u in FactionRegistry.Pack.Units:
		if u.Kind == "fighter" and fighter.is_empty():
			fighter = u.DisplayName
		if u.Kind == "troop" and troop.is_empty():
			troop = u.DisplayName
	_check(DefenseWindow._is_fighter_named(fighter) and not DefenseWindow._is_fighter_named(troop),
		"the Defenses window knows a squadron (%s) from a regiment (%s)" % [fighter, troop])

	for n in [plated, bare, moving, list]:
		n.free()
	_remove(Art.UserArtRoot)
	Art.IgnoreProjectFolder = false
	Art.UserArtRoot = "user://art"
	Art.Reset()
	print("[card_plates] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


static func _remove(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in DirAccess.get_directories_at(path):
		_remove("%s/%s" % [path, sub])
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute("%s/%s" % [path, file])
	DirAccess.remove_absolute(path)
