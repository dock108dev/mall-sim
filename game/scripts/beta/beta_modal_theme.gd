## Shared StyleBox factory for beta modals (decision card, day summary, etc.)
## so they read as the same family — dark translucent paper with warm
## brown/gold borders and cream text. Centralised here so a one-line palette
## tweak propagates to every beta modal without per-panel edits.
class_name BetaModalTheme
extends RefCounted

const COLOR_PANEL_BG: Color = Color(0.094, 0.078, 0.067, 0.94)
const COLOR_PANEL_BORDER: Color = Color(0.534, 0.420, 0.260, 1.0)
const COLOR_BLOCKER: Color = Color(0.024, 0.020, 0.016, 0.74)
const COLOR_TEXT_PRIMARY: Color = Color(0.957, 0.914, 0.831, 1.0)
const COLOR_TEXT_HEADER: Color = Color(0.910, 0.647, 0.278, 1.0)
const COLOR_TEXT_MUTED: Color = Color(0.722, 0.660, 0.549, 1.0)
const COLOR_BUTTON_BG: Color = Color(0.157, 0.118, 0.086, 1.0)
const COLOR_BUTTON_HOVER: Color = Color(0.235, 0.180, 0.118, 1.0)
const COLOR_BUTTON_BORDER: Color = Color(0.534, 0.420, 0.260, 1.0)
const COLOR_BUTTON_BORDER_FOCUS: Color = Color(0.910, 0.647, 0.278, 1.0)
## Soft green for "completed step" treatments (objective rail checkmark
## prefix, today checklist row glyph). Distinct from the warm gold used for
## active text so the player parses "done" vs "do this now" at a glance.
const COLOR_ACCENT: Color = Color(0.4, 0.85, 0.55, 1.0)


## StyleBox for the main modal panel (rounded brown frame on warm-dark fill).
static func make_panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_PANEL_BG
	sb.border_color = COLOR_PANEL_BORDER
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_right = 6
	sb.corner_radius_bottom_left = 6
	sb.content_margin_left = 24.0
	sb.content_margin_top = 20.0
	sb.content_margin_right = 24.0
	sb.content_margin_bottom = 20.0
	return sb


## StyleBox for choice / continue buttons in the modal — matches the panel
## frame so the buttons read as cards on the same paper.
static func make_button_style(state: String = "normal") -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_BUTTON_HOVER if state == "hover" else COLOR_BUTTON_BG
	sb.border_color = (
		COLOR_BUTTON_BORDER_FOCUS if state == "focus" else COLOR_BUTTON_BORDER
	)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_right = 4
	sb.corner_radius_bottom_left = 4
	sb.content_margin_left = 14.0
	sb.content_margin_top = 8.0
	sb.content_margin_right = 14.0
	sb.content_margin_bottom = 8.0
	return sb


## Applies the warm modal palette to a button. Idempotent — calling twice
## does no harm; the second call simply re-overrides the same theme keys.
static func apply_button_theme(button: Button) -> void:
	button.add_theme_stylebox_override("normal", make_button_style("normal"))
	button.add_theme_stylebox_override("hover", make_button_style("hover"))
	button.add_theme_stylebox_override("pressed", make_button_style("hover"))
	button.add_theme_stylebox_override("focus", make_button_style("focus"))
	button.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	button.add_theme_color_override("font_hover_color", COLOR_TEXT_HEADER)
	button.add_theme_color_override("font_pressed_color", COLOR_TEXT_HEADER)
	button.add_theme_color_override("font_focus_color", COLOR_TEXT_PRIMARY)
