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
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	centre.add_child(column)
	_column = column

	var title := Label.new()
	title.text = "Choose a setting"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	# The carousel: an arrow either side of the cards on show.
	_row = HBoxContainer.new()
	_row.name = "Carousel"
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 12)
	column.add_child(_row)
	_left = _arrow("CarouselLeft", -1)
	_row.add_child(_left)
	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", CardGap)
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_child(_cards)
	_right = _arrow("CarouselRight", 1)
	_row.add_child(_right)

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
		quit.text = "Exit Game"
		quit.custom_minimum_size = Vector2(160, 40)
		quit.pressed.connect(func() -> void: get_tree().quit())
		var foot := CenterContainer.new()
		foot.add_child(quit)
		column.add_child(foot)


## One pack's card. A pack that fails validation still gets a card, with its
## problems in place of the summary and no Play - the list must never lie
## about what is installed.
func _card(id: String, pack: PackLoader.LoadedPack, errors: Array[String]) -> Button:
	var panel := PanelContainer.new()
	panel.name = "Card_" + id
	panel.custom_minimum_size = Vector2(CardWidth, 0)
	_cards.add_child(panel)
	_panels[id] = panel
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	# The name, centred, with the favorite's star in the corner.
	var head := HBoxContainer.new()
	var balance := Control.new()   # as wide as the star, so the name stays centred
	balance.custom_minimum_size = Vector2(StarButton.Size, 0)
	head.add_child(balance)
	var name := Label.new()
	name.text = pack.Manifest.DisplayName if pack != null else id
	name.add_theme_font_size_override("font_size", 24)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name)
	var star := StarButton.new()
	star.name = "Star"
	star.on = Favorites().has(id)
	star.tooltip_text = _star_tip(star.on)
	star.pressed.connect(func() -> void: _toggle_star(id, star))
	head.add_child(star)
	box.add_child(head)

	if pack != null:
		# The map picture - from the art set, when it is imported - else the
		# pack's own card picture (TeeJ, 2026-09-24).
		var picture := TextureRect.new()
		picture.name = "Picture"
		picture.texture = Art.PackImage(pack.Manifest.MapImage, id, pack.Manifest.ArtSets)
		if picture.texture == null and not pack.Manifest.CardImage.is_empty():
			picture.texture = Art.PackImage(pack.Manifest.CardImage, id, pack.Manifest.ArtSets)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.custom_minimum_size = Vector2(300, 170)
		box.add_child(picture)

		var summary := Label.new()
		summary.text = pack.Manifest.Summary
		summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		summary.custom_minimum_size = Vector2(300, 0)
		box.add_child(summary)

		var sides := HBoxContainer.new()
		sides.alignment = BoxContainer.ALIGNMENT_CENTER
		sides.add_theme_constant_override("separation", 16)
		for f in pack.Factions:
			var side := Label.new()
			side.text = f.DisplayName
			side.add_theme_color_override("font_color", FactionRegistry.ParseColor(f.ColorHex))
			sides.add_child(side)
		box.add_child(sides)
	else:
		var broken := Label.new()
		broken.text = "Cannot load this pack:\n" + "\n".join(errors.slice(0, 6))
		broken.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		broken.custom_minimum_size = Vector2(300, 0)
		broken.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
		box.add_child(broken)

	var play := Button.new()
	play.name = "Play"
	play.text = "Play"
	play.custom_minimum_size = Vector2(0, 40)
	play.disabled = pack == null
	play.pressed.connect(func() -> void: Play(id))
	box.add_child(play)
	_play[id] = play

	# The imported artwork, clearable - only when there is some to clear.
	if pack != null and not _imported_sets(pack).is_empty():
		var clear := Button.new()
		clear.name = "ClearArtwork"
		clear.text = "Clear artwork pack"
		clear.pressed.connect(func() -> void:
			_confirm("Clear artwork pack",
				"Remove the imported artwork? %s plays without it until you import your artwork file again." % pack.Manifest.DisplayName,
				"Remove", func() -> void:
					for e in _imported_sets(pack):
						PackImport.Remove(PackImport.KIND_ART_SET, e.id)
					_rebuild()))
		box.add_child(clear)
	# A pack the player imported can go again; the ones that ship cannot.
	if _is_imported(id):
		var remove := Button.new()
		remove.name = "RemovePack"
		remove.text = "Remove pack"
		var title: String = pack.Manifest.DisplayName if pack != null else id
		remove.pressed.connect(func() -> void:
			_confirm("Remove pack", "Remove %s? Import its file again to get it back." % title, "Remove", func() -> void:
				PackImport.Remove(PackImport.KIND_FACTION_PACK, id)
				SetFavorite(id, false)   # a removed pack is no favorite
				_rebuild()))
		box.add_child(remove)
	return play


# ---- the carousel -------------------------------------------------------------------

## The "+" card, as big as the others, always last: a faction pack of the
## player's own, from the file picker (TeeJ, 2026-09-24).
func _add_card() -> Control:
	var card := Button.new()
	card.name = "AddPack"
	card.custom_minimum_size = Vector2(CardWidth, 0)
	card.tooltip_text = "Import a faction pack (.zip) made with the pack editor. It stays on this " \
		+ ("browser" if OS.has_feature("web") else "computer") + ": keep the .zip, to import it again."
	var plain := get_theme_stylebox("panel", "PanelContainer")
	if plain != null:
		for st in ["normal", "focus", "disabled"]:
			card.add_theme_stylebox_override(st, plain)
	card.pressed.connect(func() -> void: PackImport.PickFile(_on_imported))
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	for part in [["+", 72, Color(0.85, 0.85, 0.9)], ["Add your own pack", 24, Color.WHITE],
			["A faction pack (.zip) made with the pack editor.", 16, Color(0.75, 0.75, 0.8)]]:
		var l := Label.new()
		l.text = part[0]
		l.add_theme_font_size_override("font_size", part[1])
		l.add_theme_color_override("font_color", part[2])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(l)
	_cards.add_child(card)
	return card


func _arrow(node_name: String, dir: int) -> Button:
	var b := ArrowButton.new()
	b.name = node_name
	b.dir = dir
	b.custom_minimum_size = Vector2(ArrowWidth, 120)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = "Previous" if dir < 0 else "Next"
	b.pressed.connect(func() -> void: Turn(dir))
	return b


## How many cards fit on screen: as many as the width takes, three at most.
func _shown() -> int:
	var width: float = size.x if size.x > 0 else get_viewport_rect().size.x
	var fit := int((width - 2 * (ArrowWidth + 12)) / float(CardWidth + CardGap))
	return mini(clampi(fit, 1, MaxShown), _order.size())


## Shows the cards from _start on, in carousel order, wrapping round; the
## arrows only when there are more cards than fit.
func _layout_carousel() -> void:
	if _cards == null or _order.is_empty():
		return
	var n := _order.size()
	var shown := _shown()
	var turning := n > shown
	_left.visible = turning
	_right.visible = turning
	_start = posmod(_start, n) if turning else 0
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


static func _star_tip(on: bool) -> String:
	return "A favorite: first on this screen. Click to unstar." if on \
		else "Star as a favorite (up to %d): favorites come first on this screen." % MaxFavorites


## Left and Right, and the mouse wheel over the cards, turn the carousel -
## not while a window or a question is up over it.
func _input(event: InputEvent) -> void:
	if _row == null or not _left.visible or ArtworkWindow() != null or _dialog_up():
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


## A triangle pointing the way the carousel turns.
class ArrowButton extends Button:
	var dir: int = 1

	func _ready() -> void:
		flat = true
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) * 0.3
		var col := Color.WHITE if is_hovered() else Color(0.7, 0.7, 0.78)
		draw_colored_polygon(PackedVector2Array([c + Vector2(r * dir, 0), c + Vector2(-r * 0.6 * dir, -r), c + Vector2(-r * 0.6 * dir, r)]), col)


## A favorite's star: gold and filled when starred, an outline when not.
class StarButton extends Button:
	const Size := 30
	var on: bool = false

	func _ready() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(Size, Size)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func _draw() -> void:
		var c := size / 2.0
		var outer := minf(size.x, size.y) * 0.45
		var pts := PackedVector2Array()
		for i in 10:
			var r := outer if i % 2 == 0 else outer * 0.45
			var a := -PI / 2.0 + i * PI / 5.0
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		if on:
			draw_colored_polygon(pts, Color(1.0, 0.82, 0.2))
		else:
			var ring := pts.duplicate()
			ring.append(pts[0])
			draw_polyline(ring, Color.WHITE if is_hovered() else Color(0.65, 0.65, 0.72), 2.0, true)


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
	var solid := StyleBoxFlat.new()   # the theme's panel lets the cards show through
	solid.bg_color = Color(0.11, 0.11, 0.15)
	solid.border_color = Color(0.35, 0.35, 0.45)
	solid.set_border_width_all(1)
	solid.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", solid)
	centre.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	var title := Label.new()
	title.text = "Your artwork is out of date" if not outdated.is_empty() else "The original artwork"
	title.add_theme_font_size_override("font_size", 24)
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
		said.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6) if ok else Color(1.0, 0.45, 0.45))
		box.add_child(said)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var pick := _button("ImportArtwork", "Import artwork file...")
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
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(620, 0)
	return l


static func _button(node_name: String, text: String) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text
	b.custom_minimum_size = Vector2(0, 40)
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
