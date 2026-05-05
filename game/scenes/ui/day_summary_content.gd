## Static content-population helpers for DaySummary. Pulled out so the
## per-headline / per-row formatting (revenue delta, net profit colors,
## warranty attach, ACC grading) lives next to its kin and the overlay file
## stays focused on lifecycle / animation / signal wiring. Each helper takes
## the live label nodes and the data values; nothing here holds state.
class_name DaySummaryContent
extends Object

const NET_PROFIT_POSITIVE_COLOR := Color(0.2, 0.8, 0.2)
const NET_PROFIT_NEGATIVE_COLOR := Color(0.9, 0.2, 0.2)
const NET_PROFIT_ZERO_COLOR := Color(1.0, 1.0, 1.0)
const REVENUE_DELTA_POSITIVE_COLOR := Color(0.35, 0.85, 0.35)
const REVENUE_DELTA_NEGATIVE_COLOR := Color(0.9, 0.45, 0.45)


static func apply_revenue_headline(
	revenue_label: Label,
	revenue: float,
	previous_day_revenue: float,
	has_previous_day_revenue: bool,
) -> void:
	var base: String = TranslationServer.translate("DAY_SUMMARY_REVENUE") % revenue
	if not has_previous_day_revenue:
		revenue_label.text = base
		revenue_label.remove_theme_color_override("font_color")
		return
	var delta: float = revenue - previous_day_revenue
	var delta_text: String
	var delta_color: Color
	if delta > 0.0:
		delta_text = "  (+$%.2f vs yesterday)" % delta
		delta_color = REVENUE_DELTA_POSITIVE_COLOR
	elif delta < 0.0:
		delta_text = "  (-$%.2f vs yesterday)" % absf(delta)
		delta_color = REVENUE_DELTA_NEGATIVE_COLOR
	else:
		delta_text = "  (flat vs yesterday)"
		delta_color = NET_PROFIT_ZERO_COLOR
	revenue_label.text = base + delta_text
	revenue_label.add_theme_color_override("font_color", delta_color)


static func set_net_profit(
	profit_label: Label, net_profit: float
) -> void:
	if net_profit > 0.0:
		profit_label.text = "NET PROFIT: +$%.2f" % net_profit
		profit_label.add_theme_color_override(
			"font_color", UIThemeConstants.get_positive_color()
		)
	elif net_profit < 0.0:
		profit_label.text = "NET LOSS: -$%.2f" % absf(net_profit)
		profit_label.add_theme_color_override(
			"font_color", NET_PROFIT_NEGATIVE_COLOR
		)
	else:
		profit_label.text = "NET PROFIT: $0.00"
		profit_label.add_theme_color_override(
			"font_color", NET_PROFIT_ZERO_COLOR
		)


static func set_warranty_attach(
	attach_label: Label,
	demo_status_label: Label,
	attach_rate: float,
	demo_active: bool,
	demo_contribution_revenue: float,
) -> void:
	var has_attach: bool = attach_rate > 0.0
	attach_label.visible = has_attach
	if has_attach:
		attach_label.text = (
			"Warranty Attach Rate: %.0f%%" % (attach_rate * 100.0)
		)
	demo_status_label.visible = true
	if demo_active:
		if demo_contribution_revenue > 0.0:
			demo_status_label.text = (
				"Demo Unit: Active — Contribution: +$%.2f"
				% demo_contribution_revenue
			)
		else:
			demo_status_label.text = "Demo Unit: Active"
		demo_status_label.add_theme_color_override(
			"font_color", UIThemeConstants.get_positive_color()
		)
	else:
		demo_status_label.text = "Demo Unit: Inactive"
		demo_status_label.remove_theme_color_override("font_color")


static func set_grading(
	grading_label: Label, pending_count: int, returned: Array
) -> void:
	if grading_label == null:
		return
	var lines: Array[String] = []
	for entry: Variant in returned:
		if entry is Dictionary:
			var d: Dictionary = entry as Dictionary
			lines.append(
				"ACC Grade: %s — %d (%s)"
				% [
					str(d.get("card_name", d.get("card_id", "?"))),
					int(d.get("grade", 0)),
					str(d.get("grade_label", "")),
				]
			)
	if pending_count > 0:
		lines.append(
			"%d card%s pending ACC grading" % [
				pending_count,
				"s" if pending_count != 1 else "",
			]
		)
	if lines.is_empty():
		grading_label.visible = false
		return
	grading_label.text = "\n".join(lines)
	grading_label.visible = true


static func set_discrepancy(
	discrepancy_label: Label, discrepancy: float
) -> void:
	if discrepancy_label == null:
		return
	var has_discrepancy: bool = absf(discrepancy) > 0.001
	discrepancy_label.visible = has_discrepancy
	if has_discrepancy:
		var sign_str: String = "+" if discrepancy > 0.0 else ""
		discrepancy_label.text = (
			TranslationServer.translate("DAY_SUMMARY_UNACCOUNTED")
			% [sign_str, discrepancy]
		)
		discrepancy_label.add_theme_color_override(
			"font_color", Color(0.9, 0.7, 0.3)
		)


static func set_warranty(
	revenue_label: Label,
	claims_label: Label,
	warranty_revenue: float,
	warranty_claims: float,
) -> void:
	var has_warranty_data: bool = (
		warranty_revenue > 0.0 or warranty_claims > 0.0
	)
	revenue_label.visible = has_warranty_data
	claims_label.visible = has_warranty_data
	if has_warranty_data:
		revenue_label.text = (
			TranslationServer.translate("DAY_SUMMARY_WARRANTY_REV")
			% warranty_revenue
		)
		claims_label.text = (
			TranslationServer.translate("DAY_SUMMARY_WARRANTY_CLAIMS")
			% warranty_claims
		)
