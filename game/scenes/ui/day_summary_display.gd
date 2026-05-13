## Helper class for day summary display setup and styling.
## Extracted from DaySummary to keep main class under 1000 lines.
class_name DaySummaryDisplay


## Sets staff wages display if wages exceed 0.
static func set_staff_wages_display(
	staff_wages_label: Label, wages: float
) -> void:
	var has_wages: bool = wages > 0.0
	staff_wages_label.visible = has_wages
	if has_wages:
		staff_wages_label.text = "Staff Wages: -$%.2f" % wages


## Sets tier change display with new tier name.
static func set_tier_change_display(
	tier_change_label: Label, reputation_delta: float, new_tier_name: String
) -> void:
	tier_change_label.visible = true
	var delta_str: String = (
		"+%.1f" % reputation_delta
		if reputation_delta >= 0.0 else "%.1f" % reputation_delta
	)
	tier_change_label.text = "%s (Tier: %s)" % [delta_str, new_tier_name]
	tier_change_label.add_theme_color_override(
		"font_color", Color(1.0, 0.84, 0.0)
	)


## Sets haggle win/loss display.
static func set_haggle_display(
	haggle_label: Label, wins: int, losses: int
) -> void:
	var has_haggle: bool = wins > 0 or losses > 0
	haggle_label.visible = has_haggle
	if has_haggle:
		haggle_label.text = "Haggle: %d wins, %d losses" % [wins, losses]


## Applies color to profit label based on profit value.
static func apply_profit_color(
	profit_label: Label, net_profit: float
) -> void:
	if net_profit > 0.0:
		profit_label.add_theme_color_override(
			"font_color", DaySummaryContent.NET_PROFIT_POSITIVE_COLOR
		)
	elif net_profit < 0.0:
		profit_label.add_theme_color_override(
			"font_color", DaySummaryContent.NET_PROFIT_NEGATIVE_COLOR
		)
	else:
		profit_label.add_theme_color_override(
			"font_color", DaySummaryContent.NET_PROFIT_ZERO_COLOR
		)


## Hoists top-seller and forward-hook above detail dump for visibility.
static func apply_headline_order(
	revenue_label: Label, top_item_label: Label, forward_hook_label: Label
) -> void:
	var vbox: VBoxContainer = revenue_label.get_parent() as VBoxContainer
	if vbox == null:
		return
	var anchor_index: int = revenue_label.get_index() + 1
	if is_instance_valid(top_item_label):
		vbox.move_child(top_item_label, anchor_index)
		anchor_index += 1
	if is_instance_valid(forward_hook_label):
		vbox.move_child(forward_hook_label, anchor_index)


## De-emphasizes secondary action buttons vs. primary Continue CTA.
static func apply_secondary_button_style(
	review_inventory_button: Button, continue_button: Button
) -> void:
	const SECONDARY_MODULATE := Color(1.0, 1.0, 1.0, 0.65)
	review_inventory_button.custom_minimum_size = Vector2(160, 36)
	review_inventory_button.flat = true
	review_inventory_button.modulate = SECONDARY_MODULATE
	review_inventory_button.focus_mode = Control.FOCUS_NONE
	continue_button.custom_minimum_size = Vector2(240, 56)


## Sets archetype label and subtext display.
static func apply_archetype_display(
	archetype_separator: HSeparator, archetype_label: Label,
	archetype_subtext_label: Label, floor_awareness_row: Control,
	archetype: String, archetype_subtext: Dictionary,
	mark_fired_note: String
) -> void:
	var has_archetype: bool = not archetype.is_empty()
	archetype_separator.visible = has_archetype
	archetype_label.visible = has_archetype
	archetype_subtext_label.visible = has_archetype
	floor_awareness_row.visible = has_archetype
	if not has_archetype:
		return
	archetype_label.text = archetype
	var subtext: String = String(archetype_subtext.get(archetype, ""))
	if archetype == "The Mark":
		archetype_subtext_label.text = mark_fired_note + "\n\n" + subtext
	else:
		archetype_subtext_label.text = subtext


## Sets floor awareness star display.
static func apply_floor_stars_display(floor_stars_label: Label, stars: int) -> void:
	var clamped: int = clampi(stars, 1, 5)
	floor_stars_label.text = "★".repeat(clamped) + "☆".repeat(5 - clamped)


## Sets attention notes display.
static func apply_attention_notes_display(
	attention_separator: HSeparator, attention_notes_label: Label,
	notes: Array
) -> void:
	if notes.is_empty():
		attention_separator.visible = false
		attention_notes_label.visible = false
		return
	attention_separator.visible = true
	attention_notes_label.visible = true
	var lines: Array[String] = []
	for note in notes:
		lines.append(str(note))
	attention_notes_label.text = "\n".join(lines)

