extends SceneTree
## THE LOOK (src/ui/look.gd, SCHEMA.md section 15; docs/ww2-look-plan.md).
## Run once per pack - one pack per process:
##
##   .\tools\run-gd.ps1 tests/look_system.gd -- --pack=ww2
##   .\tools\run-gd.ps1 tests/look_system.gd -- --pack=star-wars-rebellion
##
## A pack WITH a look: the theme builds with every shared piece, every face and
## texture loads, every contrast pair clears its bar, and Adopt takes a tagged
## node's own colours off while an untagged one keeps them.
## A pack WITHOUT one: nothing is active, Install puts no theme on, and a
## tagged node keeps the colours its scene gave it - the Star Wars pack stays
## exactly as it was drawn.

var _failed := 0
var _ok := 0


func _init() -> void:
	# Nodes join the tree - and inherit its theme - only once the loop runs.
	await process_frame
	FactionRegistry.EnsureLoaded()
	if not FactionRegistry.IsLoaded():
		print("[look_system] FAIL no pack loaded")
		quit(1)
		return
	var id := FactionRegistry.LoadedId()
	if Look.Active():
		await _with_look(id)
	else:
		await _without_look(id)
	print("[look_system] %s: %d ok, %d failed" % [id, _ok, _failed])
	quit(1 if _failed > 0 else 0)


func _with_look(id: String) -> void:
	var t := Look.GetTheme()
	_check(t != null, "%s: the theme builds" % id)
	if t == null:
		return
	for piece in Look.PIECES:
		_check(t.is_type_variation(piece, t.get_type_variation_base(piece)) and not String(t.get_type_variation_base(piece)).is_empty(),
			"piece %s is a variation of %s" % [piece, t.get_type_variation_base(piece)])
	var faces: Dictionary = FactionRegistry.Pack.Look.get("fonts", {})
	for role in JsonUtil.data_keys(faces):
		var f := Look.F(role)
		_check(f is FontVariation and (f as FontVariation).base_font != null and (f as FontVariation).base_font != ThemeDB.fallback_font,
			"face '%s' loads from %s" % [role, faces[role].get("file", "")])
		if bool(faces[role].get("tabular", false)) and f is FontVariation:
			_check(not (f as FontVariation).opentype_features.is_empty(), "face '%s' asks for tabular figures" % role)
	var textures: Dictionary = FactionRegistry.Pack.Look.get("textures", {})
	for name in JsonUtil.data_keys(textures):
		_check(Look.Tex(name) != null, "texture '%s' loads" % name)
	for pair in Look.CONTRAST_PAIRS:
		var ratio := Look.Contrast(Look.C(pair[0]), Look.C(pair[1]))
		_check(ratio >= float(pair[2]), "contrast %s on %s is %.2f (needs %.1f)" % [pair[0], pair[1], ratio, pair[2]])
	# A side's chrome colour is text too (the map mode's name).
	for f in FactionRegistry.Playable:
		var ratio := Look.Contrast(Look.SideColor(f), Look.C("chassis"))
		_check(ratio >= 4.5, "contrast %s's side colour on chassis is %.2f (needs 4.5)" % [f.Id, ratio])

	# Install puts it on the tree; Adopt strips a tagged node, spares the rest.
	Look.Install(self)
	_check(root.theme == t, "Install puts the look on the root")
	var tagged := Label.new()
	tagged.theme_type_variation = Look.HEADING
	tagged.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	tagged.add_theme_font_size_override("font_size", 21)
	var plain := Label.new()
	plain.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	var bar := ColorRect.new()
	bar.theme_type_variation = Look.TITLE_BAR
	bar.color = Color(0.18, 0.22, 0.28)
	for n in [tagged, plain, bar]:
		root.add_child(n)
	await process_frame
	await process_frame
	Look.AdoptTree(root)
	_check(not tagged.has_theme_color_override("font_color"), "a tagged node loses the colour its scene gave it")
	_check(tagged.get_theme_color("font_color") == Look.C("heading"), "and wears its piece's")
	_check(tagged.has_theme_font_size_override("font_size"), "but keeps its size (layout)")
	_check(plain.has_theme_color_override("font_color"), "an untagged node keeps its colour")
	_check(bar.color == Look.C("chassis_deep"), "a tagged ColorRect takes the piece's bg")
	Look.Install(self)   # twice is harmless
	_check(root.theme == t, "Install is idempotent")


func _without_look(id: String) -> void:
	_check(not Look.Active(), "%s has no look" % id)
	_check(Look.GetTheme() == null, "no theme is built")
	Look.Install(self)
	_check(root.theme == null, "Install puts no theme on the root")
	var tagged := Label.new()
	tagged.theme_type_variation = Look.HEADING
	tagged.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	root.add_child(tagged)
	await process_frame
	Look.AdoptTree(root)
	_check(tagged.has_theme_color_override("font_color") and tagged.get_theme_color("font_color") == Color(0.6, 0.7, 0.8),
		"a tagged node keeps the colour its scene gave it")


func _check(cond: bool, what: String) -> void:
	if cond:
		_ok += 1
		print("[look_system] ok   %s" % what)
	else:
		_failed += 1
		print("[look_system] FAIL %s" % what)
