class_name UnitMenuButton
extends Button
## frontend/Buttons/UnitMenuButton.cs - a unit row that can be dragged onto a
## fleet or a system.

var UnitData: Unit
var UIManagerRef: UIManager
var ParentWindow: DraggableWindow   # C#: DefenseWindow
var SelectionGroup: Array = []


func _get_drag_data(_at_position: Vector2) -> Variant:
	if UnitData == null or UnitData.Status == Enums.Status.Enroute:
		return null

	var source: Array = SelectionGroup if SelectionGroup.has(UnitData) else [UnitData]
	var dragGroup: Array = Lq.where(source, func(u: Unit) -> bool: return u.Status != Enums.Status.Enroute)
	if dragGroup.is_empty():
		return null

	UIManagerRef.StartUnitDrag(dragGroup)
	if ParentWindow != null:
		ParentWindow.move_to_front()

	var previewVBox := VBoxContainer.new()
	for u in dragGroup:
		var previewLabel := Label.new()
		previewLabel.text = u.Name
		previewLabel.add_theme_color_override("font_color", u.Faction.FactionColor if u.Faction != null else Color.WHITE)
		previewLabel.add_theme_font_size_override("font_size", 16)
		previewVBox.add_child(previewLabel)
	set_drag_preview(previewVBox)
	return "unit_move"
