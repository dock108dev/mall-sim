## Static helpers for the DaySummary metric-bar block — bar styling, color
## buckets, and qualitative-tier labels. Pulled out so the overlay file can
## stay focused on the day-summary stat-row presentation. The `apply_*`
## helpers take the live node references as arguments so callers don't need
## to wire a stateful helper just to update a single bar.
class_name DaySummaryMetrics
extends Object

const BAR_COLOR_LOW: Color = Color(0.85, 0.30, 0.30)
const BAR_COLOR_MID: Color = Color(0.95, 0.75, 0.30)
const BAR_COLOR_HIGH: Color = Color(0.35, 0.80, 0.40)
const BAR_BG_COLOR: Color = Color(0.18, 0.16, 0.20)


## Builds a flat StyleBoxFlat for the bar fill in the value-coded color,
## plus a neutral background. Replacing fill / background each call avoids
## leaking previous-day color overrides into the current frame.
static func apply_bar_style(bar: ProgressBar, value: float) -> void:
	if bar == null:
		return
	var fill := StyleBoxFlat.new()
	fill.bg_color = color_for_value(value)
	fill.corner_radius_top_left = 4
	fill.corner_radius_top_right = 4
	fill.corner_radius_bottom_left = 4
	fill.corner_radius_bottom_right = 4
	bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = BAR_BG_COLOR
	bg.corner_radius_top_left = 4
	bg.corner_radius_top_right = 4
	bg.corner_radius_bottom_left = 4
	bg.corner_radius_bottom_right = 4
	bar.add_theme_stylebox_override("background", bg)


static func color_for_value(value: float) -> Color:
	var v: float = clampf(value, 0.0, 1.0)
	if v < 0.34:
		return BAR_COLOR_LOW
	if v < 0.67:
		return BAR_COLOR_MID
	return BAR_COLOR_HIGH


static func qualitative_label(value: float) -> String:
	var v: float = clampf(value, 0.0, 1.0)
	if v < 0.20:
		return "Poor"
	if v < 0.40:
		return "Strained"
	if v < 0.60:
		return "Neutral"
	if v < 0.80:
		return "Steady"
	return "Strong"


static func set_metric_bar(
	label: Label, bar: ProgressBar, prefix: String, value: float
) -> void:
	if not is_instance_valid(label) or not is_instance_valid(bar):
		return
	var clamped: float = clampf(value, 0.0, 1.0)
	bar.value = clamped
	apply_bar_style(bar, clamped)
	label.text = "%s — %s" % [prefix, qualitative_label(clamped)]
