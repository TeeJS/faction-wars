extends SceneTree
## THE ORIGINAL'S FONT (TeeJ, 2026-09-28: "you should be using the same font
## as the original"; the web build's Encyclopedia text had to scroll):
##   - the player's own Arial in the art set (fonts/arial.ttf, the exporter's)
##     is the face, bold from arialbd.ttf;
##   - without it, the system's Arial where there is one (this machine);
##   - the bundled Liberation Sans is Arial's width, letter for letter;
##   - in it, the original's Diplomacy and Incite Uprising texts fit the
##     Encyclopedia's text box (396 x 86 at Arial 13) in five lines - no scroll.
##
##   .\tools\run-gd.ps1 tests/original_font.gd

const Art := preload("res://src/ui/artwork.gd")
const OUI := preload("res://src/ui/original_ui.gd")
const ArtRoot := "user://test-original-font-art"
const Liberation := "res://assets/fonts/LiberationSans-Regular.ttf"
const LiberationBold := "res://assets/fonts/LiberationSans-Bold.ttf"

## The original's Encyclopedia texts, as TeeJ's screenshots show them.
const Texts := {
	"diplomacy": "Diplomacy missions increase loyalty for your side in a planetary system. The success of this mission depends on the diplomacy attribute of the characters and the current loyalty of the population.  Diplomacy missions can only be targeted at friendly or explored neutral systems.",
	"incite uprising": "The objective of the incite uprising mission is to create or assist in a revolt on an enemy controlled system. The success of this mission depends on the leadership attributes of the characters and the SpecForces assigned to the mission team and the loyalty of the system.",
}

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[original_font] ok   %s" % what)
	else:
		_fails += 1
		print("[original_font] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = ArtRoot
	_remove(ArtRoot)
	FactionRegistry.EnsureLoaded()
	Art.Reset()
	OUI._face = null
	OUI._bold = null

	# Without the art set's font: the system's Arial on this machine.
	var system_arial: bool = OS.get_system_fonts().has("Arial")
	var plain: Font = OUI.Face()
	_check(Art.OriginalFont() == null, "no art set font: none")
	_check((plain is SystemFont) == system_arial and (system_arial or plain.resource_path == Liberation),
		"... the system's Arial here (%s), else the bundled Liberation Sans" % ("it has one" if system_arial else "it has none"))

	# The bundled one is Arial's width, letter for letter (13 px, both weights).
	var lib: Font = load(Liberation)
	var lib_bold: Font = load(LiberationBold)
	_check(lib != null and lib_bold != null, "Liberation Sans is bundled, regular and bold")
	if system_arial:
		var arial := SystemFont.new()
		arial.font_names = PackedStringArray(["Arial"])
		var arial_bold := SystemFont.new()
		arial_bold.font_names = PackedStringArray(["Arial"])
		arial_bold.font_weight = 700
		for t in ["See all games", "Diplomacy Mission Report", Texts["diplomacy"]]:
			var a: float = arial.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			var l: float = lib.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			var ab: float = arial_bold.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			var lb: float = lib_bold.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			_check(absf(a - l) < 1.0 and absf(ab - lb) < 1.0, "'%s...' as wide in Liberation Sans as in Arial (%.1f / %.1f, bold %.1f / %.1f)" % [t.left(20), l, a, lb, ab])

	# In it, the original's texts fit the Encyclopedia's box: five lines, 86 high.
	var k: int = OUI.K
	for key in Texts:
		var box: Vector2 = lib.get_multiline_string_size(Texts[key], HORIZONTAL_ALIGNMENT_LEFT, 396 * k, 13 * k)
		var lines: int = roundi(box.y / lib.get_height(13 * k))
		_check(lines == 5 and box.y <= 86 * k, "%s: %d lines, %.0f of 86 high - no scroll" % [key, lines, box.y / k])

	# The player's own Arial in the art set: the face, bold from its own file.
	var m: PackDefs.PackManifest = FactionRegistry.Pack.Manifest
	var dir := "%s/%s/fonts" % [ArtRoot, m.ArtSets[0]]
	DirAccess.make_dir_recursive_absolute(dir)
	for pair in [["arial.ttf", Liberation], ["arialbd.ttf", LiberationBold]]:
		var out := FileAccess.open("%s/%s" % [dir, pair[0]], FileAccess.WRITE)
		out.store_buffer(FileAccess.get_file_as_bytes(pair[1]))
		out.close()
	Art.Reset()
	var own: Font = OUI.Face()
	var own_bold: Font = OUI.Face(true)
	_check(own is FontFile and own == Art.OriginalFont() and (own as FontFile).data == FileAccess.get_file_as_bytes(Liberation),
		"with fonts/arial.ttf in the art set: that is the face")
	_check(own_bold is FontFile and own_bold != own and (own_bold as FontFile).data == FileAccess.get_file_as_bytes(LiberationBold),
		"... and bold is fonts/arialbd.ttf")

	_remove(ArtRoot)
	Art.IgnoreProjectFolder = false
	Art.UserArtRoot = "user://art"
	Art.Reset()
	print("[original_font] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


static func _remove(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in DirAccess.get_directories_at(path):
		_remove("%s/%s" % [path, sub])
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute("%s/%s" % [path, file])
	DirAccess.remove_absolute(path)
