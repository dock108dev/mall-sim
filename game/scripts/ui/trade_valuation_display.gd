## Displays the trade fairness summary derived from card values.
class_name TradeValuationDisplay
extends Label

const FAIR_TRADE_THRESHOLD: float = 0.20
const FAIR_TEXT: String = "Fair Trade"
const UNEVEN_TEXT: String = "Uneven Trade"


## Updates the fairness label from the wanted and offered values.
func show_trade_ratio(wanted_val: float, offered_val: float) -> void:
	if wanted_val <= 0.0:
		text = ""
		return
	var ratio: float = absf(wanted_val - offered_val) / wanted_val
	if ratio <= FAIR_TRADE_THRESHOLD:
		text = FAIR_TEXT
		add_theme_color_override(
			"font_color", UIThemeConstants.get_positive_color()
		)
		return
	text = UNEVEN_TEXT
	add_theme_color_override(
		"font_color", UIThemeConstants.get_warning_color()
	)
