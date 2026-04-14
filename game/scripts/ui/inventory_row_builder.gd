## Builds item row UI nodes for the InventoryPanel item list.
class_name InventoryRowBuilder
extends RefCounted


## Creates a single item row PanelContainer with all display elements.
static func build(item: ItemInstance) -> PanelContainer:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 48)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)

	var rarity_key: String = _get_rarity(item)
	hbox.add_child(_build_rarity_stripe(rarity_key))
	hbox.add_child(_build_info_column(item, rarity_key))
	hbox.add_child(_build_price_column(item))
	row.add_child(hbox)
	return row


## Adds an invisible overlay button for click/hover detection.
static func add_overlay_button(
	row: PanelContainer,
	on_pressed: Callable,
	on_mouse_entered: Callable,
	on_mouse_exited: Callable,
) -> void:
	var btn := Button.new()
	btn.flat = true
	btn.anchors_preset = Control.PRESET_FULL_RECT
	btn.pressed.connect(on_pressed)
	btn.mouse_entered.connect(on_mouse_entered)
	btn.mouse_exited.connect(on_mouse_exited)
	row.add_child(btn)


static func _get_rarity(item: ItemInstance) -> String:
	if item.definition:
		return item.definition.rarity
	return ""


static func _build_rarity_stripe(rarity_key: String) -> ColorRect:
	var rect := ColorRect.new()
	rect.custom_minimum_size = Vector2(6, 0)
	rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rect.color = UIThemeConstants.get_rarity_color(rarity_key)
	return rect


static func _build_info_column(
	item: ItemInstance, rarity_key: String
) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 0)

	var name_label := Label.new()
	name_label.text = item.definition.item_name if item.definition else "???"
	name_label.clip_text = true
	vbox.add_child(name_label)

	var badge_row := HBoxContainer.new()
	badge_row.add_theme_constant_override("separation", 8)

	var cond_label := Label.new()
	cond_label.text = item.condition.capitalize()
	cond_label.add_theme_font_size_override("font_size", 11)
	badge_row.add_child(cond_label)

	var rarity_label := Label.new()
	var shape: String = UIThemeConstants.get_rarity_shape(rarity_key)
	rarity_label.text = "%s %s" % [
		shape, UIThemeConstants.get_rarity_label(rarity_key),
	]
	rarity_label.add_theme_font_size_override("font_size", 11)
	rarity_label.add_theme_color_override(
		"font_color", UIThemeConstants.get_rarity_color(rarity_key)
	)
	badge_row.add_child(rarity_label)

	if item.authentication_status == "authenticated":
		var auth_label := Label.new()
		auth_label.text = "[Authenticated]"
		auth_label.add_theme_font_size_override("font_size", 11)
		auth_label.add_theme_color_override(
			"font_color", Color(0.2, 0.8, 0.4, 1.0)
		)
		badge_row.add_child(auth_label)

	badge_row.add_child(_build_test_badge(item))

	vbox.add_child(badge_row)
	return vbox


static func _build_test_badge(item: ItemInstance) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 11)
	if not item.definition:
		return label
	var is_testable: bool = (
		item.definition.store_type == "retro_games"
		and item.definition.category in TestingSystem.TESTABLE_CATEGORIES
	)
	if not is_testable:
		return label
	if not item.tested:
		label.text = "[Untested]"
		label.add_theme_color_override(
			"font_color", Color(0.9, 0.7, 0.2, 1.0)
		)
	elif item.test_result == "tested_working":
		label.text = "[Working]"
		label.add_theme_color_override(
			"font_color", Color(0.2, 0.8, 0.4, 1.0)
		)
	elif item.test_result == "tested_not_working":
		label.text = "[Not Working]"
		label.add_theme_color_override(
			"font_color", Color(0.9, 0.3, 0.3, 1.0)
		)
	return label


static func _build_price_column(item: ItemInstance) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)

	var price_label := Label.new()
	var price: float = (
		item.player_set_price if item.player_set_price > 0.0
		else item.get_current_value()
	)
	price_label.text = "$%.2f" % price
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(price_label)

	var loc_label := Label.new()
	loc_label.add_theme_font_size_override("font_size", 11)
	loc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if item.current_location == "backroom":
		loc_label.text = "Backroom"
	elif item.current_location.begins_with("shelf:"):
		loc_label.text = "Shelf"
		loc_label.add_theme_color_override(
			"font_color", UIThemeConstants.get_positive_color()
		)
	else:
		loc_label.text = item.current_location.capitalize()
	vbox.add_child(loc_label)

	return vbox
