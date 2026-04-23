## Tests for CompletionTrackerPanel — visibility, empty state, row rendering,
## and live refresh on tracker-input EventBus signals (ISSUE-022).
extends GutTest

const _SCENE: PackedScene = preload(
	"res://game/scenes/ui/completion_tracker_panel.tscn"
)

var _panel: CompletionTrackerPanel
var _tracker: CompletionTracker
var _data_loader: DataLoader


func before_each() -> void:
	_data_loader = DataLoader.new()
	_data_loader.load_all_content()
	_tracker = CompletionTracker.new()
	add_child_autofree(_tracker)
	_tracker.initialize(_data_loader)

	_panel = _SCENE.instantiate() as CompletionTrackerPanel
	_panel.completion_tracker = _tracker
	add_child_autofree(_panel)


# ── Visibility ────────────────────────────────────────────────────────────────

func test_panel_hidden_on_ready() -> void:
	assert_false(
		_panel._panel.visible,
		"Panel root should be hidden on ready"
	)


func test_open_panel_shows_root() -> void:
	_panel.open_panel()
	assert_true(_panel.is_open(), "Panel reports open")
	assert_true(_panel._panel.visible, "Panel root visible after open")


func test_close_panel_hides_root() -> void:
	_panel.open_panel()
	_panel.close_panel()
	assert_false(_panel.is_open(), "Panel reports closed")
	assert_false(_panel._panel.visible, "Panel root hidden after close")


func test_toggle_opens_then_closes() -> void:
	_panel.toggle()
	assert_true(_panel.is_open())
	_panel.toggle()
	assert_false(_panel.is_open())


# ── Signals ───────────────────────────────────────────────────────────────────

func test_open_emits_panel_opened() -> void:
	watch_signals(EventBus)
	_panel.open_panel()
	assert_signal_emitted(EventBus, "panel_opened")
	var params: Array = get_signal_parameters(EventBus, "panel_opened")
	assert_eq(params[0], CompletionTrackerPanel.PANEL_NAME)


func test_close_emits_panel_closed() -> void:
	_panel.open_panel()
	watch_signals(EventBus)
	_panel.close_panel()
	assert_signal_emitted(EventBus, "panel_closed")


func test_toggle_completion_tracker_panel_signal_opens_panel() -> void:
	EventBus.toggle_completion_tracker_panel.emit()
	assert_true(_panel.is_open(), "Hub-routed toggle should open panel")


# ── Rendering ─────────────────────────────────────────────────────────────────

func test_open_renders_one_row_per_criterion() -> void:
	_panel.open_panel()
	var grid: VBoxContainer = _panel._grid
	# Tracker emits 14 criteria; each criterion adds a row + separator.
	var criteria: Array[Dictionary] = _tracker.get_completion_data()
	assert_eq(
		grid.get_child_count(),
		criteria.size() * 2,
		"One HBox + one HSeparator per criterion"
	)


func test_summary_reflects_completed_count() -> void:
	_panel.open_panel()
	assert_string_contains(_panel._summary.text, "0 /")


func test_states_use_locked_in_progress_complete_vocabulary() -> void:
	# Drive some progress: 2 stores leased → "In progress" for
	# `all_5_stores_opened`. Others still locked.
	EventBus.store_leased.emit(0, "sports_memorabilia")
	EventBus.store_leased.emit(1, "retro_games")
	_panel.open_panel()
	var found_in_progress: bool = false
	var found_locked: bool = false
	for child: Node in _panel._grid.get_children():
		var row: HBoxContainer = child as HBoxContainer
		if row == null:
			continue
		var state_label: Label = row.get_child(row.get_child_count() - 1) as Label
		if state_label == null:
			continue
		if state_label.text == CompletionTrackerPanel.STATE_IN_PROGRESS:
			found_in_progress = true
		elif state_label.text == CompletionTrackerPanel.STATE_LOCKED:
			found_locked = true
	assert_true(found_in_progress, "At least one row should read 'In progress'")
	assert_true(found_locked, "At least one row should read 'Locked'")


# ── Empty state ───────────────────────────────────────────────────────────────

func test_empty_state_visible_when_tracker_null() -> void:
	_panel.completion_tracker = null
	_panel.open_panel()
	assert_true(
		_panel._empty_state.visible,
		"Empty state label shown when no tracker is attached"
	)
	assert_eq(
		_panel._grid.get_child_count(),
		0,
		"Grid should be empty when no criteria"
	)


func test_empty_state_hidden_when_criteria_present() -> void:
	_panel.open_panel()
	assert_false(
		_panel._empty_state.visible,
		"Empty state hidden when tracker returns criteria"
	)


# ── Live refresh ──────────────────────────────────────────────────────────────

func test_refreshes_on_tracker_signal_while_open() -> void:
	_panel.open_panel()
	# Initial state: first criterion `all_5_stores_opened` has 0 / 5.
	var first_row: HBoxContainer = _panel._grid.get_child(0) as HBoxContainer
	assert_not_null(first_row)
	var progress_label: Label = first_row.get_child(1) as Label
	assert_string_contains(progress_label.text, "0 /")

	# Emit a tracked signal — tracker updates first, then panel refreshes.
	EventBus.store_leased.emit(0, "sports_memorabilia")

	var refreshed_row: HBoxContainer = _panel._grid.get_child(0) as HBoxContainer
	var refreshed_progress: Label = refreshed_row.get_child(1) as Label
	assert_string_contains(
		refreshed_progress.text,
		"1 /",
		"Panel should reflect new tracker state after EventBus signal"
	)


func test_does_not_refresh_when_closed() -> void:
	# Emit before opening. Open later and verify the state is current, not
	# a stale cached render (guards against double-refresh bugs).
	EventBus.store_leased.emit(0, "sports_memorabilia")
	_panel.open_panel()
	var first_row: HBoxContainer = _panel._grid.get_child(0) as HBoxContainer
	var progress_label: Label = first_row.get_child(1) as Label
	assert_string_contains(progress_label.text, "1 /")
