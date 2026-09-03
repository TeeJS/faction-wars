class_name GalaxyOverviewWindow
extends PanelContainer
## frontend/GalaxyOverviewWindow.cs - THE GALAXY OVERVIEW, manual p030 Fig. 2.17
## and the agent droid's own command (p031); ALT-O.
## "The Galaxy Overview lists EVERY FACILITY, SPECFORCE, SHIP AND TROOP TYPE in
## three columns: ICON, HOW MANY YOU CONTROL, and TOTAL MAINTENANCE REQUIREMENT
## for those items." - "six X-wings are each using eight maintenance units", so
## the column is COUNT x PER-UNIT COST.

var _rows: VBoxContainer
var Total: int = 0


func Setup() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(200, 100)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.13, 0.97)
	sb.border_color = Color(0.40, 0.62, 0.92, 0.85)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(12)
	add_theme_stylebox_override("panel", sb)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)

	var title := Label.new()
	title.text = "Galaxy Overview"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close := Button.new()
	close.text = "X"
	close.flat = true
	close.focus_mode = Control.FOCUS_NONE
	close.tooltip_text = "Close window."
	close.pressed.connect(queue_free)
	header.add_child(close)

	root.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(420, 420)
	root.add_child(scroll)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 1)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)

	Refresh()


func Refresh() -> void:
	for child in _rows.get_children():
		child.queue_free()
	Total = 0

	var us: Faction = GameSettings.PlayerFaction
	var galaxy: Array = GameState.ActiveGalaxy
	if us == null or galaxy == null:
		return

	var worlds: Array = Lq.where(GameState.AllPlanets(), func(p: Planet) -> bool: return p.ControllingFaction == us)

	Head("Facilities")
	# Every facility TYPE, whether or not any are held - a zero row is information too.
	for rule in Lq.order_by(FacilityCatalog.All(), func(r) -> String: return r.Name):
		var type: int = FacilityCatalog.TypeOf(rule)
		var held: int = Lq.sum(worlds, func(p: Planet) -> int:
			return Lq.count(p.Facilities, func(f: Facility) -> bool: return f.Type == type and f.Tier == rule.Tier))
		Row(rule.Name, held, held * rule.MaintenanceCost)

	Head("Ships")
	Units(worlds, us, "CapitalShip")

	Head("Fighters")
	Units(worlds, us, "Fighter")

	Head("Troops")
	Units(worlds, us, "Troop")

	Head("Special Forces")
	Units(worlds, us, "SpecForce")

	_rows.add_child(HSeparator.new())

	# The remainder the three monitors above the GID show, so the two readouts
	# can be reconciled without leaving the window.
	var committed: int = Total
	var foot := Label.new()
	foot.text = "Total maintenance committed: %d" % committed
	foot.add_theme_font_size_override("font_size", 14)
	foot.add_theme_color_override("font_color", Color(1.0, 0.9, 0.45))
	_rows.add_child(foot)


func Units(worlds: Array, us: Faction, type: String) -> void:
	# Everything of that type this side can field, held anywhere it can be.
	var all: Array = []
	for p in worlds:
		all.append_array(p.Garrison)
		all.append_array(p.FighterSquadrons)
		for f in p.OrbitingFleets:
			if f.Faction != us:
				continue
			all.append_array(f.Ships)
			for s in f.Ships:
				if s.Hangar != null:
					all.append_array(s.Hangar)

	var rules: Array = Lq.where(MilitaryCatalog.All(), func(r) -> bool: return r.Type == type and MilitaryCatalog.CanBeBuiltBy(r, us))
	for rule in Lq.order_by(rules, func(r) -> String: return r.Name):
		var held: int = Lq.count(all, func(u: Unit) -> bool: return u.Name == rule.Name and u.Faction == us)
		Row(rule.Name, held, held * rule.MaintenanceCost)


func Head(text: String) -> void:
	var h := Label.new()
	h.text = text
	h.add_theme_font_size_override("font_size", 13)
	h.add_theme_color_override("font_color", Color(0.62, 0.72, 0.88))
	_rows.add_child(h)


## The manual's three columns: icon, count, maintenance. No unit art exists
## yet, so the first column carries the name.
func Row(name_: String, count: int, maintenance: int) -> void:
	Total += maintenance

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var label := Label.new()
	label.text = name_
	label.custom_minimum_size = Vector2(240, 0)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0) if count > 0 else Color(0.45, 0.48, 0.56))
	row.add_child(label)

	var n := Label.new()
	n.text = str(count)
	n.custom_minimum_size = Vector2(50, 0)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	n.add_theme_font_size_override("font_size", 12)
	n.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0) if count > 0 else Color(0.45, 0.48, 0.56))
	row.add_child(n)

	var m := Label.new()
	m.text = str(maintenance)
	m.custom_minimum_size = Vector2(70, 0)
	m.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	m.add_theme_font_size_override("font_size", 12)
	m.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45) if maintenance > 0 else Color(0.45, 0.48, 0.56))
	row.add_child(m)

	_rows.add_child(row)
