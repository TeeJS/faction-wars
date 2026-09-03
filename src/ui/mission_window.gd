class_name MissionWindow
extends DraggableWindow
## frontend/MissionWindow.cs
##
## "Double-click on the Mission icon to bring up the Mission window ... there
## may be more than one mission on a given system" (manual p109). The window
## reports each mission, its progress, and who is on it - and once decoys exist,
## their status separately.

var _planet: Planet

var _tabbedFor: Planet


func Populate(planet: Planet) -> void:
	var newSubject: bool = _tabbedFor != planet
	_tabbedFor = planet

	_planet = planet
	(get_node("%TitleBarLabel") as Label).text = " Missions at %s" % planet.Name
	(get_node("%PlanetName") as Label).text = planet.Name

	var tabs: TabContainer = get_node("%MissionTabs")
	# Only jump to the first tab when this window is opened on a NEW
	# subject. A refresh must leave the player where they were: once
	# repaints moved onto a four-times-a-second poll, resetting here
	# yanked them back to the first tab about once a second and made
	# every other tab unusable.
	if newSubject:
		tabs.current_tab = 0

	var activeLabel: Label = get_node("%ActiveMissionLabel")
	var operativeLabel: Label = get_node("%OperativeLabel")
	var decoyLabel: Label = get_node("%DecoyLabel")

	# NOT gated on IsExplored any more, and it must not be.
	#
	# "Reconnaissance: any system not under your control - explored OR
	# UNEXPLORED. The ONLY mission that can target an unexplored system"
	# (manual p107). This window bailed out with "Unknown" before it ever
	# looked at the mission list, so the one mission the manual sends into
	# unexplored space was the one mission this window could never report -
	# and with it went p109's Abort, which lives on these rows.
	#
	# What stays hidden is the SYSTEM, not your operation: with nothing of
	# yours running there, an unexplored world still says Unknown below.

	# Only your own missions are listed. Reading an opponent's operations
	# off their target system would hand over intelligence the game makes
	# you run an Espionage mission to obtain.
	var mine: Array = Lq.where(MissionManager.Active(),
		# Aborted missions are dropped from the list at once. Finished is set
		# the instant the order is given, but the mission is not removed from
		# the active list until the next day tick - without this filter an
		# aborted mission sits in the window looking as if nothing happened.
		func(m: Mission) -> bool: return m.Target == planet and m.Faction == GameSettings.PlayerFaction and not m.Finished)

	if mine.size() == 0:
		# An unexplored world with nothing of yours running on it is still
		# unknown - you have no way to see whether anyone else is at work
		# there, and saying "No Active Missions" would claim otherwise.
		var blind: bool = not planet.IsExplored
		activeLabel.text    = "Unknown" if blind else "No Active Missions"
		operativeLabel.text = "Sensors detect no data..." if blind else "No personnel assigned."
		decoyLabel.text     = "Sensors detect no data..." if blind else "No decoys assigned."
		ClearAbortRows(activeLabel)
		return

	activeLabel.text = "\n".join(Lq.select(mine, Describe))
	BuildAbortRows(activeLabel, mine)

	# "The window separately reports the status of AGENTS and of DECOYS"
	# (manual p109). Operatives listed the whole team with decoys mixed in,
	# and the Decoys tab beside it was never filled in at all.
	operativeLabel.text = "\n".join(Lq.select(mine, func(m: Mission) -> String:
		var agents: Array = Lq.select(
			Lq.where(m.Team, func(c: Unit) -> bool: return not m.Decoys.has(c)),
			func(c: Unit) -> String: return c.Name)
		return ("%s: " % m.DisplayName()) + (", ".join(agents) if agents.size() > 0 else "none")))

	decoyLabel.text = "\n".join(Lq.select(mine, func(m: Mission) -> String:
		return ("%s: " % m.DisplayName()) \
			+ (", ".join(Lq.select(m.Decoys, func(c: Unit) -> String: return c.Name)) if m.Decoys.size() > 0 else "none")))


# "Right-click on the Mission icon ... lets you check on the status of the
# mission, or give the order to abort or continue the mission IF THE TEAM
# IS NOT IN HYPERSPACE." (manual p109) Abort was only reachable from a
# message report; a mission already under way had no way to be called off.
func BuildAbortRows(anchor: Label, missions: Array) -> void:
	ClearAbortRows(anchor)
	var parent: Node = anchor.get_parent()
	if parent == null:
		return

	for m in missions:
		var row := HBoxContainer.new()

		# Named the same way as the status line above, so it is unambiguous
		# WHICH mission an Abort button belongs to when a system has several.
		var label := Label.new()
		label.text = LabelText(m)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 11)
		row.add_child(label)

		var abort := Button.new()
		abort.text = "Abort"
		abort.add_theme_font_size_override("font_size", 11)

		# No orders reach a team in hyperspace (manual p109).
		if not m.Arrived():
			abort.disabled = true
			abort.tooltip_text = "In hyperspace - %dd out. Orders cannot be given in transit." % m.DaysToTarget
		else:
			var captured: Mission = m
			abort.pressed.connect(func() -> void:
				CommandBus.issue("abort_mission", { "mission": captured.Serial })
				Populate(_planet))

		row.add_child(abort)
		parent.add_child(row)
		_abortRows.append(row)


# The rows this window built, tracked by reference rather than by node name.
#
# Matching on the name did not work and the failure was invisible: QueueFree
# only schedules the free for the end of the frame, so the old row was still
# a child when the replacement was added, Godot renamed the newcomer to dodge
# the collision ("AbortRow0" -> "@AbortRow0@2"), and the next pass no longer
# recognised it. Rows then accumulated one per refresh - and since refreshes
# now happen on every state change, a single mission grew a stack of Abort
# buttons. Detaching immediately and holding references removes both halves
# of that: no name to mangle, and the node is out of the tree at once.
var _abortRows: Array[HBoxContainer] = []


func ClearAbortRows(anchor: Label) -> void:
	var parent: Node = anchor.get_parent() if anchor != null else null
	for row in _abortRows:
		if row == null or not is_instance_valid(row):
			continue
		if parent != null:
			parent.remove_child(row)
		row.queue_free()
	_abortRows.clear()


# A mission names its team wherever it is listed.
#
# Without it, two independent missions against one system both read as bare
# "Diplomacy" and look like a single mission whose members are arriving at
# different times - which is not a thing that happens, since a team always
# shares one countdown. The original makes the distinction with the team's
# portraits on the mission entry; this is the same information in text.
#
# C# `Label(Mission)` - renamed because `Label` shadows the Control class in
# GDScript (the same reason GidMode.Label became LabelText).
static func LabelText(m: Mission) -> String:
	return m.DisplayName() if m.Team.size() == 0 \
		else "%s (%s)" % [m.DisplayName(), ", ".join(Lq.select(m.Team, func(c: Unit) -> String: return c.Name))]


static func Describe(m: Mission) -> String:
	# "Any time you send a character from one system to another, there is a
	# period of time when the character is in hyperspace ... you cannot give
	# orders to units in hyperspace" (manual p109).
	if not m.Arrived():
		return "%s - in hyperspace, %dd out" % [LabelText(m), m.DaysToTarget]

	var attempts: String = "arriving" if m.Attempts == 0 else "attempt %d" % m.Attempts

	# Diplomacy is persistent - it repeats "until the system supports your
	# side completely" (manual p110), so show how far along that is.
	if m.Type == Enums.MissionType.Diplomacy:
		return "%s - %s, support %d%%" % [LabelText(m), attempts, m.Target.SupportFor(m.Faction)]

	return "%s - %s" % [LabelText(m), attempts]


func StateSignature() -> Variant:
	return GameSignature.ForPlanet(_planet)


func Refresh() -> void:
	if not CanRefresh():
		return
	if _planet != null:
		Populate(_planet)
