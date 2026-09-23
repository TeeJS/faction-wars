class_name EconomyWindow
extends DraggableWindow
## frontend/EconomyWindow.cs - the Manufacturing/Production window (manual
## p083-p086): the three queues with their progress bars and Destination lines,
## one management tab per facility kind, the Build Selection window (p045) and
## the Build / Stop / Destination menu (p084).
##
## With the original's art imported it IS the original's window (TeeJ,
## 2026-09-23, from his screenshots of Chandrila, Duros and Mon Calamari):
## the 226x304 plate, the six tab pictures on its dark band, the left column
## of three pictures over their ratio boxes, the three row frames with the
## side's header bars, and each facility tab a caption over a grid of cards.

var _associatedPlanet: Planet

var _tabbedFor: Planet

# THE ORIGINAL'S LAYOUT, in its own pixels (drawn OUI.K times as large).
const PlateW := 226
const PlateH := 304
const PagesTop := 53
const TabNames := ["manufacturing", "shipyards", "training_facilities", "construction_yards", "refineries", "mines"]
const TabXs := [0, 39, 77, 115, 152, 190]
const TabY := 20
## The Manufacturing page, in page pixels (the plate's y less PagesTop): the
## left column (10298) and its ratio boxes, the three row frames (10290).
const ColumnX := 6
const ColumnY := 18
const RatioYs := [66, 147, 227]
const RowX := 55
const RowYs := [4, 85, 166]
const RowHeaders := ["Ship Construction", "Troops in Training", "Facilities Under Construction"]
const RowKeys := ["Ship", "Troop", "Fac"]
const QueuePaths := ["%ShipQueueLabel", "%TroopQueueLabel", "%FacQueueLabel"]

var _original: bool = false


func Populate(planet: Planet) -> void:
	var newSubject: bool = _tabbedFor != planet
	_tabbedFor = planet

	_associatedPlanet = planet
	var original: bool = _BuildOriginal()
	# The original titles the window with the system's name alone.
	(get_node("%TitleBarLabel") as Label).text = planet.Name if original else " %s Economy" % planet.Name

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
		# --- OVERVIEW TAB: producers counted by ROLE ---
		var shipyards: int = Lq.count(planet.Facilities, func(f: Facility) -> bool: return f.HasRole("produces_unit"))
		var training: int = Lq.count(planet.Facilities, func(f: Facility) -> bool: return f.HasRole("produces_troop"))
		var construction: int = Lq.count(planet.Facilities, func(f: Facility) -> bool: return f.HasRole("produces_facility"))

		# "The first number here is the number of construction yards at this
		# site. The second number also includes the construction yard now
		# being built." (manual p083, fig 3.24)
		(get_node("%ShipCapLabel") as Label).text = Pair(shipyards, planet, "produces_unit")
		(get_node("%TroopCapLabel") as Label).text = Pair(training, planet, "produces_troop")
		(get_node("%FacCapLabel") as Label).text = Pair(construction, planet, "produces_facility")

		# The original's own idle lines (its Manufacturing window, verbatim).
		(get_node("%ShipQueueLabel") as Label).text = QueueSummary(planet.ShipyardQueue, "No Ships are being built")
		(get_node("%TroopQueueLabel") as Label).text = QueueSummary(planet.TrainingQueue, "No Troops in training")
		(get_node("%FacQueueLabel") as Label).text = QueueSummary(planet.BuildingQueue, "No Facilities are being built")

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
		AttachQueueMenu("%ShipQueueLabel", planet, "produces_unit", planet.ShipyardQueue)
		AttachQueueMenu("%TroopQueueLabel", planet, "produces_troop", planet.TrainingQueue)
		AttachQueueMenu("%FacQueueLabel", planet, "produces_facility", planet.BuildingQueue)

		# "GRAYED-OUT TABS INDICATE NO FACILITIES OF THAT TYPE ARE ON THE
		# SYSTEM" (manual p084).
		GreyEmptyTab(tabs, "Shipyards", shipyards)
		GreyEmptyTab(tabs, "Training Facilities", training)
		GreyEmptyTab(tabs, "Construction Yards", construction)
		GreyEmptyTab(tabs, Terms.cap("refineries"), Lq.count(planet.Facilities, func(f: Facility) -> bool: return f.HasRole("refines")))
		GreyEmptyTab(tabs, Terms.cap("mines"), Lq.count(planet.Facilities, func(f: Facility) -> bool: return f.HasRole("extracts_raw")))

		# --- SPECIFIC MANAGEMENT TABS: Dynamic Population ---
		PopulateFacilityTab(tabs, "Shipyards", planet, "shipyard", "No Shipyards operational.")
		PopulateFacilityTab(tabs, "Training Facilities", planet, "training_facility", "No Training Centers operational.")
		PopulateFacilityTab(tabs, "Construction Yards", planet, "construction_yard", "No Construction Yards operational.")
		PopulateFacilityTab(tabs, Terms.cap("refineries"), planet, "refinery", "No %s operational." % Terms.lower("refineries"))
		PopulateFacilityTab(tabs, Terms.cap("mines"), planet, "mine", "No %s active." % Terms.lower("mines"))

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

		# Nothing seen: the rows stay empty (TeeJ: no "Sensors detect no data").
		var none: String = ""

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
		StaleFacilityTab(tabs, "Shipyards", "shipyard", yards)
		StaleFacilityTab(tabs, "Training Facilities", "training_facility", yards)
		StaleFacilityTab(tabs, "Construction Yards", "construction_yard", yards)
		StaleFacilityTab(tabs, Terms.cap("refineries"), "refinery", yards)
		StaleFacilityTab(tabs, Terms.cap("mines"), "mine", yards)

		# The original greys what the snapshot shows none of, as it does on
		# a world of your own.
		for pair in [["Shipyards", "shipyard"], ["Training Facilities", "training_facility"],
				["Construction Yards", "construction_yard"], [Terms.cap("refineries"), "refinery"],
				[Terms.cap("mines"), "mine"]]:
			var nm: String = Facility.NameOf(pair[1])
			GreyEmptyTab(tabs, pair[0], Lq.count(yards.Lines, func(l: String) -> bool: return l == nm or l == "Advanced %s" % nm) if yards.Known else 0)
	OUI.RefreshStrip(tabs)


# ---- THE ORIGINAL'S WINDOW -------------------------------------------------

## Build the original's window once, when its art is imported: the title
## bar, the plate, the tab strip and the Manufacturing page - the scene's
## own labels moved into the original's boxes (reparent() keeps their
## unique names, so every lookup still finds them). False without the art.
func _BuildOriginal() -> bool:
	if _original:
		return true
	var side: String = OUI.Side(GameSettings.PlayerFaction)
	if not OUI.Has(["mfg_background", "mfg_column", "mfg_row", "header.%s" % side]):
		return false
	for n in TabNames:
		if Art.TabIcon(n, side) == null:
			return false
	_original = true
	OUI.TitleBar(self, GameSettings.PlayerFaction)
	var area: MarginContainer = OUI.Flatten(self)
	var body: Control = OUI.Canvas(area, PlateW, PlateH)
	OUI.Place(body, OUI.Pic("mfg_background"), 0, 0, "Plate")
	var tabs: TabContainer = get_node("%EconomyTabs")
	tabs.reparent(body, false)
	tabs.tabs_visible = false
	tabs.custom_minimum_size = Vector2.ZERO
	tabs.position = Vector2(0, PagesTop) * OUI.K
	tabs.size = Vector2(PlateW, PlateH - PagesTop) * OUI.K
	tabs.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	OUI.TabStrip(body, tabs, TabNames, side, TabXs, TabY)

	# The Manufacturing page (Fig 3.24).
	var page: Control = tabs.get_node("Manufacturing")
	var mfg := Control.new()
	mfg.name = "OriginalManufacturing"
	mfg.custom_minimum_size = Vector2(PlateW, PlateH - PagesTop) * OUI.K
	mfg.mouse_filter = Control.MOUSE_FILTER_PASS
	page.add_child(mfg)
	OUI.Place(mfg, OUI.Pic("mfg_column"), ColumnX, ColumnY, "Column")
	for i in 3:
		var y: int = RowYs[i]
		OUI.Place(mfg, OUI.Pic("mfg_row"), RowX, y, "Row%d" % i)
		OUI.Place(mfg, OUI.Pic("header.%s" % side), RowX, y, "Header%d" % i)
		var head := OUI.Text(mfg, RowHeaders[i], RowX + 4, y, 156, 13, 11, Color.BLACK, HORIZONTAL_ALIGNMENT_LEFT, false, "HeaderText%d" % i)
		head.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		# The progress bar runs in the frame's black track (rows 70-74).
		var fill := ColorRect.new()
		fill.name = "Progress%d" % i
		fill.color = OUI.SideColor(GameSettings.PlayerFaction)
		fill.position = Vector2(RowX + 1, y + 70) * OUI.K
		fill.size = Vector2(0, 5) * OUI.K
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mfg.add_child(fill)
		var q: Label = get_node("%%%sQueueLabel" % RowKeys[i])
		OUI.Seat(q, mfg, RowX + 4, y + 16, 158, 40)
		OUI.Style(q, 11, Color.WHITE)
		q.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var d: Label = get_node("%%%sDestLabel" % RowKeys[i])
		OUI.Seat(d, mfg, RowX + 4, y + 57, 158, 12)
		OUI.Style(d, 11, Color.WHITE)
		d.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		var c: Label = get_node("%%%sCapLabel" % RowKeys[i])
		OUI.Seat(c, mfg, ColumnX, RatioYs[i], 46, 16)
		OUI.Style(c, 12, Color.WHITE)
		c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	for n in ["ShipQueue", "TroopQueue", "FacQueue"]:
		var shell: Control = page.get_node_or_null(n)
		if shell != null:
			shell.visible = false
	return true


## A facility tab's list: the original's caption over its grid of cards, or
## the plain list.
func _facility_list(container: Control, tabName: String, second: String = "") -> Container:
	if _original:
		return OUI.Page(container, [tabName] if second.is_empty() else [tabName, second], PlateW, PlateH - PagesTop)
	for child in container.get_children():
		child.queue_free()
	return container


# The manual's progress bar, under the queue's own line (p084). Shows the
# HEAD of the queue only, which the manual states outright: "if there is
# more than one unit in line to be built, this shows status of current unit
# only" (p083).
func QueueBar(labelPath: String, queue: Array, _planet: Planet) -> void:
	var label: Label = get_node_or_null(labelPath)
	if label == null:
		return
	if _original:
		# In the row frame's own track, the side's colour (the bar's colour is
		# not in any reference - single-source: the frame's black band).
		var fill: ColorRect = get_node_or_null("%%EconomyTabs/Manufacturing/OriginalManufacturing/Progress%d" % QueuePaths.find(labelPath))
		if fill != null:
			var pct: int = (queue[0] as ConstructionTask).PercentComplete() if queue.size() > 0 else 0
			fill.size = Vector2(160.0 * pct / 100.0, 5) * OUI.K
		if queue.size() > 0:
			var head0: ConstructionTask = queue[0]
			label.tooltip_text = "%s - %d%% complete" % [head0.DisplayName(), head0.PercentComplete()] \
				+ ((", %d more queued" % (queue.size() - 1)) if queue.size() > 1 else "") + "\nRight-click for orders"
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


## A manufacturing queue's Status window (manual p086, Fig 3.29: it "tells you
## the day on which construction will be finished") with the fields TeeJ's
## screenshot of the original shows (Facilities Under Construction on
## Xyquine): Location, Status, Items to Build, Estimated Day of Completion,
## then the queue's picture and name (GOKRES.DLL 263 / "Construction"; the
## ship and troop queues' 262 / 264 and "Shipyard" / "Training" are their
## neighbours in the DLLs, not yet on a screenshot). The day is when the
## whole queue is done, each item in turn at a point a day per producing
## facility.
const QueueStatus := {
	"produces_unit": ["Ship Construction", "queue.ships", "Shipyard", "Building"],
	"produces_troop": ["Troops in Training", "queue.troops", "Training", "Training"],
	"produces_facility": ["Facilities Under Construction", "queue.facilities", "Construction", "Building"],
}


static func QueueStatusData(planet: Planet, producer: String) -> Dictionary:
	var info: Array = QueueStatus.get(producer, ["Status", "", "", "Building"])
	var q: Variant = planet.QueueFor(producer)
	var queue: Array = q if q != null else []
	var workers: int = Lq.count(planet.Facilities, func(f: Facility) -> bool: return f.HasRole(producer))
	var days: int = 0
	for t in queue:
		var task: ConstructionTask = t
		days += ceili(float(maxi(0, task.TotalWork - task.Progress)) / float(maxi(1, workers)))
	var done: String = str(StrategicTickManager.Today + days) if not queue.is_empty() and workers > 0 else "n/a"
	return {
		"title": info[0],
		"fields": [["Location:", planet.Name], ["Status:", info[3] if not queue.is_empty() else "Idle"],
			["Items to Build:", str(queue.size())], ["Estimated Day of Completion:", done]],
		"picture": OUI.Pic(info[1]) if not str(info[1]).is_empty() else null,
		"name": info[2],
		"encyclopedia": ["facilities", FacilityCatalog.FamilyForRole(producer)],
	}


# A production queue entry carries the orders. "Right-click a production
# entry" gives Build, Stop, Destination (manual p084) - the same menu the
# original shows, minus the parts that need systems we do not have.
func AttachQueueMenu(labelPath: String, planet: Planet, producer: String, queue: Array) -> void:
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
	# "When you right-click on the Facilities Under Construction area ... one
	# of the options is Status. This brings up the Facilities Under
	# Construction window" (manual p086, Fig 3.29) - each queue has its own.
	menu.add_item("Status", 4)
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
			3:   # Encyclopedia - the producing facility's entry
				var ui3: UIManager = get_parent() as UIManager
				if ui3 != null:
					ui3.OpenEncyclopedia("facilities", FacilityCatalog.FamilyForRole(producer))
			4:   # Status - the queue's own Status window (Fig 3.29)
				var ui4: UIManager = get_parent() as UIManager
				if ui4 != null:
					ui4.OpenQueueStatusWindow(planet, producer)
			1:
				CommandBus.issue("cancel_build", { "planet": planet.Name, "producer": producer })
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


func PopulateFacilityTab(tabs: TabContainer, tabName: String, planet: Planet, family: String, emptyMsg: String) -> void:
	var container: VBoxContainer = tabs.get_node_or_null(tabName)
	if container == null:
		return

	var list: Container = _facility_list(container, tabName)
	if not _original:
		# Create a styled sub-header
		var header := Label.new()
		header.text = "Manage %s" % tabName
		header.add_theme_font_size_override("font_size", 13)
		header.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
		container.add_child(header)

	var matchingFacilities: Array = Lq.where(planet.Facilities, func(f: Facility) -> bool: return f.Family() == family)

	if matchingFacilities.size() == 0:
		if _original:
			return
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
		# The queue this facility feeds, by its producer ROLE; null if it feeds none.
		var ownQ: Variant = planet.QueueFor(fac.ProducerRole())

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
		# The original's list miniature of this facility, when the player imported it.
		var mini: Texture2D = Art.Miniature("facilities", fac.Def.Id if fac.Def != null else fac.Family())
		if mini != null:
			rowBtn.icon = mini
			rowBtn.set_meta("miniature", true)
		rowBtn.toggle_mode = true
		rowBtn.button_pressed = picked
		rowBtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rowBtn.add_theme_font_size_override("font_size", 12)
		rowBtn.add_theme_color_override("font_color", Color.WHITE if picked else statusColor)

		if _original:
			# THE ORIGINAL'S CARD: the facility's miniature over its name; the
			# tier and what it is doing go to the tooltip.
			var tip: String = rowBtn.text
			OUI.Card(rowBtn, fac.Name(), OUI.Mini("facilities", fac.Def.Id if fac.Def != null else fac.Family()),
				Color.RED if fac.IsDamaged else Color.WHITE, OUI.SideColor(GameSettings.PlayerFaction))
			rowBtn.tooltip_text = tip

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
					if f.Family() == rowFac.Family():
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
		var produces: bool = rowFac.HasRole("produces_facility") \
			or rowFac.HasRole("produces_unit") \
			or rowFac.HasRole("produces_troop")

		var menu := PopupMenu.new()

		if produces:
			var q: Variant = planet.QueueFor(rowFac.ProducerRole())
			var ownQueue: Array = q if q != null else planet.BuildingQueue

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
		if rowFac.HasRole("produces_facility"):
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
					OpenBuildChooser(planet, rowFac.ProducerRole())
				2:   # Encyclopedia - this facility's entry (manual p085)
					var ui2: UIManager = get_parent() as UIManager
					if ui2 != null and rowFac.Def != null:
						ui2.OpenEncyclopedia("facilities", rowFac.Def.Id)
				4:
					OpenDestinationChooser(planet)
				6:
					CommandBus.issue("cancel_build", { "planet": planet.Name, "producer": rowFac.ProducerRole() })
					Populate(planet)
				1:
					# Windows are children of the UIManager, so it is the
					# parent - this window is never handed one directly.
					var ui: UIManager = get_parent() as UIManager
					if ui != null:
						ui.OpenDefenseFacilityStatusWindow(rowFac)
				3:
					var r: int = FacilityCatalog.ConstructionCost(rowFac.Family(), rowFac.Tier) * Planet.ScrapRefundPercent / 100
					var mt: int = FacilityCatalog.MaintenanceCost(rowFac.Family(), rowFac.Tier)
					var onScrap := func() -> void:
						CommandBus.issue("scrap_facility", { "facility": rowFac.Serial })
						_selected.erase(rowFac)
					ConfirmScrap(planet, rowFac.Name(), r, mt, onScrap)
		menu.id_pressed.connect(onMenuId)

		if _original:
			row.remove_child(rowBtn)
			row.queue_free()
			list.add_child(rowBtn)
		else:
			container.add_child(row)

	# Say out loud what selecting several of them buys you, because the
	# speed rule was previously invisible and automatic.
	var chosen: int = Lq.count(_selected, func(f: Facility) -> bool: return f.Family() == family)
	if chosen > 1 and not _original:
		var note := Label.new()
		note.text = "%d selected - they share a job and finish it %dx faster." % [chosen, chosen]
		note.add_theme_font_size_override("font_size", 11)
		note.add_theme_color_override("font_color", Color.LIGHT_GREEN)
		container.add_child(note)


# built : built + under construction
## Built, and built-plus-queued, for a producer ROLE.
static func Pair(built: int, planet: Planet, producer_role: String) -> String:
	var building: int = Lq.count(planet.BuildingQueue, func(t: ConstructionTask) -> bool:
		var d := FacilityCatalog.Get(t.Family, t.Tier)
		return d != null and d.HasRole(producer_role))
	return "%d:%d" % [built, built + building]


static func QueueSummary(queue: Array, idle: String = "Idle") -> String:
	# The original's own wording: the item's NAME on one line and
	# "Building: N" beneath it - the count of that item on order. Not a
	# percentage; how far along it is belongs to the progress bar, which is
	# what the manual gives that job to ("this progress bar shows how far
	# along the current construction progress is", p084).
	if queue.size() == 0:
		return idle

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
func OpenBuildChooser(planet: Planet, producer: String) -> void:
	var owner: Faction = planet.ControllingFaction
	if owner == null or owner != GameSettings.PlayerFaction:
		return

	var target: Planet = _destination if _destination != null else planet
	var helpers: int = maxi(1, Lq.count(_selected, func(f: Facility) -> bool: return f.HasRole(producer)))

	# One shape for both catalogues, so the window does not care whether it
	# is ordering a refinery or a Star Destroyer.
	var names: Array[String] = []
	var refined: Array[int] = []
	var maint: Array[int] = []
	var days: Array[int] = []
	var place: Array[Callable] = []   # C#: List<Func<int, (int made, string error)>> - each returns a Result (value = made, error)
	var blocked: Array[String] = []   # C#: null when nothing blocks - "" here

	if producer == "produces_facility":
		var rate: int = planet.BestYardRateForUi()
		for rule in FacilityCatalog.BuildableBy(owner):
			var r: PackDefs.FacilityDef = rule
			var rFamily: String = r.Family
			names.append("%s (Tier %d)" % [r.DisplayName, r.Tier])
			refined.append(r.ConstructionCost)
			maint.append(r.MaintenanceCost)
			days.append(r.ConstructionCost * rate)
			var why: Result = planet.CanQueueFacility(rFamily, r.Tier, target)
			blocked.append(why.error)
			place.append(func(n: int) -> Result:
				return CommandBus.issue("queue_facility", { "planet": planet.Name, "type": rFamily, "tier": r.Tier, "destination": target.Name if target != null else "", "count": n }))
	else:
		var rate: int = planet.BestProducerRateForUi(producer)
		for rule in MilitaryCatalog.BuildableAt(producer, owner):
			var r: PackDefs.UnitDef = rule
			names.append(r.Name)
			refined.append(r.ConstructionCost)
			maint.append(r.MaintenanceCost)
			days.append(r.ConstructionCost * rate)
			var why: Result = planet.CanQueueUnit(r, target)
			blocked.append(why.error)
			place.append(func(n: int) -> Result:
				return CommandBus.issue("queue_units", { "planet": planet.Name, "rule": r.Name, "destination": target.Name if target != null else "", "count": n }))

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
		costLine.text = "%s necessary: %d      Maintenance capacity necessary: %d" % [Terms.label("refined_materials"), refined[i], maint[i]]
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
		+ "Returns %d %s and %d maintenance capacity,\n" % [refund, Terms.lower("refined_materials"), maint] \
		+ "and frees one %s slot on %s." % [Terms.lower("energy"), planet.Name]
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
func StaleFacilityTab(tabs: TabContainer, tabName: String, family: String, yards: IntelManager.IntelView) -> void:
	if not yards.Known:
		ClearFacilityTab(tabs, tabName, "")   # nothing seen: an empty page
		return

	var name: String = Facility.NameOf(family)
	var seen: Array = Lq.where(yards.Lines, func(l: String) -> bool: return l == name or l == "Advanced %s" % name)

	if seen.size() == 0:
		ClearFacilityTab(tabs, tabName, "" if _original else "None seen.")
		return

	var container: VBoxContainer = tabs.get_node_or_null(tabName)
	if container == null:
		return
	var list: Container = _facility_list(container, tabName, "Last seen day %d" % yards.Day)

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
				func(f: Facility) -> bool: return f.Family() == family)
			var current: Facility = ofType[nth] if nth < ofType.size() else null

			if current == null:
				print("[Mission] Nothing answers at that position - the intelligence may be stale.")
				return

			ui.ResolveObjectTarget(current))

		if _original:
			var seenDef: PackDefs.FacilityDef = FacilityCatalog.Get(family, 2 if str(line).begins_with("Advanced") else 1)
			OUI.Card(row, str(line), OUI.Mini("facilities", seenDef.Id if seenDef != null else family),
				Color.WHITE, OUI.SideColor(GameSettings.PlayerFaction))
			row.tooltip_text = "%s (seen day %d)" % [line, yards.Day]
		list.add_child(row)


func ClearFacilityTab(tabs: TabContainer, tabName: String, msg: String) -> void:
	var container: VBoxContainer = tabs.get_node_or_null(tabName)
	if container == null:
		return

	_facility_list(container, tabName)
	if _original or msg.is_empty():
		return
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
