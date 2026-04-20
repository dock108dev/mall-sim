## Palette constants, colorblind-safe overrides, and icon helpers.
## All cross-system color reads go through the helper functions, not the raw constants.
class_name UIThemeConstants
extends RefCounted

# ---------------------------------------------------------------------------
# Rarity palette
# ---------------------------------------------------------------------------

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

# ---------------------------------------------------------------------------
# Dark panel tier — HUD, inventory strip, ticker (#1F1A16 fill / #F4E9D4 text)
# Contrast: 15.1:1 (WCAG AAA)
# ---------------------------------------------------------------------------
const DARK_PANEL_FILL := Color(0.122, 0.102, 0.086, 0.96)
const DARK_PANEL_BORDER := Color(0.239, 0.188, 0.157, 0.9)
const DARK_PANEL_TEXT := Color(0.957, 0.914, 0.831, 1.0)
const DARK_PANEL_TEXT_SECONDARY := Color(0.722, 0.659, 0.549, 1.0)

# ---------------------------------------------------------------------------
# Light panel tier — menus, dialogs, day summary (#F5ECD6 fill / #2B1D12 text)
# Contrast: 14.8:1 (WCAG AAA)
# ---------------------------------------------------------------------------
const LIGHT_PANEL_FILL := Color(0.961, 0.925, 0.839, 1.0)
const LIGHT_PANEL_BORDER := Color(0.420, 0.306, 0.180, 0.9)
const LIGHT_PANEL_TEXT := Color(0.169, 0.114, 0.071, 1.0)
const LIGHT_PANEL_TEXT_SECONDARY := Color(0.420, 0.306, 0.180, 1.0)

# ---------------------------------------------------------------------------
# Legacy running-state colors (dark panel context)
# ---------------------------------------------------------------------------
const BODY_FONT_COLOR := DARK_PANEL_TEXT
const HEADER_FONT_COLOR := Color(0.9, 0.75, 0.45, 1.0)
const ACCENT_COLOR := Color(0.83, 0.63, 0.33, 1.0)
const POSITIVE_COLOR := Color(0.4, 0.8, 0.35, 1.0)
const NEGATIVE_COLOR := Color(0.9, 0.3, 0.25, 1.0)
const WARNING_COLOR := Color(0.95, 0.75, 0.2, 1.0)

## Deuteranopia-friendly status colors (blue-orange scheme).
const POSITIVE_COLOR_CB := Color(0.35, 0.7, 0.9, 1.0)
const NEGATIVE_COLOR_CB := Color(0.9, 0.6, 0.0, 1.0)
const WARNING_COLOR_CB := Color(0.8, 0.47, 0.65, 1.0)

# ---------------------------------------------------------------------------
# Store accent hex values (from four-layer palette spec)
# Use on borders/headers only; never as body text unless darkened variant
# ---------------------------------------------------------------------------
const STORE_ACCENT_RETRO_GAMES := Color(0.482, 0.294, 0.812, 1.0)      # #7B4BCF Cartridge Purple
const STORE_ACCENT_POCKET_CREATURES := Color(0.180, 0.710, 0.659, 1.0) # #2EB5A8 Holo Teal
const STORE_ACCENT_VIDEO_RENTAL := Color(0.820, 0.231, 0.180, 1.0)     # #D13B2E VHS Red
const STORE_ACCENT_ELECTRONICS := Color(0.227, 0.659, 0.847, 1.0)      # #3AA8D8 CRT Cyan
const STORE_ACCENT_SPORTS_CARDS := Color(0.788, 0.604, 0.169, 1.0)     # #C99A2B Foil Gold

## Inactive (desaturated) store accent for hub view when store is not selected.
const STORE_ACCENT_INACTIVE_RETRO_GAMES := Color(0.239, 0.188, 0.314, 1.0)
const STORE_ACCENT_INACTIVE_POCKET_CREATURES := Color(0.157, 0.259, 0.251, 1.0)
const STORE_ACCENT_INACTIVE_VIDEO_RENTAL := Color(0.314, 0.180, 0.180, 1.0)
const STORE_ACCENT_INACTIVE_ELECTRONICS := Color(0.157, 0.231, 0.314, 1.0)
const STORE_ACCENT_INACTIVE_SPORTS_CARDS := Color(0.275, 0.239, 0.157, 1.0)

## Keyed by store StringName for runtime lookup.
const STORE_ACCENTS: Dictionary = {
	"retro_games": Color(0.482, 0.294, 0.812, 1.0),
	"pocket_creatures": Color(0.180, 0.710, 0.659, 1.0),
	"video_rental": Color(0.820, 0.231, 0.180, 1.0),
	"electronics": Color(0.227, 0.659, 0.847, 1.0),
	"sports_cards": Color(0.788, 0.604, 0.169, 1.0),
}

const STORE_ACCENTS_INACTIVE: Dictionary = {
	"retro_games": Color(0.239, 0.188, 0.314, 1.0),
	"pocket_creatures": Color(0.157, 0.259, 0.251, 1.0),
	"video_rental": Color(0.314, 0.180, 0.180, 1.0),
	"electronics": Color(0.157, 0.231, 0.314, 1.0),
	"sports_cards": Color(0.275, 0.239, 0.157, 1.0),
}

# ---------------------------------------------------------------------------
# Semantic alert palette with colorblind-safe icon/shape pairs
# Each entry: { color, icon, label }
# Icons: ✓ success, ! warning, ✕ error, ◆ info, ✖ critical
# ---------------------------------------------------------------------------
const SEMANTIC_SUCCESS := Color(0.427, 0.812, 0.353, 1.0)   # #6DCF5A
const SEMANTIC_WARNING := Color(0.949, 0.722, 0.110, 1.0)   # #F2B81C
const SEMANTIC_ERROR := Color(0.898, 0.243, 0.169, 1.0)     # #E53E2B
const SEMANTIC_INFO := Color(0.357, 0.722, 0.910, 1.0)      # #5BB8E8
const SEMANTIC_CRITICAL := Color(1.0, 0.176, 0.310, 1.0)    # #FF2D4F
const SEMANTIC_MONEY_GAIN := Color(0.561, 0.878, 0.459, 1.0) # #8FE075
const SEMANTIC_MONEY_COST := Color(1.0, 0.706, 0.659, 1.0)  # #FFB4A8

const SEMANTIC_ICON_SUCCESS: String = "\u2713"  # ✓
const SEMANTIC_ICON_WARNING: String = "!"
const SEMANTIC_ICON_ERROR: String = "\u2715"   # ✕
const SEMANTIC_ICON_INFO: String = "\u25C6"    # ◆
const SEMANTIC_ICON_CRITICAL: String = "\u2716" # ✖

## Full semantic descriptor including hex value, color, icon, and label.
const SEMANTIC_STATES: Dictionary = {
	"success": {
		"color": Color(0.427, 0.812, 0.353, 1.0),
		"icon": "\u2713",
		"label": "Success",
		"hex": "#6DCF5A",
	},
	"warning": {
		"color": Color(0.949, 0.722, 0.110, 1.0),
		"icon": "!",
		"label": "Warning",
		"hex": "#F2B81C",
	},
	"error": {
		"color": Color(0.898, 0.243, 0.169, 1.0),
		"icon": "\u2715",
		"label": "Error",
		"hex": "#E53E2B",
	},
	"info": {
		"color": Color(0.357, 0.722, 0.910, 1.0),
		"icon": "\u25C6",
		"label": "Info",
		"hex": "#5BB8E8",
	},
	"critical": {
		"color": Color(1.0, 0.176, 0.310, 1.0),
		"icon": "\u2716",
		"label": "Critical",
		"hex": "#FF2D4F",
	},
}

# ---------------------------------------------------------------------------
# Typography constants
# ---------------------------------------------------------------------------

## Minimum letter spacing (tracking) for primary labels in 1/1000 em units.
const TRACKING_PRIMARY: int = 80
## Minimum letter spacing for body copy.
const TRACKING_BODY: int = 40
## Recommended font size for primary UI labels.
const FONT_SIZE_BODY: int = 16
const FONT_SIZE_HEADER: int = 22
const FONT_SIZE_TITLE: int = 28
const FONT_SIZE_SMALL: int = 13

## Markup label thresholds: ratio <= threshold yields that label.
const MARKUP_LABEL_FAIR_MAX: float = 1.5
const MARKUP_LABEL_HIGH_MAX: float = 2.0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Returns the Color for a given rarity string, or white if unknown.
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


## Returns the store accent Color for a given store_id StringName.
static func get_store_accent(store_id: StringName, active: bool = true) -> Color:
	if active:
		return STORE_ACCENTS.get(str(store_id), ACCENT_COLOR)
	return STORE_ACCENTS_INACTIVE.get(str(store_id), ACCENT_COLOR)


## Returns the semantic color for a named state ("success", "warning", etc.).
static func get_semantic_color(state: String) -> Color:
	var entry: Dictionary = SEMANTIC_STATES.get(state, {})
	return entry.get("color", Color.WHITE)


## Returns the icon for a named semantic state.
static func get_semantic_icon(state: String) -> String:
	var entry: Dictionary = SEMANTIC_STATES.get(state, {})
	return entry.get("icon", "")


## Returns "icon label" display string for a semantic state, e.g. "✓ Success".
static func get_semantic_display(state: String) -> String:
	var entry: Dictionary = SEMANTIC_STATES.get(state, {})
	if entry.is_empty():
		return state.capitalize()
	return "%s %s" % [entry["icon"], entry["label"]]


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
