## Builds UI rows for the order panel catalog and cart displays.
class_name OrderRowBuilder
extends RefCounted


static func build_catalog_row(
	item_def: ItemDefinition,
	cost: float,
	add_callback: Callable,
) -> PanelContainer:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(0, 44)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)

	var rarity_bar := ColorRect.new()
	rarity_bar.custom_minimum_size = Vector2(5, 0)
	rarity_bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rarity_bar.color = UIThemeConstants.get_rarity_color(
		item_def.rarity
	)
	hbox.add_child(rarity_bar)

	var name_label := Label.new()
	name_label.text = item_def.name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	hbox.add_child(name_label)

	var rarity_label := Label.new()
	rarity_label.text = UIThemeConstants.get_rarity_display(
		item_def.rarity
	)
	rarity_label.custom_minimum_size = Vector2(90, 0)
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_label.add_theme_color_override(
		"font_color",
		UIThemeConstants.get_rarity_color(item_def.rarity),
	)
	hbox.add_child(rarity_label)

	var condition_label := Label.new()
	condition_label.text = _format_condition_range(item_def)
	condition_label.custom_minimum_size = Vector2(100, 0)
	condition_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hbox.add_child(condition_label)

	var price_label := Label.new()
	price_label.text = "$%.2f" % cost
	price_label.custom_minimum_size = Vector2(70, 0)
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(price_label)

	var add_btn := Button.new()
	add_btn.text = "Add"
	add_btn.custom_minimum_size = Vector2(60, 0)
	add_btn.pressed.connect(add_callback)
	hbox.add_child(add_btn)

	cell.add_child(hbox)
	return cell


static func build_cart_row(
	item_def: ItemDefinition,
	qty: int,
	line_total: float,
	minus_callback: Callable,
	plus_callback: Callable,
	remove_callback: Callable,
) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)

	var name_label := Label.new()
	name_label.text = item_def.name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	hbox.add_child(name_label)

	var minus_btn := Button.new()
	minus_btn.text = "-"
	minus_btn.custom_minimum_size = Vector2(30, 0)
	minus_btn.pressed.connect(minus_callback)
	hbox.add_child(minus_btn)

	var qty_label := Label.new()
	qty_label.text = str(qty)
	qty_label.custom_minimum_size = Vector2(30, 0)
	qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hbox.add_child(qty_label)

	var plus_btn := Button.new()
	plus_btn.text = "+"
	plus_btn.custom_minimum_size = Vector2(30, 0)
	plus_btn.pressed.connect(plus_callback)
	hbox.add_child(plus_btn)

	var cost_label := Label.new()
	cost_label.text = "$%.2f" % line_total
	cost_label.custom_minimum_size = Vector2(70, 0)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(cost_label)

	var remove_btn := Button.new()
	remove_btn.text = "X"
	remove_btn.custom_minimum_size = Vector2(30, 0)
	remove_btn.pressed.connect(remove_callback)
	hbox.add_child(remove_btn)

	return hbox


static func build_delivery_row(
	count: int,
	supplier_name: String,
	delivery_day: int,
) -> Label:
	var label := Label.new()
	label.text = "%d item(s) via %s — arrives day %d" % [
		count, supplier_name, delivery_day,
	]
	return label


static func _format_condition_range(
	item_def: ItemDefinition,
) -> String:
	if item_def.condition_range.is_empty():
		return "N/A"
	if item_def.condition_range.size() == 1:
		return item_def.condition_range[0].capitalize()
	var first: String = item_def.condition_range[0].capitalize()
	var last: String = item_def.condition_range[
		item_def.condition_range.size() - 1
	].capitalize()
	return "%s-%s" % [first, last]
