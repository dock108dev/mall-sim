## Verifies the Day 1 ObjectiveRail surfaces the first step of the chain
## ("Talk to the customer at the register checkout.") with a "Press E" action and an
## "E" key badge, that the rail occupies a different screen zone than the
## InteractionPrompt, and that the Day1ReadinessAudit objective check passes
## once the day starts and the player enters the store.
extends GutTest


const _OBJECTIVE_TEXT: String = "Talk to the customer at the register checkout."
const _ACTION_TEXT: String = "Press E at the counter"
const _KEY_TEXT: String = "E"

const _RAIL_SCENE: String = "res://game/scenes/ui/objective_rail.tscn"
const _PROMPT_SCENE: String = "res://game/scenes/ui/interaction_prompt.tscn"

var _saved_state: GameManager.State
var _saved_show_rail: bool
var _saved_director_day: int
var _saved_director_stocked: bool
var _saved_director_sold: bool
var _saved_director_loop: bool
var _saved_director_step: int
var _saved_director_waiting: bool
var _saved_first_sale_flag: bool


func before_each() -> void:
	_saved_state = GameManager.current_state
	_saved_show_rail = Settings.show_objective_rail
	_saved_director_day = ObjectiveDirector._current_day
	_saved_director_stocked = ObjectiveDirector._stocked
	_saved_director_sold = ObjectiveDirector._sold
	_saved_director_loop = ObjectiveDirector._loop_completed
	_saved_director_step = ObjectiveDirector._day1_step_index
	_saved_director_waiting = ObjectiveDirector._waiting_for_note_dismiss
	_saved_first_sale_flag = bool(GameState.get_flag(&"first_sale_complete"))
	GameManager.current_state = GameManager.State.STORE_VIEW
	Settings.show_objective_rail = true
	ObjectiveDirector._current_day = 0
	ObjectiveDirector._stocked = false
	ObjectiveDirector._sold = false
	ObjectiveDirector._loop_completed = false
	ObjectiveDirector._day1_step_index = -1
	ObjectiveDirector._waiting_for_note_dismiss = false
	GameState.set_flag(&"first_sale_complete", false)
	if InputFocus != null:
		InputFocus._reset_for_tests()
	EventBus.fp_mode_changed.emit(false)
	EventBus.interactable_unfocused.emit()


func after_each() -> void:
	GameManager.current_state = _saved_state
	Settings.show_objective_rail = _saved_show_rail
	ObjectiveDirector._current_day = _saved_director_day
	ObjectiveDirector._stocked = _saved_director_stocked
	ObjectiveDirector._sold = _saved_director_sold
	ObjectiveDirector._loop_completed = _saved_director_loop
	ObjectiveDirector._day1_step_index = _saved_director_step
	ObjectiveDirector._waiting_for_note_dismiss = _saved_director_waiting
	GameState.set_flag(&"first_sale_complete", _saved_first_sale_flag)
	if InputFocus != null:
		InputFocus._reset_for_tests()
	# Reset FP-mode signal so a test that flipped it on does not leak into
	# subsequent tests (or the production autoload's rail listener).
	EventBus.fp_mode_changed.emit(false)
	EventBus.interactable_unfocused.emit()


## Drives the production handshake for tests that exercise post-dismiss state:
## day_started fires the pre-chain gate, then the player dismisses the note.
func _start_day1_after_note_dismiss() -> void:
	EventBus.day_started.emit(1)
	EventBus.manager_note_dismissed.emit("")


func _make_rail() -> CanvasLayer:
	var rail: CanvasLayer = preload(
		"res://game/scenes/ui/objective_rail.tscn"
	).instantiate() as CanvasLayer
	add_child_autofree(rail)
	return rail


# ── Day 1 content surfacing ────────────────────────────────────────────────────

func test_rail_visible_on_day1_after_day_started_and_store_entered() -> void:
	var rail := _make_rail()
	EventBus.day_started.emit(1)
	EventBus.store_entered.emit(&"retro_games")
	assert_true(
		rail.visible,
		"ObjectiveRail must be visible in STORE_VIEW with Day 1 payload and no modal"
	)


func test_objective_label_shows_stock_first_item_text_on_day1() -> void:
	var rail := _make_rail()
	_start_day1_after_note_dismiss()
	assert_eq(rail._objective_label.text, _OBJECTIVE_TEXT)


func test_action_label_shows_press_i_on_day1() -> void:
	var rail := _make_rail()
	_start_day1_after_note_dismiss()
	assert_eq(rail._action_label.text, _ACTION_TEXT)


func test_hint_badge_shows_letter_i_on_day1() -> void:
	var rail := _make_rail()
	_start_day1_after_note_dismiss()
	assert_eq(rail._hint_label.text, _KEY_TEXT)
	assert_true(
		rail._hint_label.visible,
		"Day 1 key badge 'I' must be visible alongside the action hint"
	)


# ── Legibility at 1920x1080 ────────────────────────────────────────────────────

func test_project_theme_label_font_size_meets_legibility_floor() -> void:
	# Visual grammar (docs/style/visual-grammar.md) treats <18pt body text as a
	# merge-blocker. The rail's Labels carry no font_size override, so they
	# resolve through the project theme. Verify the project theme keeps Label
	# at the 18pt floor that gives the Day 1 guidance legibility at 1920x1080.
	var theme_src: String = FileAccess.get_file_as_string(
		"res://game/themes/game_theme.tres"
	)
	assert_ne(theme_src, "", "game_theme.tres must be readable")
	assert_true(
		theme_src.contains("Label/font_sizes/font_size = 18"),
		"Project theme must keep Label font_size >= 18 for 1080p legibility"
	)


func test_rail_labels_have_no_smaller_font_override() -> void:
	# Defensive: if the rail later adds a theme_override_font_sizes/font_size,
	# it must not push body text below the 18pt grammar floor.
	var rail_src: String = FileAccess.get_file_as_string(_RAIL_SCENE)
	assert_ne(rail_src, "", "objective_rail.tscn must be readable")
	var idx: int = rail_src.find("theme_override_font_sizes/font_size = ")
	while idx != -1:
		var rest: String = rail_src.substr(
			idx + "theme_override_font_sizes/font_size = ".length()
		)
		var line_end: int = rest.find("\n")
		if line_end == -1:
			line_end = rest.length()
		var value: int = int(rest.substr(0, line_end))
		assert_true(
			value >= 18,
			"objective_rail.tscn font_size override %d must be >= 18" % value
		)
		idx = rail_src.find(
			"theme_override_font_sizes/font_size = ", idx + 1
		)


# ── Zone separation: rail vs InteractionPrompt ─────────────────────────────────

func _y_range_from_scene(scene_path: String, node_marker: String) -> Vector2:
	# Parses the offset_top / offset_bottom of the first node block matching
	# `node_marker` in the .tscn source. Returns Vector2(top, bottom) in pixels
	# from the bottom of the screen (positive = pixels above bottom).
	var src: String = FileAccess.get_file_as_string(scene_path)
	assert_ne(src, "", "scene must be readable: %s" % scene_path)
	var marker_idx: int = src.find(node_marker)
	assert_gt(marker_idx, -1, "scene %s must contain node block %s"
		% [scene_path, node_marker])
	var block: String = src.substr(marker_idx)
	var next_block: int = block.find("\n\n[")
	if next_block != -1:
		block = block.substr(0, next_block)
	var top: float = _extract_offset(block, "offset_top")
	var bottom: float = _extract_offset(block, "offset_bottom")
	# Anchored to bottom (anchor_bottom=1.0): positive distance = -offset.
	return Vector2(-top, -bottom)


func _extract_offset(block: String, key: String) -> float:
	var needle: String = "%s = " % key
	var idx: int = block.find(needle)
	if idx == -1:
		return 0.0
	var rest: String = block.substr(idx + needle.length())
	var end: int = rest.find("\n")
	if end == -1:
		end = rest.length()
	return float(rest.substr(0, end))


func test_interaction_prompt_zone_does_not_overlap_objective_rail_zone() -> void:
	var rail_range: Vector2 = _y_range_from_scene(
		_RAIL_SCENE, '[node name="MarginContainer" type="MarginContainer" parent="."]'
	)
	var band_range: Vector2 = _y_range_from_scene(
		_RAIL_SCENE, '[node name="AccentBand" type="ColorRect" parent="."]'
	)
	var prompt_range: Vector2 = _y_range_from_scene(
		_PROMPT_SCENE, '[node name="PanelContainer" type="PanelContainer" parent="."]'
	)
	# rail occupies [rail_range.y .. rail_range.x] px from bottom (margin
	# container) plus the 4px accent band [band_range.y .. band_range.x].
	# Combined upper edge = max(rail_range.x, band_range.x).
	var rail_top: float = max(rail_range.x, band_range.x)
	var rail_bottom: float = min(rail_range.y, band_range.y)
	var prompt_top: float = prompt_range.x
	var prompt_bottom: float = prompt_range.y
	# Prompt must sit fully above rail: prompt_bottom >= rail_top.
	assert_true(
		prompt_bottom >= rail_top,
		(
			"InteractionPrompt bottom edge (%.0fpx from bottom) must clear "
			+ "ObjectiveRail top edge (%.0fpx from bottom). Rail [%.0f..%.0f], "
			+ "prompt [%.0f..%.0f]."
		) % [
			prompt_bottom, rail_top,
			rail_bottom, rail_top, prompt_bottom, prompt_top
		]
	)


# ── Chain advancement drives ObjectiveDirector update ─────────────────────────

func test_chain_advance_updates_rail_with_next_step_copy() -> void:
	# Walks the chain so item_stocked actually advances a step
	# (TALK_TO_CUSTOMER → BACK_ROOM_INVENTORY → STOCK_SHELF → CLOSE_DAY) and
	# verifies the rail re-renders with each new step's copy. With the emit
	# dedup, identical-payload re-emissions are suppressed; the rail only
	# refreshes when content changes.
	var rail := _make_rail()
	_start_day1_after_note_dismiss()
	assert_eq(rail._objective_label.text, _OBJECTIVE_TEXT)
	EventBus.customer_interacted.emit(null)
	assert_eq(
		rail._objective_label.text, "Check the back room delivery.",
		"customer_interacted at TALK_TO_CUSTOMER must re-render the rail with step 2"
	)
	EventBus.placement_mode_entered.emit()
	assert_eq(
		rail._objective_label.text, "Stock the Retro Games shelves.",
		"placement_mode_entered at BACK_ROOM_INVENTORY must re-render with step 3"
	)
	EventBus.item_stocked.emit("item_001", "shelf_a")
	assert_eq(
		rail._objective_label.text, "Close the day at the register.",
		"item_stocked at STOCK_SHELF must re-render with the close-day step"
	)


func test_duplicate_emit_does_not_overwrite_rail_labels() -> void:
	# Dedup contract: when ObjectiveDirector recomputes _emit_current() with
	# the same text/action/key/hint as the last emission, no signal fires.
	# Mutated labels stay mutated — the rail isn't touched. Out-of-order
	# signals that don't advance the Day 1 chain (item_stocked while at
	# TALK_TO_CUSTOMER) are the production path that exercises this.
	var rail := _make_rail()
	_start_day1_after_note_dismiss()
	rail._objective_label.text = ""
	rail._action_label.text = ""
	EventBus.item_stocked.emit("item_001", "shelf_a")
	assert_eq(
		rail._objective_label.text, "",
		"Out-of-order item_stocked must not re-emit the identical payload"
	)
	assert_eq(rail._action_label.text, "")


# ── FP-mode focus chip (absorbs InteractionPrompt content) ────────────────────
#
# In first-person mode the ObjectiveRail takes over the inline
# "[E] action" copy that the InteractionPrompt would otherwise render
# bottom-center. The right-side chip swaps the cached objective action for
# the focused interactable's action_label, the cream KeyBadge appears, and
# the cached HintLabel suppresses for the duration of focus. Disabled
# focus mutes the action label and hides the badge; unfocus restores the
# cached payload.

func test_fp_mode_focus_renders_focused_action_in_rail() -> void:
	var rail := _make_rail()
	_start_day1_after_note_dismiss()
	EventBus.fp_mode_changed.emit(true)
	EventBus.interactable_focused.emit("Talk to Customer")
	assert_eq(
		rail._action_label.text, "Talk to Customer",
		"FP-mode focus must replace the cached action chip with the focused interactable's action_label"
	)


func test_fp_mode_focus_shows_styled_keybadge() -> void:
	var rail := _make_rail()
	_start_day1_after_note_dismiss()
	EventBus.fp_mode_changed.emit(true)
	EventBus.interactable_focused.emit("Talk to Customer")
	var badge: PanelContainer = rail._key_badge
	assert_true(
		badge.visible,
		"Cream KeyBadge must surface in the rail's right-side chip during FP-mode focus"
	)


func test_fp_mode_focus_suppresses_cached_hint_chip() -> void:
	var rail := _make_rail()
	_start_day1_after_note_dismiss()
	EventBus.fp_mode_changed.emit(true)
	EventBus.interactable_focused.emit("Talk to Customer")
	assert_false(
		rail._hint_label.visible,
		"Cached HintLabel must hide while the FP focus chip owns the right side"
	)


func test_fp_mode_disabled_focus_hides_keybadge_and_mutes_label() -> void:
	var rail := _make_rail()
	_start_day1_after_note_dismiss()
	EventBus.fp_mode_changed.emit(true)
	EventBus.interactable_focused_disabled.emit("No customer waiting")
	assert_false(
		rail._key_badge.visible,
		"Disabled focus must hide the KeyBadge so the player sees E will not act"
	)
	assert_eq(
		rail._action_label.text, "No customer waiting",
		"Disabled focus must surface the get_disabled_reason() text in the rail's action label"
	)
	assert_lt(
		rail._action_label.modulate.a, 0.85,
		"Disabled-reason text must render with reduced alpha to match the prompt's muted treatment"
	)


func test_fp_mode_unfocus_restores_cached_payload() -> void:
	var rail := _make_rail()
	_start_day1_after_note_dismiss()
	EventBus.fp_mode_changed.emit(true)
	EventBus.interactable_focused.emit("Talk to Customer")
	EventBus.interactable_unfocused.emit()
	assert_eq(
		rail._action_label.text, _ACTION_TEXT,
		"Unfocus must restore the cached objective action chip"
	)
	assert_eq(
		rail._hint_label.text, _KEY_TEXT,
		"Unfocus must restore the cached key chip"
	)
	assert_false(
		rail._key_badge.visible,
		"KeyBadge must hide once focus clears"
	)


func test_non_fp_mode_does_not_route_focused_text_into_rail() -> void:
	# Regression guard: outside FP mode, the InteractionPrompt is the sole
	# renderer of focused-interactable copy. The rail must keep showing the
	# cached objective payload so the management/non-FP surfaces are
	# unchanged.
	var rail := _make_rail()
	_start_day1_after_note_dismiss()
	EventBus.interactable_focused.emit("Counter — Press E to use")
	assert_eq(
		rail._action_label.text, _ACTION_TEXT,
		"Non-FP focus must not overwrite the cached action chip"
	)
	assert_false(
		rail._key_badge.visible,
		"KeyBadge must stay hidden outside FP mode"
	)


func test_beta_fp_mode_hides_objective_rail_surface() -> void:
	var rail := _make_rail()
	_start_day1_after_note_dismiss()
	assert_true(rail.visible, "Pre-condition: rail visible before beta FP suppression")
	var beta_controller: Node = Node.new()
	beta_controller.add_to_group("beta_day_one_controller")
	add_child_autofree(beta_controller)

	EventBus.fp_mode_changed.emit(true)

	assert_false(
		rail.visible,
		"Beta FP mode must hide ObjectiveRail so the right panel is the only checklist"
	)


# ── Day1ReadinessAudit objective check ────────────────────────────────────────

func test_day1_readiness_objective_check_passes_after_day1_payload() -> void:
	# ObjectiveRail is the production autoload; the rail consumes payload in
	# _ready, so emitting day_started after the autoload is alive populates
	# _current_payload before Day1ReadinessAudit reads it.
	EventBus.day_started.emit(1)
	EventBus.store_entered.emit(&"retro_games")
	assert_true(
		ObjectiveRail.has_active_objective(),
		"Day1ReadinessAudit check 8 (has_active_objective) must be true on Day 1"
	)


# ── Step slot clearing on payload shrink / disappearance ──────────────────────

func test_steps_payload_shrink_blanks_out_of_range_slots() -> void:
	# Switching from a 3-step render to a 1-step render must blank slots 1-3
	# so the rail does not surface stale text from the larger payload.
	var rail := _make_rail()
	var three_step: Dictionary = {
		"text": "three",
		"action": "act",
		"key": "E",
		"steps": [
			{"text": "alpha", "state": "active"},
			{"text": "bravo", "state": "future"},
			{"text": "charlie", "state": "future"},
		],
	}
	EventBus.objective_changed.emit(three_step)
	assert_eq(rail._step_slots[1].text, "bravo")
	assert_eq(rail._step_slots[2].text, "charlie")
	var one_step: Dictionary = {
		"text": "one",
		"action": "act",
		"key": "E",
		"steps": [
			{"text": "delta", "state": "active"},
		],
	}
	EventBus.objective_changed.emit(one_step)
	assert_eq(
		rail._step_slots[0].text, "delta",
		"Slot 0 must render the new single step"
	)
	assert_eq(
		rail._step_slots[1].text, "",
		"Slot 1 text must be blanked when payload shrinks to 1 step"
	)
	assert_eq(rail._step_slots[2].text, "")
	assert_eq(rail._step_slots[3].text, "")


func test_steps_absent_blanks_every_slot() -> void:
	# A payload that omits the `steps` key entirely (the legacy non-beta
	# render path) must clear every slot — otherwise a later payload with
	# steps would surface ghost text from the prior multi-step render.
	var rail := _make_rail()
	var multi_step: Dictionary = {
		"text": "multi",
		"action": "act",
		"key": "E",
		"steps": [
			{"text": "alpha", "state": "active"},
			{"text": "bravo", "state": "future"},
		],
	}
	EventBus.objective_changed.emit(multi_step)
	var no_steps: Dictionary = {
		"text": "no steps",
		"action": "act",
		"key": "E",
	}
	EventBus.objective_changed.emit(no_steps)
	for slot: Label in rail._step_slots:
		assert_eq(
			slot.text, "",
			"Every slot must be blanked when the payload drops the steps key"
		)
		assert_false(slot.visible)


# ── AccentBand visual weight ──────────────────────────────────────────────────
#
# The bottom AccentBand is a subtle warm separator, not a heavy strip. The rail
# must render it in the amber tone (~#E8A547) at a reduced alpha so the bottom
# of the screen does not read as a permanent debug console. Anchors stay pinned
# full-width to the bottom edge.

func test_accent_band_color_is_warm_amber() -> void:
	var rail := _make_rail()
	var band: ColorRect = rail.get_node("AccentBand") as ColorRect
	assert_not_null(band, "AccentBand node must exist on the rail")
	# Hue match against ACCENT_COLOR_AMBER (the single source of truth for the
	# warm amber tone); alpha is checked separately by the weight-reduction
	# test so this assertion stays orthogonal.
	assert_almost_eq(
		band.color.r, UIThemeConstants.ACCENT_COLOR_AMBER.r, 0.01,
		"AccentBand red channel must match ACCENT_COLOR_AMBER"
	)
	assert_almost_eq(
		band.color.g, UIThemeConstants.ACCENT_COLOR_AMBER.g, 0.01,
		"AccentBand green channel must match ACCENT_COLOR_AMBER"
	)
	assert_almost_eq(
		band.color.b, UIThemeConstants.ACCENT_COLOR_AMBER.b, 0.01,
		"AccentBand blue channel must match ACCENT_COLOR_AMBER"
	)


func test_accent_band_rendered_alpha_is_reduced() -> void:
	# Rendered alpha = color.a × modulate.a. Must sit at or below 0.55 so the
	# band reads as a subtle warm separator, not a heavy bar.
	var rail := _make_rail()
	var band: ColorRect = rail.get_node("AccentBand") as ColorRect
	var rendered_alpha: float = band.color.a * band.modulate.a
	assert_lte(
		rendered_alpha, 0.55,
		"AccentBand rendered alpha (%.3f) must sit at or below 0.55"
			% rendered_alpha
	)


func test_accent_band_remains_full_width_and_bottom_pinned() -> void:
	# Layout contract: the band spans the viewport width and pins to the
	# bottom (offsets are negative, anchored at bottom). Reducing visual weight
	# must not break the anchor geometry.
	var rail := _make_rail()
	var band: ColorRect = rail.get_node("AccentBand") as ColorRect
	assert_eq(band.anchor_left, 0.0, "AccentBand anchor_left stays at 0.0")
	assert_eq(band.anchor_right, 1.0, "AccentBand anchor_right stays at 1.0")
	assert_eq(band.anchor_top, 1.0, "AccentBand anchor_top stays at 1.0")
	assert_eq(band.anchor_bottom, 1.0, "AccentBand anchor_bottom stays at 1.0")
	assert_lt(band.offset_top, 0.0, "AccentBand offset_top stays negative (bottom-pinned)")
	assert_lte(
		band.offset_bottom, 0.0,
		"AccentBand offset_bottom stays at or above the viewport bottom"
	)


func test_accent_band_color_unchanged_by_store_entry() -> void:
	# Hub and store share the same subtle amber separator — the band is no
	# longer a per-context status indicator. Entering and exiting a store must
	# leave the rendered band color and alpha at the amber default.
	var rail := _make_rail()
	var band: ColorRect = rail.get_node("AccentBand") as ColorRect
	EventBus.store_entered.emit(&"retro_games")
	assert_almost_eq(
		band.color.r, UIThemeConstants.ACCENT_COLOR_AMBER.r, 0.01,
		"AccentBand red channel must stay amber after store_entered"
	)
	assert_lte(
		band.color.a * band.modulate.a, 0.55,
		"AccentBand rendered alpha must stay reduced after store_entered"
	)
	EventBus.store_exited.emit(&"retro_games")
	assert_almost_eq(
		band.color.r, UIThemeConstants.ACCENT_COLOR_AMBER.r, 0.01,
		"AccentBand red channel must stay amber after store_exited"
	)
	assert_lte(
		band.color.a * band.modulate.a, 0.55,
		"AccentBand rendered alpha must stay reduced after store_exited"
	)
