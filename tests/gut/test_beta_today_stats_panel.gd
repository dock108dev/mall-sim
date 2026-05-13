## Tests for the right-anchored beta Day-1 stats panel
## (`BetaTodayStatsPanel`).
##
## Covers the AC for the right-side surface: panel renders the current
## day + phase header, four live stat rows (On Shelves, Back Room,
## Customers, Sold Today) all updating from the same EventBus signals as
## the TopBar, hides in FP mode, dims under CTX_MODAL, and seeds its
## state at `_ready` (no signal required to first appear).
extends GutTest


func before_each() -> void:
	InputFocus._reset_for_tests()
	BetaRunState.reset_new_run()


func _make_panel() -> BetaTodayStatsPanel:
	var panel: BetaTodayStatsPanel = BetaTodayStatsPanel.new()
	add_child_autofree(panel)
	return panel


# ── initial visibility / seed ─────────────────────────────────────────────────

func test_panel_is_visible_at_ready_without_signals() -> void:
	# AC: visible from Day 1 start without requiring a player interaction
	# or an external signal to first appear.
	var panel: BetaTodayStatsPanel = _make_panel()
	assert_true(
		panel.visible,
		"Stats panel must be visible immediately after _ready"
	)


func test_header_reads_day_and_phase_at_ready() -> void:
	# AC: header renders 'DAY N — PHASE' with the current day from
	# BetaRunState.day. Initial phase is PRE_OPEN, which the panel maps
	# to the 'OPENING' label.
	BetaRunState.day = 1
	var panel: BetaTodayStatsPanel = _make_panel()
	assert_eq(
		panel.get_header_text(), "DAY 1 — OPENING",
		"Header must render 'DAY N — PHASE' at _ready"
	)


func test_header_uses_betarunstate_day_at_ready() -> void:
	# Day 2 seed — the panel reads BetaRunState.day on construction so
	# the day number is correct before any day_started fires.
	BetaRunState.day = 2
	var panel: BetaTodayStatsPanel = _make_panel()
	assert_true(
		panel.get_header_text().begins_with("DAY 2 —"),
		"Header must reflect BetaRunState.day at construction; got '%s'"
		% panel.get_header_text()
	)


func test_all_stat_values_start_at_zero() -> void:
	var panel: BetaTodayStatsPanel = _make_panel()
	for stat_name: String in ["On Shelves", "Back Room", "Customers", "Sold Today"]:
		assert_eq(
			panel.get_stat_value(stat_name), "0",
			"'%s' value must start at 0" % stat_name
		)


# ── live updates from EventBus ────────────────────────────────────────────────

func test_shelf_count_updates_on_shelves_value() -> void:
	var panel: BetaTodayStatsPanel = _make_panel()
	EventBus.beta_shelf_count_changed.emit(7)
	await get_tree().process_frame
	assert_eq(
		panel.get_stat_value("On Shelves"), "7",
		"On Shelves must reflect beta_shelf_count_changed"
	)


func test_backroom_count_updates_back_room_value() -> void:
	var panel: BetaTodayStatsPanel = _make_panel()
	EventBus.beta_backroom_count_changed.emit(5)
	await get_tree().process_frame
	assert_eq(
		panel.get_stat_value("Back Room"), "5",
		"Back Room must reflect beta_backroom_count_changed"
	)


func test_customer_purchased_increments_customers_value() -> void:
	var panel: BetaTodayStatsPanel = _make_panel()
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
	var panel: BetaTodayStatsPanel = _make_panel()
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
	var panel: BetaTodayStatsPanel = _make_panel()
	EventBus.customer_purchased.emit(
		&"retro_games", &"item_x", 5.0, &"cust1"
	)
	EventBus.item_sold.emit("item_a", 5.0, "games")
	await get_tree().process_frame
	# Now roll the day — per-day counters reset, persistent inventory
	# counters do not.
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


# ── FP mode hides the panel ───────────────────────────────────────────────────

func test_fp_mode_changed_hides_panel() -> void:
	var panel: BetaTodayStatsPanel = _make_panel()
	EventBus.fp_mode_changed.emit(true)
	await get_tree().process_frame
	assert_false(
		panel.visible,
		"Stats panel must hide when FP mode is enabled"
	)
	EventBus.fp_mode_changed.emit(false)
	await get_tree().process_frame
	assert_true(
		panel.visible,
		"Stats panel must re-show when FP mode is disabled"
	)


# ── modal-dim contract ────────────────────────────────────────────────────────

func test_panel_dims_under_modal_context() -> void:
	var panel: BetaTodayStatsPanel = _make_panel()
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
