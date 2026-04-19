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
	_overview._day_close_button.pressed.emit()
	assert_eq(_day_close_requests, 1, "Day close button must emit day_close_requested")


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


# ── helpers ───────────────────────────────────────────────────────────────────

func _on_day_close_requested() -> void:
	_day_close_requests += 1


func _make_left_click() -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	return ev
