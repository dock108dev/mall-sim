## Builds item row UI nodes for the InventoryPanel item list.
class_name InventoryRowBuilder
extends RefCounted


## Creates a single item row PanelContainer with all display elements.
## When rental_controller is supplied and the item is a rental tape, a wear
## badge and tooltip are added. `quantities` maps definition_id -> {
## "backroom": int, "on_shelf": int } and is rendered into the per-row
## quantity column. Missing entries default to zero.
static func build(
	item: ItemInstance,
	rental_controller: VideoRentalStoreController = null,
	quantities: Dictionary = {},
) -> PanelContainer:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 48)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)

	var rarity_key: String = _get_rarity(item)
	hbox.add_child(_build_rarity_stripe(rarity_key))
	hbox.add_child(_build_icon(item))
	hbox.add_child(_build_info_column(item, rarity_key, rental_controller))
	hbox.add_child(_build_quantity_column(item, quantities))
	hbox.add_child(_build_price_column(item))
	# Reserved width on the right edge so the floating action buttons (added
	# by `add_stock_buttons` / `add_remove_button`) sit cleanly without
	# clipping the price/qty columns.
	hbox.add_child(_build_action_spacer())
	row.add_child(hbox)
	return row


## Adds an invisible overlay button for click/hover detection across the row.
## Returns the button so optional child controls (e.g. the Select button) can
## be parented under it and stay on top of the input stack.
static func add_overlay_button(
	row: PanelContainer,
	on_pressed: Callable,
	on_mouse_entered: Callable,
	on_mouse_exited: Callable,
) -> Button:
	var btn := Button.new()
	btn.flat = true
	btn.anchors_preset = Control.PRESET_FULL_RECT
	btn.pressed.connect(on_pressed)
	btn.mouse_entered.connect(on_mouse_entered)
	btn.mouse_exited.connect(on_mouse_exited)
	row.add_child(btn)
	return btn


## Adds stacked "Stock 1" and "Stock Max" buttons anchored to the right edge
## of the row. Parented under `overlay_button` so they sit above the full-rect
## overlay in input order — clicks on either button fire only their own
## handler, while clicks elsewhere on the row still reach the overlay.
static func add_stock_buttons(
	overlay_button: Button,
	on_stock_one: Callable,
	on_stock_max: Callable,
) -> void:
	var stock_one := _build_action_button("Stock 1", on_stock_one)
	stock_one.offset_top = -23.0
	stock_one.offset_bottom = -1.0
	overlay_button.add_child(stock_one)

	var stock_max := _build_action_button("Stock Max", on_stock_max)
	stock_max.offset_top = 1.0
	stock_max.offset_bottom = 23.0
	overlay_button.add_child(stock_max)


## Adds a single "Remove" Button anchored to the right edge of the row for
## shelf items. Mirrors `add_stock_buttons` parenting so the click does not
## bubble to the overlay context-menu handler.
static func add_remove_button(
	overlay_button: Button,
	on_pressed: Callable,
) -> void:
	var btn := _build_action_button("Remove", on_pressed)
	btn.offset_top = -16.0
	btn.offset_bottom = 16.0
	overlay_button.add_child(btn)


static func _build_action_button(
	label: String, on_pressed: Callable
) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(82, 22)
	btn.add_theme_font_size_override("font_size", 11)
	btn.set_anchor(SIDE_LEFT, 1.0)
	btn.set_anchor(SIDE_TOP, 0.5)
	btn.set_anchor(SIDE_RIGHT, 1.0)
	btn.set_anchor(SIDE_BOTTOM, 0.5)
	btn.offset_left = -90.0
	btn.offset_right = -8.0
	btn.pressed.connect(on_pressed)
	return btn


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


static func _build_quantity_column(
	item: ItemInstance,
	quantities: Dictionary,
) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	vbox.custom_minimum_size = Vector2(70, 0)

	var def_id: String = ""
	if item.definition:
		def_id = item.definition.id
	var entry: Dictionary = {}
	if not def_id.is_empty() and quantities.has(def_id):
		entry = quantities[def_id]
	var backroom_qty: int = int(entry.get("backroom", 0))
	var shelf_qty: int = int(entry.get("on_shelf", 0))

	var backroom_label := Label.new()
	backroom_label.name = "BackroomQtyLabel"
	backroom_label.text = "Backroom: %d" % backroom_qty
	backroom_label.add_theme_font_size_override("font_size", 11)
	backroom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(backroom_label)

	var shelf_label := Label.new()
	shelf_label.name = "ShelfQtyLabel"
	shelf_label.text = "Shelf: %d" % shelf_qty
	shelf_label.add_theme_font_size_override("font_size", 11)
	shelf_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if shelf_qty > 0:
		shelf_label.add_theme_color_override(
			"font_color", UIThemeConstants.get_positive_color()
		)
	vbox.add_child(shelf_label)
	return vbox


## Reserves width at the right edge for the floating action buttons (Stock 1 /
## Stock Max / Remove). The buttons themselves parent under the overlay (not
## the HBox), so this spacer keeps the price/qty columns from being painted
## over.
static func _build_action_spacer() -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(94, 0)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


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
	loc_label.name = "LocationLabel"
	loc_label.add_theme_font_size_override("font_size", 11)
	loc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if item.current_location == "backroom":
		loc_label.text = "Backroom"
	elif item.current_location.begins_with("shelf:"):
		loc_label.text = "Shelf: %s" % item.current_location.substr(6)
		loc_label.add_theme_color_override(
			"font_color", UIThemeConstants.get_positive_color()
		)
	else:
		loc_label.text = item.current_location.capitalize()
	vbox.add_child(loc_label)

	return vbox
