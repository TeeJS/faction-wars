class_name CharacterStatusWindow
extends DraggableWindow
## frontend/CharacterStatusWindow.cs - the Character Status window (manual p041,
## p096, p101; figs 2.33 and 3.46).

var _associatedCharacter: Character


func _ready() -> void:
	super()   # Ensures closing and dragging works!


func Populate(character: Character) -> void:
	_associatedCharacter = character
	# Set Window Title
	var displayRank: String = "" if character.Rank == Enums.Rank.None else "%s " % JsonUtil.enum_name(Enums.Rank, character.Rank)
	(get_node("%TitleBarLabel") as Label).text = " %s%s Status" % [displayRank, character.Name]

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

	# if (character.IsKnownJedi || character.JediLevel != ForceRanking.None)
	if character.JediProbability > 0:
		# GD.Print($"Known Jedi: {character.IsKnownJedi}, Jedi Level: ");
		# Print the rank and the integer level
		forceText = "%s" % JsonUtil.enum_name(Enums.ForceRanking, character.ForceRank())
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


## C#: GameSignature.For(Character); the port splits the overloads by type.
func StateSignature() -> Variant:
	return GameSignature.ForCharacter(_associatedCharacter)


func Refresh() -> void:
	if _associatedCharacter != null:
		Populate(_associatedCharacter)
