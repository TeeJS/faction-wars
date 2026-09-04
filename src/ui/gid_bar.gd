class_name GidBar
extends CanvasLayer
## frontend/GidBar.cs - the GID overlay: a top-center label naming the active
## mode, and a bottom category selector (one button per category, each popping
## its sub-modes). Built entirely in code and owned by GalaxyMap.

var _map: GalaxyMap
var _activeLabel: Label
var _key: GidKey


func Setup(map: GalaxyMap) -> void:
	_map = map
	# BELOW THE WINDOWS, ABOVE THE MAP. UIManager is a CanvasLayer on layer 1;
	# layer 0 puts this in the base canvas with the map, so windows and the
	# bottom HUD both sit on top.
	layer = 0

	# --- Marker key, spawned upper-left, draggable ---
	_key = GidKey.new()
	add_child(_key)
	_key.Setup()

	# --- Active-mode label, top-center (always visible) ---
	_activeLabel = Label.new()
	_activeLabel.text = ""
	_activeLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_activeLabel.add_theme_font_size_override("font_size", 22)
	# The active-mode label ("Popular Support", etc.) takes the player's faction
	# color - red for the Rebellion, green for the Empire, and whatever a future
	# faction pack defines. One source of truth: PlayerFaction.FactionColor.
	# (Was hardcoded Color(0.45,1.0,0.45) green, which showed Empire green to a
	# Rebel player - TeeJ, room, 2026-09-03.)
	var labelColor := Color(0.45, 1.0, 0.45)
	if GameSettings.PlayerFaction != null:
		labelColor = GameSettings.PlayerFaction.FactionColor
	_activeLabel.add_theme_color_override("font_color", labelColor)
	_activeLabel.anchor_left = 0.5
	_activeLabel.anchor_right = 0.5
	_activeLabel.anchor_top = 0.0
	_activeLabel.anchor_bottom = 0.0
	_activeLabel.offset_left = -240
	_activeLabel.offset_right = 240
	# TUCKED DIRECTLY UNDER THE MONITORS: Main.tscn's Resources row runs from 0
	# to offset_bottom 40, so this starts 4px below it.
	_activeLabel.offset_top = 44
	_activeLabel.offset_bottom = 78
	add_child(_activeLabel)

	# --- Category selector: a solid backed bar sitting ABOVE the bottom HUD row ---
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.13, 0.94)
	sb.border_color = Color(0.40, 0.62, 0.92, 0.85)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", sb)
	# SITS DIRECTLY ON TOP OF THE HUD BAR (offset_top -34 to -3): the band
	# immediately above it with a 2px gap, matching its left inset and its -151
	# right inset so both stop clear of the 150px taskbar strip.
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 2
	panel.offset_right = -151
	panel.offset_top = -80
	panel.offset_bottom = -36
	add_child(panel)

	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 6)
	panel.add_child(bar)

	print("[GID] selector built: %d categories; viewport=%s" % [Gid.Categories.size(), str(get_viewport().get_visible_rect().size)])

	for cat in Gid.Categories:
		var btn := Button.new()
		btn.text = cat.Name
		var pop := PopupMenu.new()
		for i in cat.Modes.size():
			pop.add_item(cat.Modes[i].LabelText, i)
		add_child(pop)

		var localCat: Gid.GidCategory = cat
		pop.id_pressed.connect(func(id: int) -> void: _map.SetMode(localCat.Modes[id]))

		var localBtn: Button = btn
		var localPop: PopupMenu = pop
		btn.pressed.connect(func() -> void: PopupAbove(localBtn, localPop))
		bar.add_child(btn)

	var off := Button.new()
	off.text = "Display Off"
	off.pressed.connect(func() -> void: _map.SetMode(Gid.DisplayOff))
	bar.add_child(off)


## Open a category's menu ABOVE its button (cascading up), so it never falls off
## the bottom of the screen / behind the taskbar.
func PopupAbove(btn: Button, pop: PopupMenu) -> void:
	var anchor: Vector2 = btn.global_position          # viewport coords (subwindows are embedded)
	var estHeight: int = pop.item_count * 34 + 12      # approximate; corrected after it opens
	pop.position = Vector2i(int(anchor.x), int(anchor.y - estHeight))
	pop.popup()
	# Now that the popup has a real size, snap its bottom to the button's top.
	pop.position = Vector2i(int(anchor.x), int(anchor.y - pop.size.y))


func SetActiveLabel(text: String) -> void:
	if _activeLabel != null:
		_activeLabel.text = text


## Rebuild the key for the newly-selected mode (hides itself on Display Off).
func ShowKeyFor(mode: Gid.GidMode) -> void:
	if _key != null:
		_key.ShowMode(mode)
