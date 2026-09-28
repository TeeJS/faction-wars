extends SceneTree
## Game imported's icon in the Message Index (TeeJ, 2026-09-28: "could you use
## the CD from the cockpit?"): the load monitor's frame with the three arrows,
## cut to a row icon's 15 x 16, round, its arrows whole. On a stand-in strip,
## never the player's art.
##
##   .\tools\run-gd.ps1 tests/imported_icon.gd

const Art := preload("res://src/ui/artwork.gd")
const ArtRoot := "user://test-imported-icon-art"

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[imported_icon] ok   %s" % what)
	else:
		_fails += 1
		print("[imported_icon] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = ArtRoot
	FactionRegistry.EnsureLoaded()
	Art.Reset()
	_check(MessageWindow.ImportedIcon() == null, "no art: no icon (the row has none, as before)")
	# The strip: 30 frames of 40 x 36, grey; frame 10's arrows red.
	var dir := "%s/%s/menu" % [ArtRoot, FactionRegistry.Pack.Manifest.ArtSets[0]]
	DirAccess.make_dir_recursive_absolute(dir)
	var strip := Image.create(40 * 30, 36, false, Image.FORMAT_RGBA8)
	strip.fill(Color(0.6, 0.6, 0.6))
	strip.fill_rect(Rect2i(40 * 10 + 20, 25, 7, 5), Color(0.8, 0.05, 0.05))
	strip.save_png("%s/load.png" % dir)
	Art.Reset()
	var icon: Texture2D = MessageWindow.ImportedIcon()
	_check(icon != null and icon.get_size() == Vector2(15, 16), "the icon a row icon's 15 x 16 (%s)" % (str(icon.get_size()) if icon != null else "none"))
	if icon != null:
		var img: Image = icon.get_image()
		_check(img.get_pixel(0, 0).a == 0.0 and img.get_pixel(14, 0).a == 0.0 and img.get_pixel(0, 15).a == 0.0, "round: the corners clear")
		_check(img.get_pixel(7, 8).a == 1.0 and absf(img.get_pixel(7, 8).r - 0.6) < 0.05, "the disc's middle solid")
		var red := false
		for y in range(11, 16):
			for x in range(9, 15):
				var c: Color = img.get_pixel(x, y)
				red = red or (c.r > 0.5 and c.g < 0.2 and c.a == 1.0)
		_check(red, "frame 10's arrows, red and whole")
		var m := GameMessage.new("Game imported", "Imported from ...")
		m.Icon = "imported"
		_check(MessageWindow.OwnIcon(m) == icon and MessageWindow.OwnIcon(GameMessage.new("Other", "")) == null and m.Copy().Icon == "imported",
			"Game imported's own icon; any other message its category's")
	_remove(ArtRoot)
	Art.Reset()
	print("[imported_icon] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


static func _remove(path: String) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	for f in d.get_files():
		d.remove(f)
	for sub in d.get_directories():
		_remove("%s/%s" % [path, sub])
	DirAccess.remove_absolute(path)
