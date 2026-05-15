## Tests for the merged right-side beta panel (`BetaRightPanel`).
##
## Covers the merged surface AC:
##   - day-title header reads "DAY N — PHASE" from `BetaRunState.day` at
##     construction (no signal required to first appear).
##   - four stat rows (On Shelves / Back Room / Customers / Sold Today)
##     update from the same EventBus signals as the TopBar.
##   - "STORE" and "TODAY" section labels separate the stats block from
##     the objective checklist.
##   - all chain entries seed as rows at `_ready`: first row paints active
##     (●, amber), the rest paint future (○, muted, ~0.5 alpha).
##   - `EventBus.objective_changed` re-stamps active/future state on the
##     existing rows; no rows lift in or out.
##   - `EventBus.beta_objective_completed` flips a row to ✓ for
##     `COMPLETION_HOLD_SECONDS` and then animates a height-collapse over
##     `COLLAPSE_DURATION_SECONDS` before freeing the row.
##   - the panel has NO "Unlocked: …" or recent-events label at any
##     point — those belong to ToastNotificationUI.
##   - stays visible across FP-mode toggles (does NOT subscribe to
##     EventBus.fp_mode_changed), dims under CTX_MODAL.
extends GutTest


const _OBJECTIVES: Array[Dictionary] = [
	{
		"id": "talk_to_customer",
		"stage": "talk_to_customer",
		"label": "Day 1: Help the customer at the register.",
		"action": "Talk to the customer",
		"key": "E",
		"target_path": "BetaDayOneCustomer/Interactable",
		"time_cost_minutes": 30,
		"required": true,
	},
	{
		"id": "back_room_inventory",
		"stage": "back_room_inventory",
		"label": "Day 1: Check today's back room stock.",
		"action": "Check inventory",
		"key": "E",
		"target_path": "BetaBackroomPickup/Interactable",
		"time_cost_minutes": 30,
		"required": true,
	},
	{
		"id": "stock_shelf",
		"stage": "stock_shelf",
		"label": "Day 1: Put a few items on the used games shelf.",
		"action": "Stock the shelf",
		"key": "E",
		"target_path": "BetaRestockShelf/Interactable",
		"time_cost_minutes": 60,
		"required": true,
	},
	{
		"id": "close_day",
		"stage": "end_day",
		"label": "Day 1: Close the day at the register.",
		"action": "Close the day",
		"key": "E",
		"target_path": "BetaDayEndTrigger/Interactable",
		"time_cost_minutes": 0,
		"required": false,
	},
]


func before_each() -> void:
	InputFocus._reset_for_tests()
	BetaRunState.reset_new_run()


func _make_panel(with_objectives: bool = true) -> BetaRightPanel:
	var panel: BetaRightPanel = BetaRightPanel.new()
	if with_objectives:
		panel.set_objectives(_OBJECTIVES)
	add_child_autofree(panel)
	return panel


# ── initial visibility / seed ─────────────────────────────────────────────────

func test_panel_is_visible_at_ready_without_signals() -> void:
	var panel: BetaRightPanel = _make_panel()
	assert_true(
		panel.visible,
		"Right panel must be visible immediately after _ready"
	)


func test_header_reads_day_and_phase_at_ready() -> void:
	BetaRunState.day = 1
	var panel: BetaRightPanel = _make_panel()
	assert_eq(
		panel.get_header_text(), "DAY 1 — OPENING",
		"Header must render 'DAY N — PHASE' at _ready"
	)


func test_header_uses_betarunstate_day_at_ready() -> void:
	BetaRunState.day = 2
	var panel: BetaRightPanel = _make_panel()
	assert_true(
		panel.get_header_text().begins_with("DAY 2 —"),
		"Header must reflect BetaRunState.day at construction; got '%s'"
		% panel.get_header_text()
	)


func test_all_stat_values_start_at_zero() -> void:
	var panel: BetaRightPanel = _make_panel()
	for stat_name: String in ["On Shelves", "Back Room", "Customers", "Sold Today"]:
		assert_eq(
			panel.get_stat_value(stat_name), "0",
			"'%s' value must start at 0" % stat_name
		)


# ── merged column layout ──────────────────────────────────────────────────────

func test_column_layout_has_store_and_today_section_labels() -> void:
	# AC: the merged column contains explicit STORE and TODAY section
	# labels — they anchor the stats block and the checklist block.
	var panel: BetaRightPanel = _make_panel()
	var store: Label = panel.get_node_or_null("Panel/Column/StoreSection") as Label
	var today: Label = panel.get_node_or_null("Panel/Column/TodaySection") as Label
	assert_not_null(store, "Column must contain a 'STORE' section label")
	assert_not_null(today, "Column must contain a 'TODAY' section label")
	if store != null:
		assert_eq(store.text, "STORE", "Store section label must read 'STORE'")
	if today != null:
		assert_eq(today.text, "TODAY", "Today section label must read 'TODAY'")


func test_column_has_no_unlock_or_recent_label() -> void:
	# AC: the merged panel has no "Unlocked:" surface and no Recent
	# events section. Unlock notifications belong to ToastNotificationUI.
	var panel: BetaRightPanel = _make_panel()
	_assert_no_label_contains(panel, "Unlocked")
	_assert_no_label_contains(panel, "Recent")


func _assert_no_label_contains(root: Node, needle: String) -> void:
	for child: Node in root.get_children():
		if child is Label:
			var text: String = (child as Label).text
			assert_false(
				text.contains(needle),
				"No Label descendant may contain '%s'; found '%s' on %s"
				% [needle, text, child.get_path()]
			)
		_assert_no_label_contains(child, needle)


# ── live stat updates from EventBus ───────────────────────────────────────────

func test_shelf_count_updates_on_shelves_value() -> void:
	var panel: BetaRightPanel = _make_panel()
	EventBus.beta_shelf_count_changed.emit(7)
	await get_tree().process_frame
	assert_eq(
		panel.get_stat_value("On Shelves"), "7",
		"On Shelves must reflect beta_shelf_count_changed"
	)


func test_backroom_count_updates_back_room_value() -> void:
	var panel: BetaRightPanel = _make_panel()
	EventBus.beta_backroom_count_changed.emit(5)
	await get_tree().process_frame
	assert_eq(
		panel.get_stat_value("Back Room"), "5",
		"Back Room must reflect beta_backroom_count_changed"
	)


func test_customer_purchased_increments_customers_value() -> void:
	var panel: BetaRightPanel = _make_panel()
	EventBus.customer_purchased.emit(
		&"retro_games", &"item_x", 5.0, &"cust1"
	)
	EventBus.customer_purchased.emit(
		&"retro_games", &"item_y", 8.0, &"cust2"
	)
	await get_tree().process_frame
	assert_eq(
		panel.get_stat_value("Customers"), "2",
		"Customers must tick once per customer_purchased emission"
	)


func test_item_sold_increments_sold_today_value() -> void:
	var panel: BetaRightPanel = _make_panel()
	EventBus.item_sold.emit("item_a", 5.0, "games")
	EventBus.item_sold.emit("item_b", 9.0, "games")
	EventBus.item_sold.emit("item_c", 3.0, "games")
	await get_tree().process_frame
	assert_eq(
		panel.get_stat_value("Sold Today"), "3",
		"Sold Today must tick once per item_sold emission"
	)


# ── day reset ─────────────────────────────────────────────────────────────────

func test_day_started_updates_header_and_resets_day_counters() -> void:
	var panel: BetaRightPanel = _make_panel()
	EventBus.customer_purchased.emit(
		&"retro_games", &"item_x", 5.0, &"cust1"
	)
	EventBus.item_sold.emit("item_a", 5.0, "games")
	await get_tree().process_frame
	EventBus.beta_shelf_count_changed.emit(3)
	EventBus.day_started.emit(2)
	await get_tree().process_frame
	assert_true(
		panel.get_header_text().begins_with("DAY 2 —"),
		"Header must advance to Day 2 on day_started; got '%s'"
		% panel.get_header_text()
	)
	assert_eq(
		panel.get_stat_value("Customers"), "0",
		"Customers must reset on day_started"
	)
	assert_eq(
		panel.get_stat_value("Sold Today"), "0",
		"Sold Today must reset on day_started"
	)
	assert_eq(
		panel.get_stat_value("On Shelves"), "3",
		"Shelf count is persistent inventory state and must survive day_started"
	)


# ── checklist initial seed ────────────────────────────────────────────────────

func test_all_chain_steps_seed_at_construction() -> void:
	# AC: all four Day 1 chain steps are visible from the moment the day
	# starts — no future-step filter; future rows render at reduced alpha.
	var panel: BetaRightPanel = _make_panel()
	assert_eq(
		panel.get_visible_item_count(), _OBJECTIVES.size(),
		"All chain entries must seed as visible rows at construction"
	)


func test_first_row_paints_active_and_rest_paint_future_at_construction() -> void:
	var panel: BetaRightPanel = _make_panel()
	var first_id: StringName = StringName(str(_OBJECTIVES[0].get("id", "")))
	assert_eq(
		panel.get_item_glyph(first_id), "●",
		"First row '%s' must render the active glyph (●)" % String(first_id)
	)
	assert_eq(
		panel.get_row_state(first_id), "active",
		"First row '%s' must seed in the active state" % String(first_id)
	)
	for i: int in range(1, _OBJECTIVES.size()):
		var obj_id: StringName = StringName(str(_OBJECTIVES[i].get("id", "")))
		assert_eq(
			panel.get_item_glyph(obj_id), "○",
			"Row '%s' must render the future glyph (○) at construction" % String(obj_id)
		)
		assert_eq(
			panel.get_row_state(obj_id), "future",
			"Row '%s' must seed in the future state" % String(obj_id)
		)


func test_active_row_uses_amber_accent_color() -> void:
	# AC: active row references UIThemeConstants.ACCENT_COLOR_AMBER —
	# never a hardcoded hex or Color literal.
	var panel: BetaRightPanel = _make_panel()
	var first_id: StringName = StringName(str(_OBJECTIVES[0].get("id", "")))
	var label: Label = panel.get_node_or_null(
		"Panel/Column/Item_%s" % String(first_id)
	) as Label
	assert_not_null(label, "Active row label must exist")
	if label == null:
		return
	var color: Color = label.get_theme_color("font_color")
	assert_eq(
		color, UIThemeConstants.ACCENT_COLOR_AMBER,
		"Active row font_color must be UIThemeConstants.ACCENT_COLOR_AMBER"
	)


func test_future_rows_use_reduced_alpha() -> void:
	var panel: BetaRightPanel = _make_panel()
	var future_id: StringName = StringName(str(_OBJECTIVES[1].get("id", "")))
	var label: Label = panel.get_node_or_null(
		"Panel/Column/Item_%s" % String(future_id)
	) as Label
	assert_not_null(label, "Future row label must exist")
	if label == null:
		return
	var color: Color = label.get_theme_color("font_color")
	assert_almost_eq(
		color.a, 0.5, 0.05,
		"Future row font_color alpha must be approximately 0.5"
	)


func test_objective_changed_restamps_active_step_state() -> void:
	var panel: BetaRightPanel = _make_panel()
	EventBus.objective_changed.emit({
		"text": "Day 1: Check today's back room stock.",
		"action": "Check inventory",
		"key": "E",
		"steps": [
			{
				"id": "talk_to_customer",
				"text": "Day 1: Help the customer at the register.",
				"state": "completed",
			},
			{
				"id": "back_room_inventory",
				"text": "Day 1: Check today's back room stock.",
				"state": "active",
			},
			{
				"id": "stock_shelf",
				"text": "Day 1: Put a few items on the used games shelf.",
				"state": "future",
			},
			{
				"id": "close_day",
				"text": "Day 1: Close the day at the register.",
				"state": "future",
			},
		],
	})
	await get_tree().process_frame
	assert_eq(
		panel.get_item_glyph(&"back_room_inventory"), "●",
		"Active back-room row must repaint as ● after the chain advances"
	)
	assert_eq(
		panel.get_item_glyph(&"stock_shelf"), "○",
		"stock_shelf must stay as future (○) while still pending"
	)
	assert_eq(
		panel.get_item_glyph(&"close_day"), "○",
		"close_day must stay as future (○) while still pending"
	)


func test_objective_changed_ignores_completed_state_payload() -> void:
	# `beta_objective_completed` owns the green ✓ → hold → collapse flow;
	# a "completed" entry on `objective_changed` must not bypass that
	# flow by stamping the row directly.
	var panel: BetaRightPanel = _make_panel()
	EventBus.objective_changed.emit({
		"text": "Day 1: Check today's back room stock.",
		"steps": [
			{
				"id": "talk_to_customer",
				"text": "Day 1: Help the customer at the register.",
				"state": "completed",
			},
		],
	})
	await get_tree().process_frame
	assert_eq(
		panel.get_item_glyph(&"talk_to_customer"), "●",
		"Row state must remain active when only objective_changed reports it as completed"
	)


func test_objective_changed_matches_by_step_id_when_text_differs() -> void:
	var panel: BetaRightPanel = _make_panel()
	EventBus.objective_changed.emit({
		"text": "different copy",
		"steps": [
			{
				"id": "back_room_inventory",
				"text": "Totally different label that drifted from the chain.",
				"state": "active",
			},
		],
	})
	await get_tree().process_frame
	assert_eq(
		panel.get_item_glyph(&"back_room_inventory"), "●",
		"Row must restamp via step.id even when step.text no longer matches the chain label"
	)


func test_item_label_strips_day_one_prefix() -> void:
	# Section header already says "TODAY" — per-row copy must not echo
	# the "Day 1: ..." rail prefix.
	var panel: BetaRightPanel = _make_panel()
	var label: Label = panel.get_node_or_null(
		"Panel/Column/Item_talk_to_customer"
	) as Label
	assert_not_null(label, "Item row must exist for talk_to_customer")
	if label == null:
		return
	assert_false(
		label.text.contains("Day 1:"),
		"Per-row copy must not echo the 'Day 1:' prefix; got '%s'" % label.text
	)


# ── checklist completion → check → collapse ───────────────────────────────────

func test_completion_signal_flips_row_to_checkmark() -> void:
	var panel: BetaRightPanel = _make_panel()
	EventBus.beta_objective_completed.emit(&"talk_to_customer")
	await get_tree().process_frame
	assert_eq(
		panel.get_item_glyph(&"talk_to_customer"), "✓",
		"Row must flip to ✓ after beta_objective_completed fires"
	)


func test_completion_signal_for_unknown_id_is_a_noop() -> void:
	var panel: BetaRightPanel = _make_panel()
	var before: int = panel.get_visible_item_count()
	EventBus.beta_objective_completed.emit(&"not_a_real_objective")
	await get_tree().process_frame
	assert_eq(
		panel.get_visible_item_count(), before,
		"Unknown objective id must not affect the visible row count"
	)


func test_completed_row_collapses_after_hold_and_tween() -> void:
	# Hold for COMPLETION_HOLD_SECONDS, then animate the row's
	# custom_minimum_size.y to 0 over COLLAPSE_DURATION_SECONDS, then
	# queue_free. The row is gone after that full window.
	var panel: BetaRightPanel = _make_panel()
	EventBus.beta_objective_completed.emit(&"talk_to_customer")
	var settle: float = (
		BetaRightPanel.COMPLETION_HOLD_SECONDS
		+ BetaRightPanel.COLLAPSE_DURATION_SECONDS
		+ 0.15
	)
	await get_tree().create_timer(settle).timeout
	await get_tree().process_frame
	assert_eq(
		panel.get_item_glyph(&"talk_to_customer"), "",
		"Row must be freed off the list after the hold + collapse tween"
	)
	# The remaining three future rows are still seeded — only the
	# completed row collapses.
	assert_eq(
		panel.get_visible_item_count(), _OBJECTIVES.size() - 1,
		"Future rows must remain visible after one completion collapses"
	)


func test_collapse_animates_row_height_to_zero() -> void:
	# AC: collapse is animated — the row's custom_minimum_size.y must
	# shrink during the tween rather than dropping to 0 in one frame.
	var panel: BetaRightPanel = _make_panel()
	var label: Label = panel.get_node_or_null(
		"Panel/Column/Item_talk_to_customer"
	) as Label
	assert_not_null(label, "Row must exist before the completion signal")
	if label == null:
		return
	var natural_height: float = label.custom_minimum_size.y
	assert_gt(
		natural_height, 0.0,
		"Row must seed with a non-zero natural height"
	)
	EventBus.beta_objective_completed.emit(&"talk_to_customer")
	# Sample mid-tween: hold elapsed, partway through the collapse.
	var mid: float = (
		BetaRightPanel.COMPLETION_HOLD_SECONDS
		+ BetaRightPanel.COLLAPSE_DURATION_SECONDS * 0.5
	)
	await get_tree().create_timer(mid).timeout
	assert_true(
		is_instance_valid(label),
		"Row label must still exist mid-tween, not freed instantly"
	)
	if is_instance_valid(label):
		assert_lt(
			label.custom_minimum_size.y, natural_height,
			"Row custom_minimum_size.y must shrink during the collapse tween"
		)


func test_day_started_reseeds_full_chain() -> void:
	var panel: BetaRightPanel = _make_panel()
	EventBus.beta_objective_completed.emit(&"talk_to_customer")
	await get_tree().process_frame
	EventBus.day_started.emit(2)
	await get_tree().process_frame
	assert_eq(
		panel.get_visible_item_count(), _OBJECTIVES.size(),
		"day_started must reseed every chain entry, not just the first row"
	)
	var first_id: StringName = StringName(str(_OBJECTIVES[0].get("id", "")))
	assert_eq(
		panel.get_item_glyph(first_id), "●",
		"After day_started, the first row must reseed as the active glyph"
	)
	for i: int in range(1, _OBJECTIVES.size()):
		var obj_id: StringName = StringName(str(_OBJECTIVES[i].get("id", "")))
		assert_eq(
			panel.get_item_glyph(obj_id), "○",
			"After day_started, row '%s' must reseed as future" % String(obj_id)
		)


# ── FP mode keeps the panel visible ───────────────────────────────────────────

func test_fp_mode_changed_does_not_hide_panel() -> void:
	# The merged panel is the sole stat surface in both desktop and FP
	# modes — the HUD no longer reparents stat labels into corner
	# overlays, so there is nothing to duplicate.
	var panel: BetaRightPanel = _make_panel()
	EventBus.fp_mode_changed.emit(true)
	await get_tree().process_frame
	assert_true(
		panel.visible,
		"Right panel must remain visible when FP mode is enabled"
	)
	EventBus.fp_mode_changed.emit(false)
	await get_tree().process_frame
	assert_true(
		panel.visible,
		"Right panel must remain visible when FP mode is disabled"
	)


func test_panel_does_not_connect_fp_mode_changed() -> void:
	# BetaRightPanel must not subscribe to EventBus.fp_mode_changed at all
	# — the panel is mode-agnostic. Inspect the signal's connection list
	# and assert no entry targets this panel.
	var panel: BetaRightPanel = _make_panel()
	var connections: Array = EventBus.fp_mode_changed.get_connections()
	for entry: Dictionary in connections:
		var callable: Callable = entry.get("callable") as Callable
		assert_ne(
			callable.get_object(), panel,
			(
				"BetaRightPanel must not connect to EventBus.fp_mode_changed; "
				+ "found '%s' bound to the panel"
			) % callable.get_method()
		)


# ── modal-dim contract ────────────────────────────────────────────────────────

func test_panel_dims_under_modal_context() -> void:
	var panel: BetaRightPanel = _make_panel()
	InputFocus.push_context(InputFocus.CTX_MODAL)
	await get_tree().process_frame
	var any_dimmed: bool = false
	for child: Node in panel.get_children():
		if child is CanvasItem and (child as CanvasItem).modulate.a < 1.0:
			any_dimmed = true
			break
	assert_true(
		any_dimmed,
		"Panel children must dim when CTX_MODAL is pushed"
	)
	InputFocus.pop_context()
	await get_tree().process_frame
	for child: Node in panel.get_children():
		if child is CanvasItem:
			assert_almost_eq(
				(child as CanvasItem).modulate.a, 1.0, 0.001,
				"Panel children must restore to full alpha when modal pops"
			)
