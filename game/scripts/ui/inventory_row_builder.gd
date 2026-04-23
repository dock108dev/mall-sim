## Builds item row UI nodes for the InventoryPanel item list.
class_name InventoryRowBuilder
extends RefCounted


## Creates a single item row PanelContainer with all display elements.
## When rental_controller is supplied and the item is a rental tape, a wear
## badge and tooltip are added.
static func build(
	item: ItemInstance,
	rental_controller: VideoRentalStoreController = null,
) -> PanelContainer:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 48)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)

	var rarity_key: String = _get_rarity(item)
	hbox.add_child(_build_rarity_stripe(rarity_key))
	hbox.add_child(_build_icon(item))
	hbox.add_child(_build_info_column(item, rarity_key, rental_controller))
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


static func _build_icon(item: ItemInstance) -> TextureRect:
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(32, 32)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	if not item.definition or item.definition.icon_path.is_empty():
		return icon
	var tex: Texture2D = load(item.definition.icon_path) as Texture2D
	if tex:
		icon.texture = tex
	return icon


static func _build_info_column(
	item: ItemInstance,
	rarity_key: String,
	rental_controller: VideoRentalStoreController = null,
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

	var wear_badge: Label = _build_wear_badge(item, rental_controller)
	if wear_badge != null:
		badge_row.add_child(wear_badge)

	vbox.add_child(badge_row)
	return vbox


static func _build_wear_badge(
	item: ItemInstance,
	rental_controller: VideoRentalStoreController,
) -> Label:
	if rental_controller == null or item == null or item.definition == null:
		return null
	if not rental_controller.is_rental_item(String(item.definition.category)):
		return null
	var wear_class: String = rental_controller.get_tape_wear_class(item)
	var wear_amount: float = rental_controller.get_tape_wear_amount(
		String(item.instance_id)
	)
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 11)
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	var display_text: String = ""
	var color: Color = Color(0.75, 0.75, 0.75, 1.0)
	match wear_class:
		"pristine":
			display_text = "Wear: Pristine"
			color = Color(0.3, 0.85, 0.4, 1.0)
		"light":
			display_text = "Wear: Light"
			color = Color(0.55, 0.85, 0.35, 1.0)
		"moderate":
			display_text = "Wear: Moderate"
			color = Color(0.9, 0.8, 0.2, 1.0)
		"heavy":
			display_text = "Wear: Heavy"
			color = Color(0.95, 0.55, 0.2, 1.0)
		"worn_out":
			display_text = "Wear: Worn Out"
			color = Color(0.9, 0.25, 0.25, 1.0)
	label.text = display_text
	label.add_theme_color_override("font_color", color)
	var tooltip_parts: PackedStringArray = [
		"Tape wear: %.0f%%" % (wear_amount * 100.0),
	]
	var reason: String = rental_controller.get_rentability_reason(item)
	if reason.is_empty():
		var appeal: float = rental_controller.get_tape_appeal_factor(item)
		tooltip_parts.append(
			"Customer appeal: %d%%" % int(round(appeal * 100.0))
		)
	else:
		tooltip_parts.append(reason)
	label.tooltip_text = "\n".join(tooltip_parts)
	return label


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
