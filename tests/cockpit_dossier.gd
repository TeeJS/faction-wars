extends SceneTree
## THE COCKPIT AS A CAMPAIGN DOSSIER (src/ui/cockpit_dossier.gd; docs/ww2-look-plan.md
## phase 2). A pack with a look lays the button Cockpit out as the dossier; a
## pack without one keeps the labelled buttons exactly as they were.
##
##   .\tools\run-gd.ps1 tests/cockpit_dossier.gd
##
## With a look (the WWII pack): every function of manual p021 Fig. 2.2 is on
## screen, inside the 1440x850 design, none overlapping another - difficulty,
## size, Headquarters Only Victory, load, credits, head-to-head, exit and each
## side - and each launch plate is still the one click that starts the game.
## The size choice is in the pack's words. The lamp's drift stops when motion
## is to be held still. View Credits opens the Credits sheet with the pack's
## lines and an entry for every asset. Without a look (Star Wars): no dossier.

const Art := preload("res://src/ui/artwork.gd")
const Dossier := preload("res://src/ui/cockpit_dossier.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[cockpit_dossier] ok   %s" % what)
	else:
		_fails += 1
		print("[cockpit_dossier] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = "user://test-cockpit-dossier-none"
	var keep_motion := GameSettings.ReduceMotion

	FactionRegistry.Unload()
	FactionRegistry.EnsureLoaded("ww2")
	var menu: Control = load("res://Menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	menu.size = Vector2(1440, 850)
	for _i in 3:
		await process_frame

	_check(menu.get_node_or_null("DossierLayout") != null, "ww2: the Cockpit is laid out as the dossier")
	_check(not (menu.get_node("CenterContainer") as Control).visible, "the labelled-button column is put away")
	var screen := Rect2(0, 0, 1440, 850)
	var controls := {}
	for n in ["BtnEasy", "BtnMedium", "BtnHard", "BtnSmall", "BtnMediumSize", "BtnLarge",
			"ChkHQOnly", "ChkFeedback", "ChkReduceMotion", "BtnAlliance", "BtnEmpire",
			"BtnLoad", "BtnMultiplayer", "BtnCredits", "BtnExit"]:
		var c: Control = menu.find_child(n, true, false)
		_check(c != null and c.is_visible_in_tree(), "Fig. 2.2: %s is on screen" % n)
		if c != null:
			_check(c.focus_mode == Control.FOCUS_ALL, "%s takes keyboard focus" % n)
			var r := c.get_global_rect()
			_check(screen.encloses(r) and r.size.x > 0 and r.size.y > 0, "%s lies inside 1440x850 (%s)" % [n, str(r)])
			controls[n] = r
	var names := controls.keys()
	var overlaps: Array[String] = []
	for i in names.size():
		for j in range(i + 1, names.size()):
			if (controls[names[i]] as Rect2).intersects(controls[names[j]] as Rect2):
				overlaps.append("%s/%s" % [names[i], names[j]])
	_check(overlaps.is_empty(), "no two controls overlap %s" % str(overlaps))

	var sides := FactionRegistry.Playable
	for pair in [["BtnAlliance", sides[0]], ["BtnEmpire", sides[1]]]:
		var b: Button = menu.find_child(pair[0], true, false)
		_check(b.text == "LAUNCH AS %s" % (pair[1] as Faction).DisplayName.to_upper(), "%s reads '%s'" % [pair[0], b.text])
		_check(b.pressed.get_connections().size() > 0, "%s still starts the game in one click" % pair[0])
		_check(b.find_child("SideBand", false, false) != null, "%s carries its side's band" % pair[0])
	var size_label: Label = menu.find_child("SizeLabel", true, false)
	_check(size_label != null and size_label.text == "Map Size", "the size choice is in the pack's words ('%s')" % (size_label.text if size_label else "?"))
	_check(menu.find_child("CampaignName", true, false) != null and menu.find_child("MapPlate", true, false) != null,
		"the dossier shows the campaign's name and its map plate")

	# Reduced motion holds the lamp still; without it, it drifts.
	GameSettings.ReduceMotion = false
	Dossier.Drift(menu)
	_check(menu.has_meta("drift") and menu.get_meta("drift") is Tween, "the lamp drifts")
	GameSettings.ReduceMotion = true
	Dossier.Drift(menu)
	# Held still, the drift is gone (set_meta to null removes it).
	_check(not menu.has_meta("drift"), "Reduce motion holds it still")
	GameSettings.ReduceMotion = keep_motion

	# View Credits: the Credits sheet, the pack's lines, every asset.
	(menu.find_child("BtnCredits", true, false) as Button).pressed.emit()
	await process_frame
	var cw: Node = menu.get_node_or_null("CreditsWindow")
	_check(cw != null and cw.has_meta("sheet"), "View Credits opens the Credits sheet")
	if cw != null:
		var lines: Node = cw.find_child("Lines", true, false)
		_check(lines != null and lines.get_child_count() == Menu.PackCredits().size(), "it lists the pack's %d lines" % Menu.PackCredits().size())
		var assets: Node = cw.find_child("Assets", true, false)
		_check(assets != null and assets.get_child_count() == FactionRegistry.Pack.AssetCredits.size(),
			"and an entry for each of the pack's %d credited assets" % FactionRegistry.Pack.AssetCredits.size())
		_check(cw.find_child("EngineAssets", true, false) != null, "and the engine's own")
		(cw.find_child("BtnClose", true, false) as Button).pressed.emit()
		await process_frame
		await process_frame
		_check(menu.get_node_or_null("CreditsWindow") == null, "Close takes the sheet away")
	# Picking a side reads the option boxes by their %names (menu.gd
	# StartGame): moved into the orders, they must still answer to them
	# (TeeJ, 2026-10-04: "now I can't pick a side and proceed to the game").
	var layout: Node = menu.get_node_or_null("DossierLayout")
	for n in ["ChkHQOnly", "ChkFeedback"]:
		var by_name: Node = menu.get_node_or_null("%" + n)
		_check(by_name != null and layout != null and layout.is_ancestor_of(by_name), "%%%s still finds the box in the orders" % n)
	var hq: CheckBox = menu.get_node_or_null("%ChkHQOnly")
	if hq != null:
		hq.button_pressed = true
		_check((menu.get_node("%ChkHQOnly") as CheckBox).button_pressed, "and reads what was ticked")
		hq.button_pressed = false
	menu.queue_free()
	await process_frame

	# Without a look: the Cockpit as it always was.
	FactionRegistry.Unload()
	FactionRegistry.EnsureLoaded("star-wars-rebellion")
	var plain: Control = load("res://Menu.tscn").instantiate()
	root.add_child(plain)
	await process_frame
	await process_frame
	_check(plain.get_node_or_null("DossierLayout") == null and (plain.get_node("CenterContainer") as Control).visible,
		"star-wars-rebellion: no look, the labelled buttons as before")
	var sw_size: Label = plain.find_child("SizeLabel", true, false)
	_check(sw_size.text == "Galaxy Size", "its size choice still reads 'Galaxy Size'")
	_check(plain.theme == null, "and no theme is put on it")
	plain.queue_free()
	await process_frame

	print("[cockpit_dossier] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
