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

	# The unit kinds are the PACK's words (display.json terms, SCHEMA.md section 10).
	var fighters_word := "   %s:" % Terms.label("fighter_squadrons")
	var troops_word := "   %s:" % Terms.label("trooper_regiments")
	Header(body, "Capacity")
	Row(body, fighters_word, str(fighterCap))
	Row(body, troops_word, str(troopCap))

	Header(body, "Embarked")
	Row(body, fighters_word, "%d" % fighters, Color.INDIAN_RED if fighters > fighterCap else Color.WHITE)
	Row(body, troops_word, "%d" % troops, Color.INDIAN_RED if troops > troopCap else Color.WHITE)
	Row(body, "   Personnel:", str(personnel))

	Gap(body)

	# "Damaged Ships" - the ships whose damage state is below design
	# (Unit.IsDamaged; it read `Hull > 0 and Shield < 0`, never true, so it
	# was always 0). Hyperdrive Rating is a yes/no in the original, not the
	# number: the number belongs to a ship, and what matters for a fleet is
	# whether it can make the jump at all (manual p055).
	Row(body, "Damaged Ships:", str(Lq.count(fleet.Ships, func(s: Unit) -> bool: return s.IsDamaged())))
	Row(body, Terms.field("hyperdrive"), "Yes" if fleet.HyperdriveRating() > 0 else "No")


## Everything the ORIGINAL'S Status window shows for a fleet (OUI.StatusPlate),
## in its order and words (TEXTSTRA.DLL 34616-34625), measured on TeeJ's
## screenshot of an Alliance fleet (2026-09-23): no colon on Number Of Ships,
## the Capacity: and Embarked: headings with their rows unindented, Damaged
## Ships, Hyperdrive Rating Yes / No; the fleet's picture per side (STRATEGY
## 10425; the Empire's 10426 inferred) over its flames when a ship of it is
## damaged (10427). ETA Destination only while it travels (the photograph this
## window was first built from; not on the new capture).
static func StatusData(fleet: Fleet) -> Dictionary:
	var Holder := func(rank: int) -> String:
		if GameState.ActiveRoster == null:
			return "Not Assigned"
		var c: Character = Lq.first_or_null(GameState.ActiveRoster,
			func(x: Character) -> bool: return x.Commanding == fleet and x.Rank == rank)
		return c.Name if c != null else "Not Assigned"
	var fighterCap: int = Lq.sum(fleet.Ships, func(s: Unit) -> int: return s.FighterCapacity)
	var troopCap: int = Lq.sum(fleet.Ships, func(s: Unit) -> int: return s.TroopCapacity)
	var fighters: int = Lq.sum(fleet.Ships, func(s: Unit) -> int:
		return Lq.count(s.Hangar, func(h: Unit) -> bool: return h.Type == Enums.UnitType.Fighter) if s.Hangar != null else 0)
	var troops: int = Lq.sum(fleet.Ships, func(s: Unit) -> int:
		return Lq.count(s.Hangar, func(h: Unit) -> bool: return h.Type == Enums.UnitType.Troop) if s.Hangar != null else 0)
	var personnel: int = Lq.count(GameState.ActiveRoster, func(c: Character) -> bool: return c.Attached == fleet) \
		if GameState.ActiveRoster != null else 0
	var damaged: int = Lq.count(fleet.Ships, func(s: Unit) -> bool: return s.IsDamaged())
	var rows: Array = []
	rows.append(["Status:", UnitStatusWindow.StatusWord(fleet.Status)])
	if fleet.Status == Enums.Status.Enroute and fleet.DaysToDestination > 0:
		rows.append(["ETA Destination:", "Day %d" % (StrategicTickManager.Today + fleet.DaysToDestination)])
	rows.append(["Admiral:", Holder.call(Enums.Rank.Admiral)])
	rows.append(["General:", Holder.call(Enums.Rank.General)])
	rows.append(["Commander:", Holder.call(Enums.Rank.Commander)])
	rows.append(["Number Of Ships", str(fleet.Ships.size())])
	rows.append(["Capacity:", ""])
	rows.append(["Fighter Squadrons:", str(fighterCap)])
	rows.append(["Trooper Regiments:", str(troopCap)])
	rows.append(["Embarked:", ""])
	rows.append(["Fighter Squadrons:", str(fighters)])
	rows.append(["Trooper Regiments:", str(troops)])
	rows.append(["Personnel:", str(personnel)])
	rows.append(["Damaged Ships:", str(damaged)])
	rows.append(["Hyperdrive Rating:", "Yes" if fleet.HyperdriveRating() > 0 else "No"])
	var side: String = OUI.Side(fleet.Faction)
	return {
		"title": "Fleet Status",
		"fields": rows,
		"picture": OUI.Pic("status_fleet.%s" % side),
		"backdrop": OUI.Pic("status_fleet_damage") if damaged > 0 else null,
		"name": fleet.Name,
	}


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
