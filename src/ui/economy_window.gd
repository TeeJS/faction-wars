class_name EconomyWindow
extends DraggableWindow
## frontend/EconomyWindow.cs - the Manufacturing/Production window (manual
## p083-p086): the three queues with their progress bars and Destination lines,
## one management tab per facility kind, the Build Selection window (p045) and
## the Build / Stop / Destination menu (p084).

var _associatedPlanet: Planet

var _tabbedFor: Planet


func Populate(planet: Planet) -> void:
	var newSubject: bool = _tabbedFor != planet
	_tabbedFor = planet

	_associatedPlanet = planet
	(get_node("%TitleBarLabel") as Label).text = " %s Economy" % planet.Name

	var tabs: TabContainer = get_node("%EconomyTabs")
	# Only jump to the first tab when this window is opened on a NEW
	# subject. A refresh must leave the player where they were: once
	# repaints moved onto a four-times-a-second poll, resetting here
	# yanked them back to the first tab about once a second and made
	# every other tab unusable.
	if newSubject:
		tabs.current_tab = 0

	# THE OTHER WINDOW THE MANUAL NAMES. "If successful on an enemy or
	# neutral system, the information you see in the MANUFACTURING/PRODUCTION
	# and System Defense windows for that system is accurate" (p106) - and
	# Reconnaissance explicitly "DOES NOT REVEAL MANUFACTURING-WINDOW
	# INFORMATION" (p107). So this window is the one an Espionage mission
	# buys you and a probe droid does not.
	#
	# The gate used to be IsExplored, which meant a scouted world showed its
	# live build queues for the rest of the game - the exact thing the manual
	# reserves for espionage, handed over by a probe and never going stale.
	if IntelManager.IsLive(GameSettings.PlayerFaction, planet):
		# --- OVERVIEW TAB: Strong Enum Checking ---
		var shipyards: int = Lq.count(planet.Facilities, func(f: Facility) -> bool: return f.Type == Enums.FacilityType.Shipyard)
		var training: int = Lq.count(planet.Facilities, func(f: Facility) -> bool: return f.Type == Enums.FacilityType.TrainingFacility)
		var construction: int = Lq.count(planet.Facilities, func(f: Facility) -> bool: return f.Type == Enums.FacilityType.ConstructionYard)

		# "The first number here is the number of construction yards at this
		# site. The second number also includes the construction yard now
		# being built." (manual p083, fig 3.24)
		(get_node("%ShipCapLabel") as Label).text = Pair(shipyards, planet, Enums.FacilityType.Shipyard)
		(get_node("%TroopCapLabel") as Label).text = Pair(training, planet, Enums.FacilityType.TrainingFacility)
		(get_node("%FacCapLabel") as Label).text = Pair(construction, planet, Enums.FacilityType.ConstructionYard)

		(get_node("%ShipQueueLabel") as Label).text = QueueSummary(planet.ShipyardQueue)
		(get_node("%TroopQueueLabel") as Label).text = QueueSummary(planet.TrainingQueue)
		(get_node("%FacQueueLabel") as Label).text = QueueSummary(planet.BuildingQueue)

		# "THIS PROGRESS BAR shows how far along the current construction
		# progress is" (manual p084). A percentage in text is not a progress
		# bar, and it was on a tab the player was not looking at - so an
		# order placed from a producer tab gave no sign of anything
		# happening, even while it ran to completion.
		QueueBar("%ShipQueueLabel", planet.ShipyardQueue, planet)
		QueueBar("%TroopQueueLabel", planet.TrainingQueue, planet)
		QueueBar("%FacQueueLabel", planet.BuildingQueue, planet)

		# "Each with its own DESTINATION: line" (manual p084). The three
		# queues can be aimed at different worlds, so each reports its own
		# rather than all three parroting the host system.
		var dest: Planet = _destination if _destination != null else planet
		var destLine: String = ("Destination: %s" % planet.Name) if dest == planet \
			else ("Destination: %s  (+%dd)" % [dest.Name, planet.DeploymentDaysTo(dest)])
		(get_node("%ShipDestLabel") as Label).text = destLine
		(get_node("%TroopDestLabel") as Label).text = destLine
		(get_node("%FacDestLabel") as Label).text = destLine

		# "Right-click a production entry" for Build, Stop, Destination -
		# the orders live on the QUEUE, not on the facility (manual p084,
		# and the original's own menu). Each of the three queues is one
		# entry: Ship Construction, Troops in Training, Facilities Under
		# Construction.
		AttachQueueMenu("%ShipQueueLabel", planet, Enums.FacilityType.Shipyard, planet.ShipyardQueue)
		AttachQueueMenu("%TroopQueueLabel", planet, Enums.FacilityType.TrainingFacility, planet.TrainingQueue)
		AttachQueueMenu("%FacQueueLabel", planet, Enums.FacilityType.ConstructionYard, planet.BuildingQueue)

		# "GRAYED-OUT TABS INDICATE NO FACILITIES OF THAT TYPE ARE ON THE
		# SYSTEM" (manual p084).
		GreyEmptyTab(tabs, "Shipyards", shipyards)
		GreyEmptyTab(tabs, "Training Facilities", training)
		GreyEmptyTab(tabs, "Construction Yards", construction)
		GreyEmptyTab(tabs, "Refineries", Lq.count(planet.Facilities, func(f: Facility) -> bool: return f.Type == Enums.FacilityType.Refinery))
		GreyEmptyTab(tabs, "Mines", Lq.count(planet.Facilities, func(f: Facility) -> bool: return f.Type == Enums.FacilityType.Mine))

		# --- SPECIFIC MANAGEMENT TABS: Dynamic Population ---
		PopulateFacilityTab(tabs, "Shipyards", planet, Enums.FacilityType.Shipyard, "No Shipyards operational.")
		PopulateFacilityTab(tabs, "Training Facilities", planet, Enums.FacilityType.TrainingFacility, "No Training Centers operational.")
		PopulateFacilityTab(tabs, "Construction Yards", planet, Enums.FacilityType.ConstructionYard, "No Construction Yards operational.")
		PopulateFacilityTab(tabs, "Refineries", planet, Enums.FacilityType.Refinery, "No Refineries operational.")
		PopulateFacilityTab(tabs, "Mines", planet, Enums.FacilityType.Mine, "No Mining Operations active.")

		# Each producer gets a build panel on its own tab, matching the
		# manual's split: construction yards make facilities, orbital
		# shipyards make ships and fighters, training facilities make
		# trooper regiments AND SpecForces (p097, p113, p129).
		# NOTHING BUILDABLE IS LISTED IN THE TAB. The tab is a list of the
		# facilities you own, exactly like the personnel and trooper lists.
		# What to build is chosen from the facility's own right-click menu,
		# which opens a chooser - the original does the same: right-click a
		# production entry and the menu offers Build, Stop, Destination,
		# Encyclopedia, Status.
	else:
		# Somebody else's system. Two separate categories land here and an
		# informant can hand over either without the other: what is BEING
		# BUILT (Manufacturing) and what it is being built IN
		# (ProductionFacilities).
		var viewer: Faction = GameSettings.PlayerFaction
		var queues: IntelManager.IntelView = IntelManager.View(viewer, planet, Enums.IntelSection.Manufacturing)
		var yards: IntelManager.IntelView = IntelManager.View(viewer, planet, Enums.IntelSection.ProductionFacilities)

		var none: String = "Sensors detect no data"

		(get_node("%ShipCapLabel") as Label).text = "0:0"
		(get_node("%TroopCapLabel") as Label).text = "0:0"
		(get_node("%FacCapLabel") as Label).text = "0:0"

		# The three queue lines carry the snapshot. It is one list in the
		# game's own category, so it is reported as one list rather than
		# split three ways on a guess about which yard owns which entry -
		# the snapshot already labels each line with its queue.
		var built: String
		if not queues.Known:
			built = none
		elif queues.Lines.size() == 0:
			built = "Nothing under construction"
		else:
			built = "\n".join(queues.Lines)

		(get_node("%ShipQueueLabel") as Label).text = built
		(get_node("%TroopQueueLabel") as Label).text = "" if queues.Known else none
		(get_node("%FacQueueLabel") as Label).text = "" if queues.Known else none

		(get_node("%ShipDestLabel") as Label).text = ""
		(get_node("%TroopDestLabel") as Label).text = ""
		(get_node("%FacDestLabel") as Label).text = ""

		# ONE INTEL CATEGORY, FIVE TABS. The snapshot is stored as one list
		# because that is the game's own category - but each tab shows one
		# KIND of facility, so its lines are dealt to the tab they name.
		# Writing the whole list into all five put mines and refineries on
		# the Training Facilities tab. Reported from play on Drall.
		#
		# "The information you see in the Manufacturing/Production windows
		# for that system is accurate ... a snapshot" (manual p106) - a
		# snapshot of each tab as it stood, not of the union pasted five
		# times.
		StaleFacilityTab(tabs, "Shipyards", Enums.FacilityType.Shipyard, yards)
		StaleFacilityTab(tabs, "Training Facilities", Enums.FacilityType.TrainingFacility, yards)
		StaleFacilityTab(tabs, "Construction Yards", Enums.FacilityType.ConstructionYard, yards)
		StaleFacilityTab(tabs, "Refineries", Enums.FacilityType.Refinery, yards)
		StaleFacilityTab(tabs, "Mines", Enums.FacilityType.Mine, yards)


# The manual's progress bar, under the queue's own line (p084). Shows the
# HEAD of the queue only, which the manual states outright: "if there is
# more than one unit in line to be built, this shows status of current unit
# only" (p083).
func QueueBar(labelPath: String, queue: Array, _planet: Planet) -> void:
	var label: Label = get_node_or_null(labelPath)
	if label == null:
		return
	var parent: Control = label.get_parent() as Control
	if parent == null:
		return

	var barName: String = labelPath.trim_prefix("%") + "Bar"
	var bar: ProgressBar = parent.get_node_or_null(barName)

	if queue.size() == 0:
		if bar != null:
			bar.visible = false
		return

	if bar == null:
		bar = ProgressBar.new()
		bar.name = barName
		bar.min_value = 0
		bar.max_value = 100
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 10)
		parent.add_child(bar)
		# Directly beneath the line it describes.
		parent.move_child(bar, label.get_index() + 1)

	var head: ConstructionTask = queue[0]
	bar.visible = true
	bar.value = head.PercentComplete()

	bar.tooltip_text = "%s - %d%% complete" % [head.DisplayName(), head.PercentComplete()] \
		+ ((", %d more queued" % (queue.size() - 1)) if queue.size() > 1 else "")


# A production queue entry carries the orders. "Right-click a production
# entry" gives Build, Stop, Destination (manual p084) - the same menu the
# original shows, minus the parts that need systems we do not have.
func AttachQueueMenu(labelPath: String, planet: Planet, producer: int, queue: Array) -> void:
	var label: Label = get_node_or_null(labelPath)
	if label == null:
		return

	label.mouse_filter = Control.MOUSE_FILTER_STOP
	label.tooltip_text = "Right-click for orders"

	# Rebuilt every refresh, so the menu must not accumulate.
	for child in label.get_children():
		if child is PopupMenu:
			label.remove_child(child)
			child.queue_free()

	var menu := PopupMenu.new()
	menu.add_item("Build...", 0)
	menu.add_item("Stop", 1)
	menu.set_item_disabled(menu.get_item_index(1), queue.size() == 0)
	menu.add_item("Destination...", 2)
	menu.add_separator()
	menu.add_item("Encyclopedia", 3)
	menu.set_item_disabled(menu.get_item_index(3), true)
	label.add_child(menu)
	RegisterPopupMenu(menu)

	label.gui_input.connect(func(e: InputEvent) -> void:
		if not (e is InputEventMouseButton) or not e.pressed or e.button_index != MOUSE_BUTTON_RIGHT:
			return
		menu.position = Vector2i(int(e.global_position.x), int(e.global_position.y))
		menu.popup()
		label.accept_event())

	var onId := func(id: int) -> void:
		match id:
			0: OpenBuildChooser(planet, producer)
			1:
				planet.CancelCurrentBuild(producer)
				Populate(planet)
			2: OpenDestinationChooser(planet)
	menu.id_pressed.connect(onId)


# A tab with nothing of that type on the system is greyed out (manual p084).
static func GreyEmptyTab(tabs: TabContainer, tabName: String, count: int) -> void:
	var page: Control = tabs.get_node_or_null(tabName)
	if page == null:
		return
	var idx: int = page.get_index()
	if idx >= 0 and idx < tabs.get_tab_count():
		tabs.set_tab_disabled(idx, count == 0)


func PopulateFacilityTab(tabs: TabContainer, tabName: String, planet: Planet, type: int, emptyMsg: String) -> void:
	var container: VBoxContainer = tabs.get_node_or_null(tabName)
	if container == null:
		return

	# Clear existing placeholder label or old entries
	for child in container.get_children():
		child.queue_free()

	# Create a styled sub-header
	var header := Label.new()
	header.text = "Manage %s" % tabName
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
	container.add_child(header)

	var matchingFacilities: Array = Lq.where(planet.Facilities, func(f: Facility) -> bool: return f.Type == type)

	if matchingFacilities.size() == 0:
		var emptyLabel := Label.new()
		emptyLabel.text = emptyMsg
		emptyLabel.add_theme_font_size_override("font_size", 11)
		emptyLabel.add_theme_color_override("font_color", Color.GRAY)
		container.add_child(emptyLabel)
		return

	# One SELECTABLE ROW per facility, the way the Defenses window lists
	# trooper regiments. Click to select, shift or ctrl click to add more,
	# right-click for orders. Selecting several matters: a world earns one
	# point of build progress per producing facility per day, so three yards
	# finish a job in a third of the time - and the player should be able to
	# see and choose the facilities doing that, not have it happen silently.
	for fac in matchingFacilities:
		var rowFac: Facility = fac

		# WHAT THIS FACILITY IS DOING RIGHT NOW, on its own row.
		#
		# The game draws the distinction itself: the display has Idle
		# Shipyards, Idle Training Centers and Idle Construction Yards as
		# their own modes - "you can further pinpoint only those shipyards,
		# training centers, or construction yards that are CURRENTLY IDLE"
		# (manual p086). A facility is therefore either working or idle, and
		# the list that shows your facilities should say which.
		var ownQ: Variant
		match fac.Type:
			Enums.FacilityType.ConstructionYard: ownQ = planet.BuildingQueue
			Enums.FacilityType.Shipyard:         ownQ = planet.ShipyardQueue
			Enums.FacilityType.TrainingFacility: ownQ = planet.TrainingQueue
			_:                                   ownQ = null

		var statusText: String
		var statusColor: Color

		if fac.IsDamaged:
			statusText = "[DAMAGED]"
			statusColor = Color.RED
		elif ownQ == null:
			# A mine or refinery has no queue - it simply runs.
			statusText = "[Operational]"
			statusColor = Color.LIGHT_GREEN
		elif ownQ.size() == 0:
			# ⚠ AN IDLE PRODUCER STILL HAS A DESTINATION, AND IT USED TO
			# HIDE IT. The building branch below already reports "then Nd
			# to X", so a yard mid-job showed where its output was going and
			# the same yard between jobs did not - which is exactly when the
			# player is deciding whether to queue something.
			statusText = ("[Idle] (to %s)" % _destination.Name) if _destination != null and _destination != planet \
				else "[Idle]"
			statusColor = Color.GRAY
		else:
			var job: ConstructionTask = ownQ[0]
			var sameItem: int = Lq.count(ownQ, func(t: ConstructionTask) -> bool: return t.DisplayName() == job.DisplayName())
			var workers: int = maxi(1, matchingFacilities.size())
			var daysLeft: int = ceili(float(maxi(0, job.TotalWork - job.Progress)) / float(workers))

			# "BEST TIME TO DEPLOYMENT: days needed to deploy facility to
			# destination system ONCE IT HAS BEEN BUILT" (manual p045).
			# Construction is only the first of the two stages, so a row
			# that stops at the build time understates when the thing
			# actually arrives - and hides that it is going somewhere else.
			var leg: String = ""
			if job.Destination != null and job.Destination != planet:
				leg = " then %dd to %s" % [job.TransportDays, job.Destination.Name]
			elif job.TransportDays > 0:
				leg = " then %dd transit" % job.TransportDays

			statusText = "[Building %s - %d%%, %dd left%s" % [job.DisplayName(), job.PercentComplete(), daysLeft, leg] \
				+ ((", %d on order]" % sameItem) if sameItem > 1 else "]")
			statusColor = Color.GOLD

		var picked: bool = _selected.has(fac)

		var rowBtn := Button.new()
		rowBtn.text = "%s (Tier %d)   %s" % [fac.Name(), fac.Tier, statusText]
		rowBtn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		rowBtn.toggle_mode = true
		rowBtn.button_pressed = picked
		rowBtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rowBtn.add_theme_font_size_override("font_size", 12)
		rowBtn.add_theme_color_override("font_color", Color.WHITE if picked else statusColor)

		rowBtn.toggled.connect(func(on: bool) -> void:
			# CROSSHAIRS UP: this click is naming a sabotage target, not
			# selecting a facility to give orders to. "Missions require you,
			# for example, to select a particular FACILITY TO SABOTAGE"
			# (manual p040).
			var ui: UIManager = get_parent() as UIManager
			if ui != null and ui.IsTargetingObject():
				rowBtn.set_pressed_no_signal(_selected.has(rowFac))
				ui.ResolveObjectTarget(rowFac)
				return

			# Plain click replaces the selection; shift or ctrl adds to it.
			var additive: bool = Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_CTRL)
			if not additive:
				for f in _selected.duplicate():
					if f.Type == rowFac.Type:
						_selected.erase(f)
			if on:
				if not _selected.has(rowFac):
					_selected.append(rowFac)
			else:
				_selected.erase(rowFac)
			Populate(planet))

		var row := HBoxContainer.new()
		row.add_child(rowBtn)

		# Orders live on the facility's right-click menu, which is where the
		# manual puts them: Encyclopedia / Status / Scrap (p085).
		# A PRODUCING facility carries the full menu the original shows:
		# Build, Stop, Destination, Rename, Encyclopedia, Status, Reserved.
		#
		# Reserved being in it is the proof it is the FACILITY's menu -
		# "reserve ON A CONSTRUCTION YARD means the agent will not use that
		# facility to build mines and refineries" (p086) is a property of
		# the yard, not of a queue.
		#
		# A mine or refinery produces nothing to order, so it gets only the
		# three that apply to it: Encyclopedia, Status, Scrap (p085).
		var produces: bool = rowFac.Type == Enums.FacilityType.ConstructionYard \
			or rowFac.Type == Enums.FacilityType.Shipyard \
			or rowFac.Type == Enums.FacilityType.TrainingFacility

		var menu := PopupMenu.new()

		if produces:
			var ownQueue: Array
			match rowFac.Type:
				Enums.FacilityType.Shipyard:         ownQueue = planet.ShipyardQueue
				Enums.FacilityType.TrainingFacility: ownQueue = planet.TrainingQueue
				_:                                   ownQueue = planet.BuildingQueue

			menu.add_item("Build...", 0)
			menu.add_item("Stop", 6)
			menu.set_item_disabled(menu.get_item_index(6), ownQueue.size() == 0)
			menu.add_item("Destination...", 4)

			# Named because the original names it, disabled because nothing
			# in this project renames a facility yet.
			menu.add_item("Rename", 7)
			menu.set_item_disabled(menu.get_item_index(7), true)
			menu.add_separator()

		menu.add_item("Encyclopedia", 2)
		menu.set_item_disabled(menu.get_item_index(2), true)
		menu.add_item("Status", 1)

		# "RESERVE on a construction yard means: if you turn over
		# Maintenance Production to your agent, the agent will not use that
		# facility to build mines and refineries" (manual p086). Listed
		# where the manual puts it - on the yard - and disabled until the
		# agent's Maintenance Production role exists to be reserved from.
		if rowFac.Type == Enums.FacilityType.ConstructionYard:
			menu.add_item("Reserve", 5)
			menu.set_item_disabled(menu.get_item_index(5), true)
		if planet.ControllingFaction == GameSettings.PlayerFaction and planet.CanScrap(fac):
			menu.add_separator()
			menu.add_item("Scrap", 3)
		rowBtn.add_child(menu)
		RegisterPopupMenu(menu)

		rowBtn.gui_input.connect(func(e: InputEvent) -> void:
			if not (e is InputEventMouseButton) or not e.pressed or e.button_index != MOUSE_BUTTON_RIGHT:
				return
			# Right-clicking an unselected row selects it first, so an order
			# always applies to something the player can see is chosen.
			if not _selected.has(rowFac):
				_selected.append(rowFac)
				Populate(planet)
			menu.position = Vector2i(int(e.global_position.x), int(e.global_position.y))
			menu.popup()
			rowBtn.accept_event())

		var onMenuId := func(id: int) -> void:
			match id:
				0:
					OpenBuildChooser(planet, rowFac.Type)
				4:
					OpenDestinationChooser(planet)
				6:
					planet.CancelCurrentBuild(rowFac.Type)
					Populate(planet)
				1:
					# Windows are children of the UIManager, so it is the
					# parent - this window is never handed one directly.
					var ui: UIManager = get_parent() as UIManager
					if ui != null:
						ui.OpenDefenseFacilityStatusWindow(rowFac)
				3:
					var r: int = FacilityCatalog.ConstructionCost(rowFac.Type, rowFac.Tier) * Planet.ScrapRefundPercent / 100
					var mt: int = FacilityCatalog.MaintenanceCost(rowFac.Type, rowFac.Tier)
					var onScrap := func() -> void:
						planet.ScrapFacility(rowFac)
						_selected.erase(rowFac)
					ConfirmScrap(planet, rowFac.Name(), r, mt, onScrap)
		menu.id_pressed.connect(onMenuId)

		container.add_child(row)

	# Say out loud what selecting several of them buys you, because the
	# speed rule was previously invisible and automatic.
	var chosen: int = Lq.count(_selected, func(f: Facility) -> bool: return f.Type == type)
	if chosen > 1:
		var note := Label.new()
		note.text = "%d selected - they share a job and finish it %dx faster." % [chosen, chosen]
		note.add_theme_font_size_override("font_size", 11)
		note.add_theme_color_override("font_color", Color.LIGHT_GREEN)
		container.add_child(note)


# built : built + under construction
static func Pair(built: int, planet: Planet, type: int) -> String:
	var building: int = Lq.count(planet.BuildingQueue, func(t: ConstructionTask) -> bool: return t.Type == type)
	return "%d:%d" % [built, built + building]


static func QueueSummary(queue: Array) -> String:
	# The original's own wording: the item's NAME on one line and
	# "Building: N" beneath it - the count of that item on order. Not a
	# percentage; how far along it is belongs to the progress bar, which is
	# what the manual gives that job to ("this progress bar shows how far
	# along the current construction progress is", p084).
	if queue.size() == 0:
		return "Idle"

	var head: ConstructionTask = queue[0]

	# How many of the SAME item are stacked up, since "Number to build"
	# enqueues them one per copy and the original reports them as one line
	# with a count rather than N identical entries.
	var sameItem: int = Lq.count(queue, func(t: ConstructionTask) -> bool: return t.DisplayName() == head.DisplayName())

	return "%s\nBuilding: %d" % [head.DisplayName(), sameItem]


# The three prerequisites from manual p054 - a free energy slot, refined
# material, and maintenance capacity - plus a Build button per facility the
# owning faction is allowed to place here.

# THE BUILD SELECTION WINDOW (manual p045, and the original's own dialog).
#
# One item at a time, chosen from a drop-down - not a scrolling wall of
# everything with a Build button on each row. The manual specifies exactly
# what it shows, and every field below is one of them:
#
#   the item, picked from a chooser
#   Maintenance capacity necessary   (drawn from the pool at order time)
#   Refined materials necessary
#   Best Time To Completion          days to build
#   Best Time To Deployment          days "needed to deploy facility to
#                                    destination system once it has been built"
#   Number to build                  "You also choose Number to build in one order"
#   confirm / cancel
func OpenBuildChooser(planet: Planet, producer: int) -> void:
	var owner: Faction = planet.ControllingFaction
	if owner == null or owner != GameSettings.PlayerFaction:
		return

	var target: Planet = _destination if _destination != null else planet
	var helpers: int = maxi(1, Lq.count(_selected, func(f: Facility) -> bool: return f.Type == producer))

	# One shape for both catalogues, so the window does not care whether it
	# is ordering a refinery or a Star Destroyer.
	var names: Array[String] = []
	var refined: Array[int] = []
	var maint: Array[int] = []
	var days: Array[int] = []
	var place: Array[Callable] = []   # C#: List<Func<int, (int made, string error)>> - each returns a Result (value = made, error)
	var blocked: Array[String] = []   # C#: null when nothing blocks - "" here

	if producer == Enums.FacilityType.ConstructionYard:
		var rate: int = planet.BestYardRateForUi()
		for rule in FacilityCatalog.BuildableBy(owner):
			var r: CatalogDtos.FacilityStatRule = rule
			var rType: int = FacilityCatalog.TypeOf(r)
			names.append("%s (Tier %d)" % [r.Name, r.Tier])
			refined.append(r.ConstructionCost)
			maint.append(r.MaintenanceCost)
			days.append(r.ConstructionCost * rate)
			var why: Result = planet.CanQueueFacility(rType, r.Tier, target)
			blocked.append(why.error)
			place.append(func(n: int) -> Result:
				return planet.TryQueueMany(rType, r.Tier, target, n))
	else:
		var rate: int = planet.BestProducerRateForUi(producer)
		for rule in MilitaryCatalog.BuildableAt(producer, owner):
			var r: CatalogDtos.UnitStatRule = rule
			names.append(r.Name)
			refined.append(r.ConstructionCost)
			maint.append(r.MaintenanceCost)
			days.append(r.ConstructionCost * rate)
			var why: Result = planet.CanQueueUnit(r, target)
			blocked.append(why.error)
			place.append(func(n: int) -> Result:
				return planet.TryQueueManyUnits(r, target, n))

	if names.size() == 0:
		return

	var dialog := ConfirmationDialog.new()
	dialog.title = ("Build Selection - %d working together" % helpers) if helpers > 1 else "Build Selection"
	dialog.exclusive = true

	const W := 380
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(W, 0)

	var picker := OptionButton.new()
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in names.size():
		picker.add_item(names[i], i)
	picker.selected = 0
	box.add_child(picker)
	box.add_child(HSeparator.new())

	var costLine := Label.new()
	var completion := Label.new()
	var deployment := Label.new()
	var reason := Label.new()
	reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reason.custom_minimum_size = Vector2(W, 0)
	reason.add_theme_color_override("font_color", Color.INDIAN_RED)
	for l in [costLine, completion, deployment, reason]:
		l.add_theme_font_size_override("font_size", 12)

	box.add_child(costLine)
	box.add_child(completion)
	box.add_child(deployment)

	var qtyRow := HBoxContainer.new()
	var qtyLabel := Label.new()
	qtyLabel.text = "Number to build: "
	qtyRow.add_child(qtyLabel)
	var qty := SpinBox.new()
	qty.min_value = 1
	qty.max_value = 99
	qty.value = 1
	qty.custom_minimum_size = Vector2(70, 0)
	qtyRow.add_child(qty)
	box.add_child(qtyRow)

	var destLine := Label.new()
	destLine.text = "Destination: %s" % target.Name
	destLine.add_theme_font_size_override("font_size", 12)
	box.add_child(destLine)
	box.add_child(reason)

	var deployDays: int = planet.DeploymentDaysTo(target)

	var Show := func() -> void:
		var i: int = picker.selected
		# Several facilities on one job finish it proportionally sooner -
		# "best" time is with everything selected working it.
		var best: int = maxi(1, days[i] / helpers)
		costLine.text = "Refined materials necessary: %d      Maintenance capacity necessary: %d" % [refined[i], maint[i]]
		completion.text = ("Best Time To Completion: %d Days" % best) \
			+ (("   (%d with one)" % days[i]) if helpers > 1 else "")
		deployment.text = "Best Time To Deployment: %d Days" % deployDays
		reason.text = blocked[i]
		dialog.get_ok_button().disabled = not blocked[i].is_empty()

	picker.item_selected.connect(func(_i: int) -> void: Show.call())
	Show.call()

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 12)
	pad.add_theme_constant_override("margin_right", 12)
	pad.add_theme_constant_override("margin_top", 8)
	pad.add_theme_constant_override("margin_bottom", 8)
	pad.add_child(box)
	dialog.add_child(pad)

	dialog.confirmed.connect(func() -> void:
		var i: int = picker.selected
		var want: int = int(qty.value)
		var res: Result = place[i].call(want)
		var made: int = int(res.value) if res.value != null else 0
		var err: String = res.error
		if made > 0 and made < want:
			print("[Build] Queued %d of %d - %s" % [made, want, err])
		elif made == 0:
			print("[Build] %s" % err)
		Populate(planet)
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)

	dialog.max_size = Vector2i(W + 40, 320)
	add_child(dialog)
	dialog.popup_centered(Vector2i(W + 40, 320))


# DESTINATION IS PICKED ON THE MAP, exactly like Move and Mission.
#
# "Right-click your agent droid, choose Build Facilities, THE CURSOR BECOMES
# TARGETING CROSSHAIRS, click the destination system" (manual p044). It is
# the same targeting gesture the game uses everywhere else you name a place,
# not a list of names in a box - a list also cannot show you where the world
# is, which is half of what makes the choice.
func OpenDestinationChooser(planet: Planet) -> void:
	var ui: UIManager = get_parent() as UIManager
	if ui == null:
		return

	print("[Build] Select a destination system.")
	ui.StartTargeting(func(chosen: Planet) -> void:
		if chosen == null:
			return

		# A yard builds for any world the faction controls (manual p084),
		# so an enemy or neutral world is not a legal delivery address.
		if not planet.ValidDestinations().has(chosen):
			print("[Build] %s is not yours - finished items cannot be sent there." % chosen.Name)
			return

		_destination = chosen
		print("[Build] Destination set to %s (+%dd transit)." % [chosen.Name, planet.DeploymentDaysTo(chosen)])
		Populate(planet))


# Sticky destination choice across repopulates.
var _destination: Planet

# Which facilities the player has picked, and which catalogue they asked to
# see. Held on the window rather than in the buttons: this window rebuilds
# about four times a second, so a selection living in the controls would be
# wiped before the player finished choosing.
var _selected: Array = []


# The original confirms before scrapping: "Are you sure you want to scrap
# the following units?" followed by the item's name, with a tick and a
# cross. Same shape here, plus what you get back, since scrapping is
# irreversible and returns only half the refined material.
func ConfirmScrap(planet: Planet, what: String, refund: int, maint: int, onConfirm: Callable) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Confirm Scrap"
	dialog.dialog_text = "Are you sure you want to scrap the following units?\n\n" \
		+ "    %s\n\n" % what \
		+ "Returns %d refined material and %d maintenance capacity,\n" % [refund, maint] \
		+ "and frees one energy slot on %s." % planet.Name
	dialog.exclusive = true

	dialog.confirmed.connect(func() -> void:
		onConfirm.call()
		Populate(planet)
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)

	add_child(dialog)
	dialog.popup_centered()


# One tab's worth of a ProductionFacilities snapshot. The stored lines are
# Facility.NameOf strings - "Mine", "Advanced Refinery" - so a tab keeps
# exactly the lines naming its own type, in both tiers.
#
# ⚠ ROWS, NOT A TEXT BLOB - because these are SABOTAGE TARGETS. The
# mission's list is "enemy FACILITY, capital ship, fighter squadron,
# trooper regiment, or SpecForce" (p105-p108) and the gesture is "select a
# particular FACILITY to sabotage" (p040) - and the only facilities the
# rule admits live on worlds this window shows as a snapshot. The live
# rows have carried the targeting hook all along, on the one branch where
# CanSabotage refuses everything as yours - so facility sabotage was
# impossible from the day it shipped: the backend accepted a target no
# window could deliver. Found on the third report, after the system gate
# and the ship path had each been fixed and each turned out not to be the
# whole story.
func StaleFacilityTab(tabs: TabContainer, tabName: String, type: int, yards: IntelManager.IntelView) -> void:
	if not yards.Known:
		ClearFacilityTab(tabs, tabName, "Sensors detect no data.")
		return

	var name: String = Facility.NameOf(type)
	var seen: Array = Lq.where(yards.Lines, func(l: String) -> bool: return l == name or l == "Advanced %s" % name)

	if seen.size() == 0:
		ClearFacilityTab(tabs, tabName, "None seen.")
		return

	var container: VBoxContainer = tabs.get_node_or_null(tabName)
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()

	var world: Planet = _associatedPlanet
	var index: int = 0
	for line in seen:
		var nth: int = index
		index += 1
		var row := Button.new()
		row.text = line
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.flat = true
		row.add_theme_font_size_override("font_size", 12)
		row.add_theme_color_override("font_color", Color.LIGHT_GRAY)

		row.pressed.connect(func() -> void:
			var ui: UIManager = get_parent() as UIManager
			if ui == null or not ui.IsTargetingObject():
				return   # look-only otherwise

			# ⚠ OURS, approved as "the small leak": the snapshot stores
			# strings, so the click re-resolves the nth facility of this
			# type standing there NOW. If it was scrapped since the
			# sighting, nothing answers - which tells the player one bit
			# the fog should hide. The alternative (launch anyway, fail on
			# arrival) invents a mechanic no source describes, so the leak
			# was ruled the lesser evil. If play shows it matters, the fix
			# is here.
			var ofType: Array = Lq.where(world.Facilities if world != null else [],
				func(f: Facility) -> bool: return f.Type == type)
			var current: Facility = ofType[nth] if nth < ofType.size() else null

			if current == null:
				print("[Mission] Nothing answers at that position - the intelligence may be stale.")
				return

			ui.ResolveObjectTarget(current))

		container.add_child(row)


func ClearFacilityTab(tabs: TabContainer, tabName: String, msg: String) -> void:
	var container: VBoxContainer = tabs.get_node_or_null(tabName)
	if container == null:
		return

	for child in container.get_children():
		child.queue_free()
	var emptyLabel := Label.new()
	emptyLabel.text = msg
	emptyLabel.add_theme_color_override("font_color", Color.GRAY)
	container.add_child(emptyLabel)


# C#: GameSignature.For(Planet) - the port names the overloads ForPlanet/ForSector/...
func StateSignature() -> Variant:
	return GameSignature.ForPlanet(_associatedPlanet)


func Refresh() -> void:
	if not CanRefresh():
		return
	if _associatedPlanet != null:
		Populate(_associatedPlanet)


# The manual's "Number to build" field, on every build row. One order, many
# copies - without it a player wanting ten troop regiments clicks Build ten
# times, which is not what the game asks of them.
static func BuildQuantityBox() -> SpinBox:
	var qty := SpinBox.new()
	qty.min_value = 1
	qty.max_value = 99
	qty.value = 1
	qty.custom_minimum_size = Vector2(58, 0)
	qty.tooltip_text = "Number to build in this order"
	qty.add_theme_font_size_override("font_size", 12)
	return qty
