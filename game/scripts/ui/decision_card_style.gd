## Shared visual constants for decision-card UIs.
##
## The midday event card and the customer decision card must look and feel
## like the same widget — only the header differentiates "store event" from
## "customer interaction". These constants are the single source of truth for
## the dimensions, border, corner radius, and font sizes both cards use.
##
## Header background colors are *intentionally* different per card type so the
## player can distinguish them at a glance: cool/slate blue for store events,
## warm tone for customer interactions.
class_name DecisionCardStyle
extends Object


enum ConflictLevel {
	LOW,
	NEUTRAL,
	TENSION,
}


const CARD_WIDTH: int = 460
const CARD_MIN_HEIGHT: int = 240
const CARD_BORDER_WIDTH: int = 2
const CARD_CORNER_RADIUS: int = 8
const CARD_PADDING_PX: int = 16

const FONT_SIZE_HEADER_TAG: int = 12
const FONT_SIZE_TITLE: int = 22
const FONT_SIZE_BODY: int = 16
const FONT_SIZE_CHOICE_LABEL: int = 16
const FONT_SIZE_CHOICE_CONSEQUENCE: int = 12

## Cool/slate blue header background for store-event cards.
const STORE_EVENT_HEADER_COLOR: Color = Color(0.16, 0.22, 0.32, 1.0)
## Warm tone reserved for customer decision cards. Declared here so both
## cards reference the same palette source even though only the customer
## card consumes this constant.
const CUSTOMER_DECISION_HEADER_COLOR: Color = Color(0.36, 0.20, 0.18, 1.0)

const CARD_BACKGROUND_COLOR: Color = Color(0.10, 0.10, 0.12, 0.96)
const CARD_BORDER_COLOR: Color = Color(0.65, 0.65, 0.70, 1.0)
const CHOICE_CONSEQUENCE_COLOR: Color = Color(0.74, 0.74, 0.78, 1.0)

## Card-active vs result palette: result-state cards desaturate the bg so the
## interaction reads as resolving rather than prompting.
const CARD_ACTIVE_BG_COLOR: Color = Color(0.16, 0.16, 0.20, 0.96)
const CARD_RESULT_BG_COLOR: Color = Color(0.10, 0.10, 0.12, 0.96)

## Archetype-conflict pill colors — green/amber/red encode tension at a glance.
const ARCHETYPE_COLOR_LOW: Color = Color(0.30, 0.62, 0.34, 1.0)
const ARCHETYPE_COLOR_NEUTRAL: Color = Color(0.85, 0.62, 0.20, 1.0)
const ARCHETYPE_COLOR_TENSION: Color = Color(0.78, 0.32, 0.24, 1.0)

## Map archetype_id → ConflictLevel. Low: gift-givers and casual browsers.
## Neutral: collectors and value-seekers (transactional, not adversarial).
## Tension: hagglers, return abusers, and impatient/excitable shoppers.
const ARCHETYPE_CONFLICT: Dictionary = {
	&"confused_parent": ConflictLevel.LOW,
	&"casual_shopper": ConflictLevel.LOW,
	&"gift_giver": ConflictLevel.LOW,
	&"casual_browser": ConflictLevel.LOW,
	&"enthusiast": ConflictLevel.NEUTRAL,
	&"collector": ConflictLevel.NEUTRAL,
	&"sports_regular": ConflictLevel.NEUTRAL,
	&"value_seeker": ConflictLevel.NEUTRAL,
	&"hype_teen": ConflictLevel.NEUTRAL,
	&"bargain_hunter": ConflictLevel.TENSION,
	&"haggler": ConflictLevel.TENSION,
	&"impatient": ConflictLevel.TENSION,
	&"return_abuser": ConflictLevel.TENSION,
	&"angry_return_customer": ConflictLevel.TENSION,
	&"shady_regular": ConflictLevel.TENSION,
	&"reseller": ConflictLevel.TENSION,
}


## Resolves an archetype id to its conflict-pill color. Unknown archetypes
## default to the neutral color so a missing entry never crashes the UI.
static func archetype_color(archetype_id: StringName) -> Color:
	var level: int = int(ARCHETYPE_CONFLICT.get(
		archetype_id, ConflictLevel.NEUTRAL
	))
	match level:
		ConflictLevel.LOW:
			return ARCHETYPE_COLOR_LOW
		ConflictLevel.TENSION:
			return ARCHETYPE_COLOR_TENSION
		_:
			return ARCHETYPE_COLOR_NEUTRAL


## Returns the conflict tier int for a given archetype id; tests use this to
## verify the conflict-color encoding without depending on RGB values.
static func archetype_conflict_level(archetype_id: StringName) -> int:
	return int(ARCHETYPE_CONFLICT.get(
		archetype_id, ConflictLevel.NEUTRAL
	))


## Returns a StyleBoxFlat for the outer card container with the shared border,
## corner radius, and background color applied.
static func make_card_stylebox() -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = CARD_BACKGROUND_COLOR
	box.border_width_left = CARD_BORDER_WIDTH
	box.border_width_top = CARD_BORDER_WIDTH
	box.border_width_right = CARD_BORDER_WIDTH
	box.border_width_bottom = CARD_BORDER_WIDTH
	box.border_color = CARD_BORDER_COLOR
	box.corner_radius_top_left = CARD_CORNER_RADIUS
	box.corner_radius_top_right = CARD_CORNER_RADIUS
	box.corner_radius_bottom_left = CARD_CORNER_RADIUS
	box.corner_radius_bottom_right = CARD_CORNER_RADIUS
	box.content_margin_left = CARD_PADDING_PX
	box.content_margin_right = CARD_PADDING_PX
	box.content_margin_top = CARD_PADDING_PX
	box.content_margin_bottom = CARD_PADDING_PX
	return box


## Returns a StyleBoxFlat for the card header strip in the supplied color.
## Used by both card types — store events pass STORE_EVENT_HEADER_COLOR;
## customer cards pass CUSTOMER_DECISION_HEADER_COLOR.
static func make_header_stylebox(color: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.corner_radius_top_left = CARD_CORNER_RADIUS - 1
	box.corner_radius_top_right = CARD_CORNER_RADIUS - 1
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box


## Applies the shared italic + muted reasoning-text style to a RichTextLabel.
## Both decision cards (checkout, haggle) render their reasoning hint with the
## same font size, color, and bbcode-enabled layout — this helper is the single
## source of truth so the two cards can't drift visually.
static func apply_reasoning_style(label: RichTextLabel) -> void:
	if label == null:
		return
	label.add_theme_font_size_override(
		"normal_font_size", FONT_SIZE_CHOICE_CONSEQUENCE
	)
	label.add_theme_color_override(
		"default_color", CHOICE_CONSEQUENCE_COLOR
	)
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false


## Applies the shared archetype-badge style: a rounded pill colored by
## archetype conflict tier, with the badge label set to FONT_SIZE_HEADER_TAG
## and white. Both panels feed `archetype_color()` through this helper so the
## badge looks identical across surfaces.
static func apply_archetype_badge_style(
	badge: PanelContainer,
	label: Label,
	archetype_id: StringName,
) -> void:
	if badge == null or label == null:
		return
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = archetype_color(archetype_id)
	box.corner_radius_top_left = 8
	box.corner_radius_top_right = 8
	box.corner_radius_bottom_left = 8
	box.corner_radius_bottom_right = 8
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	badge.add_theme_stylebox_override("panel", box)
	label.add_theme_font_size_override(
		"font_size", FONT_SIZE_HEADER_TAG
	)
	label.add_theme_color_override(
		"font_color", Color(1.0, 1.0, 1.0, 1.0)
	)
