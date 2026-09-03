class_name CharacterMenuButton
extends Button
## frontend/Buttons/CharacterMenuButton.cs - a personnel row that can be dragged
## onto a system or a fleet (manual p110).

var CharacterData: Character
var UIManagerRef: UIManager
var ParentWindow: DraggableWindow


func _get_drag_data(_at_position: Vector2) -> Variant:
	if CharacterData == null or CharacterData.Status == Enums.Status.Enroute:
		return null
	var source: Array = ParentWindow.SelectedCharacters if ParentWindow.SelectedCharacters.has(CharacterData) else [CharacterData]
	var dragGroup: Array = Lq.where(source, func(c: Character) -> bool: return c.Status != Enums.Status.Enroute)
	if dragGroup.is_empty():
		return null

	UIManagerRef.StartCharacterDrag(dragGroup)

	# Pop the window to the front so the native drag preview draws over other windows.
	if ParentWindow != null:
		ParentWindow.move_to_front()

	var previewVBox := VBoxContainer.new()
	for c in dragGroup:
		var previewLabel := Label.new()
		previewLabel.text = c.Name
		previewLabel.add_theme_color_override("font_color", c.Faction.FactionColor)
		previewLabel.add_theme_font_size_override("font_size", 16)
		previewVBox.add_child(previewLabel)

	set_drag_preview(previewVBox)
	return "character_move"
