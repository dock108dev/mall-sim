## Tests for TrendsPanel — visibility, empty state, trend row rendering, and signal emission.
extends GutTest

const _SCENE: PackedScene = preload(
	"res://game/scenes/ui/trends_panel.tscn"
)

var _panel: TrendsPanel
var _trend_system: TrendSystem
var _game_world: Node
var _meta_shift_system: MetaShiftSystem
var _saved_day: int
var _saved_store_id: StringName = &""
var _saved_data_loader: DataLoader


func before_each() -> void:
	_saved_day = GameManager.current_day
	_saved_store_id = GameManager.current_store_id
	_saved_data_loader = GameManager.data_loader
	DataLoaderSingleton.load_all_content()
	GameManager.data_loader = DataLoaderSingleton
	GameManager.current_store_id = &"retro_games"

	_trend_system = TrendSystem.new()
	add_child_autofree(_trend_system)
	_trend_system.initialize(GameManager.data_loader)

	_panel = _SCENE.instantiate() as TrendsPanel
	_panel.trend_system = _trend_system
	add_child_autofree(_panel)


func after_each() -> void:
	if _game_world and is_instance_valid(_game_world):
		_game_world.free()
		_game_world = null
	GameManager._current_day_shadow = _saved_day
	GameManager.current_store_id = _saved_store_id
	GameManager.data_loader = _saved_data_loader


# ── Visibility ────────────────────────────────────────────────────────────────

func test_panel_hidden_on_ready() -> void:
	assert_false(_panel.visible, "Panel should be hidden on ready")


func test_open_panel_makes_visible() -> void:
	_panel.open_panel()
	assert_true(_panel.visible, "Panel should be visible after open_panel()")


func test_close_panel_hides() -> void:
	_panel.open_panel()
	_panel.close_panel()
	assert_false(_panel.visible, "Panel should be hidden after close_panel()")


func test_open_panel_is_idempotent() -> void:
	_panel.open_panel()
	_panel.open_panel()
	assert_true(_panel.visible, "Calling open_panel twice keeps panel visible")


func test_close_panel_is_idempotent() -> void:
	_panel.close_panel()
	assert_false(_panel.visible, "Calling close_panel when already closed is a no-op")


# ── Signals ───────────────────────────────────────────────────────────────────

func test_open_panel_emits_panel_opened() -> void:
	watch_signals(EventBus)
	_panel.open_panel()
	assert_signal_emitted(EventBus, "panel_opened")
	var params: Array = get_signal_parameters(EventBus, "panel_opened")
	assert_eq(params[0], TrendsPanel.PANEL_NAME, "panel_opened should carry PANEL_NAME")


func test_close_panel_emits_panel_closed() -> void:
	_panel.open_panel()
	watch_signals(EventBus)
	_panel.close_panel()
	assert_signal_emitted(EventBus, "panel_closed")
	var params: Array = get_signal_parameters(EventBus, "panel_closed")
	assert_eq(params[0], TrendsPanel.PANEL_NAME, "panel_closed should carry PANEL_NAME")


func test_open_panel_does_not_emit_twice_on_double_call() -> void:
	watch_signals(EventBus)
	_panel.open_panel()
	_panel.open_panel()
	assert_signal_emit_count(EventBus, "panel_opened", 1)


# ── Empty State ───────────────────────────────────────────────────────────────

func test_empty_state_visible_when_no_trends() -> void:
	_panel.open_panel()
	var empty_state: Label = _panel.get_node("VBoxContainer/EmptyState")
	assert_true(empty_state.visible, "Empty state label should be visible when no trends")


func test_empty_state_hidden_when_trends_present() -> void:
	_inject_hot_trend()
	_panel.open_panel()
	var empty_state: Label = _panel.get_node("VBoxContainer/EmptyState")
	assert_false(empty_state.visible, "Empty state label should be hidden when trends exist")


func test_empty_state_visible_without_trend_system() -> void:
	_panel.trend_system = null
	_panel.open_panel()
	var empty_state: Label = _panel.get_node("VBoxContainer/EmptyState")
	assert_true(empty_state.visible, "Empty state should show when trend_system is null")


# ── Trend Rows ────────────────────────────────────────────────────────────────

func test_trend_row_count_matches_active_trends() -> void:
	_inject_hot_trend()
	_panel.open_panel()
	var trend_list: VBoxContainer = _panel.get_node(
		"VBoxContainer/ScrollContainer/TrendList"
	)
	assert_eq(trend_list.get_child_count(), 1, "One row per active trend")


func test_two_trends_produce_two_rows() -> void:
	_inject_hot_trend()
	_inject_cold_trend()
	_panel.open_panel()
	var trend_list: VBoxContainer = _panel.get_node(
		"VBoxContainer/ScrollContainer/TrendList"
	)
	assert_eq(trend_list.get_child_count(), 2, "Two rows for two active trends")


# ── Placeholder Vars ──────────────────────────────────────────────────────────

func test_rest_x_placeholder_declared() -> void:
	assert_true(
		_panel._rest_x == 0.0 or _panel._rest_x is float,
		"_rest_x placeholder should be declared as float"
	)


func test_anim_tween_placeholder_starts_null() -> void:
	# TrendsPanel has no _anim_tween property — it slides via PanelAnimator without
	# holding a reference. Assert the absence so the contract is explicit.
	assert_false(
		"_anim_tween" in _panel,
		"TrendsPanel should not expose a persistent _anim_tween member"
	)


# ── Auto-refresh on Signal ────────────────────────────────────────────────────

func test_trend_changed_signal_refreshes_open_panel() -> void:
	_panel.open_panel()
	var trend_list: VBoxContainer = _panel.get_node(
		"VBoxContainer/ScrollContainer/TrendList"
	)
	assert_eq(trend_list.get_child_count(), 0, "Starts with no rows")
	_inject_hot_trend()
	EventBus.trend_changed.emit([], [])
	await get_tree().process_frame
	assert_gt(trend_list.get_child_count(), 0, "Row added after trend_changed signal")


func test_trend_changed_signal_ignored_when_panel_closed() -> void:
	_inject_hot_trend()
	EventBus.trend_changed.emit([], [])
	await get_tree().process_frame
	var trend_list: VBoxContainer = _panel.get_node(
		"VBoxContainer/ScrollContainer/TrendList"
	)
	assert_eq(trend_list.get_child_count(), 0, "Closed panel should not populate on signal")


# ── Meta Watch ────────────────────────────────────────────────────────────────

func test_meta_watch_hidden_outside_pocket_creatures() -> void:
	_create_game_world_meta_shift(false)
	_panel.open_panel()

	assert_null(
		_find_meta_watch_section(),
		"Meta Watch section should be hidden outside PocketCreatures"
	)


func test_meta_watch_shows_pending_shift_for_pocket_creatures() -> void:
	_switch_active_store(&"pocket_creatures")
	_create_game_world_meta_shift(false)

	_panel.open_panel()
	var section: VBoxContainer = _find_meta_watch_section()

	assert_not_null(
		section,
		"Meta Watch section should show in PocketCreatures stores"
	)
	assert_true(
		_section_contains_text(section, "Activates day 5"),
		"Pending shifts should show their activation day"
	)
	assert_true(
		_section_contains_text(section, "Hot Card"),
		"Rising card name should be listed"
	)
	assert_true(
		_section_contains_text(section, "base_set"),
		"Rising card set tag should be listed"
	)
	assert_true(
		_section_contains_text(section, "+150%"),
		"Rising card multiplier should be formatted as a percent spike"
	)
	assert_true(
		_section_contains_text(section, "Cold Card"),
		"Falling card name should be listed"
	)
	assert_true(
		_section_contains_text(section, "-50%"),
		"Falling card drop should be displayed as -50%"
	)


func test_meta_watch_shows_active_shift_for_pocket_creatures() -> void:
	_switch_active_store(&"pocket_creatures")
	_create_game_world_meta_shift(true)

	_panel.open_panel()
	var section: VBoxContainer = _find_meta_watch_section()

	assert_not_null(section, "Meta Watch section should be present")
	assert_true(
		_section_contains_text(section, "Active shift"),
		"Active shifts should use active status text"
	)


func test_meta_shift_announced_signal_refreshes_open_panel() -> void:
	_switch_active_store(&"pocket_creatures")
	_create_game_world_meta_shift(false)
	_panel.open_panel()
	_meta_shift_system.load_save_data({
		"rising_cards": [
			{
				"item_id": "new_hot",
				"name": "New Hot",
				"multiplier": 3.0,
				"set_tag": "fossil",
			}
		],
		"falling_cards": [],
		"active_day": 8,
		"announced_day": 6,
		"days_until_next_announcement": 9,
		"shift_active": false,
	})

	EventBus.meta_shift_announced.emit(["New Hot"], [])
	await get_tree().process_frame

	var section: VBoxContainer = _find_meta_watch_section()
	assert_not_null(section, "Meta Watch section should still be present")
	assert_true(
		_section_contains_text(section, "New Hot"),
		"meta_shift_announced should refresh Meta Watch contents"
	)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _inject_hot_trend() -> void:
	var current_day: int = GameManager.current_day
	_trend_system._active_trends.append({
		"target_type": "category",
		"target": "cartridges",
		"trend_type": TrendSystem.TrendType.HOT,
		"multiplier": 1.8,
		"announced_day": current_day - 2,
		"active_day": current_day - 1,
		"end_day": current_day + 4,
		"fade_end_day": current_day + 6,
	})


func _inject_cold_trend() -> void:
	var current_day: int = GameManager.current_day
	_trend_system._active_trends.append({
		"target_type": "category",
		"target": "consoles",
		"trend_type": TrendSystem.TrendType.COLD,
		"multiplier": 0.6,
		"announced_day": current_day - 2,
		"active_day": current_day - 1,
		"end_day": current_day + 3,
		"fade_end_day": current_day + 5,
	})


func _create_game_world_meta_shift(active: bool) -> void:
	_game_world = Node.new()
	_game_world.name = "GameWorld"
	get_tree().root.add_child(_game_world)

	_meta_shift_system = MetaShiftSystem.new()
	_meta_shift_system.name = "MetaShiftSystem"
	_game_world.add_child(_meta_shift_system)
	_meta_shift_system.load_save_data({
		"rising_cards": [
			{
				"item_id": "hot_card",
				"name": "Hot Card",
				"multiplier": 2.5,
				"set_tag": "base_set",
			}
		],
		"falling_cards": [
			{
				"item_id": "cold_card",
				"name": "Cold Card",
				"multiplier": MetaShiftSystem.DROP_MULT,
				"set_tag": "jungle",
			}
		],
		"active_day": 5,
		"announced_day": 3,
		"days_until_next_announcement": 7,
		"shift_active": active,
	})


func _switch_active_store(store_id: StringName) -> void:
	GameManager.current_store_id = store_id
	EventBus.active_store_changed.emit(store_id)


func _find_meta_watch_section() -> VBoxContainer:
	return _panel.get_node_or_null(
		"VBoxContainer/ScrollContainer/TrendList/MetaWatchSection"
	) as VBoxContainer


func _section_contains_text(node: Node, text: String) -> bool:
	if node == null:
		return false
	if node is Label and (node as Label).text == text:
		return true
	for child: Node in node.get_children():
		if _section_contains_text(child, text):
			return true
	return false
