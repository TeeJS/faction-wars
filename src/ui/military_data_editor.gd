class_name MilitaryDataEditor
extends Control
## frontend/MilitaryDataEditor.cs - the developer tool that lists the military
## units in data/military_units.json, shows their properties, and writes the
## file back. EDITOR ONLY: Menu hides its button outside the editor.
##
## The C# file also declares `public class MilitaryUnit`, the editor's own view
## of military_units.json; in the port that lives at CatalogDtos.MilitaryUnit
## (src/data/dto/catalog_dtos.gd) and is loaded by Loaders.military_units_editor().

signal BackToMainMenu

# UI Elements
var treeUnits: Tree
var detailsPanel: VBoxContainer
var btnBack: Button
var btnSave: Button
var filterInput: LineEdit
var lblStatus: Label

# Data storage
var militaryUnits: Array = []

# A REAL FILESYSTEM PATH, because everything below uses System.IO rather
# than Godot's FileAccess - and System.IO has never heard of "res://". It
# treated the whole string as a relative path, and the "../" on top of that
# pointed one level ABOVE the project root, so this only ever resolved by
# accident of the working directory.
#
# GlobalizePath turns res:// into the actual path on disk. It is also the
# line that survives an export: a packed build has no loose data/ folder, so
# the editor below is editor-only by nature - see Menu.cs, which now hides
# the button outside the editor rather than shipping one that cannot work.
#
# Port: FileAccess reads and writes the globalized path just as System.IO did;
# the load goes through Loaders (the same res://data/military_units.json).
var jsonFilePath: String = ProjectSettings.globalize_path("res://data/military_units.json")

# Unit properties
var spinBoxes: Dictionary = {}
var checkBoxes: Dictionary = {}
var lineEdits: Dictionary = {}
var optionButtons: Dictionary = {}
var lblSelectedUnitName: Label = null
var unitPreview: TextureRect = null


func _ready() -> void:
	# Initialize UI elements
	treeUnits = get_node("MarginContainer/VBoxContainer/HBoxContainer/TreeContainer/Tree")
	detailsPanel = get_node("MarginContainer/VBoxContainer/HBoxContainer/DetailsPanel")
	btnBack = get_node("MarginContainer/VBoxContainer/BottomBar/BackButton")
	btnSave = get_node("MarginContainer/VBoxContainer/BottomBar/SaveButton")
	filterInput = get_node("MarginContainer/VBoxContainer/TopBar/FilterInput")
	lblStatus = get_node("MarginContainer/VBoxContainer/BottomBar/StatusLabel")

	# Setup tree
	var root := treeUnits.create_item()
	treeUnits.set_column_title(0, "Military Units")
	treeUnits.set_column_expand(0, true)
	# treeUnits.set_column_custom_minimum_width(0, 200)

	# Connect signals
	btnBack.pressed.connect(OnBackPressed)
	btnSave.pressed.connect(OnSavePressed)
	filterInput.text_changed.connect(OnFilterChanged)
	treeUnits.item_selected.connect(OnItemSelected)

	# Load data
	LoadData()

	print("Tree node found:", treeUnits != null)
	print("Details panel found:", detailsPanel != null)
	print("Units loaded:", militaryUnits.size())


func LoadData() -> void:
	# Port: GDScript has no exceptions. A malformed file is reported by
	# JsonUtil.parse (push_error) and comes back as an empty list.
	if not FileAccess.file_exists(jsonFilePath):
		lblStatus.text = "Error: File %s not found!" % jsonFilePath
		return

	militaryUnits = Loaders.military_units_editor()

	UpdateTreeView()
	lblStatus.text = "Loaded %d military units" % militaryUnits.size()


func UpdateTreeView() -> void:
	treeUnits.clear()
	var root := treeUnits.create_item()
	root.set_text(0, "Military Units")

	var firstItem: TreeItem = null
	for unit in militaryUnits:
		var item := treeUnits.create_item(root)
		item.set_text(0, "%s (ID: %d)" % [unit.Name, unit.Id])
		item.set_metadata(0, unit.Id)
		if firstItem == null:
			firstItem = item

	# Select first item automatically
	if firstItem != null:
		# Select via the TreeItem API
		firstItem.select(0)


func OnItemSelected() -> void:
	var selectedItem := treeUnits.get_selected()
	if selectedItem != null:
		var unitId: int = int(selectedItem.get_metadata(0))
		var unit: CatalogDtos.MilitaryUnit = Lq.first_or_null(militaryUnits, func(u) -> bool: return u.Id == unitId)

		if unit != null:
			ShowUnitDetails(unit)


func ShowUnitDetails(unit: CatalogDtos.MilitaryUnit) -> void:
	# Clear previous controls
	for child in detailsPanel.get_children():
		if child != null and child != lblSelectedUnitName and child != unitPreview:
			detailsPanel.remove_child(child)
			child.queue_free()

	# Create/update header label
	if lblSelectedUnitName == null:
		lblSelectedUnitName = Label.new()
		lblSelectedUnitName.text = unit.Name
		detailsPanel.add_child(lblSelectedUnitName)
	else:
		lblSelectedUnitName.text = unit.Name

	# Create dynamic controls for unit properties
	spinBoxes.clear()
	checkBoxes.clear()
	lineEdits.clear()
	optionButtons.clear()

	# Basic properties
	CreatePropertyRow("Id", str(unit.Id), "id", TYPE_INT)
	CreatePropertyRow("FamilyId", str(unit.FamilyId), "familyId", TYPE_INT)
	CreatePropertyRow("StringId", str(unit.StringId), "stringId", TYPE_INT)
	CreatePropertyRow("Type", unit.Type, "type", TYPE_STRING)
	CreatePropertyRow("ConstructionCost", str(unit.ConstructionCost), "constructionCost", TYPE_INT)
	CreatePropertyRow("MaintenanceCost", str(unit.MaintenanceCost), "maintenanceCost", TYPE_INT)
	CreatePropertyRow("Detection", str(unit.Detection), "detection", TYPE_INT)

	# Boolean flags
	# One checkbox per playable faction, from the pack. Two fixed
	# checkboxes could not represent a 3-4 faction pack.
	for f in FactionRegistry.Playable:
		CreateCheckbox("%s can build" % f.DisplayName,
					   unit.BuildableBy != null and unit.BuildableBy.has(f.Id),
					   "buildableBy:%s" % f.Id)

	# Specialized properties based on type
	if unit.Type == "CapitalShip":
		CreatePropertyRow("Shield", _or0(unit.Shield), "shield", TYPE_INT)
		CreatePropertyRow("Sublight", _or0(unit.Sublight), "sublight", TYPE_INT)
		CreatePropertyRow("Hyperdrive", _or0(unit.Hyperdrive), "hyperdrive", TYPE_INT)
		CreatePropertyRow("Turbolaser", _or0(unit.Turbolaser), "turbolaser", TYPE_INT)
		CreatePropertyRow("IonCannon", _or0(unit.IonCannon), "ionCannon", TYPE_INT)
		CreatePropertyRow("LaserRating", _or0(unit.LaserRating), "laserRating", TYPE_INT)
		CreatePropertyRow("Hull", _or0(unit.Hull), "hull", TYPE_INT)
		CreatePropertyRow("Bombardment", _or0(unit.Bombardment), "bombardment", TYPE_INT)
		CreatePropertyRow("FighterCapacity", _or0(unit.FighterCapacity), "fighterCapacity", TYPE_INT)
		CreatePropertyRow("TroopCapacity", _or0(unit.TroopCapacity), "troopCapacity", TYPE_INT)
	elif unit.Type == "Fighter":
		CreatePropertyRow("Shield", _or0(unit.Shield), "shield", TYPE_INT)
		CreatePropertyRow("Sublight", _or0(unit.Sublight), "sublight", TYPE_INT)
		CreatePropertyRow("Hyperdrive", _or0(unit.Hyperdrive), "hyperdrive", TYPE_INT)
		CreatePropertyRow("IonCannon", _or0(unit.IonCannon), "ionCannon", TYPE_INT)
		CreatePropertyRow("LaserRating", _or0(unit.LaserRating), "laserRating", TYPE_INT)
		CreatePropertyRow("Torpedoes", _or0(unit.Torpedoes), "torpedoes", TYPE_INT)
		CreatePropertyRow("Bombardment", _or0(unit.Bombardment), "bombardment", TYPE_INT)
	elif unit.Type == "Troop":
		CreatePropertyRow("BombardmentDefense", _or0(unit.BombardmentDefense), "bombardmentDefense", TYPE_INT)
		CreatePropertyRow("Attack", _or0(unit.Attack), "attack", TYPE_INT)
		CreatePropertyRow("Defense", _or0(unit.Defense), "defense", TYPE_INT)
	elif unit.Type == "SpecForce":
		# SpecForce has minimal additional properties
		pass


## C# `unit.X?.ToString() ?? "0"`: a nullable stat as text, "0" when absent.
func _or0(v: Variant) -> String:
	return str(v) if v != null else "0"


func CreatePropertyRow(label: String, value: String, propertyKey: String, type: int) -> void:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var lbl := Label.new()
	lbl.text = label + ": "
	lbl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	hbox.add_child(lbl)

	var spinBox := SpinBox.new()
	spinBox.min_value = 0
	spinBox.step = 1
	spinBox.value = float(value) if type == TYPE_INT else 0
	spinBox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spinBox.name = propertyKey
	spinBox.value_changed.connect(func(val: float) -> void: OnPropertyChanged(propertyKey, val))
	spinBoxes[propertyKey] = spinBox
	hbox.add_child(spinBox)

	detailsPanel.add_child(hbox)


func CreateCheckbox(label: String, value: bool, propertyKey: String) -> void:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var lbl := Label.new()
	lbl.text = label + ": "
	lbl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	hbox.add_child(lbl)

	var chkBox := CheckBox.new()
	chkBox.button_pressed = value
	chkBox.name = propertyKey
	chkBox.toggled.connect(func(pressed: bool) -> void: OnPropertyChanged(propertyKey, pressed))
	checkBoxes[propertyKey] = chkBox
	hbox.add_child(chkBox)

	detailsPanel.add_child(hbox)


func OnPropertyChanged(propertyKey: String, value: Variant) -> void:
	# This method updates the in-memory data structure when properties change
	print("Property %s changed to %s" % [propertyKey, value])


func OnFilterChanged(text: String) -> void:
	# Filter units in the tree view
	pass


func OnSavePressed() -> void:
	# Port: GDScript has no exceptions; FileAccess.open reports failure as null.
	var jsonString := SerializeUnits()
	var file := FileAccess.open(jsonFilePath, FileAccess.WRITE)
	if file == null:
		var err := error_string(FileAccess.get_open_error())
		lblStatus.text = "Error saving data: %s" % err
		push_error("Failed to save data: %s" % err)
		return
	file.store_string(jsonString)
	file.close()
	lblStatus.text = "Data saved successfully!"


## What `JsonSerializer.Serialize(militaryUnits, options)` produced: one object
## per unit, every MilitaryUnit property in declaration order under its
## [JsonPropertyName] (which overrides the CamelCase policy, so the keys stay
## PascalCase), `int?` nulls written as null, WriteIndented (two spaces).
## The property walk is the reflection STJ did: the DTO's script variables.
func SerializeUnits() -> String:
	var list: Array = []
	for unit in militaryUnits:
		list.append(UnitToDict(unit))
	return JSON.stringify(list, "  ", false)


func UnitToDict(unit: CatalogDtos.MilitaryUnit) -> Dictionary:
	var d := {}
	for p in unit.get_property_list():
		if not (p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		d[p.name] = unit.get(p.name)
	return d


func OnBackPressed() -> void:
	BackToMainMenu.emit()
	# Port: the editor is opened with change_scene_to_file (Menu.cs), so nothing
	# subscribes to BackToMainMenu; the way back is the root menu scene.
	get_tree().change_scene_to_file("res://Menu.tscn")
