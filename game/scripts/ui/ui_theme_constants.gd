## Rarity color constants, colorblind-safe palettes, and icon helpers.
class_name UIThemeConstants
extends RefCounted


const RARITY_COLORS: Dictionary = {
	"common": Color(1.0, 1.0, 1.0, 1.0),
	"uncommon": Color(0.3, 0.69, 0.31, 1.0),
	"rare": Color(0.29, 0.62, 1.0, 1.0),
	"very_rare": Color(0.69, 0.36, 0.9, 1.0),
	"legendary": Color(1.0, 0.84, 0.0, 1.0),
}

## Deuteranopia-friendly palette (blue-orange instead of green-red).
const RARITY_COLORS_CB: Dictionary = {
	"common": Color(1.0, 1.0, 1.0, 1.0),
	"uncommon": Color(0.35, 0.7, 0.9, 1.0),
	"rare": Color(0.0, 0.45, 0.7, 1.0),
	"very_rare": Color(0.8, 0.47, 0.65, 1.0),
	"legendary": Color(0.9, 0.6, 0.0, 1.0),
}

## Unicode shape indicators per rarity tier (grayscale-distinguishable).
const RARITY_SHAPES: Dictionary = {
	"common": "\u25CF",
	"uncommon": "\u25C6",
	"rare": "\u2605",
	"very_rare": "\u2605\u2605",
	"legendary": "\u265B",
}

## Human-readable rarity tier labels.
const RARITY_LABELS: Dictionary = {
	"common": "Common",
	"uncommon": "Uncommon",
	"rare": "Rare",
	"very_rare": "Very Rare",
	"legendary": "Legendary",
}

const CURRENCY_SYMBOL: String = "$"

const BODY_FONT_COLOR := Color(0.96, 0.9, 0.82, 1.0)
const HEADER_FONT_COLOR := Color(0.9, 0.75, 0.45, 1.0)
const ACCENT_COLOR := Color(0.83, 0.63, 0.33, 1.0)
const POSITIVE_COLOR := Color(0.4, 0.8, 0.35, 1.0)
const NEGATIVE_COLOR := Color(0.9, 0.3, 0.25, 1.0)
const WARNING_COLOR := Color(0.95, 0.75, 0.2, 1.0)

## Deuteranopia-friendly status colors (blue-orange scheme).
const POSITIVE_COLOR_CB := Color(0.35, 0.7, 0.9, 1.0)
const NEGATIVE_COLOR_CB := Color(0.9, 0.6, 0.0, 1.0)
const WARNING_COLOR_CB := Color(0.8, 0.47, 0.65, 1.0)

## Markup label thresholds: ratio <= threshold yields that label.
const MARKUP_LABEL_FAIR_MAX: float = 1.5
const MARKUP_LABEL_HIGH_MAX: float = 2.0


## Returns the color for a given rarity string, or white if unknown.
static func get_rarity_color(rarity: String) -> Color:
	if Settings.colorblind_mode:
		return RARITY_COLORS_CB.get(rarity, Color.WHITE)
	return RARITY_COLORS.get(rarity, Color.WHITE)


## Returns the Unicode shape icon for a rarity tier.
static func get_rarity_shape(rarity: String) -> String:
	return RARITY_SHAPES.get(rarity, "\u25CF")


## Returns the human-readable label for a rarity tier.
static func get_rarity_label(rarity: String) -> String:
	return RARITY_LABELS.get(rarity, rarity.capitalize())


## Returns rarity text with shape prefix: e.g. "★ Rare".
static func get_rarity_display(rarity: String) -> String:
	return "%s %s" % [get_rarity_shape(rarity), get_rarity_label(rarity)]


## Returns the positive status color respecting colorblind mode.
static func get_positive_color() -> Color:
	if Settings.colorblind_mode:
		return POSITIVE_COLOR_CB
	return POSITIVE_COLOR


## Returns the negative status color respecting colorblind mode.
static func get_negative_color() -> Color:
	if Settings.colorblind_mode:
		return NEGATIVE_COLOR_CB
	return NEGATIVE_COLOR


## Returns the warning status color respecting colorblind mode.
static func get_warning_color() -> Color:
	if Settings.colorblind_mode:
		return WARNING_COLOR_CB
	return WARNING_COLOR


## Returns a markup text label based on price-to-market ratio.
static func get_markup_label(ratio: float) -> String:
	if ratio <= MARKUP_LABEL_FAIR_MAX:
		return "Fair"
	if ratio <= MARKUP_LABEL_HIGH_MAX:
		return "High"
	return "Very High"


## Returns the color for a markup ratio respecting colorblind mode.
static func get_markup_color(ratio: float) -> Color:
	if ratio <= MARKUP_LABEL_FAIR_MAX:
		return get_positive_color()
	if ratio <= MARKUP_LABEL_HIGH_MAX:
		return get_warning_color()
	return get_negative_color()
