## Helper class for day summary display setup and styling.
## Extracted from DaySummary to keep main class under 1000 lines.
class_name DaySummaryDisplay


## Sets warranty display labels based on revenue and claim costs.
static func set_warranty_display(
	warranty_revenue_label: Label, warranty_claims_label: Label,
	warranty_revenue: float, warranty_claims: float
) -> void:
	DaySummaryContent.set_warranty(
		warranty_revenue_label, warranty_claims_label,
		warranty_revenue, warranty_claims,
	)


## Sets seasonal event display if impact text is provided.
static func set_seasonal_display(
	seasonal_event_label: Label, seasonal_impact: String
) -> void:
	var has_seasonal: bool = not seasonal_impact.is_empty()
	seasonal_event_label.visible = has_seasonal
	if has_seasonal:
		var seasonal_fmt: String = TranslationServer.translate(
			"DAY_SUMMARY_SEASONAL"
		)
		seasonal_event_label.text = (
			seasonal_fmt % seasonal_impact
		)


## Sets staff wages display if wages exceed 0.
static func set_staff_wages_display(
	staff_wages_label: Label, wages: float
) -> void:
	var has_wages: bool = wages > 0.0
	staff_wages_label.visible = has_wages
	if has_wages:
		staff_wages_label.text = "Staff Wages: -$%.2f" % wages


## Sets late fee display if amount exceeds 0.
static func set_late_fee_display(
	late_fee_label: Label, amount: float
) -> void:
	var has_fees: bool = amount > 0.0
	late_fee_label.visible = has_fees
	if has_fees:
		late_fee_label.text = "Late Fees Collected: +$%.2f" % amount


## Updates overdue count label visibility and text.
static func set_overdue_count_display(
	overdue_count_label: Label, count: int
) -> void:
	if not is_instance_valid(overdue_count_label):
		return
	var has_overdue: bool = count > 0
	overdue_count_label.visible = has_overdue
	if has_overdue:
		overdue_count_label.text = "Overdue Items: %d" % count


## Sets warranty attachment and demo status display.
static func set_warranty_attach_display(
	warranty_attach_label: Label, demo_status_label: Label,
	attach_rate: float, demo_active: bool, demo_contribution_revenue: float
) -> void:
	var has_attach_rate: bool = attach_rate > 0.0
	warranty_attach_label.visible = has_attach_rate
	if has_attach_rate:
		warranty_attach_label.text = (
			"Warranty Attach Rate: %.1f%%" % (attach_rate * 100.0)
		)
	var has_demo: bool = demo_active or demo_contribution_revenue > 0.0
	demo_status_label.visible = has_demo
	if has_demo:
		demo_status_label.text = (
			"Electronics Demo Revenue: $%.2f" % demo_contribution_revenue
		)


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

