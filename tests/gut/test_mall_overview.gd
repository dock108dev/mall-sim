## Tests mall overview scene structure and ISSUE-018 acceptance criteria.
extends GutTest

const MALL_OVERVIEW_SCENE_PATH: String = (
	"res://game/scenes/mall/mall_overview.tscn"
)
const STORE_SLOT_CARD_SCENE_PATH: String = (
	"res://game/scenes/mall/store_slot_card.tscn"
)
const FIVE_STORES: int = 5

var _overview: MallOverview = null
var _store_selected_ids: Array[StringName] = []
var _day_close_requests: int = 0


func before_each() -> void:
	_store_selected_ids.clear()
	_day_close_requests = 0
	if not EventBus.day_close_requested.is_connected(_on_day_close_requested):
		EventBus.day_close_requested.connect(_on_day_close_requested)


func after_each() -> void:
	if EventBus.day_close_requested.is_connected(_on_day_close_requested):
		EventBus.day_close_requested.disconnect(_on_day_close_requested)
	if _overview and is_instance_valid(_overview):
		_overview.queue_free()
		_overview = null


# ── scene structure ────────────────────────────────────────────────────────────

func test_mall_overview_scene_exists() -> void:
	var scene: PackedScene = load(MALL_OVERVIEW_SCENE_PATH)
	assert_not_null(scene, "mall_overview.tscn must exist at the required path")


func test_store_slot_card_scene_exists() -> void:
	var scene: PackedScene = load(STORE_SLOT_CARD_SCENE_PATH)
	assert_not_null(scene, "store_slot_card.tscn must exist at the required path")


func test_mall_overview_is_mall_overview_class() -> void:
	var scene: PackedScene = load(MALL_OVERVIEW_SCENE_PATH)
	assert_not_null(scene)
	var inst: MallOverview = scene.instantiate() as MallOverview
	assert_not_null(inst, "Root node must be MallOverview")
	inst.queue_free()


func test_mall_overview_has_store_grid() -> void:
	var scene: PackedScene = load(MALL_OVERVIEW_SCENE_PATH)
	var state: SceneState = scene.get_state()
	var found: bool = false
	for i: int in range(state.get_node_count()):
		if state.get_node_name(i) == &"StoreGrid":
			found = true
			break
	assert_true(found, "mall_overview.tscn must contain a StoreGrid node")


func test_mall_overview_has_day_close_button() -> void:
	var scene: PackedScene = load(MALL_OVERVIEW_SCENE_PATH)
	var state: SceneState = scene.get_state()
	var found: bool = false
	for i: int in range(state.get_node_count()):
		if state.get_node_name(i) == &"DayCloseButton":
			found = true
			break
	assert_true(found, "mall_overview.tscn must contain a DayCloseButton node")


func test_store_slot_card_has_alert_badge() -> void:
	var scene: PackedScene = load(STORE_SLOT_CARD_SCENE_PATH)
	var state: SceneState = scene.get_state()
	var found: bool = false
	for i: int in range(state.get_node_count()):
		if state.get_node_name(i) == &"AlertBadge":
			found = true
			break
	assert_true(found, "store_slot_card.tscn must contain an AlertBadge node")


# ── StoreSlotCard unit ─────────────────────────────────────────────────────────

func test_store_slot_card_emits_store_selected() -> void:
	var card: StoreSlotCard = (
		load(STORE_SLOT_CARD_SCENE_PATH).instantiate() as StoreSlotCard
	)
	add_child_autofree(card)
	var received: Array[StringName] = []
	card.store_selected.connect(func(sid: StringName) -> void: received.append(sid))
	card.setup(&"retro_games", "Retro Games")
	card._gui_input(_make_left_click())
	assert_eq(received.size(), 1, "store_selected must fire once on left-click")
	assert_eq(received[0], &"retro_games")


func test_store_slot_card_alert_hidden_when_stock_adequate() -> void:
	var card: StoreSlotCard = (
		load(STORE_SLOT_CARD_SCENE_PATH).instantiate() as StoreSlotCard
	)
	add_child_autofree(card)
	card.setup(&"retro_games", "Retro Games")
	card.update_stock(5)
	assert_false(
		card._alert_badge.visible,
		"Alert badge must be hidden when stock >= 3"
	)


func test_store_slot_card_alert_visible_when_low_stock() -> void:
	var card: StoreSlotCard = (
		load(STORE_SLOT_CARD_SCENE_PATH).instantiate() as StoreSlotCard
	)
	add_child_autofree(card)
	card.setup(&"retro_games", "Retro Games")
	card.update_stock(2)
	assert_true(
		card._alert_badge.visible,
		"Alert badge must be visible when stock < 3"
	)


func test_store_slot_card_alert_visible_when_event_pending() -> void:
	var card: StoreSlotCard = (
		load(STORE_SLOT_CARD_SCENE_PATH).instantiate() as StoreSlotCard
	)
	add_child_autofree(card)
	card.setup(&"retro_games", "Retro Games")
	card.update_stock(10)
	card.set_event_pending(true)
	assert_true(
		card._alert_badge.visible,
		"Alert badge must be visible when an event is pending"
	)


func test_store_slot_card_alert_hidden_after_event_cleared() -> void:
	var card: StoreSlotCard = (
		load(STORE_SLOT_CARD_SCENE_PATH).instantiate() as StoreSlotCard
	)
	add_child_autofree(card)
	card.setup(&"retro_games", "Retro Games")
	card.update_stock(10)
	card.set_event_pending(true)
	card.set_event_pending(false)
	assert_false(
		card._alert_badge.visible,
		"Alert badge must be hidden once event_pending is cleared"
	)


func test_store_slot_card_revenue_label_updates() -> void:
	var card: StoreSlotCard = (
		load(STORE_SLOT_CARD_SCENE_PATH).instantiate() as StoreSlotCard
	)
	add_child_autofree(card)
	card.setup(&"retro_games", "Retro Games")
	card.update_revenue(123.0)
	assert_eq(card._revenue_label.text, "$123")


# ── MallOverview signal behaviour ─────────────────────────────────────────────

func test_day_close_button_emits_event_bus_signal() -> void:
	_overview = load(MALL_OVERVIEW_SCENE_PATH).instantiate() as MallOverview
	add_child_autofree(_overview)
	GameManager.set_current_day(2)
	GameState.set_flag(&"first_sale_complete", false)
	_overview._day_close_button.pressed.emit()
	assert_eq(_day_close_requests, 1, "Day close button must emit day_close_requested")


# ── Day 1 close gate ──────────────────────────────────────────────────────────

func test_day_close_gated_on_day1_before_first_sale() -> void:
	_overview = load(MALL_OVERVIEW_SCENE_PATH).instantiate() as MallOverview
	add_child_autofree(_overview)
	GameManager.set_current_day(1)
	GameState.set_flag(&"first_sale_complete", false)
	watch_signals(EventBus)
	_overview._day_close_button.pressed.emit()
	assert_eq(
		_day_close_requests,
		0,
		"Day close must not emit day_close_requested on Day 1 before first sale"
	)
	assert_signal_emitted(
		EventBus,
		"critical_notification_requested",
		"Gate must surface a critical notification on Day 1 before first sale"
	)


func test_day_close_passes_on_day1_after_first_sale() -> void:
	_overview = load(MALL_OVERVIEW_SCENE_PATH).instantiate() as MallOverview
	add_child_autofree(_overview)
	GameManager.set_current_day(1)
	GameState.set_flag(&"first_sale_complete", true)
	_overview._day_close_button.pressed.emit()
	assert_eq(
		_day_close_requests,
		1,
		"Day close must emit day_close_requested on Day 1 once first sale is complete"
	)


func test_day_close_passes_on_day_two_unconditionally() -> void:
	_overview = load(MALL_OVERVIEW_SCENE_PATH).instantiate() as MallOverview
	add_child_autofree(_overview)
	GameManager.set_current_day(2)
	GameState.set_flag(&"first_sale_complete", false)
	_overview._day_close_button.pressed.emit()
	assert_eq(
		_day_close_requests,
		1,
		"Day close must emit day_close_requested on Day 2+ regardless of flag"
	)


func test_store_exited_shows_overview() -> void:
	_overview = load(MALL_OVERVIEW_SCENE_PATH).instantiate() as MallOverview
	add_child_autofree(_overview)
	_overview.visible = false
	EventBus.store_exited.emit(&"retro_games")
	assert_true(_overview.visible, "Overview must become visible on store_exited")


func test_store_entered_hides_overview() -> void:
	_overview = load(MALL_OVERVIEW_SCENE_PATH).instantiate() as MallOverview
	add_child_autofree(_overview)
	_overview.visible = true
	EventBus.store_entered.emit(&"retro_games")
	assert_false(_overview.visible, "Overview must become hidden on store_entered")


# ── StoreSlotCard reputation and locked state ─────────────────────────────────

func test_store_slot_card_has_rep_badge() -> void:
	var scene: PackedScene = load(STORE_SLOT_CARD_SCENE_PATH)
	var state: SceneState = scene.get_state()
	var found: bool = false
	for i: int in range(state.get_node_count()):
		if state.get_node_name(i) == &"RepBadge":
			found = true
			break
	assert_true(found, "store_slot_card.tscn must contain a RepBadge node")


func test_store_slot_card_has_locked_overlay() -> void:
	var scene: PackedScene = load(STORE_SLOT_CARD_SCENE_PATH)
	var state: SceneState = scene.get_state()
	var found: bool = false
	for i: int in range(state.get_node_count()):
		if state.get_node_name(i) == &"LockedOverlay":
			found = true
			break
	assert_true(found, "store_slot_card.tscn must contain a LockedOverlay node")


func test_store_slot_card_rep_badge_updates() -> void:
	var card: StoreSlotCard = (
		load(STORE_SLOT_CARD_SCENE_PATH).instantiate() as StoreSlotCard
	)
	add_child_autofree(card)
	card.setup(&"retro_games", "Retro Games")
	card.set_reputation_tier("REPUTABLE")
	assert_eq(card._rep_badge.text, "REPUTABLE")


func test_store_slot_card_locked_shows_overlay() -> void:
	var card: StoreSlotCard = (
		load(STORE_SLOT_CARD_SCENE_PATH).instantiate() as StoreSlotCard
	)
	add_child_autofree(card)
	card.setup(&"pocket_creatures", "Pocket Creatures")
	card.set_locked(true, "REP 25 | $500")
	assert_true(card._locked_overlay.visible, "LockedOverlay must be visible when locked")
	assert_string_contains(card._locked_overlay.text, "LOCKED")
	assert_string_contains(card._locked_overlay.text, "REP 25")


func test_store_slot_card_locked_hides_rep_badge() -> void:
	var card: StoreSlotCard = (
		load(STORE_SLOT_CARD_SCENE_PATH).instantiate() as StoreSlotCard
	)
	add_child_autofree(card)
	card.setup(&"pocket_creatures", "Pocket Creatures")
	card.set_reputation_tier("UNREMARKABLE")
	card.set_locked(true, "REP 25 | $500")
	assert_false(card._rep_badge.visible, "RepBadge must be hidden when card is locked")


func test_store_slot_card_locked_blocks_click() -> void:
	var card: StoreSlotCard = (
		load(STORE_SLOT_CARD_SCENE_PATH).instantiate() as StoreSlotCard
	)
	add_child_autofree(card)
	var received: Array[StringName] = []
	card.store_selected.connect(func(sid: StringName) -> void: received.append(sid))
	card.setup(&"pocket_creatures", "Pocket Creatures")
	card.set_locked(true, "")
	card._gui_input(_make_left_click())
	assert_eq(received.size(), 0, "Locked card must not emit store_selected on click")


func test_store_slot_card_unlocked_shows_rep_badge_hides_overlay() -> void:
	var card: StoreSlotCard = (
		load(STORE_SLOT_CARD_SCENE_PATH).instantiate() as StoreSlotCard
	)
	add_child_autofree(card)
	card.setup(&"retro_games", "Retro Games")
	card.set_locked(true, "")
	card.set_locked(false, "")
	assert_false(card._locked_overlay.visible, "LockedOverlay must be hidden when unlocked")
	assert_true(card._rep_badge.visible, "RepBadge must be visible when unlocked")


# ── MallOverview event feed ───────────────────────────────────────────────────

func test_mall_overview_has_event_feed_scroll() -> void:
	var scene: PackedScene = load(MALL_OVERVIEW_SCENE_PATH)
	var state: SceneState = scene.get_state()
	var found: bool = false
	for i: int in range(state.get_node_count()):
		if state.get_node_name(i) == &"EventFeedScroll":
			found = true
			break
	assert_true(found, "mall_overview.tscn must contain an EventFeedScroll node")


func test_mall_overview_has_event_feed() -> void:
	var scene: PackedScene = load(MALL_OVERVIEW_SCENE_PATH)
	var state: SceneState = scene.get_state()
	var found: bool = false
	for i: int in range(state.get_node_count()):
		if state.get_node_name(i) == &"EventFeed":
			found = true
			break
	assert_true(found, "mall_overview.tscn must contain an EventFeed node")


func test_event_feed_appends_entry_on_day_started() -> void:
	_overview = load(MALL_OVERVIEW_SCENE_PATH).instantiate() as MallOverview
	add_child_autofree(_overview)
	var feed: VBoxContainer = _overview._event_feed
	var before: int = feed.get_child_count()
	EventBus.day_started.emit(3)
	assert_gt(feed.get_child_count(), before, "Feed must grow after day_started")


func test_event_feed_appends_entry_on_market_event() -> void:
	_overview = load(MALL_OVERVIEW_SCENE_PATH).instantiate() as MallOverview
	add_child_autofree(_overview)
	var feed: VBoxContainer = _overview._event_feed
	EventBus.market_event_triggered.emit(
		&"boom", &"retro_games", {}
	)
	assert_gt(feed.get_child_count(), 0, "Feed must show market event entry")


func test_event_feed_appends_entry_on_milestone_reached() -> void:
	_overview = load(MALL_OVERVIEW_SCENE_PATH).instantiate() as MallOverview
	add_child_autofree(_overview)
	var feed: VBoxContainer = _overview._event_feed
	EventBus.milestone_reached.emit(&"first_sale")
	assert_gt(feed.get_child_count(), 0, "Feed must show milestone entry")


func test_event_feed_caps_at_ten_entries() -> void:
	_overview = load(MALL_OVERVIEW_SCENE_PATH).instantiate() as MallOverview
	add_child_autofree(_overview)
	# Fire 15 events to exceed the cap.
	for i: int in range(15):
		EventBus.day_started.emit(i + 1)
	assert_lte(
		_overview._event_feed.get_child_count(),
		10,
		"Event feed must not exceed 10 entries"
	)


# ── Completion button (ISSUE-019) ─────────────────────────────────────────────

func test_mall_overview_has_completion_button() -> void:
	var scene: PackedScene = load(MALL_OVERVIEW_SCENE_PATH)
	var state: SceneState = scene.get_state()
	var found: bool = false
	for i: int in range(state.get_node_count()):
		if state.get_node_name(i) == &"CompletionButton":
			found = true
			break
	assert_true(found, "mall_overview.tscn must contain a CompletionButton node")


func test_completion_button_emits_toggle_signal() -> void:
	_overview = load(MALL_OVERVIEW_SCENE_PATH).instantiate() as MallOverview
	add_child_autofree(_overview)
	watch_signals(EventBus)
	_overview._completion_button.pressed.emit()
	assert_signal_emitted(
		EventBus,
		"toggle_completion_tracker_panel",
		"Completion button must emit toggle_completion_tracker_panel"
	)


# ── ISSUE-005: locked card does not emit enter_store_requested ─────────────────

func test_locked_card_click_does_not_emit_enter_store_requested() -> void:
	_overview = load(MALL_OVERVIEW_SCENE_PATH).instantiate() as MallOverview
	add_child_autofree(_overview)
	var locked_ids: Array[StringName] = [
		&"sports_memorabilia",
		&"video_rental",
		&"pocket_creatures",
		&"consumer_electronics",
	]
	for store_id: StringName in locked_ids:
		var card: StoreSlotCard = (
			load(STORE_SLOT_CARD_SCENE_PATH).instantiate() as StoreSlotCard
		)
		add_child_autofree(card)
		card.setup(store_id, String(store_id))
		card.set_locked(true, "REP 5 | $200")
		card.store_selected.connect(_overview._on_card_store_selected)
		watch_signals(EventBus)
		card._gui_input(_make_left_click())
		assert_signal_not_emitted(
			EventBus,
			"enter_store_requested",
			"Locked card %s must not emit enter_store_requested" % store_id
		)


func test_unlocked_card_click_emits_enter_store_requested() -> void:
	_overview = load(MALL_OVERVIEW_SCENE_PATH).instantiate() as MallOverview
	add_child_autofree(_overview)
	var card: StoreSlotCard = (
		load(STORE_SLOT_CARD_SCENE_PATH).instantiate() as StoreSlotCard
	)
	add_child_autofree(card)
	card.setup(&"retro_games", "Retro Games")
	card.set_locked(false, "")
	card.store_selected.connect(_overview._on_card_store_selected)
	watch_signals(EventBus)
	card._gui_input(_make_left_click())
	assert_signal_emitted(
		EventBus,
		"enter_store_requested",
		"Unlocked retro_games card must emit enter_store_requested"
	)


# ── helpers ───────────────────────────────────────────────────────────────────

func _on_day_close_requested() -> void:
	_day_close_requests += 1


func _make_left_click() -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	return ev
