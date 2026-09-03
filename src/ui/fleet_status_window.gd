class_name FleetStatusWindow
extends DraggableWindow
## frontend/FleetStatusWindow.cs
##
## THE FLEET STATUS WINDOW.
##
## Every field and its wording is taken from the original's own window, which the
## user photographed while we were measuring travel times:
##
##   Status, ETA Destination, Admiral, General, Commander, Number Of Ships,
##   Capacity (Fighter Squadrons / Trooper Regiments),
##   Embarked (Fighter Squadrons / Trooper Regiments / Personnel),
##   Damaged Ships, Hyperdrive Rating
##
## Before this, picking Status on a fleet did nothing at all: no scene existed,
## so UIManager fell through to a console dump the player never sees.

var _fleet: Fleet


func Populate(fleet: Fleet) -> void:
	_fleet = fleet
	if fleet == null:
		return

	get_node("%TitleBarLabel").text = " %s" % fleet.Name

	var body: VBoxContainer = get_node("%Body")
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()

	# "ETA Destination: Day N" - the original states the ARRIVAL DAY, not the
	# number of days left, so the player can read it against the day counter
	# without doing arithmetic.
	var eta: String = ("Day %d" % (StrategicTickManager.Today + fleet.DaysToDestination)) \
		if fleet.Status == Enums.Status.Enroute and fleet.DaysToDestination > 0 \
		else "-"

	var statusText: String
	match fleet.Status:
		Enums.Status.Enroute:        statusText = "Enroute"
		Enums.Status.AwaitingOrders: statusText = "Awaiting Orders"
		_:                           statusText = JsonUtil.enum_name(Enums.Status, fleet.Status)
	Row(body, "Status:", statusText, Color.GOLDENROD if fleet.Status == Enums.Status.Enroute else Color.LIGHT_GREEN)

	Row(body, "ETA Destination:", eta)
	if fleet.Status == Enums.Status.Enroute and fleet.Destination != null:
		Row(body, "Destination:", fleet.Destination.Name)
	else:
		Row(body, "Location:", fleet.Attached.Name if fleet.Attached != null else "-")

	Gap(body)

	# The three command posts the original lists - and they are three
	# SEPARATE posts. A fleet can carry an admiral, a general and a commander
	# at once: "a character holding one can be put in charge of all regiments
	# on a fleet or system, all ships in a fleet, or all fighter squadrons"
	# (manual p095). This used to find ONE ranked character aboard and test
	# it against all three rows, so a fleet with a general and an admiral
	# showed only whichever came first.
	var Holder := func(rank: int) -> String:
		if GameState.ActiveRoster == null:
			return "Not Assigned"
		var c: Character = Lq.first_or_null(GameState.ActiveRoster,
			func(x: Character) -> bool: return x.Commanding == fleet and x.Rank == rank)
		return c.Name if c != null else "Not Assigned"

	Row(body, "Admiral:",   Holder.call(Enums.Rank.Admiral))
	Row(body, "General:",   Holder.call(Enums.Rank.General))
	Row(body, "Commander:", Holder.call(Enums.Rank.Commander))

	Gap(body)

	Row(body, "Number Of Ships:", str(fleet.Ships.size()))

	# Capacity is what the ships COULD carry; Embarked is what is aboard.
	# The original shows both, which is the only way to see spare lift.
	var fighterCap: int = Lq.sum(fleet.Ships, func(s: Unit) -> int: return s.FighterCapacity)
	var troopCap: int   = Lq.sum(fleet.Ships, func(s: Unit) -> int: return s.TroopCapacity)
	var fighters: int   = Lq.sum(fleet.Ships, func(s: Unit) -> int:
		return Lq.count(s.Hangar, func(h: Unit) -> bool: return h.Type == Enums.UnitType.Fighter) if s.Hangar != null else 0)
	var troops: int     = Lq.sum(fleet.Ships, func(s: Unit) -> int:
		return Lq.count(s.Hangar, func(h: Unit) -> bool: return h.Type == Enums.UnitType.Troop) if s.Hangar != null else 0)
	var personnel: int  = Lq.count(GameState.ActiveRoster, func(c: Character) -> bool: return c.Attached == fleet) \
		if GameState.ActiveRoster != null else 0

	Header(body, "Capacity")
	Row(body, "   Fighter Squadrons:", str(fighterCap))
	Row(body, "   Trooper Regiments:", str(troopCap))

	Header(body, "Embarked")
	Row(body, "   Fighter Squadrons:", "%d" % fighters, Color.INDIAN_RED if fighters > fighterCap else Color.WHITE)
	Row(body, "   Trooper Regiments:", "%d" % troops, Color.INDIAN_RED if troops > troopCap else Color.WHITE)
	Row(body, "   Personnel:", str(personnel))

	Gap(body)

	# "Damaged Ships" - damage is not modelled, so this is honestly 0 rather
	# than absent. Hyperdrive Rating is a yes/no in the original, not the
	# number: the number belongs to a ship, and what matters for a fleet is
	# whether it can make the jump at all (manual p055).
	Row(body, "Damaged Ships:", str(Lq.count(fleet.Ships, func(s: Unit) -> bool: return s.Hull > 0 and s.Shield < 0)))
	Row(body, "Hyperdrive Rating:", "Yes" if fleet.HyperdriveRating() > 0 else "No")


static func Header(into: VBoxContainer, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
	into.add_child(l)


static func Gap(into: VBoxContainer) -> void:
	into.add_child(HSeparator.new())


## C#: Row(into, key, value, Color? valueColor = null).
static func Row(into: VBoxContainer, key: String, value: String, valueColor: Variant = null) -> void:
	var row := HBoxContainer.new()

	var k := Label.new()
	k.text = key
	k.custom_minimum_size = Vector2(160, 0)
	k.add_theme_font_size_override("font_size", 12)
	k.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))

	var v := Label.new()
	v.text = value
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_font_size_override("font_size", 12)
	v.add_theme_color_override("font_color", valueColor if valueColor != null else Color.WHITE)

	row.add_child(k)
	row.add_child(v)
	into.add_child(row)


# Repaints as the fleet's transit counts down, so the ETA stays honest
# instead of freezing at whatever it said when the window opened.
func StateSignature() -> Variant:
	if _fleet == null:
		return null
	return "%s.%s.%d.%d." % [_fleet.Name, JsonUtil.enum_name(Enums.Status, _fleet.Status), _fleet.DaysToDestination, _fleet.Ships.size()] \
		+ "%s.%s" % [(_fleet.Attached as Planet).Name if (_fleet.Attached as Planet) != null else "",
					 _fleet.Destination.Name if _fleet.Destination != null else ""]


func Refresh() -> void:
	if not CanRefresh():
		return
	if _fleet != null:
		Populate(_fleet)
