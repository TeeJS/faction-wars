class_name PackPicker
extends Control
## The first screen: WHICH SETTING to play. One card per pack under packs/,
## built from the pack's own manifest - name, summary, the sides in their
## colours, the map picture - and a Play button that loads that pack and goes
## on to its Cockpit (Menu.tscn). Engine screen, not a manual one: the original
## had one setting, so its first screen is the Cockpit (manual p021); this one
## sits in front of it only because there is more than one pack to choose.
##
## Nothing but the cards (TeeJ, 2026-09-24: "the launch screen is very
## cluttered"). A pack whose original look needs an art set the player has not
## imported - or imported from too old an exporter - opens the ARTWORK WINDOW
## on Play: why the art comes from the player's own copy, the steps to export
## and import it, and Continue without artwork. With the art in, the card has
## Clear artwork pack under Play; a pack the player imported has Remove pack.
## A pack file dropped on the window still imports, on every screen.
##
## The cards are a CAROUSEL (TeeJ, 2026-09-24): three on screen at most,
## turned by its arrows, the wheel or Left/Right, wrapping round. Up to three
## favorites, starred on their cards, come first when the screen loads. The
## last card is "+": Add your own pack, a faction pack from the file picker.
##
## Skipped straight through to the Cockpit when the choice is already made:
## `--pack=<id>` on the command line, a pack already loaded (a scene coming
## back here mid-flow), or exactly one pack installed.
##
## The Cockpit's Exit comes BACK here (ExitToPicker): the loaded pack is
## unloaded - the one place that happens - and another can be chosen. With
## nothing to choose (one pack, or --pack= forcing it) that Exit quits
## instead. Exit Game is this screen's own button, hidden on the web.
##
## The last choice is remembered in user://pack.cfg and pre-focused next time;
## packs/active.json stays the headless default.

## The pack's pictures, including an art set's (docs/original-art-plan.md).
const Art := preload("res://src/ui/artwork.gd")
## Importing the player's art set and faction packs (plan phase 3).
const PackImport := preload("res://src/ui/pack_import.gd")

const MENU_SCENE := "res://Menu.tscn"
## The last pack played and the favorites. A static var so a test can point it
## at a scratch file and never touch the player's own.
static var LastFile := "user://pack.cfg"
## THE CAROUSEL (TeeJ, 2026-09-24): three cards on screen at most, turned by
## the arrows at its sides, the mouse wheel over it or the Left and Right
## keys, wrapping round; up to three FAVORITES, starred on their cards, come
## first when the screen loads; the "+" card to add a pack is always last.
const MaxShown := 3
const MaxFavorites := 3
const CardWidth := 340
const CardGap := 24
const ArrowWidth := 44
## The "+" card's place in the carousel order.
const ADD_CARD := "+"

## THE LOOK (TeeJ, 2026-09-24: "clean this up and improve the design"), in
## the colours of the FACTION WARS logo art (a vintage space poster: warm
## charcoal, a red planet, an orange-red glow): charcoal cards over the page,
## the planet's red for Play alone, the glow's peach for a favorite and a lit
## edge, white type. The logo goes across the top (LOGO_FILE) and its
## background behind the page (BACKGROUND_FILE) once the artist delivers them;
## until then a stand-in wordmark and a drawn backdrop.
const LOGO_FILE := "res://assets/brand/logo.png"
const BACKGROUND_FILE := "res://assets/brand/background.jpg"
const LogoH := 120
const CInk := Color("#121416")
const CCard := Color(0.086, 0.078, 0.082, 0.92)
const CEdge := Color("#3a2c2c")
const CAccent := Color("#c8240e")
const CGlow := Color("#fbc8a6")
const CText := Color("#f2efec")
const CMuted := Color("#a39a98")
## An import's result on a box: done, or refused.
const COk := Color("#9fe0a4")
const CFail := Color("#ff8a70")
const PictureH := 176
const PlayW := 180
## A card's foot: its bottom margin, and the gap between Play and the row
## under it - one, so a link in that row is centred between them.
const CardFootMargin := 16
## The card's inset inside its edge (_dress_card).
const CardInset := 6
const CardPad := 18
## Slightly rounded, like the logo's letters (TeeJ, 2026-09-24).
const CardRadius := 8
const ButtonRadius := 6
## The Faction Wars Exporter's download: always the newest release's exe (one
## file, from exporter 2.2.0 on).
const EXPORTER_URL := "https://github.com/TeeJS/faction-wars/releases/latest/download/FactionWarsExporter.exe"
## What the files window names for each art set the engine knows: the game it
## comes from, the files the exporter writes (its Export and its Export
## movies...) and what the movies are (the exporter's README: 15 movies, about
## 350 MB, 10-15 minutes).
const ART_SOURCES := {"swr-original": {"game": "Star Wars: Rebellion", "file": "swr-original.art.zip",
	"movies": "swr-original.movies.zip", "movies_note": "the 15 movies. Optional: about 350 MB, 10-15 minutes.", "short": "Rebellion"}}

## pack id -> the Play button, for the test and the keyboard.
var _play: Dictionary = {}
## pack id -> its loaded manifest and tables (null for one that failed).
var _packs: Dictionary = {}
var _cards: HBoxContainer
## The carousel: its order (pack ids, then ADD_CARD), each card's panel, the
## arrows, and the first card on screen (kept across a rebuild).
var _order: Array[String] = []
var _panels: Dictionary = {}
var _row: HBoxContainer
var _left: Button
var _right: Button
var _dots: HBoxContainer
var _start: int = 0
## Set by ExitToPicker: the next picker is a return from the Cockpit.
static var _returning: bool = false
var _column: VBoxContainer
## The artwork window while it is up, and the pack it is for.
var _art_window: Control = null
var _art_for: String = ""


func _ready() -> void:
	# Back from a Cockpit: its music is that setting's, not the picker's.
	preload("res://src/ui/music.gd").Stop()
	# A pack file dropped on the game imports from here on, on every screen.
	PackImport.ListenForDrops(get_tree())
	PackImport.OnImported = _on_imported
	PackImport.OnProgress = _on_progress
	var ids := FactionRegistry.ListPackIds()
	if _returning:
		_returning = false
		if not CanReturn():
			# Nothing else to choose: the Cockpit's Exit means quit here.
			get_tree().quit()
			if not OS.has_feature("web"):
				return
		FactionRegistry.Unload()
		_build(ids)
		return
	if FactionRegistry.IsLoaded() or not _cmdline_pack().is_empty():
		FactionRegistry.EnsureLoaded()
		_go()
		return
	if ids.size() == 1:
		Choose(ids[0])
		return
	_build(ids)


## Whether the Cockpit's Exit has anywhere to go: more than one pack, and
## none forced by --pack=. Otherwise that Exit quits, and says so.
static func CanReturn() -> bool:
	return FactionRegistry.ListPackIds().size() > 1 and _cmdline_pack().is_empty()


## The Cockpit's Exit: back to this screen to choose again. Remembers the
## pack being left so its card is the focused one.
static func ExitToPicker(tree: SceneTree) -> void:
	_returning = true
	if FactionRegistry.IsLoaded():
		_remember(FactionRegistry.LoadedId())
	tree.change_scene_to_file("res://PackPicker.tscn")


## Load `pack_id` and go on to its Cockpit. False when it cannot load.
func Choose(pack_id: String) -> bool:
	if not FactionRegistry.EnsureLoaded(pack_id):
		return false
	_remember(pack_id)
	_go()
	return true


## A card's Play: the artwork window first when the pack's original look is
## not ready, else straight on.
func Play(pack_id: String) -> void:
	var pack: PackLoader.LoadedPack = _packs.get(pack_id)
	if pack != null and not ArtState(pack).is_empty():
		_open_art_window(pack_id)
		return
	Choose(pack_id)


## The Play buttons by pack id, in card order.
func PlayButtons() -> Dictionary:
	return _play


## The artwork window, or null when it is not up.
func ArtworkWindow() -> Control:
	return _art_window if is_instance_valid(_art_window) else null


func _go() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)


static func _cmdline_pack() -> String:
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a.begins_with("--pack="):
			return a.substr("--pack=".length())
	return ""


static func _remember(pack_id: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(LastFile)   # keep the favorites
	cfg.set_value("pack", "last", pack_id)
	cfg.save(LastFile)


## The starred packs, in the order they were starred.
static func Favorites() -> Array[String]:
	var out: Array[String] = []
	var cfg := ConfigFile.new()
	if cfg.load(LastFile) != OK:
		return out
	for f in cfg.get_value("pack", "favorites", []):
		out.append(str(f))
	return out


## Star or unstar a pack. False when it would be a fourth favorite.
static func SetFavorite(pack_id: String, on: bool) -> bool:
	var favs := Favorites()
	if on:
		if favs.has(pack_id):
			return true
		if favs.size() >= MaxFavorites:
			return false
		favs.append(pack_id)
	elif not favs.has(pack_id):
		return true
	else:
		favs.erase(pack_id)
	var cfg := ConfigFile.new()
	cfg.load(LastFile)   # keep the last pack played
	cfg.set_value("pack", "favorites", favs)
	cfg.save(LastFile)
	return true


## The carousel's order: the favorites as starred, then the packs that come
## with the game, then the player's own, then the "+" card.
static func CarouselOrder(ids: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for f in Favorites():
		if ids.has(f) and not out.has(f):
			out.append(f)
	for shipped in [true, false]:
		for id in ids:
			if not out.has(id) and _is_imported(id) != shipped:
				out.append(id)
	out.append(ADD_CARD)
	return out


static func _last() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(LastFile) != OK:
		return ""
	return str(cfg.get_value("pack", "last", ""))


## What stands between a pack and its original look: "" when every art set it
## declares is here and new enough, "missing" when one is not imported,
## "outdated" when one came from an exporter older than the game needs.
static func ArtState(pack: PackLoader.LoadedPack) -> String:
	for s in pack.Manifest.ArtSets:
		if not Art.HasArtSet(s):
			return "missing"
	if not _outdated_sets(pack).is_empty():
		return "outdated"
	return ""


## The pack's art sets the player imported ({kind, id, title, exporter, outdated, ...}).
static func _imported_sets(pack: PackLoader.LoadedPack) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in PackImport.Installed():
		if e.kind == PackImport.KIND_ART_SET and pack.Manifest.ArtSets.has(e.id):
			out.append(e)
	return out


static func _outdated_sets(pack: PackLoader.LoadedPack) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in _imported_sets(pack):
		if e.outdated:
			out.append(e)
	return out


## A pack the player imported (user://packs), not one that ships with the game.
static func _is_imported(pack_id: String) -> bool:
	return FactionRegistry.PackDir(pack_id).begins_with(FactionRegistry.USER_PACKS_ROOT)


func _build(ids: Array[String]) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = _tooltip_theme()
	var bg := Backdrop.new()
	bg.name = "Backdrop"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 26)
	centre.add_child(column)
	_column = column

	# The logo across the top (TeeJ, 2026-09-24), and nothing under it: the
	# cards say what the screen is for ("CHOOSE A SETTING" went - TeeJ: "makes
	# no sense").
	var logo := LogoSlot.new()
	logo.name = "LogoSlot"
	logo.custom_minimum_size = Vector2(CardWidth * MaxShown + CardGap * 2, LogoH)
	column.add_child(logo)

	# The carousel: an arrow either side of the cards on show, and a dot per
	# card under them.
	_row = HBoxContainer.new()
	_row.name = "Carousel"
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 18)
	column.add_child(_row)
	_left = _arrow("CarouselLeft", -1)
	_row.add_child(_left)
	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", CardGap)
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_child(_cards)
	_right = _arrow("CarouselRight", 1)
	_row.add_child(_right)
	_dots = HBoxContainer.new()
	_dots.name = "Dots"
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots.add_theme_constant_override("separation", 8)
	column.add_child(_dots)

	_order = CarouselOrder(ids)
	for id in _order:
		if id == ADD_CARD:
			_panels[id] = _add_card()
			continue
		var errors: Array[String] = []
		var pack := PackLoader.Load(FactionRegistry.PackDir(id), errors)
		_packs[id] = pack
		_card(id, pack, errors)
	_layout_carousel()
	if not resized.is_connected(_layout_carousel):
		resized.connect(_layout_carousel)
	# The last pack played has the focus when its card is on show; else the first.
	var last := _last()
	var focus_first: Button = null
	for id in VisibleIds():
		if _play.has(id) and (focus_first == null or id == last):
			focus_first = _play[id]
	if focus_first != null and not focus_first.disabled:
		focus_first.grab_focus()

	# A browser tab has no desktop to quit to (TeeJ, room #97).
	if not OS.has_feature("web"):
		var quit := Button.new()
		quit.name = "ExitGame"
		quit.text = "EXIT GAME"
		quit.custom_minimum_size = Vector2(150, 38)
		_outline(quit)
		quit.pressed.connect(func() -> void: get_tree().quit())
		var foot := CenterContainer.new()
		foot.add_child(quit)
		column.add_child(foot)
	_reveal()


## One pack's card. A pack that fails validation still gets a card, with its
## problems in place of the summary and no Play - the list must never lie
## about what is installed.
func _card(id: String, pack: PackLoader.LoadedPack, errors: Array[String]) -> Button:
	var panel := PanelContainer.new()
	panel.name = "Card_" + id
	panel.custom_minimum_size = Vector2(CardWidth, 0)
	_dress_card(panel)
	_cards.add_child(panel)
	_panels[id] = panel
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	panel.add_child(outer)

	# THE PICTURE across the card's top: the map from the art set when it is
	# imported, else the pack's own card picture (TeeJ, 2026-09-24) - filling
	# its plate and cut to it, fading into the card at its foot. The
	# favorite's star sits on its corner.
	var plate := Control.new()
	plate.name = "PictureFrame"
	plate.custom_minimum_size = Vector2(0, PictureH)
	plate.clip_contents = true
	outer.add_child(plate)
	var backing := ColorRect.new()
	backing.color = Color(0.03, 0.035, 0.05)
	backing.set_anchors_preset(Control.PRESET_FULL_RECT)
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(backing)
	var picture := TextureRect.new()
	picture.name = "Picture"
	if pack != null:
		picture.texture = Art.PackImage(pack.Manifest.MapImage, id, pack.Manifest.ArtSets)
		if picture.texture == null and not pack.Manifest.CardImage.is_empty():
			picture.texture = Art.PackImage(pack.Manifest.CardImage, id, pack.Manifest.ArtSets)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(picture)
	var fade := TextureRect.new()
	fade.texture = _fade_texture()
	fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fade.stretch_mode = TextureRect.STRETCH_SCALE
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(fade)
	var star := StarButton.new()
	star.name = "Star"
	star.on = Favorites().has(id)
	star.tooltip_text = _star_tip(star.on)
	star.pressed.connect(func() -> void: _toggle_star(id, star))
	star.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	star.offset_left = -StarButton.Size - 8
	star.offset_right = -8
	star.offset_top = 8
	star.offset_bottom = 8 + StarButton.Size
	plate.add_child(star)

	var body := MarginContainer.new()
	for side in ["left", "right"]:
		body.add_theme_constant_override("margin_" + side, CardPad)
	body.add_theme_constant_override("margin_top", 6)
	# Less the card's own inset (_dress_card), so the gap to its edge is CardFootMargin.
	body.add_theme_constant_override("margin_bottom", CardFootMargin - CardInset)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(body)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	body.add_child(box)

	var name := _label(pack.Manifest.DisplayName if pack != null else id, 24, CText, _face(0, 0.5))
	name.name = "Title"
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(name)
	# The pack's own version, "v1.3" (pack.json `version`), when it has one.
	if pack != null and not pack.Manifest.VersionLabel().is_empty():
		var version := _label(pack.Manifest.VersionLabel(), 13, CMuted)
		version.name = "Version"
		version.tooltip_text = "This pack's version."
		version.mouse_filter = Control.MOUSE_FILTER_PASS
		box.add_child(version)
	if pack != null:
		var summary := _label(pack.Manifest.Summary, 14, CMuted)
		summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		summary.custom_minimum_size = Vector2(CardWidth - 12 - 2 * CardPad, 0)
		summary.add_theme_constant_override("line_spacing", 3)
		box.add_child(summary)
		# The sides, each a dot of its colour and its name.
		var sides := HFlowContainer.new()
		sides.add_theme_constant_override("h_separation", 16)
		sides.add_theme_constant_override("v_separation", 4)
		for f in pack.Factions:
			var colour: Color = FactionRegistry.ParseColor(f.ColorHex)
			var chip := HBoxContainer.new()
			chip.add_theme_constant_override("separation", 6)
			var dot := Panel.new()
			dot.custom_minimum_size = Vector2(8, 8)
			dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			dot.add_theme_stylebox_override("panel", _box(colour, colour, 4, 0))
			chip.add_child(dot)
			chip.add_child(_label(f.DisplayName, 13, colour.lightened(0.15), _face(1, 0.3)))
			sides.add_child(chip)
		box.add_child(sides)
	else:
		var broken := _label("Cannot load this pack:\n" + "\n".join(errors.slice(0, 6)), 13, Color(1.0, 0.5, 0.5))
		broken.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		broken.custom_minimum_size = Vector2(CardWidth - 12 - 2 * CardPad, 0)
		box.add_child(broken)

	# Everything below sits at the card's foot, so every card's Play is at the
	# same height, the same size, narrower than the card (TeeJ, 2026-09-24).
	var push := Control.new()
	push.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(push)
	var foot := VBoxContainer.new()
	foot.name = "Foot"
	# Play, then the row of the card's other actions, a link centred in it as
	# far from Play as from the card's foot (TeeJ, 2026-09-28: "should be equal
	# from each"): the gap above it the body's bottom margin, its row's slack
	# shared above and below it.
	foot.add_theme_constant_override("separation", CardFootMargin)
	box.add_child(foot)
	var play := Button.new()
	play.name = "Play"
	play.text = "PLAY"
	play.custom_minimum_size = Vector2(PlayW, 42)
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_primary(play)
	play.disabled = pack == null
	play.pressed.connect(func() -> void: Play(id))
	foot.add_child(play)
	_play[id] = play
	# The card's other actions, on a row every card keeps (empty or not), so
	# the cards stay the same height and their Play buttons level.
	var links := HBoxContainer.new()
	links.name = "Links"
	links.alignment = BoxContainer.ALIGNMENT_CENTER
	links.custom_minimum_size = Vector2(0, 32)
	links.add_theme_constant_override("separation", 10)
	foot.add_child(links)

	# The player's own files for it - the artwork and the movies: Manage files
	# (TeeJ, 2026-09-28: "The clear artwork pack button needs to be renamed
	# Manage files"), the files window with each file's Import and Remove. On
	# every pack that uses an art set, so a player who went on without the
	# artwork can bring it in later.
	if pack != null and not pack.Manifest.ArtSets.is_empty():
		var manage := _link("ManageFiles", "Manage files")
		manage.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		manage.tooltip_text = "Import or remove %s's artwork and movies - your own files." % pack.Manifest.DisplayName
		manage.pressed.connect(func() -> void: _open_art_window(id, "", true, true))
		links.add_child(manage)
	# A pack the player imported can go again; the ones that ship cannot.
	if _is_imported(id):
		# Every version kept of it goes too (PackImport.Remove), and says so.
		var versions: int = 1 + PackImport.ArchivedVersions(id).size()
		var remove := _link("RemovePack", "Remove pack" if versions == 1 else "Remove pack (all %d versions)" % versions)
		var title: String = pack.Manifest.DisplayName if pack != null else id
		var what: String = title if versions == 1 else "%s and every version of it kept here (%d)" % [title, versions]
		remove.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		remove.tooltip_text = "Remove %s. Import its .zip again to get it back." % what
		remove.pressed.connect(func() -> void:
			_confirm("Remove pack", "Remove %s? Import its file again to get it back." % what, "Remove", func() -> void:
				PackImport.Remove(PackImport.KIND_FACTION_PACK, id)
				SetFavorite(id, false)   # a removed pack is no favorite
				_rebuild()))
		links.add_child(remove)
	return play


# ---- the carousel -------------------------------------------------------------------

## The "+" card, as big as the others, always last: a faction pack of the
## player's own, from the file picker (TeeJ, 2026-09-24).
func _add_card() -> Control:
	var card := AddCard.new()
	card.name = "AddPack"
	card.custom_minimum_size = Vector2(CardWidth, 0)
	card.tooltip_text = "Import a faction pack (.zip file).\nKeep the file: you can import it again at any time."
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		card.add_theme_stylebox_override(st, empty)
	card.pressed.connect(func() -> void: PackImport.PickFile(_on_imported))
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	var room := Control.new()   # where AddCard draws its ring and plus
	room.custom_minimum_size = Vector2(0, AddCard.Ring * 2 + 24)
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(room)
	for part in [["ADD YOUR OWN PACK", 16, CText, _face(3, 0.7)],
			["A faction pack (.zip) made with the pack editor.", 14, CText.darkened(0.12), null]]:
		var l := _label(part[0], part[1], part[2], part[3])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(CardWidth - 60, 0)
		l.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(l)
	# What a click does, said as a button would say it.
	var cta := PanelContainer.new()
	cta.name = "ChooseFile"
	cta.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pill := _box(Color(CGlow, 0.08), CGlow, ButtonRadius, 1)
	pill.content_margin_left = 16
	pill.content_margin_right = 16
	pill.content_margin_top = 7
	pill.content_margin_bottom = 7
	cta.add_theme_stylebox_override("panel", pill)
	var cta_text := _label("CHOOSE A .ZIP FILE", 13, CGlow, _face(2, 0.5))
	cta_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cta.add_child(cta_text)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(gap)
	box.add_child(cta)
	_cards.add_child(card)
	return card


func _arrow(node_name: String, dir: int) -> Button:
	var b := ArrowButton.new()
	b.name = node_name
	b.dir = dir
	b.custom_minimum_size = Vector2(ArrowWidth, ArrowWidth)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = "Previous setting" if dir < 0 else "Next setting"
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, empty)
	b.pressed.connect(func() -> void: Turn(dir))
	return b


## How many cards fit on screen: as many as the width takes, three at most.
func _shown() -> int:
	var width: float = size.x if size.x > 0 else get_viewport_rect().size.x
	var fit := int((width - 2 * (ArrowWidth + 18)) / float(CardWidth + CardGap))
	return mini(clampi(fit, 1, MaxShown), _order.size())


## Shows the cards from _start on, in carousel order, wrapping round. The
## arrows are always there (TeeJ, 2026-09-24: "I do not have the arrows"),
## dimmed when every card is on show; the dots mark which cards are.
func _layout_carousel() -> void:
	if _cards == null or _order.is_empty():
		return
	var n := _order.size()
	var shown := _shown()
	var turning := n > shown
	_left.disabled = not turning
	_right.disabled = not turning
	_left.tooltip_text = "Previous setting" if turning else "Every setting is on screen"
	_right.tooltip_text = "Next setting" if turning else "Every setting is on screen"
	_left.queue_redraw()
	_right.queue_redraw()
	_start = posmod(_start, n) if turning else 0
	if _dots != null:
		for d in _dots.get_children():
			_dots.remove_child(d)
			d.queue_free()
		_dots.visible = turning
		for i in n:
			var on: bool = posmod(i - _start, n) < shown
			var dot := Panel.new()
			dot.custom_minimum_size = Vector2(18 if on else 8, 8)
			dot.add_theme_stylebox_override("panel", _box(CAccent if on else CEdge, CAccent if on else CEdge, 4, 0))
			_dots.add_child(dot)
	for c in _cards.get_children():
		(c as Control).visible = false
	for i in shown:
		var card: Control = _panels.get(_order[(_start + i) % n])
		if card == null:
			continue
		card.visible = true
		_cards.move_child(card, i)


## The cards on screen, left to right (ADD_CARD for the "+" card).
func VisibleIds() -> Array[String]:
	var out: Array[String] = []
	if _order.is_empty():
		return out
	for i in _shown():
		out.append(_order[(_start + i) % _order.size()])
	return out


## Turn the carousel one card left (-1) or right (1), wrapping round.
func Turn(step: int) -> void:
	if _order.size() <= _shown():
		return
	_start = posmod(_start + step, _order.size())
	_layout_carousel()


## Turn until `id`'s card is on show (a pack just imported).
func _bring_into_view(id: String) -> void:
	if VisibleIds().has(id) or not _order.has(id):
		return
	_start = _order.find(id) - (_shown() - 1)
	_layout_carousel()


func _toggle_star(id: String, star: StarButton) -> void:
	var want := not star.on
	if not SetFavorite(id, want):
		_tell({"message": "Up to %d favorites: unstar one first." % MaxFavorites}, "Favorites")
		return
	star.on = want
	star.tooltip_text = _star_tip(want)
	star.queue_redraw()


## The star's state, unmistakable (TeeJ, 2026-09-24).
static func _star_tip(on: bool) -> String:
	return "Remove from favorites" if on else "Add to favorites"


## Left and Right, and the mouse wheel over the cards, turn the carousel -
## not while a window or a question is up over it.
func _input(event: InputEvent) -> void:
	if _row == null or _left.disabled or ArtworkWindow() != null or _dialog_up():
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and (event.keycode == KEY_LEFT or event.keycode == KEY_RIGHT):
		Turn(-1 if event.keycode == KEY_LEFT else 1)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed \
			and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN) \
			and _row.get_global_rect().has_point(event.position):
		Turn(-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
		get_viewport().set_input_as_handled()


func _dialog_up() -> bool:
	return _top_modal() != null


## The box on top, if one is up (a Window, or one of this screen's own boxes).
func _top_modal() -> Node:
	for i in range(get_child_count() - 1, -1, -1):
		var c: Node = get_child(i)
		if c.is_queued_for_deletion():
			continue
		if (c is Window and (c as Window).visible) or c.has_meta("modal"):
			return c
	return null


# ---- the look: styles and the drawn parts ---------------------------------------------

static func _box(bg: Color, edge: Color, radius: int = 10, width: int = 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = edge
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	return sb


## Tooltips that read (TeeJ, 2026-09-24: "hard to read"): light 15 px type on
## a solid dark panel with a warm edge, padded. Only the tooltip types are in
## it, so every other control keeps its own look.
static func _tooltip_theme() -> Theme:
	var th := Theme.new()
	var panel := _box(Color(0.07, 0.06, 0.065, 0.97), CGlow.darkened(0.35), ButtonRadius)
	panel.content_margin_left = 12
	panel.content_margin_right = 12
	panel.content_margin_top = 8
	panel.content_margin_bottom = 8
	th.set_stylebox("panel", "TooltipPanel", panel)
	th.set_color("font_color", "TooltipLabel", CText)
	th.set_font_size("font_size", "TooltipLabel", 15)
	th.set_constant("line_spacing", "TooltipLabel", 3)
	return th


## The game's font, spaced out and made heavier: the type's voice, since the
## project ships no font of its own.
static func _face(spacing: int, embolden: float = 0.0) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = ThemeDB.fallback_font
	f.spacing_glyph = spacing
	f.variation_embolden = embolden
	return f


static func _label(text: String, px: int, colour: Color, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", colour)
	if font != null:
		l.add_theme_font_override("font", font)
	return l


## A card's dossier: charcoal over the page, a thin warm edge, a soft shadow;
## the edge lights in the glow's peach under the pointer.
static func _dress_card(panel: PanelContainer) -> void:
	var rest := _box(CCard, CEdge, CardRadius)
	rest.shadow_color = Color(0, 0, 0, 0.5)
	rest.shadow_size = 16
	rest.shadow_offset = Vector2(0, 6)
	rest.set_content_margin_all(CardInset)   # the picture inset, clear of the rounded corners
	var lit: StyleBoxFlat = rest.duplicate()
	lit.border_color = CGlow.darkened(0.25)
	panel.add_theme_stylebox_override("panel", rest)
	panel.mouse_entered.connect(func() -> void: panel.add_theme_stylebox_override("panel", lit))
	panel.mouse_exited.connect(func() -> void: panel.add_theme_stylebox_override("panel", rest))


## Play: the one filled button, in the planet's red, capitals spaced out.
static func _primary(b: Button) -> void:
	var looks := {"normal": CAccent, "hover": CAccent.lightened(0.12), "pressed": CAccent.darkened(0.15),
		"disabled": Color(0.2, 0.18, 0.18)}
	for st in looks:
		var sb := _box(looks[st], looks[st], ButtonRadius, 0)
		sb.set_content_margin_all(8)
		b.add_theme_stylebox_override(st, sb)
	var ring := _box(Color(0, 0, 0, 0), CGlow, ButtonRadius, 2)
	ring.draw_center = false
	b.add_theme_stylebox_override("focus", ring)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	b.add_theme_color_override("font_disabled_color", CMuted)
	b.add_theme_font_override("font", _face(4, 0.6))
	b.add_theme_font_size_override("font_size", 15)


## A button that is not the main one, in the "+" card's voice (its CHOOSE A
## .ZIP FILE): a peach outline over a faint peach wash, spaced capitals,
## filling warmer under the pointer.
static func _outline(b: Button) -> void:
	var rest := _box(Color(CGlow, 0.05), CGlow.darkened(0.3), ButtonRadius, 1)
	var hot := _box(Color(CGlow, 0.16), CGlow, ButtonRadius, 1)
	var off := _box(Color(0, 0, 0, 0.2), CEdge, ButtonRadius, 1)
	for sb in [rest, hot, off]:
		sb.content_margin_left = 20
		sb.content_margin_right = 20
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
	for st in ["normal", "focus"]:
		b.add_theme_stylebox_override(st, rest)
	b.add_theme_stylebox_override("hover", hot)
	b.add_theme_stylebox_override("pressed", hot)
	b.add_theme_stylebox_override("disabled", off)
	b.add_theme_color_override("font_color", CGlow)
	b.add_theme_color_override("font_focus_color", CGlow)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", CMuted.darkened(0.2))
	b.add_theme_font_override("font", _face(2, 0.5))
	b.add_theme_font_size_override("font_size", 13)


## The rule under a box's title: the logo's underline, warmed - the planet's red
## burning into the glow's peach and out to nothing.
static var _rule: GradientTexture2D = null
static func _rule_texture() -> GradientTexture2D:
	if _rule != null:
		return _rule
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	g.colors = PackedColorArray([CAccent, Color(CGlow, 0.55), Color(CGlow, 0.0)])
	_rule = GradientTexture2D.new()
	_rule.gradient = g
	_rule.width = 256
	_rule.height = 1
	return _rule


## Behind a box's title: the planet's red, faint at the top, gone by its foot.
static var _glow: GradientTexture2D = null
static func _glow_texture() -> GradientTexture2D:
	if _glow != null:
		return _glow
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(CAccent, 0.16), Color(CAccent, 0.0)])
	_glow = GradientTexture2D.new()
	_glow.gradient = g
	_glow.width = 4
	_glow.height = 64
	_glow.fill_from = Vector2(0, 0)
	_glow.fill_to = Vector2(0, 1)
	return _glow


## A card's other action (TeeJ, 2026-09-24: "too subtle or ambiguous"): a
## small outlined button, light text on a clear edge, the edge and text
## warming to peach under the pointer - plainly a button, plainly less than
## Play.
static func _link(node_name: String, text: String) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 30)
	var rest := _box(Color(1, 1, 1, 0.04), CText.darkened(0.45), ButtonRadius)
	var hot := _box(Color(CGlow, 0.1), CGlow, ButtonRadius)
	for sb in [rest, hot]:
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
	for st in ["normal", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, rest)
	b.add_theme_stylebox_override("hover", hot)
	b.add_theme_stylebox_override("pressed", hot)
	b.add_theme_color_override("font_color", CText.darkened(0.08))
	b.add_theme_color_override("font_hover_color", CGlow)
	b.add_theme_color_override("font_pressed_color", CGlow)
	b.add_theme_font_size_override("font_size", 13)
	return b


## The picture's foot fading into the card.
static var _fade: GradientTexture2D = null
static func _fade_texture() -> GradientTexture2D:
	if _fade != null:
		return _fade
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
	g.colors = PackedColorArray([Color(CCard, 0.0), Color(CCard, 0.0), Color(CCard, 1.0)])
	_fade = GradientTexture2D.new()
	_fade.gradient = g
	_fade.fill_from = Vector2(0, 0)
	_fade.fill_to = Vector2(0, 1)
	_fade.width = 4
	_fade.height = 64
	return _fade


## The cards on show fade in one after the other.
func _reveal() -> void:
	var i := 0
	for id in VisibleIds():
		var card: Control = _panels.get(id)
		if card == null:
			continue
		card.modulate.a = 0.0
		var t := card.create_tween()
		t.tween_interval(0.07 * i)
		t.tween_property(card, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		i += 1


## The page behind everything: the logo art's background when the artist's
## file is in (BACKGROUND_FILE, darkened a little so the cards read), else a
## drawn one in its colours - charcoal, a red glow low on the right, stars and
## grain.
class Backdrop extends Control:
	var _picture: Texture2D = null

	func _ready() -> void:
		if ResourceLoader.exists(BACKGROUND_FILE):
			_picture = load(BACKGROUND_FILE)
		resized.connect(queue_redraw)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if _picture != null:
			var s := maxf(size.x / _picture.get_width(), size.y / _picture.get_height())
			var drawn := _picture.get_size() * s
			draw_texture_rect(_picture, Rect2((size - drawn) / 2.0, drawn), false)
			draw_rect(r, Color(0, 0, 0, 0.35))
			return
		draw_rect(r, CInk)
		# The glow, low in the right-hand corner: many faint rings, wide and
		# dark red to small and warm, so no ring shows.
		var centre := Vector2(size.x * 0.92, size.y * 1.02)
		var steps := 90
		for k in steps:
			var t := float(k) / steps
			var radius := lerpf(size.x * 0.75, size.x * 0.03, t)
			var colour := Color("#5a0d0c").lerp(Color("#b83a26"), t * t)
			colour.a = 0.018
			draw_circle(centre, radius, colour)
		# Stars and grain, the same every time.
		var rng := RandomNumberGenerator.new()
		rng.seed = 1977
		for k in 170:
			var p := Vector2(rng.randf() * size.x, rng.randf() * size.y)
			draw_rect(Rect2(p, Vector2.ONE * (2.0 if rng.randf() < 0.12 else 1.0)), Color(1, 1, 1, rng.randf_range(0.25, 0.8)))
		for k in 2400:
			var p := Vector2(rng.randf() * size.x, rng.randf() * size.y)
			draw_rect(Rect2(p, Vector2.ONE), Color(1, 1, 1, 0.035) if rng.randf() < 0.5 else Color(0, 0, 0, 0.12))


## The logo across the top: the artist's (LOGO_FILE) when it is in, else a
## stand-in wordmark in its manner - wide white capitals over a rule.
class LogoSlot extends Control:
	func _ready() -> void:
		custom_minimum_size = Vector2(0, LogoH)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if ResourceLoader.exists(LOGO_FILE):
			var pic := TextureRect.new()
			pic.name = "Logo"
			pic.texture = load(LOGO_FILE)
			pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			pic.set_anchors_preset(Control.PRESET_FULL_RECT)
			pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(pic)
			return
		var word := PackPicker._label("FACTION WARS", 64, Color.WHITE, PackPicker._face(10, 1.2))
		word.name = "Wordmark"
		word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		word.set_anchors_preset(Control.PRESET_FULL_RECT)
		word.offset_bottom = -14
		add_child(word)

	func _draw() -> void:
		if get_node_or_null("Logo") != null:
			return
		var w := minf(size.x, 820.0)
		draw_rect(Rect2(Vector2((size.x - w) / 2.0, size.y - 10), Vector2(w, 4)), Color.WHITE)


## A round arrow either side of the carousel (TeeJ, 2026-09-24: "too subtle"):
## a solid dark disc with a light ring and a white arrow, the ring peach under
## the pointer; when there is nothing to turn, still there but plainly dim.
class ArrowButton extends Button:
	var dir: int = 1

	func _ready() -> void:
		flat = true
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) / 2.0 - 1.5
		var live := not disabled
		var hot := live and is_hovered()
		draw_circle(c, r, Color(0.07, 0.06, 0.065, 0.95) if live else Color(0.07, 0.06, 0.065, 0.55))
		var ring: Color = CGlow if hot else (CText.darkened(0.2) if live else Color(CMuted, 0.4))
		draw_arc(c, r, 0, TAU, 64, ring, 2.0 if live else 1.5, true)
		var t := r * 0.38
		var col: Color = (CGlow if hot else Color.WHITE) if live else Color(CMuted, 0.45)
		draw_colored_polygon(PackedVector2Array([c + Vector2(t * dir * 1.1, 0), c + Vector2(-t * 0.7 * dir, -t), c + Vector2(-t * 0.7 * dir, t)]), col)


## A favorite's star on the card's picture, over a dark disc so it reads on
## any picture: filled in the glow's peach when starred, an outline when not.
class StarButton extends Button:
	const Size := 32
	var on: bool = false

	func _ready() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(Size, Size)
		var empty := StyleBoxEmpty.new()
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(st, empty)
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func _draw() -> void:
		var c := size / 2.0
		draw_circle(c, minf(size.x, size.y) / 2.0, Color(0, 0, 0, 0.55))
		var outer := minf(size.x, size.y) * 0.34
		var pts := PackedVector2Array()
		for i in 10:
			var r := outer if i % 2 == 0 else outer * 0.45
			var a := -PI / 2.0 + i * PI / 5.0
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		if on:
			draw_colored_polygon(pts, CGlow)
		else:
			var ring := pts.duplicate()
			ring.append(pts[0])
			draw_polyline(ring, Color.WHITE if is_hovered() else Color(1, 1, 1, 0.7), 1.6, true)


## The "+" card: a dashed outline where a card would be, a ring with a plus,
## all warming under the pointer.
class AddCard extends Button:
	const Ring := 34

	func _ready() -> void:
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func _draw() -> void:
		# Contrast raised (TeeJ, 2026-09-24: "too subtle"): a card's own dark
		# ground, a light dashed edge, the ring and plus in peach.
		var hot := is_hovered()
		var edge: Color = CGlow if hot else CText.darkened(0.35)
		var r := Rect2(Vector2(1, 1), size - Vector2(2, 2))
		var fill := PackPicker._box(Color(CCard, 0.95 if hot else 0.85), Color(0, 0, 0, 0), CardRadius, 0)
		draw_style_box(fill, r)
		# A dashed edge with the cards' rounded corners.
		var k := float(CardRadius)
		var a := r.position
		var b := r.end
		draw_dashed_line(Vector2(a.x + k, a.y), Vector2(b.x - k, a.y), edge, 2.0, 9.0)
		draw_dashed_line(Vector2(b.x, a.y + k), Vector2(b.x, b.y - k), edge, 2.0, 9.0)
		draw_dashed_line(Vector2(b.x - k, b.y), Vector2(a.x + k, b.y), edge, 2.0, 9.0)
		draw_dashed_line(Vector2(a.x, b.y - k), Vector2(a.x, a.y + k), edge, 2.0, 9.0)
		draw_arc(Vector2(a.x + k, a.y + k), k, PI, PI * 1.5, 8, edge, 2.0, true)
		draw_arc(Vector2(b.x - k, a.y + k), k, PI * 1.5, TAU, 8, edge, 2.0, true)
		draw_arc(Vector2(b.x - k, b.y - k), k, 0, PI * 0.5, 8, edge, 2.0, true)
		draw_arc(Vector2(a.x + k, b.y - k), k, PI * 0.5, PI, 8, edge, 2.0, true)
		var box: Control = get_child(0) if get_child_count() > 0 else null
		var c := Vector2(size.x / 2.0, size.y / 2.0 - 40)
		if box != null and box.get_child_count() > 0:
			var room: Control = box.get_child(0)
			c = box.position + room.position + room.size / 2.0
		draw_circle(c, Ring, Color(CGlow, 0.14 if hot else 0.08))
		draw_arc(c, Ring, 0, TAU, 64, CGlow, 2.5, true)
		var arm := Ring * 0.45
		var col: Color = Color.WHITE if hot else CGlow
		draw_line(c - Vector2(arm, 0), c + Vector2(arm, 0), col, 3.5, true)
		draw_line(c - Vector2(0, arm), c + Vector2(0, arm), col, 3.5, true)


# ---- the boxes over the screen ------------------------------------------------------
#
# EVERY BOX ON THIS SCREEN IN ITS OWN LOOK (TeeJ, 2026-09-28: "any boxes/UI on
# this main menu need to match the look and feel of the site ... You should be
# fired for this bland/boring UI"): not Godot's grey windows, but the cards'
# charcoal plate over the dimmed page - the warm edge and deep shadow, the title
# in the glow's peach in spaced capitals over the logo's underline warmed, a
# close cross; Play's red for the one thing to do, the "+" card's peach outline
# for the rest.

## A box over the screen: the page dimmed behind it, the plate `width` wide,
## its title and its close cross. Returns [the shade - named `node_name`, freed
## to close it - the body to fill, the close cross]. Esc closes the top one.
func _modal(node_name: String, title: String, width: int) -> Array:
	var shade := ColorRect.new()
	shade.name = node_name
	shade.color = Color(0.02, 0.012, 0.014, 0.8)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.set_meta("modal", true)
	add_child(shade)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.add_child(centre)
	var panel := PanelContainer.new()
	panel.name = "Plate"
	panel.custom_minimum_size = Vector2(width, 0)
	var plate := _box(Color(0.075, 0.066, 0.07, 0.985), CEdge.lightened(0.1), CardRadius)   # the cards must not show through
	plate.shadow_color = Color(0, 0, 0, 0.65)
	plate.shadow_size = 32
	plate.shadow_offset = Vector2(0, 12)
	panel.add_theme_stylebox_override("panel", plate)
	centre.add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	panel.add_child(outer)
	# The title's band, lit from above in the planet's red, as the page is.
	var lit := PanelContainer.new()
	lit.name = "Head"
	var glow := StyleBoxTexture.new()
	glow.texture = _glow_texture()
	lit.add_theme_stylebox_override("panel", glow)
	outer.add_child(lit)
	var head := MarginContainer.new()
	head.add_theme_constant_override("margin_left", 30)
	head.add_theme_constant_override("margin_right", 16)
	head.add_theme_constant_override("margin_top", 16)
	head.add_theme_constant_override("margin_bottom", 12)
	lit.add_child(head)
	var bar := HBoxContainer.new()
	head.add_child(bar)
	var t := _label(title.to_upper(), 19, CGlow, _face(5, 0.6))
	t.name = "Title"
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(t)
	var close := Button.new()
	close.name = "Close"
	close.text = "✕"
	close.tooltip_text = "Close"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(34, 34)
	for st in ["normal", "focus"]:
		close.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var ring := _box(Color(CGlow, 0.1), Color(CGlow, 0.5), 17, 1)
	close.add_theme_stylebox_override("hover", ring)
	close.add_theme_stylebox_override("pressed", ring)
	close.add_theme_color_override("font_color", CMuted)
	close.add_theme_color_override("font_hover_color", CGlow)
	close.add_theme_font_size_override("font_size", 16)
	bar.add_child(close)
	var rule := TextureRect.new()
	rule.name = "Rule"
	rule.texture = _rule_texture()
	rule.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rule.stretch_mode = TextureRect.STRETCH_SCALE
	rule.custom_minimum_size = Vector2(0, 2)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(rule)
	var bm := MarginContainer.new()
	for side in ["left", "right"]:
		bm.add_theme_constant_override("margin_" + side, 30)
	bm.add_theme_constant_override("margin_top", 18)
	bm.add_theme_constant_override("margin_bottom", 22)
	outer.add_child(bm)
	var body := VBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", 16)
	bm.add_child(body)
	return [shade, body, close]


## A row of a box's buttons, at its foot, to the right.
static func _actions(body: Control, buttons: Array) -> HBoxContainer:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	body.add_child(gap)
	var row := HBoxContainer.new()
	row.name = "Actions"
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 12)
	for b in buttons:
		row.add_child(b)
	body.add_child(row)
	return row


## Asks before something that cannot be undone from here.
func _confirm(title: String, text: String, yes_text: String, yes: Callable) -> void:
	var m := _modal("Confirm", title, 540)
	var shade: Control = m[0]
	var said := _para(text)
	said.custom_minimum_size = Vector2(480, 0)
	(m[1] as Control).add_child(said)
	var no := _button("No", "CANCEL")
	var ok := Button.new()
	ok.name = "Yes"
	ok.text = yes_text.to_upper()
	ok.custom_minimum_size = Vector2(150, 42)
	_primary(ok)
	_actions(m[1], [no, ok])
	for b in [no, m[2]]:
		(b as Button).pressed.connect(shade.queue_free)
	ok.pressed.connect(func() -> void:
		shade.queue_free()
		yes.call())
	ok.grab_focus()


## A result with nowhere else to go (a file dropped on the cards, the "+"
## card's import, a fourth star): said on the box, green done or red not.
func _tell(result: Dictionary, title: String = "Import") -> void:
	var m := _modal("ImportResult" if title == "Import" else title, title, 580)
	var shade: Control = m[0]
	var said := _para(str(result.get("message", "")))
	said.name = "Message"
	said.custom_minimum_size = Vector2(520, 0)
	if result.has("ok"):
		said.add_theme_color_override("font_color", COk if bool(result["ok"]) else CFail)
	(m[1] as Control).add_child(said)
	var ok := Button.new()
	ok.name = "Ok"
	ok.text = "OK"
	ok.custom_minimum_size = Vector2(120, 42)
	_primary(ok)
	_actions(m[1], [ok])
	for b in [ok, m[2]]:
		(b as Button).pressed.connect(shade.queue_free)
	ok.grab_focus()


# ---- the files window --------------------------------------------------------------
#
# THE PLAYER'S OWN FILES FOR A PACK (TeeJ, 2026-09-28: "this window needs to be
# bigger and have instructions for the movie files as well - IT NEEDS A
# SEPARATE IMPORT MOVIE FILE BUTTON. asking users to use the pack upload for
# everything is confusing, the back-end process can stay the same, but the UI
# for the user needs to be more clear and direct. Continue without artwork
# needs to be in its own row, and users need to know what continuing without
# artwork means - we can have a simpler version of this page once they have
# uploaded artwork that is out of date"). One window, three faces:
#   FIRST IMPORT (Play, no artwork): why the files come from the player's own
#     copy; the exporter; its two exports; a row for each file - what it is,
#     its name, whether it is in, its own Import button; then, on a row of its
#     own, Continue without artwork and what that means - Play, once the
#     artwork is in.
#   OUT OF DATE (Play, the artwork too old): the short version - export again,
#     Import artwork file; Continue without updating on its own row.
#   MANAGE FILES (the card's button): both rows, each with Import and Remove.
# The files import as they always did (PackImport.PickFile, a file dropped on
# the window): the buttons only say which file is wanted.

## The window's widths: the whole window, the short one, and its text.
const FilesW := 900
const ShortW := 740
const FilesTextW := 840
const ShortTextW := 680
## The file rows' pills.
const CIn := Color("#7fd18a")
const COld := Color("#ff9b6b")
## Manage files, not Play: the window is up to look after the files.
var _art_manage: bool = false


## Opens the files window for `pack_id`: Play's (`manage` false) or the card's
## Manage files. `message` is an import's result, said in the window.
func _open_art_window(pack_id: String, message: String = "", ok: bool = true, manage: bool = false) -> void:
	_close_art_window()
	var pack: PackLoader.LoadedPack = _packs.get(pack_id)
	if pack == null:
		return
	_art_for = pack_id
	_art_manage = manage
	var set_id: String = pack.Manifest.ArtSets[0] if not pack.Manifest.ArtSets.is_empty() else ""
	var source: Dictionary = ART_SOURCES.get(set_id, {"game": pack.Manifest.DisplayName, "file": "%s.art.zip" % set_id, "movies": "%s.movies.zip" % set_id})
	var outdated := _outdated_sets(pack)
	var short := not manage and not outdated.is_empty()
	var title := ("Manage files" if manage else ("Your artwork is out of date" if short else "The original's artwork and movies"))
	var width := ShortW if short else FilesW
	var text_w := ShortTextW if short else FilesTextW
	var m := _modal("ArtworkWindow", title, width)
	_art_window = m[0]
	var box: VBoxContainer = m[1]
	box.add_theme_constant_override("separation", 12)
	(m[2] as Button).pressed.connect(_close_art_window)

	if short:
		var e: Dictionary = outdated[0]
		box.add_child(_para("Your artwork file was made by exporter %s. This version of Faction Wars needs %s or later, so some of %s's windows and pictures are missing until you export it again." \
			% [str(e.exporter) if not str(e.exporter).is_empty() else "(unknown)", PackImport.MIN_EXPORTER.get(e.id, ""), pack.Manifest.DisplayName], text_w))
		box.add_child(_step(1, "Get the newest exporter", _exporter_link(), text_w))
		box.add_child(_step(2, "Export again", _para("Run it and click Export. It saves Documents\\Faction Wars\\%s over the old one." % source.file, text_w - 56), text_w))
		var pick := _import_button("ImportArtwork", "Import artwork file", true)
		pick.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		box.add_child(_step(3, "Import it", pick, text_w))
		_result(box, message, ok, text_w)
		box.add_child(_way_on(pack_id, "ContinueWithout", "Continue without updating",
			"Play with the artwork you have. The windows and pictures added since it was made stay missing until you update it.", false, text_w))
		pick.grab_focus()
		return

	if manage:
		# TeeJ's words (2026-09-28; mine were "incomprehensible gibberish").
		var intro := _para("Owners of the game \"%s\" can extract artwork and movies from their legally owned copy of the game to emulate the look and feel of %s in Faction Wars. The artwork stays resident on your computer and is not uploaded to our servers or the internet. Use our extraction tool to create a file with the artwork or movies. Import a file to add or update it; remove one to play without it." \
			% [source.game, source.get("short", source.game)], text_w)
		intro.name = "Intro"
		box.add_child(intro)
	else:
		box.add_child(_para("%s can look, sound and play like %s itself: its windows, pictures, sounds, music and movies. Faction Wars does not include them - they come from your own copy of the game (GOG, Steam or the CD), exported once on your computer." \
			% [pack.Manifest.DisplayName, source.game], text_w))
	box.add_child(_step(1, "Get the exporter", _exporter_link(), text_w))
	var exports := VBoxContainer.new()
	exports.add_theme_constant_override("separation", 6)
	exports.add_child(_para("Run it. It finds your game by itself, and makes each file in Documents\\Faction Wars:", text_w - 56))
	exports.add_child(_bullet("Export", "%s - the artwork, sounds and music." % source.file, text_w - 56))
	exports.add_child(_bullet("Export movies...", "%s - %s" % [source.movies, source.get("movies_note", "the movies. Optional.")], text_w - 56))
	box.add_child(_step(2, "Export your files", exports, text_w))
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	var art := _file_state(set_id, PackImport.KIND_ART_SET)
	var movies := _file_state(set_id, PackImport.KIND_MOVIES)
	rows.add_child(_file_row("Art", "Artwork", source.file, "The original's windows, pictures, sounds and music.", art, set_id, PackImport.KIND_ART_SET, manage, text_w - 56))
	rows.add_child(_file_row("Movies", "Movies", source.movies, "The original's movies, each where the original played it. Optional.", movies, set_id, PackImport.KIND_MOVIES, manage, text_w - 56))
	# One wording on the desktop and in the browser (TeeJ, 2026-09-28: "users
	# should not see a difference between file management on desktop or web"),
	# so no drag instruction: a dropped movies file does not import in the browser.
	var keep := _label("Keep both files: you can import them again at any time.", 13, CMuted)
	keep.name = "KeepNote"
	keep.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	keep.custom_minimum_size = Vector2(text_w - 56, 0)
	rows.add_child(keep)
	box.add_child(_step(3, "Import them here", rows, text_w))
	_result(box, message, ok, text_w)
	if manage:
		# TeeJ's words (2026-09-28), at the page's foot: the pack and the build
		# are what a head-to-head game checks (MultiplayerOptions._seat_mismatch;
		# the pack's hash is its JSON alone, FactionRegistry.ContentHash), and
		# nothing the simulation reads comes from the artwork.
		var mp := _label("Users can play multi-player games with or without the artwork, the gameplay will be the same, just the look and feel will differ", 14, CMuted)
		mp.name = "Multiplayer"
		mp.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mp.custom_minimum_size = Vector2(text_w, 0)
		box.add_child(mp)
		var done := _button("CloseFiles", "Close")
		done.custom_minimum_size = Vector2(130, 42)
		done.pressed.connect(_close_art_window)
		_actions(box, [done])
		return
	# The way on, on a row of its own: Play once the artwork is in, else
	# Continue without artwork, and what that means.
	if bool(art["in"]):
		box.add_child(_way_on(pack_id, "PlayNow", "Play %s" % pack.Manifest.DisplayName,
			"Your artwork is in. Import the movies too if you like, or play now.", true, text_w))
	else:
		box.add_child(_way_on(pack_id, "ContinueWithout", "Continue without artwork",
			"Play the same game - every rule, unit and mission - in Faction Wars' own plain windows, without the original's pictures, sounds, music or movies. You can import your files at any time from Manage files on this card.", false, text_w))
	(box.find_child("ImportArtwork", true, false) as Control).grab_focus()


## Whether a file of `kind` for art set `set_id` is in: {in, exporter, outdated}.
static func _file_state(set_id: String, kind: String) -> Dictionary:
	for e in PackImport.Installed():
		if e.kind == kind and e.id == set_id:
			return {"in": true, "exporter": str(e.exporter), "outdated": bool(e.outdated)}
	return {"in": false, "exporter": "", "outdated": false}


## A numbered step: the number in a peach ring, its heading in spaced
## capitals, and under the heading what to do.
static func _step(n: int, heading: String, what: Control, width: int) -> Control:
	var row := HBoxContainer.new()
	row.name = "Step%d" % n
	row.add_theme_constant_override("separation", 18)
	var num := PanelContainer.new()
	num.custom_minimum_size = Vector2(38, 38)
	num.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	num.add_theme_stylebox_override("panel", _box(Color(CGlow, 0.1), CGlow.darkened(0.15), 19, 2))
	var digit := _label(str(n), 17, CGlow, _face(0, 0.6))
	digit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	digit.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.add_child(digit)
	row.add_child(num)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.custom_minimum_size = Vector2(width - 56, 0)
	col.add_child(_label(heading.to_upper(), 14, CText, _face(3, 0.6)))
	col.add_child(what)
	row.add_child(col)
	return row


## "Export" - what it makes.
static func _bullet(button: String, what: String, width: int) -> Control:
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.scroll_active = false
	l.custom_minimum_size = Vector2(width, 0)
	l.add_theme_font_size_override("normal_font_size", 15)
	l.add_theme_font_size_override("bold_font_size", 15)
	l.add_theme_color_override("default_color", CText)
	l.add_theme_constant_override("line_separation", 3)
	l.text = "[color=#%s]•[/color]  [b]%s[/b]  %s" % [CGlow.to_html(false), button, what]
	return l


## Where to get the exporter: its address, and Copy.
static func _exporter_link() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.add_child(_label("Download the Faction Wars Exporter (Windows):", 15, CText))
	var get_it := HBoxContainer.new()
	get_it.name = "ExporterLink"
	get_it.add_theme_constant_override("separation", 10)
	# The same on the desktop and in the browser (TeeJ, 2026-09-28: "users
	# should not see a difference between file management on desktop or web"):
	# the address and Copy - the desktop game opens no other program, so the
	# browser's link that opened a tab went with it.
	var address := LineEdit.new()
	address.text = EXPORTER_URL
	address.editable = false
	address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	address.add_theme_font_size_override("font_size", 12)
	var well := _box(Color(0, 0, 0, 0.35), CEdge, ButtonRadius)
	well.content_margin_left = 10
	well.content_margin_right = 10
	for st in ["normal", "read_only", "focus"]:
		address.add_theme_stylebox_override(st, well)
	address.add_theme_color_override("font_uneditable_color", CText.darkened(0.1))
	get_it.add_child(address)
	var copy := _button("CopyAddress", "Copy")
	copy.custom_minimum_size = Vector2(90, 0)
	copy.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(EXPORTER_URL)
		if OS.has_feature("web"):
			JavaScriptBridge.eval("navigator.clipboard && navigator.clipboard.writeText(%s)" % JSON.stringify(EXPORTER_URL), true)
		copy.text = "COPIED")
	get_it.add_child(copy)
	col.add_child(get_it)
	return col


## One file: its name and what it holds, whether it is in (and new enough),
## and its own Import button - in Manage files, Remove too.
func _file_row(node: String, heading: String, file: String, what: String, state: Dictionary, set_id: String, kind: String, manage: bool, width: int) -> Control:
	var panel := PanelContainer.new()
	panel.name = "FileRow_" + node
	panel.custom_minimum_size = Vector2(width, 0)
	var sb := _box(Color(0, 0, 0, 0.28), CEdge, ButtonRadius)
	sb.content_margin_left = 18
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	top.add_child(_label(heading.to_upper(), 15, CText, _face(3, 0.7)))
	var old := bool(state["outdated"])
	var pill_text := ("OUT OF DATE" if old else "IMPORTED") if bool(state["in"]) else "NOT IMPORTED"
	var pill_colour: Color = (COld if old else CIn) if bool(state["in"]) else CMuted
	var pill := PanelContainer.new()
	pill.name = "State"
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ps := _box(Color(pill_colour, 0.12), Color(pill_colour, 0.7), 10, 1)
	ps.content_margin_left = 9
	ps.content_margin_right = 9
	ps.content_margin_top = 1
	ps.content_margin_bottom = 1
	pill.add_theme_stylebox_override("panel", ps)
	var pl := _label(pill_text, 11, pill_colour, _face(2, 0.6))
	pl.name = "StateText"
	pill.add_child(pl)
	top.add_child(pill)
	col.add_child(top)
	var name_l := _label(file, 13, CGlow.darkened(0.1))
	name_l.name = "FileName"
	col.add_child(name_l)
	var what_l := _label(what if not (bool(state["in"]) and not str(state["exporter"]).is_empty()) else "%s  Made by exporter %s." % [what, state["exporter"]], 14, CMuted)
	what_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(what_l)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	buttons.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(buttons)
	if manage and bool(state["in"]):
		var rm := _button("Remove" + node, "Remove")
		rm.custom_minimum_size = Vector2(110, 42)
		rm.pressed.connect(func() -> void:
			var pack_id := _art_for
			_confirm("Remove the %s" % heading.to_lower(), "Remove the imported %s? You can import %s again at any time." \
				% [heading.to_lower(), file], "Remove", func() -> void:
					PackImport.Remove(kind, set_id)
					_rebuild()
					_open_art_window(pack_id, "", true, true)))
		buttons.add_child(rm)
	var main := kind == PackImport.KIND_ART_SET and not (bool(state["in"]) and not old)
	var label := ("Update" if old else ("Import again" if bool(state["in"]) else "Import")) + (" artwork file" if kind == PackImport.KIND_ART_SET else " movie file")
	buttons.add_child(_import_button("ImportArtwork" if kind == PackImport.KIND_ART_SET else "ImportMovies", label, main))
	return panel


## A file's Import button: the file picker, as every import has been; the
## artwork's the red one while the artwork is what is missing.
func _import_button(node: String, text: String, main: bool) -> Button:
	var b: Button
	if main:
		b = Button.new()
		b.name = node
		b.text = text.to_upper()
		b.custom_minimum_size = Vector2(240, 42)
		_primary(b)
	else:
		b = _button(node, text)
		b.custom_minimum_size = Vector2(240, 42)
	b.pressed.connect(func() -> void: PackImport.PickFile(_on_imported))
	return b


## An import's result, when there is one, green done or red not.
static func _result(box: Control, message: String, ok: bool, width: int) -> void:
	if message.is_empty():
		return
	var said := _para(message, width)
	said.name = "ArtworkResult"
	said.add_theme_color_override("font_color", COk if ok else CFail)
	box.add_child(said)


## The way on, on a row of its own at the window's foot: its button and what
## it means.
func _way_on(pack_id: String, node: String, text: String, meaning: String, main: bool, width: int) -> Control:
	var panel := PanelContainer.new()
	panel.name = "WayOn"
	var sb := _box(Color(CAccent, 0.07) if main else Color(1, 1, 1, 0.03), CEdge, ButtonRadius)
	sb.content_margin_left = 18
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)
	var said := _label(meaning, 14, CText.darkened(0.08))
	said.name = "Meaning"
	said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	said.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	said.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	said.custom_minimum_size = Vector2(width - 330, 0)
	row.add_child(said)
	var go: Button
	if main:
		go = Button.new()
		go.name = node
		go.text = text.to_upper()
		_primary(go)
	else:
		go = _button(node, text)
	go.custom_minimum_size = Vector2(280, 42)
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	go.pressed.connect(func() -> void:
		_close_art_window()
		Choose(pack_id))
	row.add_child(go)
	return panel


func _close_art_window() -> void:
	if is_instance_valid(_art_window):
		_art_window.queue_free()
	_art_window = null
	_art_for = ""
	_art_manage = false


## Esc closes the box on top.
func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo() or (event as InputEventKey).keycode != KEY_ESCAPE:
		return
	var top: Node = _top_modal()
	if top == null:
		return
	get_viewport().set_input_as_handled()
	if top.name == "ImportProgress":
		var cancel: Button = top.find_child("CancelImport", true, false)
		if cancel != null and not cancel.disabled:
			cancel.pressed.emit()
		return
	if top == _art_window:
		_close_art_window()
	elif top is Window:
		(top as Window).hide()
	else:
		top.queue_free()


static func _para(text: String, width: int = 620) -> Label:
	var l := _label(text, 15, CText)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	l.add_theme_constant_override("line_spacing", 3)
	return l


## A box's button that is not the main one (the "+" card's peach outline), in
## capitals.
static func _button(node_name: String, text: String) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text.to_upper()
	b.custom_minimum_size = Vector2(0, 42)
	_outline(b)
	return b


## HOW AN IMPORT IS GOING (TeeJ, 2026-09-28: "is there any way to show an import
## progress bar" - "absolutely, yes"): a box over everything while it runs - what
## it is doing, how many files of how many, the bar - from PackImport's steps
## (every file checked, then written) and, in the browser, its own reading of
## the file and its checking and keeping of a movies file, with Cancel. Gone when
## the import is done or cancelled; its result is then said as before. Each counted phase's share of the
## bar: checking the first half, writing the rest.
const ProgressParts := {"check": [0.0, 0.5], "write": [0.5, 0.97], "verify": [0.0, 0.95]}


func _on_progress(phase: String, done: int, total: int) -> void:
	if not is_inside_tree():
		return
	var box: Node = get_node_or_null("ImportProgress")
	if phase.is_empty():
		if box != null:
			box.queue_free()
		return
	if box == null or box.is_queued_for_deletion():
		var m := _modal("ImportProgress", "Importing", 620)
		box = m[0]
		(m[2] as Button).visible = false   # Cancel, below, is the way out
		var said := _label("", 15, CText)
		said.name = "Phase"
		(m[1] as Control).add_child(said)
		var bar := ProgressBar.new()
		bar.name = "Bar"
		bar.custom_minimum_size = Vector2(560, 16)
		bar.show_percentage = false
		bar.max_value = 1.0
		bar.step = 0.0
		bar.add_theme_stylebox_override("background", _box(Color(0, 0, 0, 0.45), CEdge, 8))
		bar.add_theme_stylebox_override("fill", _box(CAccent, CGlow.darkened(0.2), 8))
		(m[1] as Control).add_child(bar)
		(m[1] as Control).add_child(_label("Keep this window open until it is done.", 13, CMuted))
		# TeeJ, 2026-09-28: "a cancel button in case it hangs" (PackImport.Cancel).
		var cancel := _button("CancelImport", "Cancel")
		cancel.pressed.connect(func() -> void:
			cancel.disabled = true
			PackImport.Cancel())
		_actions(m[1], [cancel])
	var words := {
		"reading": "Reading the file...",
		"check": "Checking the files - %d of %d" % [done, total],
		"write": "Writing the files - %d of %d" % [done, total],
		"place": "Putting it in place...",
		"verify": "Checking the movies - %d of %d" % [done, total],
		"store": "Storing the movies...",
	}
	(box.find_child("Phase", true, false) as Label).text = str(words.get(phase, "Importing..."))
	var bar: ProgressBar = box.find_child("Bar", true, false)
	var part: Array = ProgressParts.get(phase, [])
	bar.indeterminate = part.is_empty()
	if not part.is_empty():
		var f: float = float(done) / float(total) if total > 0 else 0.0
		bar.value = lerpf(float(part[0]), float(part[1]), clampf(f, 0.0, 1.0))


## An import finished (the files window's buttons, or a file dropped on the
## game): the cards show it at once, and the files window it came from opens
## again saying so - with its Play once the artwork is in, so the movies can
## come in too before the game starts (the artwork alone once went straight on).
func _on_imported(result: Dictionary) -> void:
	if not is_inside_tree() or _cards == null:
		return
	var waiting := _art_for
	var manage := _art_manage
	_rebuild()
	var message := str(result.get("message", ""))
	var ok := bool(result.get("ok", false))
	# A pack just imported: its card on show.
	if ok and str(result.get("kind", "")) == PackImport.KIND_FACTION_PACK:
		_bring_into_view(str(result.get("id", "")))
	if waiting.is_empty():
		if not message.is_empty():
			_tell(result)
		return
	_open_art_window(waiting, message, ok, manage)


func _rebuild() -> void:
	_close_art_window()
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_play.clear()
	_packs.clear()
	_panels.clear()
	_order.clear()
	_build(FactionRegistry.ListPackIds())   # _start is kept: the same cards stay on show
