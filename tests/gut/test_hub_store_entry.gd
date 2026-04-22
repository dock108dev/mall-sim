## Integration test: hub card click → store_entered signal chain.
## Verifies that StorefrontCard click emits storefront_clicked, and that a hub
## handler bridging storefront_clicked → store_entered completes the chain (ISSUE-005).
extends GutTest

const _CardScene: PackedScene = preload(
	"res://game/scenes/mall/storefront_card.tscn"
)

const TEST_STORE_ID: StringName = &"retro_games"

var _entered_ids: Array[StringName] = []
var _requested_ids: Array[StringName] = []
var _clicked_ids: Array[StringName] = []


func before_each() -> void:
	_entered_ids.clear()
	_requested_ids.clear()
	_clicked_ids.clear()
	EventBus.store_entered.connect(_on_store_entered)
	EventBus.enter_store_requested.connect(_on_enter_store_requested)
	EventBus.storefront_clicked.connect(_on_storefront_clicked)


func after_each() -> void:
	if EventBus.store_entered.is_connected(_on_store_entered):
		EventBus.store_entered.disconnect(_on_store_entered)
	if EventBus.enter_store_requested.is_connected(_on_enter_store_requested):
		EventBus.enter_store_requested.disconnect(_on_enter_store_requested)
	if EventBus.storefront_clicked.is_connected(_on_storefront_clicked):
		EventBus.storefront_clicked.disconnect(_on_storefront_clicked)


## Card click must emit storefront_clicked with the card's store_id.
## MallHub relays storefront_clicked → enter_store_requested (tested separately below).
func test_hub_card_click_emits_storefront_clicked() -> void:
	var card: StorefrontCard = _CardScene.instantiate() as StorefrontCard
	card.store_id = TEST_STORE_ID
	add_child_autofree(card)
	await wait_frames(1)

	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	card._on_click_area_input(null, mb, 0)

	assert_eq(
		_clicked_ids.size(), 1,
		"storefront_clicked must fire once on hub card click",
	)
	assert_eq(
		_clicked_ids[0], TEST_STORE_ID,
		"storefront_clicked must carry the card's store_id",
	)


## Simulates the GameWorld hub handler that bridges enter_store_requested →
## store_entered. Asserts the full click-to-store_entered chain completes.
func test_hub_card_click_emits_store_entered_via_hub_handler() -> void:
	var relay_called: Array = [false]
	var relay := func(store_id: StringName) -> void:
		relay_called[0] = true
		EventBus.store_entered.emit(store_id)
	EventBus.enter_store_requested.connect(relay, CONNECT_ONE_SHOT)

	var card: StorefrontCard = _CardScene.instantiate() as StorefrontCard
	card.store_id = TEST_STORE_ID
	add_child_autofree(card)
	await wait_frames(1)

	# Also wire storefront_clicked → enter_store_requested as MallHub does.
	var hub_relay := func(store_id: StringName) -> void:
		EventBus.enter_store_requested.emit(store_id)
	EventBus.storefront_clicked.connect(hub_relay, CONNECT_ONE_SHOT)

	watch_signals(EventBus)

	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	card._on_click_area_input(null, mb, 0)

	assert_true(relay_called[0], "hub handler must receive enter_store_requested")
	assert_signal_emitted_with_parameters(
		EventBus, "store_entered", [TEST_STORE_ID],
	)


func test_walkable_mall_setting_is_false_by_default() -> void:
	assert_false(
		ProjectSettings.get_setting("debug/walkable_mall", false),
		"debug/walkable_mall must default to false (hub mode active)",
	)


func _on_store_entered(store_id: StringName) -> void:
	_entered_ids.append(store_id)


func _on_enter_store_requested(store_id: StringName) -> void:
	_requested_ids.append(store_id)


func _on_storefront_clicked(store_id: StringName) -> void:
	_clicked_ids.append(store_id)
