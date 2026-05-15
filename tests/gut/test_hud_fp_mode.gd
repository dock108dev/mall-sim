## Tests for HUD.set_fp_mode — first-person layout that hides the heavy
## TopBar and surfaces static `FPCashLabel` / `FPTimeLabel` nodes anchored
## top-right. Verifies that TopBar disappears, the static FP labels mirror
## the cash / day-time signals, no node reparenting occurs, and toggling
## back restores the TopBar without leaking style overrides.
extends GutTest

const _HudScene: PackedScene = preload("res://game/scenes/ui/hud.tscn")

var _hud: CanvasLayer
var _saved_state: GameManager.State


func before_each() -> void:
	_saved_state = GameManager.current_state
	_hud = _HudScene.instantiate()
	add_child_autofree(_hud)


func after_each() -> void:
	GameManager.current_state = _saved_state


func _emit_state(new_state: GameManager.State) -> void:
	var old: GameManager.State = GameManager.current_state
	GameManager.current_state = new_state
	EventBus.game_state_changed.emit(int(old), int(new_state))


# ── TopBar visibility ─────────────────────────────────────────────────────────


func test_set_fp_mode_hides_top_bar() -> void:
	_hud.set_fp_mode(true)
	var top_bar: HBoxContainer = _hud.get_node("TopBar")
	assert_false(
		top_bar.visible,
		"TopBar HBoxContainer must be hidden when FP mode is enabled"
	)


func test_fp_mode_hides_milestones_button() -> void:
	_emit_state(GameManager.State.STORE_VIEW)
	_hud.set_fp_mode(true)
	assert_false(
		_hud._milestones_button.visible,
		"MilestonesButton must not be visible in FP mode"
	)


func test_fp_mode_hides_reputation_label() -> void:
	_emit_state(GameManager.State.STORE_VIEW)
	_hud.set_fp_mode(true)
	assert_false(
		_hud._reputation_label.visible,
		"ReputationLabel must not be visible in FP mode"
	)


func test_fp_mode_hides_speed_button() -> void:
	_emit_state(GameManager.State.STORE_VIEW)
	_hud.set_fp_mode(true)
	assert_false(
		_hud._speed_button.visible,
		"SpeedButton must not be visible in FP mode"
	)


func test_fp_mode_hides_telegraph_card() -> void:
	_hud.set_fp_mode(true)
	assert_false(
		_hud.get_node("TelegraphCard").visible,
		"TelegraphCard must be hidden in FP mode"
	)


func test_fp_mode_keeps_crosshair_visible() -> void:
	_hud.set_fp_mode(true)
	var crosshair: Node = _hud.get_node_or_null("Crosshair")
	assert_not_null(crosshair, "Crosshair must remain a child of HUD in FP mode")
	if crosshair is CanvasItem:
		assert_true(
			(crosshair as CanvasItem).visible,
			"Crosshair must remain visible in FP mode"
		)


# ── Static FP labels: presence, anchors, visibility, signal wiring ────────────


func test_fp_cash_label_present_as_canvaslayer_root_child() -> void:
	var fp_cash: Label = _hud.get_node_or_null("FPCashLabel") as Label
	assert_not_null(
		fp_cash,
		"hud.tscn must include a static FPCashLabel as a CanvasLayer-root child"
	)
	if fp_cash == null:
		return
	assert_eq(
		fp_cash.get_parent(), _hud,
		"FPCashLabel must be a direct child of the HUD CanvasLayer (no reparenting)"
	)


func test_fp_time_label_present_as_canvaslayer_root_child() -> void:
	var fp_time: Label = _hud.get_node_or_null("FPTimeLabel") as Label
	assert_not_null(
		fp_time,
		"hud.tscn must include a static FPTimeLabel as a CanvasLayer-root child"
	)
	if fp_time == null:
		return
	assert_eq(
		fp_time.get_parent(), _hud,
		"FPTimeLabel must be a direct child of the HUD CanvasLayer (no reparenting)"
	)


func test_fp_cash_label_anchored_top_right() -> void:
	var fp_cash: Label = _hud.get_node_or_null("FPCashLabel") as Label
	assert_not_null(fp_cash)
	if fp_cash == null:
		return
	assert_eq(fp_cash.anchor_left, 1.0, "FPCashLabel anchor_left at right edge")
	assert_eq(fp_cash.anchor_right, 1.0, "FPCashLabel anchor_right at right edge")
	assert_eq(fp_cash.anchor_top, 0.0, "FPCashLabel anchored to top")


func test_fp_time_label_anchored_top_right() -> void:
	var fp_time: Label = _hud.get_node_or_null("FPTimeLabel") as Label
	assert_not_null(fp_time)
	if fp_time == null:
		return
	assert_eq(fp_time.anchor_left, 1.0, "FPTimeLabel anchor_left at right edge")
	assert_eq(fp_time.anchor_right, 1.0, "FPTimeLabel anchor_right at right edge")
	assert_eq(fp_time.anchor_top, 0.0, "FPTimeLabel anchored to top")


func test_fp_labels_visible_by_default_in_tscn() -> void:
	# AC: FPCashLabel and FPTimeLabel are statically visible in hud.tscn so
	# the corner readout is always live (the same handlers drive both the
	# TopBar copies and the FP copies — no FP-mode gating required).
	var fp_cash: Label = _hud.get_node_or_null("FPCashLabel") as Label
	var fp_time: Label = _hud.get_node_or_null("FPTimeLabel") as Label
	assert_not_null(fp_cash)
	assert_not_null(fp_time)
	if fp_cash == null or fp_time == null:
		return
	assert_true(fp_cash.visible, "FPCashLabel must be visible by default")
	assert_true(fp_time.visible, "FPTimeLabel must be visible by default")


func test_fp_labels_do_not_overlap_beta_right_panel_band() -> void:
	# Vertical-stack guard: BetaRightPanel anchors at offset_top=56 on the
	# right edge. The static FP labels must sit fully above that band so the
	# two readouts read as a column rather than colliding rectangles.
	var fp_cash: Label = _hud.get_node_or_null("FPCashLabel") as Label
	var fp_time: Label = _hud.get_node_or_null("FPTimeLabel") as Label
	assert_not_null(fp_cash)
	assert_not_null(fp_time)
	if fp_cash == null or fp_time == null:
		return
	assert_lte(
		fp_cash.offset_bottom, 56.0,
		"FPCashLabel bottom edge must sit at or above the BetaRightPanel band (y=56)"
	)
	assert_lte(
		fp_time.offset_bottom, 56.0,
		"FPTimeLabel bottom edge must sit at or above the BetaRightPanel band (y=56)"
	)


func test_fp_cash_label_updates_via_money_changed() -> void:
	EventBus.money_changed.emit(0.0, 25.50)
	# Cash uses a count-up tween (~0.3 s) for the TopBar label; FPCashLabel
	# mirrors the same `_update_cash_display` write path so it lands on the
	# same final value when the tween settles.
	await get_tree().create_timer(0.45).timeout
	var fp_cash: Label = _hud.get_node_or_null("FPCashLabel") as Label
	assert_not_null(fp_cash)
	if fp_cash == null:
		return
	assert_string_contains(
		fp_cash.text, "25.50",
		"FPCashLabel must update via the same money_changed → _update_cash_display path"
	)


func test_fp_time_label_updates_via_hour_changed() -> void:
	EventBus.day_started.emit(1)
	EventBus.hour_changed.emit(11)
	var fp_time: Label = _hud.get_node_or_null("FPTimeLabel") as Label
	assert_not_null(fp_time)
	if fp_time == null:
		return
	assert_string_contains(
		fp_time.text, "11",
		"FPTimeLabel must update via the same hour_changed → _refresh_time_display path"
	)


# ── No-reparenting / no-orig-indices guarantees ──────────────────────────────


func test_top_bar_cash_label_stays_in_top_bar_after_fp_toggle() -> void:
	# Reparenting is gone: TopBar.CashLabel remains a child of TopBar at all
	# times, regardless of FP-mode state.
	_hud.set_fp_mode(true)
	assert_eq(
		_hud._cash_label.get_parent(), _hud.get_node("TopBar"),
		"TopBar.CashLabel must stay parented to TopBar in FP mode (no reparenting)"
	)
	_hud.set_fp_mode(false)
	assert_eq(
		_hud._cash_label.get_parent(), _hud.get_node("TopBar"),
		"TopBar.CashLabel must remain in TopBar after exiting FP mode"
	)


func test_top_bar_time_label_stays_in_top_bar_after_fp_toggle() -> void:
	_hud.set_fp_mode(true)
	assert_eq(
		_hud._time_label.get_parent(), _hud.get_node("TopBar"),
		"TopBar.TimeLabel must stay parented to TopBar in FP mode (no reparenting)"
	)
	_hud.set_fp_mode(false)
	assert_eq(
		_hud._time_label.get_parent(), _hud.get_node("TopBar"),
		"TopBar.TimeLabel must remain in TopBar after exiting FP mode"
	)


func test_hud_does_not_expose_fp_orig_indices_field() -> void:
	# Regression guard: the reparenting bookkeeping dictionary must not
	# linger as a property on the HUD.
	var props: Array = _hud.get_property_list()
	for entry: Dictionary in props:
		var prop_name: String = str(entry.get("name", ""))
		assert_ne(
			prop_name, "_fp_orig_indices",
			"HUD must not expose `_fp_orig_indices` after the reparenting cleanup"
		)


# ── F4 close-day hint (still spawned dynamically) ────────────────────────────


func test_fp_mode_creates_close_day_hint() -> void:
	_hud.set_fp_mode(true)
	var hint: Label = _hud.get_node_or_null("FpCloseDayHint") as Label
	assert_not_null(hint, "FP mode must add an F4 close-day hint label to HUD")
	if hint == null:
		return
	assert_true(hint.visible, "Close-day hint must be visible in FP mode")
	assert_string_contains(
		hint.text, "F4",
		"Close-day hint must surface the F4 keybinding"
	)


func test_fp_mode_hint_anchored_bottom_right() -> void:
	_hud.set_fp_mode(true)
	var hint: Label = _hud.get_node_or_null("FpCloseDayHint") as Label
	assert_not_null(hint)
	if hint == null:
		return
	assert_eq(hint.anchor_left, 1.0, "Close-day hint anchored to right edge")
	assert_eq(hint.anchor_top, 1.0, "Close-day hint anchored to bottom edge")


## Regression guard: ObjectiveRail (autoload CanvasLayer, layer 40) draws on
## top of the HUD (layer 30) and fills the bottom 68 px of the viewport. The
## F4 close-day hint must offset its bottom edge to ≤ −72 so it always sits
## above the rail's accent band, otherwise the rail buries the hint whenever
## an objective is active.
func test_fp_mode_close_day_hint_above_objective_rail() -> void:
	_hud.set_fp_mode(true)
	var hint: Label = _hud.get_node_or_null("FpCloseDayHint") as Label
	assert_not_null(hint)
	if hint == null:
		return
	assert_lt(
		hint.offset_bottom, -68.0,
		"Close-day hint bottom edge must sit above the ObjectiveRail's 68 px footprint"
	)


## Regression guard: the inventory affordance is owned by the ObjectiveRail
## (Day 1 step 0 emits the "Press I to open the inventory panel" payload with
## a key chip). A persistent corner hint here would render the same I-key
## reminder twice on Day 1 — the BRAINDUMP layout spec allows only one
## controls block per screen.
func test_fp_mode_does_not_render_duplicate_inventory_hint() -> void:
	_hud.set_fp_mode(true)
	var hint: Node = _hud.get_node_or_null("FpInventoryHint")
	assert_null(
		hint,
		"FP mode must not duplicate the ObjectiveRail's I-Inventory affordance with a corner hint"
	)


# ── Idempotence / state transitions ──────────────────────────────────────────


func test_fp_mode_idempotent_when_called_twice() -> void:
	_hud.set_fp_mode(true)
	_hud.set_fp_mode(true)
	var top_bar: HBoxContainer = _hud.get_node("TopBar")
	assert_false(
		top_bar.visible,
		"Calling set_fp_mode(true) twice must keep TopBar hidden"
	)


func test_disable_fp_mode_restores_top_bar() -> void:
	_hud.set_fp_mode(true)
	_hud.set_fp_mode(false)
	var top_bar: HBoxContainer = _hud.get_node("TopBar")
	assert_true(
		top_bar.visible,
		"TopBar must be visible again after set_fp_mode(false)"
	)


func test_disable_fp_mode_hides_close_day_hint() -> void:
	_hud.set_fp_mode(true)
	_hud.set_fp_mode(false)
	var hint: Label = _hud.get_node_or_null("FpCloseDayHint") as Label
	if hint == null:
		return
	assert_false(
		hint.visible,
		"FP close-day hint must be hidden after set_fp_mode(false)"
	)


func test_state_change_in_fp_mode_keeps_top_bar_hidden() -> void:
	# A STORE_VIEW transition normally shows TopBar children; FP mode must
	# re-assert overrides so the heavy bar does not leak back in.
	_hud.set_fp_mode(true)
	_emit_state(GameManager.State.STORE_VIEW)
	var top_bar: HBoxContainer = _hud.get_node("TopBar")
	assert_false(
		top_bar.visible,
		"TopBar must remain hidden after a STORE_VIEW transition while FP mode is on"
	)


# ── Top-center zero-state hint / FP sentence (unchanged contract) ────────────


## Top-center cluster guard: in FP mode the scene-tree ZeroStateHint at
## offset_top=52 sits below the TopBar and would visually compete with the
## bottom-bar sentence pattern. FP mode must keep that label hidden and
## route the hint copy to the bottom-center sentence slot instead.
func test_fp_mode_hides_top_center_zero_state_hint() -> void:
	_emit_state(GameManager.State.STORE_VIEW)
	_hud.set_fp_mode(true)
	_hud._items_placed_count = 0
	_hud._active_customer_count = 0
	_hud._refresh_zero_state_hint()
	var legacy_hint: Label = _hud.get_node("ZeroStateHint") as Label
	assert_false(
		legacy_hint.visible,
		"Top-center ZeroStateHint must stay hidden in FP mode"
	)


func test_fp_mode_creates_bottom_bar_sentence_label() -> void:
	_hud.set_fp_mode(true)
	var sentence: Label = _hud.get_node_or_null("FpSentenceLabel") as Label
	assert_not_null(
		sentence, "FP mode must add a bottom-bar sentence label to HUD"
	)


func test_fp_mode_sentence_anchored_bottom_center() -> void:
	_hud.set_fp_mode(true)
	var sentence: Label = _hud.get_node_or_null("FpSentenceLabel") as Label
	assert_not_null(sentence)
	if sentence == null:
		return
	assert_eq(sentence.anchor_left, 0.5, "Sentence label anchor_left at center")
	assert_eq(sentence.anchor_right, 0.5, "Sentence label anchor_right at center")
	assert_eq(sentence.anchor_top, 1.0, "Sentence label anchored to bottom edge")
	assert_eq(sentence.anchor_bottom, 1.0, "Sentence label anchored to bottom edge")
	assert_eq(
		sentence.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER,
		"Sentence label text must be horizontally centered"
	)


## Regression guard: the FP sentence must sit above the ObjectiveRail's
## AccentBand (top edge at offset_top=-148 from bottom). If the sentence
## offset_bottom is greater than -148 it overlaps the rail's content area
## and competes with the per-step rail readout.
func test_fp_mode_sentence_above_objective_rail() -> void:
	_hud.set_fp_mode(true)
	var sentence: Label = _hud.get_node_or_null("FpSentenceLabel") as Label
	assert_not_null(sentence)
	if sentence == null:
		return
	assert_lte(
		sentence.offset_bottom, -148.0,
		"Sentence bottom edge must sit at or above the ObjectiveRail AccentBand (-148)"
	)


func test_fp_mode_sentence_shows_stock_hint_when_empty_shelves() -> void:
	_emit_state(GameManager.State.STORE_VIEW)
	_hud.set_fp_mode(true)
	_hud._items_placed_count = 0
	_hud._active_customer_count = 0
	_hud._refresh_zero_state_hint()
	var sentence: Label = _hud.get_node_or_null("FpSentenceLabel") as Label
	assert_not_null(sentence)
	if sentence == null:
		return
	assert_true(
		sentence.visible,
		"Bottom-bar sentence must surface the zero-state hint in FP mode"
	)
	assert_eq(
		sentence.text, "Stock shelves to open the lane.",
		"Sentence must display the stock-floor hint when shelves are empty"
	)


func test_fp_mode_sentence_shows_waiting_hint_when_no_customers() -> void:
	_emit_state(GameManager.State.STORE_VIEW)
	_hud.set_fp_mode(true)
	_hud._items_placed_count = 4
	_hud._active_customer_count = 0
	_hud._refresh_zero_state_hint()
	var sentence: Label = _hud.get_node_or_null("FpSentenceLabel") as Label
	assert_not_null(sentence)
	if sentence == null:
		return
	assert_true(sentence.visible)
	assert_eq(
		sentence.text, "Waiting for the first customer…",
		"Sentence must display the waiting-for-customer hint once shelves are stocked"
	)


func test_fp_mode_sentence_hides_when_loop_active() -> void:
	_emit_state(GameManager.State.STORE_VIEW)
	_hud.set_fp_mode(true)
	_hud._items_placed_count = 4
	_hud._active_customer_count = 2
	_hud._refresh_zero_state_hint()
	var sentence: Label = _hud.get_node_or_null("FpSentenceLabel") as Label
	assert_not_null(sentence)
	if sentence == null:
		return
	assert_false(
		sentence.visible,
		"Sentence must hide when both shelves and customers are present"
	)


func test_disable_fp_mode_hides_bottom_bar_sentence_label() -> void:
	_hud.set_fp_mode(true)
	_hud.set_fp_mode(false)
	var sentence: Label = _hud.get_node_or_null("FpSentenceLabel") as Label
	if sentence == null:
		return
	assert_false(
		sentence.visible,
		"Bottom-bar sentence must be hidden after set_fp_mode(false)"
	)


# ── Mystery-system guard ──────────────────────────────────────────────────────


## BRAINDUMP non-negotiable: the mystery / hidden-thread system must not
## surface "meters or named mechanics" in the player-facing HUD. This guard
## walks the HUD subtree and rejects any Label whose name or text contains
## a forbidden term, so a regression that adds a thread/affinity readout
## fails immediately.
func test_fp_mode_no_player_visible_thread_or_affinity_meters() -> void:
	_hud.set_fp_mode(true)
	var forbidden: Array[String] = ["thread", "affinity", "clue"]
	var stack: Array[Node] = [_hud]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child: Node in node.get_children():
			stack.push_back(child)
		if node is Label:
			var name_lower: String = String(node.name).to_lower()
			var text_lower: String = (node as Label).text.to_lower()
			for term: String in forbidden:
				assert_false(
					name_lower.contains(term),
					"HUD label name '%s' contains forbidden mystery term '%s'" % [
						node.name, term,
					]
				)
				assert_false(
					text_lower.contains(term),
					"HUD label text '%s' contains forbidden mystery term '%s'" % [
						(node as Label).text, term,
					]
				)
