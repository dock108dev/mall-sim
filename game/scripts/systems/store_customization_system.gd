## StoreCustomizationSystem — owner of per-day store customization choices.
##
## Two player choices, both reset to null at day_started:
##   - Featured display category (gated behind employee_display_authority).
##   - Promotional poster (no unlock required from Day 1).
##
## Both selections cycle through fixed option lists; each selection produces
## small read-only effects:
##   - get_spawn_weight_bonus(archetype_id) — multiplier ≥ 1.0 used by
##     CustomerSystem when computing per-profile spawn weight.
##   - get_demand_multiplier(platform_id) — multiplier ≥ 1.0 used by
##     PlatformSystem during the daily tick to scale shortage hype gain on the
##     featured platform.
##
## Side effects on selection:
##   - Manager trust gains +0.03 once per day when the chosen featured category
##     matches the morning note's hinted preference (parsed from note_id).
##   - The featured_category_changed signal lets store controllers detect the
##     new-console-hype hookup against their own hold list and emit
##     EventBus.display_exposes_weird_inventory when a suspicious VecForce HD
##     hold is present (HiddenThreadSystem consumes that signal as a Tier 1
##     trigger).
##
## Registered as the `StoreCustomizationSystem` autoload in project.godot.
extends Node


# ── Featured category catalog ────────────────────────────────────────────────

const FEATURED_CATEGORY_NONE: StringName = &""
const FEATURED_CATEGORY_NEW_CONSOLE_HYPE: StringName = &"new_console_hype"
const FEATURED_CATEGORY_OLD_GEN_CLEARANCE: StringName = &"old_gen_clearance"
const FEATURED_CATEGORY_USED_BUNDLES: StringName = &"used_bundles"
const FEATURED_CATEGORY_SPORTS_GAMES: StringName = &"sports_games"
const FEATURED_CATEGORY_ACCESSORIES: StringName = &"accessories"
const FEATURED_CATEGORY_FAMILY_FRIENDLY: StringName = &"family_friendly"

const FEATURED_CATEGORY_ORDER: Array[StringName] = [
	FEATURED_CATEGORY_NEW_CONSOLE_HYPE,
	FEATURED_CATEGORY_OLD_GEN_CLEARANCE,
	FEATURED_CATEGORY_USED_BUNDLES,
	FEATURED_CATEGORY_SPORTS_GAMES,
	FEATURED_CATEGORY_ACCESSORIES,
	FEATURED_CATEGORY_FAMILY_FRIENDLY,
]


# ── Poster catalog ───────────────────────────────────────────────────────────

const POSTER_NONE: StringName = &""
const POSTER_NEW_RELEASES: StringName = &"new_releases"
const POSTER_RETRO_REVIVAL: StringName = &"retro_revival"
const POSTER_SPORTS_SEASON: StringName = &"sports_season"
const POSTER_FAMILY_FUN: StringName = &"family_fun"

const POSTER_ORDER: Array[StringName] = [
	POSTER_NEW_RELEASES,
	POSTER_RETRO_REVIVAL,
	POSTER_SPORTS_SEASON,
	POSTER_FAMILY_FUN,
]


# ── Effect tables ────────────────────────────────────────────────────────────

## Featured category → archetype_id → spawn weight multiplier (>= 1.0).
const _FEATURED_SPAWN_BONUSES: Dictionary = {
	FEATURED_CATEGORY_NEW_CONSOLE_HYPE: {&"hype_teen": 1.25},
	FEATURED_CATEGORY_OLD_GEN_CLEARANCE: {
		&"confused_parent": 1.20,
		&"bargain_hunter": 1.20,
	},
	FEATURED_CATEGORY_USED_BUNDLES: {&"bargain_hunter": 1.10},
	FEATURED_CATEGORY_SPORTS_GAMES: {&"sports_regular": 1.25},
	FEATURED_CATEGORY_ACCESSORIES: {},
	FEATURED_CATEGORY_FAMILY_FRIENDLY: {
		&"confused_parent": 1.10,
		&"casual_shopper": 1.10,
	},
}

## Featured category → platform_id → demand multiplier (>= 1.0).
const _FEATURED_DEMAND_MULTIPLIERS: Dictionary = {
	FEATURED_CATEGORY_NEW_CONSOLE_HYPE: {&"vecforce_hd": 1.10},
}

## Poster id → archetype_id → spawn weight multiplier (subtle ~+2%).
const _POSTER_SPAWN_BONUSES: Dictionary = {
	POSTER_NEW_RELEASES: {&"hype_teen": 1.02},
	POSTER_RETRO_REVIVAL: {&"bargain_hunter": 1.02, &"collector": 1.02},
	POSTER_SPORTS_SEASON: {&"sports_regular": 1.02},
	POSTER_FAMILY_FUN: {&"confused_parent": 1.02, &"casual_shopper": 1.02},
}

## Maps the manager-note category token (parsed from note_id) to the featured
## category the player would be rewarded for selecting. Notes without a
## matching token (Day 1 / unlock-override / fallback) leave the hint empty.
const _NOTE_CATEGORY_HINT: Dictionary = {
	&"sales": FEATURED_CATEGORY_USED_BUNDLES,
	&"operational": FEATURED_CATEGORY_OLD_GEN_CLEARANCE,
	&"staff": FEATURED_CATEGORY_FAMILY_FRIENDLY,
}

const TRUST_DELTA_HINT_MATCH: float = 0.03
const REASON_HINT_MATCH: String = "featured_display_matches_hint"
const FEATURED_UNLOCK_ID: StringName = &"employee_display_authority"


# ── Public state ─────────────────────────────────────────────────────────────

var current_featured_category: StringName = FEATURED_CATEGORY_NONE
var current_poster_id: StringName = POSTER_NONE


# ── Internal state (per-day) ─────────────────────────────────────────────────

var _morning_note_hint: StringName = &""
var _hint_match_applied_this_day: bool = false


# ── Signals ──────────────────────────────────────────────────────────────────

signal featured_category_changed(category: StringName)
signal poster_changed(poster_id: StringName)


func _ready() -> void:
	_connect_signals()


func _connect_signals() -> void:
	if not EventBus.day_started.is_connected(_on_day_started):
		EventBus.day_started.connect(_on_day_started)
	if not EventBus.manager_note_shown.is_connected(_on_manager_note_shown):
		EventBus.manager_note_shown.connect(_on_manager_note_shown)


# ── Public read API ──────────────────────────────────────────────────────────

## Returns the per-archetype spawn weight multiplier from the active featured
## category and poster. Returns 1.0 when no selections are active.
func get_spawn_weight_bonus(archetype_id: StringName) -> float:
	var multiplier: float = 1.0
	if current_featured_category != FEATURED_CATEGORY_NONE:
		var f_bonuses: Dictionary = _FEATURED_SPAWN_BONUSES.get(
			current_featured_category, {}
		)
		multiplier *= float(f_bonuses.get(archetype_id, 1.0))
	if current_poster_id != POSTER_NONE:
		var p_bonuses: Dictionary = _POSTER_SPAWN_BONUSES.get(
			current_poster_id, {}
		)
		multiplier *= float(p_bonuses.get(archetype_id, 1.0))
	return multiplier


## Returns the per-platform demand multiplier from the active featured
## category. Returns 1.0 when nothing is featured or the platform has no entry
## in the table for the active category.
func get_demand_multiplier(platform_id: StringName) -> float:
	if current_featured_category == FEATURED_CATEGORY_NONE:
		return 1.0
	var bonuses: Dictionary = _FEATURED_DEMAND_MULTIPLIERS.get(
		current_featured_category, {}
	)
	return float(bonuses.get(platform_id, 1.0))


## Returns true when the player has the unlock that grants featured-display
## authority. The Featured Display interactable surfaces an "Ask Vic" prompt
## when this returns false, mirroring the manager-handled allocation pattern
## used by the hold terminal access gate.
func can_set_featured_category() -> bool:
	var unlocks: Node = get_node_or_null("/root/UnlockSystemSingleton")
	if unlocks == null or not unlocks.has_method("is_unlocked"):
		return false
	return bool(unlocks.call("is_unlocked", FEATURED_UNLOCK_ID))


## Returns the morning-note category hint resolved at the most recent
## day_started. Empty StringName when no note carried a recognised category
## token (Day 1 override, unlock override, fallback).
func get_morning_note_hint() -> StringName:
	return _morning_note_hint


# ── Public mutation API ──────────────────────────────────────────────────────

## Cycles through FEATURED_CATEGORY_ORDER, advancing one step from the current
## selection. No-ops when the player lacks the unlock. Returns the new
## category, or FEATURED_CATEGORY_NONE if the cycle was rejected.
func cycle_featured_category() -> StringName:
	if not can_set_featured_category():
		return FEATURED_CATEGORY_NONE
	var idx: int = FEATURED_CATEGORY_ORDER.find(current_featured_category)
	idx = (idx + 1) % FEATURED_CATEGORY_ORDER.size()
	set_featured_category(FEATURED_CATEGORY_ORDER[idx])
	return current_featured_category


## Sets the featured category to `category`. Pass FEATURED_CATEGORY_NONE to
## clear the selection (e.g. test setup, manual reset). Unknown categories
## emit a warning and are ignored.
func set_featured_category(category: StringName) -> void:
	if (
		category != FEATURED_CATEGORY_NONE
		and not FEATURED_CATEGORY_ORDER.has(category)
	):
		push_warning(
			"StoreCustomizationSystem: unknown featured category '%s'"
			% category
		)
		return
	if (
		category != FEATURED_CATEGORY_NONE
		and not can_set_featured_category()
	):
		push_warning(
			"StoreCustomizationSystem: featured display gated; "
			+ "missing unlock '%s'" % FEATURED_UNLOCK_ID
		)
		return
	current_featured_category = category
	featured_category_changed.emit(category)
	_maybe_apply_hint_match_trust()


## Cycles through POSTER_ORDER. Posters carry no unlock requirement.
func cycle_poster() -> StringName:
	var idx: int = POSTER_ORDER.find(current_poster_id)
	idx = (idx + 1) % POSTER_ORDER.size()
	set_poster(POSTER_ORDER[idx])
	return current_poster_id


## Sets the poster id. Pass POSTER_NONE to clear. Unknown posters emit a
## warning and are ignored.
func set_poster(poster_id: StringName) -> void:
	if poster_id != POSTER_NONE and not POSTER_ORDER.has(poster_id):
		push_warning(
			"StoreCustomizationSystem: unknown poster_id '%s'" % poster_id
		)
		return
	current_poster_id = poster_id
	poster_changed.emit(poster_id)


# ── Test seams ───────────────────────────────────────────────────────────────

## Resets all per-day state. Used by tests to start each case from a clean
## slate without re-instantiating the autoload.
func reset_for_testing() -> void:
	current_featured_category = FEATURED_CATEGORY_NONE
	current_poster_id = POSTER_NONE
	_morning_note_hint = &""
	_hint_match_applied_this_day = false


## Force-sets the morning-note hint. Lets tests exercise the hint-match trust
## path without depending on a specific note_id parser pattern.
func _set_morning_note_hint_for_testing(hint: StringName) -> void:
	_morning_note_hint = hint
	_hint_match_applied_this_day = false


# ── Internals ────────────────────────────────────────────────────────────────

func _on_day_started(_day: int) -> void:
	current_featured_category = FEATURED_CATEGORY_NONE
	current_poster_id = POSTER_NONE
	_morning_note_hint = &""
	_hint_match_applied_this_day = false
	featured_category_changed.emit(FEATURED_CATEGORY_NONE)
	poster_changed.emit(POSTER_NONE)


func _on_manager_note_shown(
	note_id: String, _body: String, _allow_auto_dismiss: bool
) -> void:
	# Tier×category note ids follow the "{tier}_{category}_{variant}" pattern
	# (cold_sales_a, neutral_operational_b, warm_staff_a, etc.). Override notes
	# (note_override_day_1, note_override_unlock_*) and the fallback id resolve
	# to no hint, which is the correct behavior — those notes don't carry a
	# meaningful category preference.
	var parts: PackedStringArray = note_id.split("_")
	if parts.size() < 2:
		return
	var category_token: StringName = StringName(parts[1])
	if _NOTE_CATEGORY_HINT.has(category_token):
		_morning_note_hint = _NOTE_CATEGORY_HINT[category_token]


func _maybe_apply_hint_match_trust() -> void:
	if _hint_match_applied_this_day:
		return
	if current_featured_category == FEATURED_CATEGORY_NONE:
		return
	if _morning_note_hint == &"":
		return
	if current_featured_category != _morning_note_hint:
		return
	var manager: Node = get_node_or_null("/root/ManagerRelationshipManager")
	if manager == null or not manager.has_method("apply_trust_delta"):
		# §F-131 — ManagerRelationshipManager is declared as an autoload in
		# project.godot:58 with apply_trust_delta defined at line 114. Reaching
		# this branch means the autoload was disabled / removed or the API
		# contract drifted; both are project-config regressions, not test
		# seams. A silent return un-couples the +0.03 hint-match trust reward
		# from the player's display choice — the only positive trust delta on
		# the customization surface — masking the regression as missing
		# progression. Mirrors §F-122 / §F-124 in midday_event_system.
		push_error((
			"StoreCustomizationSystem: hint-match trust delta dropped — "
			+ "/root/ManagerRelationshipManager autoload missing or lacks "
			+ "apply_trust_delta(); featured='%s' hint='%s'"
		) % [current_featured_category, _morning_note_hint])
		return
	manager.call("apply_trust_delta", TRUST_DELTA_HINT_MATCH, REASON_HINT_MATCH)
	_hint_match_applied_this_day = true
