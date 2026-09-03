class_name TacticalView
extends Control
## frontend/TacticalView.cs - THE TACTICAL DISPLAY, the battlefield itself.
## ⚠ 2D TOP-DOWN IS A DELIBERATE DEPARTURE, chosen by the project owner: the
## original renders tactical combat in real-time 3D and this repo has no ship
## art. Everything the projection SHOWS - positions, facings, arcs, ranges,
## attrition - is the simulation's (TacticalBattle); this class only draws it.

var _battle: TacticalBattle
var _selected: TacticalBattle.TacticalUnit = null
var _onFinished: Callable = Callable()

# Simulated seconds per real second while the battle plays.
var _speed: float = 4.0
var _carry: float = 0.0
var _paused: bool = false

# World units per pixel, fitted to the battle on the first draw.
var _scale: float = 1.0
var _origin: Vector2 = Vector2.ZERO


func Setup(battle: TacticalBattle, onFinished: Callable) -> void:
	_battle = battle
	_onFinished = onFinished

	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	grab_focus()


func _process(delta: float) -> void:
	if _battle == null or _battle.Over or _paused:
		queue_redraw()
		return

	_carry += delta * _speed
	while _carry >= TacticalBattle.Dt:
		_carry -= TacticalBattle.Dt
		if _battle.Step():
			break

	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_selected = HitTest(event.position)
		accept_event()
		queue_redraw()
		return

	if not (event is InputEventKey) or not event.pressed or event.echo:
		return

	match event.keycode:
		KEY_SPACE:
			_paused = not _paused
			accept_event()
		KEY_1:
			_speed = 1.0
			accept_event()
		KEY_2:
			_speed = 4.0
			accept_event()
		KEY_3:
			_speed = 16.0
			accept_event()
		KEY_ESCAPE:
			Finish()
			accept_event()


func Finish() -> void:
	if _onFinished.is_valid():
		_onFinished.call()
	queue_free()


# --- DRAWING -------------------------------------------------------------

func _draw() -> void:
	if _battle == null:
		return

	var size_: Vector2 = size
	draw_rect(Rect2(Vector2.ZERO, size_), Color(0.02, 0.02, 0.05))

	Fit(size_)

	# Every unit still flying, both sides.
	for side in _battle.Sides:
		var colour: Color = side.Faction.FactionColor if side.Faction != null else Color.GRAY
		for u in side.All():
			if u.State == TacticalBattle.TacticalState.Docked:
				continue   # still in a hangar
			if not u.Alive() or u.Destroyed():
				DrawWreck(u)
				continue
			DrawUnit(u, colour)

	DrawHud(size_)


## Scale the battle to the viewport with a margin.
func Fit(size_: Vector2) -> void:
	var pts: Array[Vector2] = []
	for s in _battle.Sides:
		for u in s.All():
			if u.State != TacticalBattle.TacticalState.Docked:
				pts.append(u.Position)
	if pts.is_empty():
		_scale = 1.0
		_origin = size_ / 2
		return

	var minX: float = pts[0].x
	var maxX: float = pts[0].x
	var minY: float = pts[0].y
	var maxY: float = pts[0].y
	for p in pts:
		minX = minf(minX, p.x)
		maxX = maxf(maxX, p.x)
		minY = minf(minY, p.y)
		maxY = maxf(maxY, p.y)

	var w: float = maxf(1.0, maxX - minX)
	var h: float = maxf(1.0, maxY - minY)
	var margin := 120.0

	_scale = minf((size_.x - margin * 2) / w, (size_.y - margin * 2) / h)
	_scale = clampf(_scale, 0.05, 40.0)

	_origin = size_ / 2 - Vector2((minX + maxX) / 2, (minY + maxY) / 2) * _scale


func ToScreen(world: Vector2) -> Vector2:
	return _origin + world * _scale


## A capital ship is an arrowhead pointing where it faces; a squadron is a
## small diamond. Neither is art; both are readable.
func DrawUnit(u: TacticalBattle.TacticalUnit, colour: Color) -> void:
	var at: Vector2 = ToScreen(u.Position)
	var r: float = 5.0 if u.IsSquadron() else 11.0

	if u == _selected:
		draw_arc(at, r + 7.0, 0, TAU, 24, Color(1, 1, 1, 0.55), 1.5)

	var pt := func(ang: float, len: float) -> Vector2:
		return at + Vector2(cos(u.Facing + ang), sin(u.Facing + ang)) * len

	if u.IsSquadron():
		draw_colored_polygon(PackedVector2Array([
			pt.call(0, r), pt.call(PI / 2, r * 0.6),
			pt.call(PI, r * 0.7), pt.call(-PI / 2, r * 0.6),
		]), colour)
	else:
		draw_colored_polygon(PackedVector2Array([
			pt.call(0, r * 1.5), pt.call(2.5, r), pt.call(PI, r * 0.5), pt.call(-2.5, r),
		]), colour)
		Bars(u, at, r)


## "The first number is the current level, and the second is the ship's
## capacity" (manual p114). Shield over hull, both as a proportion.
func Bars(u: TacticalBattle.TacticalUnit, at: Vector2, r: float) -> void:
	var d: ShipDamage = u.Damage
	if d == null:
		return

	var w := 26.0
	var h := 3.0
	var top: Vector2 = at + Vector2(-w / 2, -r - 12.0)

	if d.MaxShield > 0:
		draw_rect(Rect2(top, Vector2(w, h)), Color(0.15, 0.2, 0.35))
		draw_rect(Rect2(top, Vector2(w * clampf(float(d.Shield) / float(d.MaxShield), 0, 1), h)), Color(0.45, 0.75, 1.0))

	var hull: Vector2 = top + Vector2(0, h + 1.5)
	draw_rect(Rect2(hull, Vector2(w, h)), Color(0.3, 0.15, 0.15))
	draw_rect(Rect2(hull, Vector2(w * clampf(float(d.Hull) / float(maxi(1, d.MaxHull)), 0, 1), h)), Color(1.0, 0.5, 0.35))


func DrawWreck(u: TacticalBattle.TacticalUnit) -> void:
	var at: Vector2 = ToScreen(u.Position)
	var grey := Color(0.35, 0.32, 0.30, 0.7)
	draw_line(at + Vector2(-4, -4), at + Vector2(4, 4), grey, 1.5)
	draw_line(at + Vector2(-4, 4), at + Vector2(4, -4), grey, 1.5)


## The readouts. ⚠ THE PANEL LAYOUT IS PROVISIONAL - the manual specifies the
## tactical display's panels and their named fields (Ch. 4).
func DrawHud(size_: Vector2) -> void:
	var font: Font = ThemeDB.fallback_font
	var fs := 13

	var clock: String = "t+%ds / %ds" % [int(_battle.Elapsed), int(TacticalBattle.StallLimit)]
	draw_string(font, Vector2(16, 24), clock, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.75, 0.8, 0.9))

	var y := 48.0
	for s in _battle.Sides:
		var ships: int = Lq.count(s.Ships, func(u) -> bool: return u.Alive() and not u.Destroyed())
		var sq: int = Lq.count(s.Squadrons, func(u) -> bool: return u.Alive() and not u.Destroyed())
		var line: String = "%s   Capital Ships %d   Fighter Squadrons %d   strength %d" % [
			s.Faction.DisplayName if s.Faction != null else "?", ships, sq, s.Strength]
		draw_string(font, Vector2(16, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			s.Faction.FactionColor if s.Faction != null else Color.GRAY)
		y += 18

	if _selected != null:
		var d: ShipDamage = _selected.Damage
		var sel: String = "%s   %s" % [_selected.Name(), JsonUtil.enum_name(TacticalBattle.TacticalState, _selected.State)] \
			+ (("   hull %d/%d   shield %d/%d" % [d.Hull, d.MaxHull, d.Shield, d.MaxShield]) if d != null else "")
		draw_string(font, Vector2(16, size_.y - 44), sel, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.95, 0.95, 1.0))

	# The mode banner. "Observe Battle" is the original's own name for it.
	draw_string(font, Vector2(size_.x - 210, 24), "OBSERVE BATTLE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.82, 0.4))
	draw_string(font, Vector2(size_.x - 210, 40), "the computer is fighting this", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.6, 0.65, 0.75))

	var help: String = "Battle over - Esc to return" if _battle.Over \
		else "Space pause   1/2/3 speed (%dx)   Esc return to the strategic game" % int(_speed)
	draw_string(font, Vector2(16, size_.y - 20), help, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.55, 0.6, 0.7))


func HitTest(at: Vector2) -> TacticalBattle.TacticalUnit:
	var best: TacticalBattle.TacticalUnit = null
	var bestD := 18.0
	for s in _battle.Sides:
		for u in s.All():
			if u.State == TacticalBattle.TacticalState.Docked or not u.Alive() or u.Destroyed():
				continue
			var d: float = ToScreen(u.Position).distance_to(at)
			if d > bestD:
				continue
			bestD = d
			best = u
	return best
