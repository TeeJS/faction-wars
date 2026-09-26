extends SceneTree
## Art sets and skins (docs/original-art-plan.md, phase 2). A custom pack with
## new factions - the Separatists and the Trade Federation - declares the
## player's swr-original art set and wears it:
##   - each side through its skin, swapped here (Separatists as the Empire);
##   - a shipyard by the original's own id;
##   - a character borrowing another row's pictures through `art`;
##   - a character with the pack's own picture, which comes first;
##   - the galaxy map from the art set.
## Without the art set, every one of them is simply absent (the engine's art).
## The pack is written under user://packs/ and the art set under a test root,
## never the player's own; both are removed at the end.
##
##   Godot_console.exe --headless --path . -s tests/art_sets.gd

const Art := preload("res://src/ui/artwork.gd")
const OUI := preload("res://src/ui/original_ui.gd")
const PACK_ID := "art-sets-test"
const SET_ROOT := "user://test-art-sets"
const RED := Color(1, 0, 0)        # the art set's Luke
const GREEN := Color(0, 1, 0)      # the art set's shipyard
const BLUE := Color(0, 0, 1)       # the Empire's tab
const YELLOW := Color(1, 1, 0)     # the Alliance's tab
const MAGENTA := Color(1, 0, 1)    # the pack's own Leia
const CYAN := Color(0, 1, 1)       # the art set's Leia, which the pack's own hides

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[art_sets] ok   %s" % what)
	else:
		_fails += 1
		print("[art_sets] FAIL %s" % what)


func _init() -> void:
	await process_frame
	var pack_dir := "%s/%s" % [FactionRegistry.USER_PACKS_ROOT, PACK_ID]
	_remove(pack_dir)
	_remove(SET_ROOT)
	_make_pack(pack_dir)
	_make_art_set("%s/swr-original" % SET_ROOT)
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = SET_ROOT

	_check(FactionRegistry.ListPackIds().has(PACK_ID), "an imported pack under user://packs is on the picker's list")
	_check(FactionRegistry.EnsureLoaded(PACK_ID), "it loads")
	_check(FactionRegistry.LoadedDir == pack_dir, "from the user folder (%s)" % FactionRegistry.LoadedDir)
	var sep: Faction = FactionRegistry.ById("separatists")
	var tf: Faction = FactionRegistry.ById("trade_federation")
	_check(sep.ArtSkin == "empire" and tf.ArtSkin == "alliance", "the Separatists wear the Empire, the Trade Federation the Alliance")
	_check(OUI.Side(sep) == "empire" and OUI.SideColor(sep) == Color(0, 1, 0), "the Separatists' title bars are the Empire's green")
	_check(Faction.SkinOf("trade_federation") == "alliance" and Faction.SkinOf("unexplored") == "unexplored"
		and FactionRegistry.Neutral.ArtSkin == "neutral", "a faction id maps to its skin; other names stay themselves")

	_check(_colour(Art.TabIcon("manufacturing", OUI.Side(sep))) == BLUE, "the Separatists get the Empire's Manufacturing tab")
	_check(_colour(Art.TabIcon("manufacturing", OUI.Side(tf))) == YELLOW, "the Trade Federation gets the Alliance's")
	_check(_colour(Art.Portrait("facilities", "shipyard")) == GREEN, "a shipyard kept the original's id: the original's picture")
	_check(_colour(Art.Portrait("characters", "han_solo")) == RED, "a row with `art` borrows another row's portrait")
	_check(_colour(Art.Miniature("characters", "han_solo")) == RED, "... and its miniature")
	_check(Art.Description("characters", "han_solo") == "Luke's text", "... and its description")
	_check(_colour(Art.Portrait("characters", "leia_organa")) == MAGENTA, "the pack's own picture comes before the art set's")
	_check(Art.Portrait("characters", "mon_mothma") == null, "a row the art set has no picture for: none")
	_check(Art.PackImage("swr-original:screens/galaxy.png") != null, "the map picture comes from the art set")
	_check(Art.PackImage("swr-original:screens/cockpit.png") == null, "... and one the set lacks is absent")

	_remove(SET_ROOT)
	Art.Reset()
	_check(Art.Portrait("facilities", "shipyard") == null and Art.TabIcon("manufacturing", "empire") == null
		and Art.PackImage("swr-original:screens/galaxy.png") == null,
		"without the art set: no original pictures (the engine's own art)")
	_check(_colour(Art.Portrait("characters", "leia_organa")) == MAGENTA, "... but the pack's own still shows")

	FactionRegistry.Unload()
	_remove(pack_dir)
	print("[art_sets] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## The Star Wars pack's files with its two sides renamed, skins swapped, one
## `art` reference, the map from the art set, and one picture of its own.
func _make_pack(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	for f in FactionRegistry.PACK_FILES:
		var text := FileAccess.get_file_as_string("res://packs/star-wars-rebellion/%s" % f)
		text = text.replace("\"alliance\"", "\"separatists\"").replace("\"empire\"", "\"trade_federation\"")
		_write_text("%s/%s" % [dir, f], text)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir + "/pack.json"))
	manifest["id"] = PACK_ID
	manifest["display_name"] = "Separatists vs Trade Federation"
	manifest["map_image"] = "swr-original:screens/galaxy.png"
	manifest.erase("menu")
	# Its movies name the old sides ("victory.alliance"): rule 23 would refuse them.
	manifest.erase("movies")
	_write_text(dir + "/pack.json", JSON.stringify(manifest, "  "))
	var factions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir + "/factions.json"))
	for f in factions["factions"]:
		f["skin"] = "empire" if f["id"] == "separatists" else "alliance"
	_write_text(dir + "/factions.json", JSON.stringify(factions, "  "))
	var chars: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir + "/characters.json"))
	for c in chars["characters"]:
		if c["id"] == "han_solo":
			c["art"] = "swr-original:characters/luke_skywalker"
	_write_text(dir + "/characters.json", JSON.stringify(chars, "  "))
	_write_png("%s/art/portraits/characters/leia_organa.png" % dir, MAGENTA)


func _make_art_set(root: String) -> void:
	_write_png(root + "/portraits/characters/luke_skywalker.png", RED)
	_write_png(root + "/miniatures/characters/luke_skywalker.png", RED)
	_write_png(root + "/portraits/characters/leia_organa.png", CYAN)
	_write_png(root + "/portraits/facilities/shipyard.png", GREEN)
	_write_png(root + "/tabs/manufacturing.empire.png", BLUE)
	_write_png(root + "/tabs/manufacturing.alliance.png", YELLOW)
	_write_png(root + "/screens/galaxy.png", Color(0.1, 0.1, 0.3))
	_write_text(root + "/descriptions.json", JSON.stringify({"characters": {"luke_skywalker": "Luke's text"}}))


static func _colour(tex: Texture2D) -> Color:
	return tex.get_image().get_pixel(0, 0) if tex != null else Color(0, 0, 0, 0)


static func _write_png(path: String, colour: Color) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(colour)
	img.save_png(path)


static func _write_text(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


static func _remove(path: String) -> void:
	if DirAccess.dir_exists_absolute(path):
		for sub in DirAccess.get_directories_at(path):
			_remove("%s/%s" % [path, sub])
		for file in DirAccess.get_files_at(path):
			DirAccess.remove_absolute("%s/%s" % [path, file])
		DirAccess.remove_absolute(path)
