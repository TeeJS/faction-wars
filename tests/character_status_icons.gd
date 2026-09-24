extends SceneTree
## A character's card shows its status as the original's icons do (manual
## p096, "Character Status Icons"): Ready on the grey plate; In transit on
## the ship's windows (STRATEGY 11501, not the units' hyperspace streaks);
## Captured behind its own bars (GOKRES miniature + 12288); Injured under the
## green trace (11502). Writes and removes its own test art.
##
##   .\tools\run-gd.ps1 tests/character_status_icons.gd

const Art := preload("res://src/ui/artwork.gd")
const OUI := preload("res://src/ui/original_ui.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[character_status_icons] ok   %s" % what)
	else:
		_fails += 1
		print("[character_status_icons] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = "user://test-status-icons-art"
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSession.new_game("empire", Enums.Difficulty.Medium, Enums.GalaxySize.Standard, 4243)
	var sets: Array = FactionRegistry.Pack.Manifest.ArtSets
	var dir := "%s/%s" % [Art.UserArtRoot, sets[0] if not sets.is_empty() else "swr-original"]
	for sub in ["windows", "miniatures/characters"]:
		DirAccess.make_dir_recursive_absolute("%s/%s" % [dir, sub])
	for w in ["card_plate", "card_enroute", "card_transit", "card_injured"]:
		_png("%s/windows/%s.png" % [dir, w], 61, 25, Color(0.5, 0.5, 0.5))
	var c: Character = null
	for x in GameState.ActiveRoster:
		if x.Faction == GameSettings.PlayerFaction and not x.IsOffMap() and c == null:
			c = x
	_check(c != null, "a character to show")
	if c == null:
		_finish()
		return
	_png("%s/miniatures/characters/%s.png" % [dir, c.PackId], 61, 25, Color(0.8, 0.7, 0.6))
	_png("%s/miniatures/characters/%s.captured.png" % [dir, c.PackId], 61, 25, Color(0.2, 0.9, 0.9))
	Art.Reset()

	c.CapturedBy = null
	c.Injury = 0
	c.Status = Enums.Status.AwaitingOrders
	_check(OUI.CharacterState(c) == "" and OUI.CharacterOver(c) == null, "ready: the plain card")
	_check(_plate(c) == "card_plate", "ready: the grey plate")
	c.Status = Enums.Status.Enroute
	_check(OUI.CharacterState(c) == "transit" and _plate(c) == "card_transit", "in transit: the ship's windows, not hyperspace")
	c.Status = Enums.Status.AwaitingOrders
	c.Injury = 10
	var card: Button = _card(c)
	_check(OUI.CharacterState(c) == "injured" and card.get_node_or_null("Injured") != null, "injured: the green trace over the picture")
	card.free()
	c.CapturedBy = FactionRegistry.ById("alliance")
	card = _card(c)
	_check(OUI.CharacterState(c) == "captured", "captured wins over injured")
	var over: TextureRect = card.get_node_or_null("Over")
	_check(over != null and over.texture != null and over.get_index() > card.get_node("Picture").get_index(),
		"captured: the character's own bars over the picture")
	card.free()
	_finish()


func _card(c: Character) -> Button:
	var b := Button.new()
	OUI.Card(b, c.Name, OUI.Mini("characters", c.PackId), Color.WHITE, Color.GREEN, OUI.CharacterState(c), OUI.CharacterOver(c))
	return b


## Which window picture the card's plate is.
func _plate(c: Character) -> String:
	var b := _card(c)
	var plate: TextureRect = b.get_node_or_null("Plate")
	var name := ""
	for w in ["card_transit", "card_enroute", "card_plate"]:
		if plate != null and plate.texture == OUI.Pic(w):
			name = w
			break
	b.free()
	return name


func _finish() -> void:
	_remove(Art.UserArtRoot)
	Art.Reset()
	print("[character_status_icons] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


static func _png(path: String, w: int, h: int, color: Color) -> void:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(color)
	img.save_png(path)


static func _remove(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in DirAccess.get_directories_at(path):
		_remove("%s/%s" % [path, sub])
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute("%s/%s" % [path, file])
	DirAccess.remove_absolute(path)
