class_name TransitConfirmWindow
extends DraggableWindow
## frontend/TransitConfirmWindow.cs - Confirmed Move "shows the transit time in
## days BEFORE you commit" (manual p110): Y issues the order, N drops it.

var _onConfirm: Callable = Callable()

## C# `internal List<Character> PersonelInTransit;` - null until Setup, and
## Refresh checks for that, so it stays a nullable Variant rather than [].
var PersonelInTransit: Variant = null


func Setup(characters: Array, days: int, onConfirm: Callable) -> void:
	_onConfirm = onConfirm
	PersonelInTransit = characters.duplicate()
	# Show Name if it's 1 person, or "X Personnel" if it's a group
	var nameDisplay: String = characters[0].Name if characters.size() == 1 else "%d Personnel" % characters.size()

	(get_node("%MessageLabel") as Label).text = "Transit time in days\n%s: %d" % [nameDisplay, days]

	(get_node("%ConfirmButton") as Button).pressed.connect(OnConfirmPressed)
	(get_node("%CancelButton") as Button).pressed.connect(OnCancelPressed)


func OnConfirmPressed() -> void:
	if _onConfirm.is_valid():
		_onConfirm.call()   # Execute the move!
	queue_free()            # Close the popup


func OnCancelPressed() -> void:
	queue_free()            # Close without moving


func Refresh() -> void:
	if PersonelInTransit == null:
		return
	# C# PersonelInTransit.RemoveAll(c => c.Status == Status.Enroute)
	for i in range(PersonelInTransit.size() - 1, -1, -1):
		if PersonelInTransit[i].Status == Enums.Status.Enroute:
			PersonelInTransit.remove_at(i)

	if PersonelInTransit.size() == 0:
		print("Transit aborted: All characters departed while awaiting confirmation!")
		queue_free()
		return
