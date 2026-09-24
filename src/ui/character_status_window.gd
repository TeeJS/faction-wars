class_name CharacterStatusWindow
extends DraggableWindow
## frontend/CharacterStatusWindow.cs - the Character Status window (manual p041,
## p096, p101; figs 2.33 and 3.46).

var _associatedCharacter: Character

const PortraitPath := "MainVBox/ContentArea/Padding/SplitVBox/TopSection/PortraitRect"


func _ready() -> void:
	super()   # Ensures closing and dragging works!


func Populate(character: Character) -> void:
	_associatedCharacter = character
	# THE PORTRAIT (manual p101, Fig 3.46): the original's own, when the
	# player imported it (original/portraits/characters/<id>.png), else the
	# placeholder.
	Art.Fill(get_node_or_null(PortraitPath), Art.Portrait("characters", character.PackId))
	# Set Window Title
	(get_node("%TitleBarLabel") as Label).text = " %s Status" % character.TitledName()

	# --- TOP SECTION: BASIC INFO ---
	# FIX 1: Safely handle nulls. If attached/commanding is null, it defaults to "None"
	(get_node("%ValCommanding") as Label).text = character.Commanding.Name if character.Commanding != null else "None"
	(get_node("%ValAttached") as Label).text = character.Attached.Name if character.Attached != null else "None"

	# THE STATUS FIELD SPEAKS THE GAME'S OWN WORDS. TEXTSTRA.DLL carries
	# the character statuses as one contiguous run - "Enroute | On Mission
	# | Captured | Injured | Awaiting Orders" - so INJURED is a display
	# status in its own right, not a detail hidden behind "AwaitingOrders"
	# (the raw enum this used to print, missing space and all). Reported
	# from play: an injured character read as available.
	#
	# Precedence matches the personnel rows': Captured wins over Injured -
	# a captured character sits in a cell whether or not they are also
	# hurt, and p096 lists capture ahead of injury.
	if character.IsCaptured():
		(get_node("%ValStatus") as Label).text = \
			"Captured - %s" % (character.CapturedBy.DisplayName if character.CapturedBy != null else "the enemy")
	elif character.Status == Enums.Status.Enroute:
		var destName: String = character.Destination.Name if character.Destination != null else "Unknown"
		(get_node("%ValStatus") as Label).text = "Enroute to %s (%d Days)" % [destName, character.DaysToDestination]
	elif character.Status == Enums.Status.OnMission:
		(get_node("%ValStatus") as Label).text = "On Mission"
	elif character.IsInjured():
		(get_node("%ValStatus") as Label).text = "Injured"
	elif character.Status == Enums.Status.AwaitingOrders:
		(get_node("%ValStatus") as Label).text = "Awaiting Orders"
	else:
		(get_node("%ValStatus") as Label).text = JsonUtil.enum_name(Enums.Status, character.Status)

	# --- FORCE RANKING ---
	var forceText: String = "None"

	# if (character.IsKnownSpecialPowerUser || character.SpecialPowerLevel != SpecialPowerRank.None)
	if character.SpecialPowerProbability > 0:
		# GD.Print($"Known Jedi: {character.IsKnownSpecialPowerUser}, Jedi Level: ");
		# Print the rank and the integer level
		forceText = "%s" % Character.RankLabel(character.SpecialPowerRankOf())
	else:
		forceText = "None"
	(get_node("%ValForce") as Label).text = forceText

	# --- BOTTOM LEFT: RATINGS ---
	(get_node("%ValDip") as Label).text = str(character.DiplomacyRating)
	(get_node("%ValEsp") as Label).text = str(character.EspionageRating)
	(get_node("%ValCom") as Label).text = str(character.CombatRating)
	(get_node("%ValLdr") as Label).text = str(character.LeadershipRating)

	# --- BOTTOM RIGHT: TRAITS & ABILITIES ---

	var rndList: Array[String] = []
	if character.ShipDesign     > 0: rndList.append("Ship Design")
	if character.TroopTraining  > 0: rndList.append("Troop Training")
	if character.FacilityDesign > 0: rndList.append("Facility Design")

	(get_node("%ValRnD") as Label).text = "\n".join(rndList) if rndList.size() > 0 else "None"

	var commandList: Array[String] = []

	if character.CanBeAdmiral: commandList.append("Admiral")
	if character.CanBeGeneral: commandList.append("General")
	if character.CanBeCommander: commandList.append("Commander")

	(get_node("%ValCommands") as Label).text = "\n".join(commandList) if commandList.size() > 0 else "None"


## Everything the ORIGINAL'S Status window shows for a character (OUI
## .StatusPlate; manual p063 Fig 3.2, p101 Fig 3.46), in its order and words
## (TEXTSTRA.DLL 34595-34615), measured on TeeJ's screenshot of Han Solo's
## (2026-09-23): the post commanded (or None), where they are, the status
## word, the Force ranking, the four ratings, the R&D Capabilities and Possible
## Command Ranks headings with a Yes / No under each; the 80x80 portrait; the
## name, the rank before it. General: and Commander: are INFERRED (below the
## capture's view; the scroll thumb says 17 lines). "Commanding: Sluis Van"
## under "General Jerjerrod" (TeeJ's screenshot of the original, 2026-09-24):
## the post, not the rank - the rank is in the name.
static func StatusData(c: Character) -> Dictionary:
	var word: String = "Awaiting Orders"
	if c.IsCaptured():
		word = "Captured"
	elif c.Status == Enums.Status.Enroute:
		word = "Enroute"
	elif c.Status == Enums.Status.OnMission:
		word = "On Mission"
	elif c.IsInjured():
		word = "Injured"
	var yes := func(b: bool) -> String: return "Yes" if b else "No"
	var rows: Array = []
	rows.append(["Commanding:", c.Commanding.Name if c.Rank != Enums.Rank.None and c.Commanding != null else "None"])
	rows.append(["Attached:", c.Attached.Name if c.Attached != null else "None"])
	rows.append(["Status:", word])
	if c.Status == Enums.Status.Enroute:
		rows.append(["Time to Destination:", "%d Days" % c.DaysToDestination])
	rows.append(["Force Ranking:", Character.RankLabel(c.SpecialPowerRankOf()) if c.SpecialPowerProbability > 0 else "None"])
	rows.append(["Diplomacy Rating:", str(c.DiplomacyRating)])
	rows.append(["Espionage Rating:", str(c.EspionageRating)])
	rows.append(["Combat Rating:", str(c.CombatRating)])
	rows.append(["Leadership Rating:", str(c.LeadershipRating)])
	rows.append(["R&D Capabilities", ""])
	rows.append([" Ship Design", yes.call(c.ShipDesign > 0)])
	rows.append([" Troop Training", yes.call(c.TroopTraining > 0)])
	rows.append([" Facility Design", yes.call(c.FacilityDesign > 0)])
	rows.append(["Possible Command Ranks", ""])
	rows.append(["Admiral:", yes.call(c.CanBeAdmiral)])
	rows.append(["General:", yes.call(c.CanBeGeneral)])
	rows.append(["Commander:", yes.call(c.CanBeCommander)])
	return {
		"title": "Character Status",
		"fields": rows,
		"picture": Art.Scaled(Art.Portrait("characters", c.PackId), OUI.K),
		"name": c.TitledName(),
		"encyclopedia": ["characters", c.PackId],
	}


## C#: GameSignature.For(Character); the port splits the overloads by type.
func StateSignature() -> Variant:
	return GameSignature.ForCharacter(_associatedCharacter)


func Refresh() -> void:
	if _associatedCharacter != null:
		Populate(_associatedCharacter)
