## Static content-population helpers for DaySummary. Pulled out so the
## per-headline / per-row formatting (revenue delta, net profit colors,
## discrepancy banner) lives next to its kin and the overlay file stays
## focused on lifecycle / animation / signal wiring. Each helper takes the
## live label nodes and the data values; nothing here holds state.
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
