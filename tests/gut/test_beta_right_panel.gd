## gdlint:disable=max-public-methods
## Tests for the passive right-side beta panel.
##
## Covers the compact Day panel contract:
##   - visible header and store stats seed immediately;
##   - compact stat labels render as Shelf / Stockroom / Customers / Sales;
##   - TODAY rows are passive milestones, not a second active objective rail;
##   - completions mark rows done without collapsing them;
##   - the panel stays mode-agnostic and dims under modal focus.
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


func test_panel_is_visible_at_ready_without_signals() -> void:
	var panel: BetaRightPanel = _make_panel()
	assert_true(panel.visible, "Right panel must be visible immediately")


func test_header_reads_day_and_phase_at_ready() -> void:
	BetaRunState.day = 2
	var panel: BetaRightPanel = _make_panel()
	assert_true(
		panel.get_header_text().begins_with("DAY 2 —"),
		"Header must reflect BetaRunState.day at construction"
	)


func test_compact_store_stat_rows_seed_at_zero() -> void:
	var panel: BetaRightPanel = _make_panel()
	assert_eq(panel.get_stat_value("Shelf"), "0 / 0")
	assert_eq(panel.get_stat_value("Stockroom"), "0")
	assert_eq(panel.get_stat_value("Customers"), "0")
	assert_eq(panel.get_stat_value("Sales"), "0")


func test_legacy_stat_name_aliases_still_resolve() -> void:
	var panel: BetaRightPanel = _make_panel()
	assert_eq(panel.get_stat_value("On Shelves"), panel.get_stat_value("Shelf"))
	assert_eq(panel.get_stat_value("Back Room"), panel.get_stat_value("Stockroom"))
	assert_eq(panel.get_stat_value("Sold Today"), panel.get_stat_value("Sales"))


func test_column_layout_has_store_and_today_section_labels() -> void:
	var panel: BetaRightPanel = _make_panel()
	var store: Label = panel.get_node_or_null("Panel/Column/StoreSection") as Label
	var today: Label = panel.get_node_or_null("Panel/Column/TodaySection") as Label
	assert_not_null(store, "Column must contain a STORE section label")
	assert_not_null(today, "Column must contain a TODAY section label")
	if store != null:
		assert_eq(store.text, "STORE")
	if today != null:
		assert_eq(today.text, "TODAY")


func test_column_has_no_unlock_or_recent_label() -> void:
	var panel: BetaRightPanel = _make_panel()
	_assert_no_label_contains(panel, "Unlocked")
	_assert_no_label_contains(panel, "Recent")


func test_stat_row_labels_are_compact() -> void:
	var panel: BetaRightPanel = _make_panel()
	_assert_label_contains(panel, "Shelf")
	_assert_label_contains(panel, "Stockroom")
	_assert_label_contains(panel, "Sales")
	_assert_no_label_contains(panel, "On Shelves")
	_assert_no_label_contains(panel, "Back Room")
	_assert_no_label_contains(panel, "Sold Today")


func test_shelf_stat_tracks_target_from_inventory_events() -> void:
	var panel: BetaRightPanel = _make_panel()
	EventBus.beta_backroom_count_changed.emit(5)
	await get_tree().process_frame
	assert_eq(panel.get_stat_value("Shelf"), "0 / 5")
	EventBus.beta_shelf_count_changed.emit(3)
	await get_tree().process_frame
	assert_eq(panel.get_stat_value("Shelf"), "3 / 5")


func test_backroom_count_updates_stockroom_value() -> void:
	var panel: BetaRightPanel = _make_panel()
	EventBus.beta_backroom_count_changed.emit(5)
	await get_tree().process_frame
	assert_eq(panel.get_stat_value("Stockroom"), "5")


func test_customer_purchased_increments_customers_value() -> void:
	var panel: BetaRightPanel = _make_panel()
	EventBus.customer_purchased.emit(&"retro_games", &"item_x", 5.0, &"cust1")
	EventBus.customer_purchased.emit(&"retro_games", &"item_y", 8.0, &"cust2")
	await get_tree().process_frame
	assert_eq(panel.get_stat_value("Customers"), "2")


func test_item_sold_increments_sales_value() -> void:
	var panel: BetaRightPanel = _make_panel()
	EventBus.item_sold.emit("item_a", 5.0, "games")
	EventBus.item_sold.emit("item_b", 9.0, "games")
	await get_tree().process_frame
	assert_eq(panel.get_stat_value("Sales"), "2")


func test_day_started_updates_header_resets_daily_values_and_milestones() -> void:
	var panel: BetaRightPanel = _make_panel()
	EventBus.beta_backroom_count_changed.emit(5)
	EventBus.beta_shelf_count_changed.emit(3)
	EventBus.customer_purchased.emit(&"retro_games", &"item_x", 5.0, &"cust1")
	EventBus.item_sold.emit("item_a", 5.0, "games")
	EventBus.beta_objective_completed.emit(&"talk_to_customer")
	await get_tree().process_frame
	EventBus.day_started.emit(2)
	await get_tree().process_frame
	assert_true(panel.get_header_text().begins_with("DAY 2 —"))
	assert_eq(panel.get_stat_value("Customers"), "0")
	assert_eq(panel.get_stat_value("Sales"), "0")
	assert_eq(panel.get_stat_value("Shelf"), "3 / 5")
	assert_eq(panel.get_item_glyph(&"talk_to_customer"), "•")


func test_all_day_one_milestones_seed_as_pending() -> void:
	var panel: BetaRightPanel = _make_panel()
	assert_eq(panel.get_visible_item_count(), _OBJECTIVES.size())
	for entry: Dictionary in _OBJECTIVES:
		var obj_id: StringName = StringName(str(entry.get("id", "")))
		assert_eq(panel.get_item_glyph(obj_id), "•")
		assert_eq(panel.get_row_state(obj_id), "pending")


func test_milestone_copy_is_compact_and_not_action_copy() -> void:
	var panel: BetaRightPanel = _make_panel()
	_assert_label_contains(panel, "First customer")
	_assert_label_contains(panel, "Delivery")
	_assert_label_contains(panel, "Shelf stock")
	_assert_label_contains(panel, "Close")
	_assert_no_label_contains(panel, "Talk to the customer")
	_assert_no_label_contains(panel, "Check inventory")
	_assert_no_label_contains(panel, "Stock the shelf")


func test_pending_rows_use_muted_alpha() -> void:
	var panel: BetaRightPanel = _make_panel()
	var label: Label = panel.get_node_or_null(
		"Panel/Column/Milestone_talk_to_customer"
	) as Label
	assert_not_null(label, "Pending milestone label must exist")
	if label == null:
		return
	assert_almost_eq(label.get_theme_color("font_color").a, 0.5, 0.05)


func test_objective_changed_does_not_restamp_passive_milestones() -> void:
	var panel: BetaRightPanel = _make_panel()
	EventBus.objective_changed.emit({
		"text": "Day 1: Check today's back room stock.",
		"steps": [
			{"id": "back_room_inventory", "text": "Check", "state": "active"},
		],
	})
	await get_tree().process_frame
	assert_eq(panel.get_item_glyph(&"back_room_inventory"), "•")
	assert_eq(panel.get_row_state(&"back_room_inventory"), "pending")


func test_panel_does_not_connect_objective_changed() -> void:
	var panel: BetaRightPanel = _make_panel()
	var connections: Array = EventBus.objective_changed.get_connections()
	for entry: Dictionary in connections:
		var callable: Callable = entry.get("callable") as Callable
		assert_ne(
			callable.get_object(), panel,
			"BetaRightPanel must not mirror active objective_changed payloads"
		)


func test_completion_signal_marks_row_done_without_collapsing() -> void:
	var panel: BetaRightPanel = _make_panel()
	EventBus.beta_objective_completed.emit(&"talk_to_customer")
	await get_tree().process_frame
	assert_eq(panel.get_item_glyph(&"talk_to_customer"), "✓")
	assert_eq(panel.get_row_state(&"talk_to_customer"), "completed")
	await get_tree().create_timer(2.5).timeout
	assert_eq(panel.get_visible_item_count(), _OBJECTIVES.size())


func test_completion_signal_for_unknown_id_is_a_noop() -> void:
	var panel: BetaRightPanel = _make_panel()
	var before: int = panel.get_visible_item_count()
	EventBus.beta_objective_completed.emit(&"not_a_real_objective")
	await get_tree().process_frame
	assert_eq(panel.get_visible_item_count(), before)


func test_fp_mode_changed_does_not_hide_panel() -> void:
	var panel: BetaRightPanel = _make_panel()
	EventBus.fp_mode_changed.emit(true)
	await get_tree().process_frame
	assert_true(panel.visible)
	EventBus.fp_mode_changed.emit(false)
	await get_tree().process_frame
	assert_true(panel.visible)


func test_panel_does_not_connect_fp_mode_changed() -> void:
	var panel: BetaRightPanel = _make_panel()
	var connections: Array = EventBus.fp_mode_changed.get_connections()
	for entry: Dictionary in connections:
		var callable: Callable = entry.get("callable") as Callable
		assert_ne(callable.get_object(), panel)


func test_panel_dims_under_modal_context() -> void:
	var panel: BetaRightPanel = _make_panel()
	InputFocus.push_context(InputFocus.CTX_MODAL)
	await get_tree().process_frame
	var any_dimmed: bool = false
	for child: Node in panel.get_children():
		if child is CanvasItem and (child as CanvasItem).modulate.a < 1.0:
			any_dimmed = true
			break
	assert_true(any_dimmed, "Panel children must dim under modal context")
	InputFocus.pop_context()
	await get_tree().process_frame
	for child: Node in panel.get_children():
		if child is CanvasItem:
			assert_almost_eq((child as CanvasItem).modulate.a, 1.0, 0.001)


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


func _assert_label_contains(root: Node, needle: String) -> void:
	assert_true(
		_has_label_containing(root, needle),
		"Expected a Label descendant containing '%s'" % needle
	)


func _has_label_containing(root: Node, needle: String) -> bool:
	for child: Node in root.get_children():
		if child is Label and (child as Label).text.contains(needle):
			return true
		if _has_label_containing(child, needle):
			return true
	return false
