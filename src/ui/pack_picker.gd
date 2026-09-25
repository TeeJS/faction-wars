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
const PictureH := 176
const PlayW := 180
const CardPad := 18
## Slightly rounded, like the logo's letters (TeeJ, 2026-09-24).
const CardRadius := 8
const ButtonRadius := 6
## The Faction Wars Exporter's download: always the newest release's exe (one
## file, from exporter 2.2.0 on).
const EXPORTER_URL := "https://github.com/TeeJS/faction-wars/releases/latest/download/FactionWarsExporter.exe"
## What the artwork window names for each art set the engine knows: the game
## it comes from and the file the exporter writes.
const ART_SOURCES := {"swr-original": {"game": "Star Wars: Rebellion", "file": "swr-original.art.zip"}}

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
	# A pack file dropped on the game imports from here on, on every screen.
	PackImport.ListenForDrops(get_tree())
	PackImport.OnImported = _on_imported
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

	# The logo across the top (TeeJ, 2026-09-24), then what this screen is for.
	var heading := VBoxContainer.new()
	heading.add_theme_constant_override("separation", 10)
	var logo := LogoSlot.new()
	logo.name = "LogoSlot"
	logo.custom_minimum_size = Vector2(CardWidth * MaxShown + CardGap * 2, LogoH)
	heading.add_child(logo)
	var title := _label("CHOOSE A SETTING", 16, CGlow, _face(6, 0.5))
	title.name = "Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_child(title)
	column.add_child(heading)

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
		quit.text = "Exit Game"
		quit.custom_minimum_size = Vector2(140, 36)
		_quiet(quit)
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
	body.add_theme_constant_override("margin_bottom", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(body)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	body.add_child(box)

	var name := _label(pack.Manifest.DisplayName if pack != null else id, 24, CText, _face(0, 0.5))
	name.name = "Title"
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(name)
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
	foot.add_theme_constant_override("separation", 6)
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
	# The quiet actions, on a row every card keeps (empty or not), so the
	# cards stay the same height and their Play buttons level.
	var links := HBoxContainer.new()
	links.name = "Links"
	links.alignment = BoxContainer.ALIGNMENT_CENTER
	links.custom_minimum_size = Vector2(0, 26)
	links.add_theme_constant_override("separation", 14)
	foot.add_child(links)

	# The imported artwork, clearable - only when there is some to clear.
	if pack != null and not _imported_sets(pack).is_empty():
		var clear := _link("ClearArtwork", "Clear artwork pack")
		clear.pressed.connect(func() -> void:
			_confirm("Clear artwork pack",
				"Remove the imported artwork? %s plays without it until you import your artwork file again." % pack.Manifest.DisplayName,
				"Remove", func() -> void:
					for e in _imported_sets(pack):
						PackImport.Remove(PackImport.KIND_ART_SET, e.id)
					_rebuild()))
		links.add_child(clear)
	# A pack the player imported can go again; the ones that ship cannot.
	if _is_imported(id):
		var remove := _link("RemovePack", "Remove pack")
		var title: String = pack.Manifest.DisplayName if pack != null else id
		remove.pressed.connect(func() -> void:
			_confirm("Remove pack", "Remove %s? Import its file again to get it back." % title, "Remove", func() -> void:
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
	card.tooltip_text = "Import a faction pack (.zip) made with the pack editor. It stays on this " \
		+ ("browser" if OS.has_feature("web") else "computer") + ": keep the .zip, to import it again."
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
	for part in [["ADD YOUR OWN PACK", 15, CText, _face(3, 0.6)],
			["A faction pack (.zip) made with the pack editor.", 14, CMuted, null]]:
		var l := _label(part[0], part[1], part[2], part[3])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(CardWidth - 60, 0)
		l.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(l)
	_cards.add_child(card)
	return card


func _arrow(node_name: String, dir: int) -> Button:
	var b := ArrowButton.new()
	b.name = node_name
	b.dir = dir
	b.custom_minimum_size = Vector2(ArrowWidth, ArrowWidth)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = "Previous" if dir < 0 else "Next"
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
	for c in get_children():
		if c is Window and (c as Window).visible:
			return true
	return false


# ---- the look: styles and the drawn parts ---------------------------------------------

static func _box(bg: Color, edge: Color, radius: int = 10, width: int = 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = edge
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	return sb


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
	rest.set_content_margin_all(6)   # the picture inset, clear of the rounded corners
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


## A secondary button: an outline that warms under the pointer.
static func _quiet(b: Button) -> void:
	var rest := _box(Color(0, 0, 0, 0.25), CEdge, ButtonRadius)
	var hover := _box(Color(0, 0, 0, 0.35), CMuted, ButtonRadius)
	for sb in [rest, hover]:
		sb.content_margin_left = 16
		sb.content_margin_right = 16
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
	for st in ["normal", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, rest)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_color_override("font_color", CMuted)
	b.add_theme_color_override("font_hover_color", CText)
	b.add_theme_font_size_override("font_size", 14)


## A card's quiet action: text only, warming under the pointer.
static func _link(node_name: String, text: String) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, empty)
	b.add_theme_color_override("font_color", CMuted)
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


## A round arrow either side of the carousel; dimmed when there is nothing
## to turn.
class ArrowButton extends Button:
	var dir: int = 1

	func _ready() -> void:
		flat = true
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) / 2.0 - 1.0
		var live := not disabled
		var hot := live and is_hovered()
		draw_circle(c, r, Color(0.08, 0.07, 0.075, 0.85 if live else 0.4))
		draw_arc(c, r, 0, TAU, 48, (CGlow if hot else CEdge.lightened(0.2)) if live else Color(CEdge, 0.5), 1.5, true)
		var t := r * 0.36
		var col := (Color.WHITE if hot else CText) if live else Color(CMuted, 0.35)
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
		var hot := is_hovered()
		var edge := CGlow.darkened(0.25) if hot else CEdge.lightened(0.15)
		var r := Rect2(Vector2(1, 1), size - Vector2(2, 2))
		var fill := PackPicker._box(Color(CCard, 0.55 if hot else 0.35), Color(0, 0, 0, 0), CardRadius, 0)
		draw_style_box(fill, r)
		# A dashed edge with the cards' rounded corners.
		var k := float(CardRadius)
		var a := r.position
		var b := r.end
		draw_dashed_line(Vector2(a.x + k, a.y), Vector2(b.x - k, a.y), edge, 1.5, 8.0)
		draw_dashed_line(Vector2(b.x, a.y + k), Vector2(b.x, b.y - k), edge, 1.5, 8.0)
		draw_dashed_line(Vector2(b.x - k, b.y), Vector2(a.x + k, b.y), edge, 1.5, 8.0)
		draw_dashed_line(Vector2(a.x, b.y - k), Vector2(a.x, a.y + k), edge, 1.5, 8.0)
		draw_arc(Vector2(a.x + k, a.y + k), k, PI, PI * 1.5, 8, edge, 1.5, true)
		draw_arc(Vector2(b.x - k, a.y + k), k, PI * 1.5, TAU, 8, edge, 1.5, true)
		draw_arc(Vector2(b.x - k, b.y - k), k, 0, PI * 0.5, 8, edge, 1.5, true)
		draw_arc(Vector2(a.x + k, b.y - k), k, PI * 0.5, PI, 8, edge, 1.5, true)
		var box: Control = get_child(0) if get_child_count() > 0 else null
		var c := Vector2(size.x / 2.0, size.y / 2.0 - 40)
		if box != null and box.get_child_count() > 0:
			var room: Control = box.get_child(0)
			c = box.position + room.position + room.size / 2.0
		draw_arc(c, Ring, 0, TAU, 64, edge, 2.0, true)
		var arm := Ring * 0.45
		var col := CGlow if hot else CText
		draw_line(c - Vector2(arm, 0), c + Vector2(arm, 0), col, 3.0, true)
		draw_line(c - Vector2(0, arm), c + Vector2(0, arm), col, 3.0, true)


## Asks before something that cannot be undone from here.
func _confirm(title: String, text: String, yes_text: String, yes: Callable) -> void:
	var box := ConfirmationDialog.new()
	box.name = "Confirm"
	box.title = title
	box.dialog_text = text
	box.dialog_autowrap = true
	box.ok_button_text = yes_text
	add_child(box)
	box.confirmed.connect(func() -> void:
		box.queue_free()
		yes.call())
	box.canceled.connect(box.queue_free)
	box.popup_centered(Vector2i(460, 0))


## A result with nowhere else to go (a file dropped on the cards, the "+"
## card's import, a fourth star).
func _tell(result: Dictionary, title: String = "Import") -> void:
	var box := AcceptDialog.new()
	box.name = "ImportResult" if title == "Import" else title
	box.title = title
	box.dialog_text = str(result.get("message", ""))
	box.dialog_autowrap = true
	add_child(box)
	box.confirmed.connect(box.queue_free)
	box.canceled.connect(box.queue_free)
	box.popup_centered(Vector2i(520, 0))


# ---- the artwork window ------------------------------------------------------------

## Why a pack's original look needs the player's own art, and how to get it
## there (TeeJ, 2026-09-24): clear, short steps; Continue without artwork;
## the import's result, when there is one, at the foot.
func _open_art_window(pack_id: String, message: String = "", ok: bool = true) -> void:
	_close_art_window()
	var pack: PackLoader.LoadedPack = _packs.get(pack_id)
	if pack == null:
		return
	_art_for = pack_id
	var set_id: String = pack.Manifest.ArtSets[0] if not pack.Manifest.ArtSets.is_empty() else ""
	var source: Dictionary = ART_SOURCES.get(set_id, {"game": pack.Manifest.DisplayName, "file": "%s.art.zip" % set_id})
	var outdated := _outdated_sets(pack)

	var shade := ColorRect.new()
	shade.name = "ArtworkWindow"
	shade.color = Color(0, 0, 0, 0.7)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_art_window = shade
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.add_child(centre)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(680, 0)
	var solid := _box(Color(0.086, 0.078, 0.082, 0.98), CEdge, CardRadius)   # the cards must not show through
	solid.shadow_color = Color(0, 0, 0, 0.6)
	solid.shadow_size = 24
	panel.add_theme_stylebox_override("panel", solid)
	centre.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	var title := _label(("YOUR ARTWORK IS OUT OF DATE" if not outdated.is_empty() else "THE ORIGINAL ARTWORK"), 20, CGlow, _face(4, 0.6))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	if outdated.is_empty():
		box.add_child(_para("Faction Wars does not include the artwork of %s. It comes from your own copy of the game (GOG, Steam or the CD), exported once on your computer." % source.game))
	else:
		var e: Dictionary = outdated[0]
		box.add_child(_para("Your artwork file was made by exporter %s. This version of Faction Wars needs %s or later. Export it again:" \
			% [str(e.exporter) if not str(e.exporter).is_empty() else "(unknown)", PackImport.MIN_EXPORTER.get(e.id, "")]))

	# 1. Where to get the exporter. In the browser a link that opens it in a
	# new tab; on the desktop the address to copy (the game starts no other
	# program).
	var step1 := VBoxContainer.new()
	step1.add_child(_para("1.  Download the Faction Wars Exporter (Windows):"))
	var get_it := HBoxContainer.new()
	get_it.name = "ExporterLink"
	get_it.alignment = BoxContainer.ALIGNMENT_CENTER
	if OS.has_feature("web"):
		var link := LinkButton.new()
		link.text = "FactionWarsExporter.exe"
		link.tooltip_text = EXPORTER_URL
		link.pressed.connect(func() -> void: JavaScriptBridge.eval("window.open('%s', '_blank')" % EXPORTER_URL, true))
		get_it.add_child(link)
	else:
		var address := LineEdit.new()
		address.text = EXPORTER_URL
		address.editable = false
		address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		address.add_theme_font_size_override("font_size", 12)
		get_it.add_child(address)
		var copy := _button("CopyAddress", "Copy")
		copy.custom_minimum_size = Vector2(70, 0)
		copy.pressed.connect(func() -> void:
			DisplayServer.clipboard_set(EXPORTER_URL)
			copy.text = "Copied")
		get_it.add_child(copy)
	step1.add_child(get_it)
	box.add_child(step1)
	box.add_child(_para("2.  Run it. It finds your game by itself. Click Export: it saves Documents\\Faction Wars\\%s." % source.file))
	box.add_child(_para("3.  Click Import artwork file below and choose that file, or drag the file onto this window."))
	box.add_child(_para("4.  Keep the file. If this browser forgets the artwork (cleared site data, another browser or device), import it again." \
		if OS.has_feature("web") else "4.  Keep the file: it puts the artwork back if it is ever cleared."))

	if not message.is_empty():
		var said := _para(message)
		said.name = "ArtworkResult"
		said.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6) if ok else Color(1.0, 0.5, 0.42))
		box.add_child(said)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var pick := _button("ImportArtwork", "IMPORT ARTWORK FILE")
	_primary(pick)
	pick.custom_minimum_size = Vector2(230, 42)
	pick.pressed.connect(func() -> void: PackImport.PickFile(_on_imported))
	row.add_child(pick)
	var go := _button("ContinueWithout", "Continue without artwork")
	go.pressed.connect(func() -> void:
		_close_art_window()
		Choose(pack_id))
	row.add_child(go)
	var cancel := _button("CancelArtwork", "Cancel")
	cancel.pressed.connect(_close_art_window)
	row.add_child(cancel)
	box.add_child(row)
	pick.grab_focus()


func _close_art_window() -> void:
	if is_instance_valid(_art_window):
		_art_window.queue_free()
	_art_window = null
	_art_for = ""


func _unhandled_key_input(event: InputEvent) -> void:
	if ArtworkWindow() != null and event.is_pressed() and not event.is_echo() and (event as InputEventKey).keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_close_art_window()


static func _para(text: String) -> Label:
	var l := _label(text, 15, CText)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(620, 0)
	l.add_theme_constant_override("line_spacing", 3)
	return l


## A secondary button in the artwork window (the quiet outline).
static func _button(node_name: String, text: String) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text
	b.custom_minimum_size = Vector2(0, 42)
	_quiet(b)
	return b


## An import finished (the artwork window's button, or a file dropped on the
## game): the cards show it at once. For the pack the artwork window is up
## for, artwork now in goes straight on to the game; anything else - a
## refusal and its reasons, or another kind of file - is said in the window.
func _on_imported(result: Dictionary) -> void:
	if not is_inside_tree() or _cards == null:
		return
	var waiting := _art_for
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
	var pack: PackLoader.LoadedPack = _packs.get(waiting)
	if ok and pack != null and ArtState(pack).is_empty():
		Choose(waiting)
		return
	_open_art_window(waiting, message, ok)


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
