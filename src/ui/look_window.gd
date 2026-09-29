extends RefCounted
## A PLAIN WINDOW IN THE PACK'S LOOK (docs/ww2-look-plan.md, phases 4-6): the
## template every scene window shares - a PanelContainer, a TitleBar (a
## ColorRect) holding TitleBarLabel, MinimizeButton and CloseButton, and a
## ContentArea with its Background - dressed as a steel-framed panel: a dark
## bar with a brass hairline under it, the title in the display face, the
## body in the chassis colour. Only the dress changes; drag, minimise, close
## and every control inside keep working as they did.
##
## For a pack with a look (Look.Active()) and a window in its plain form (not
## the original's, built from the player's art set). The theme goes on the
## window, so what is inside it wears the look's base controls.
##
## Preloaded by path (as LookWindow).

static func Dress(window: Control) -> void:
	if not Look.Active():
		return
	window.theme = Look.GetTheme()
	window.add_theme_stylebox_override("panel", Look.Box("chassis", "brass_dim", 1, 0, 0))

	var bar: ColorRect = window.get_node_or_null("%TitleBar")
	if bar != null:
		bar.color = Look.C("chassis_deep")
		if bar.get_node_or_null("LookRule") == null:
			var rule := ColorRect.new()
			rule.name = "LookRule"
			rule.color = Look.C("brass_dim")
			rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rule.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
			rule.offset_top = -1
			bar.add_child(rule)
		bar.custom_minimum_size.y = maxf(bar.custom_minimum_size.y, 26)
	var title: Label = window.get_node_or_null("%TitleBarLabel")
	if title != null:
		title.add_theme_font_override("font", Look.F("display"))
		title.add_theme_font_size_override("font_size", Look.Size("title"))
		title.add_theme_color_override("font_color", Look.C("text"))
		title.uppercase = true
	for n in ["%MinimizeButton", "%CloseButton"]:
		var b: Button = window.get_node_or_null(n)
		if b != null:
			b.theme_type_variation = Look.COMMAND
			b.remove_theme_font_size_override("font_size")
			b.add_theme_font_size_override("font_size", Look.Size("small"))
	var back: ColorRect = window.get_node_or_null("MainVBox/ContentArea/Background")
	if back != null:
		back.color = Look.C("chassis")
