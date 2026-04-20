## Verifies Phase 1 mall hub scene structure and StorefrontCard click wiring.
## Uses SceneState inspection rather than instantiation so the test does not
## boot the full game_world child systems.
extends GutTest

const MALL_HUB_SCENE: PackedScene = preload(
	"res://game/scenes/mall/mall_hub.tscn"
)
const STOREFRONT_CARD_SCENE: PackedScene = preload(
	"res://game/scenes/mall/storefront_card.tscn"
)

const EXPECTED_STORE_IDS: Array[StringName] = [
	&"retro_games",
	&"pocket_creatures",
	&"rentals",
	&"electronics",
	&"sports",
]


func _collect_node_names(scene: PackedScene) -> Array[StringName]:
	var state: SceneState = scene.get_state()
	var names: Array[StringName] = []
	for i: int in range(state.get_node_count()):
		names.append(state.get_node_name(i))
	return names


func _get_node_property(
	state: SceneState, node_idx: int, prop_name: StringName,
) -> Variant:
	for pi: int in range(state.get_node_property_count(node_idx)):
		if state.get_node_property_name(node_idx, pi) == prop_name:
			return state.get_node_property_value(node_idx, pi)
	return null


func test_gameplay_scene_path_points_at_mall_hub() -> void:
	assert_eq(
		GameManager.GAMEPLAY_SCENE_PATH,
		"res://game/scenes/mall/mall_hub.tscn",
		"GameManager must transition to mall_hub.tscn after boot",
	)


func test_event_bus_declares_storefront_clicked_signal() -> void:
	assert_true(
		EventBus.has_signal("storefront_clicked"),
		"EventBus must declare storefront_clicked signal",
	)


func test_mall_hub_has_five_storefront_cards_one_per_store() -> void:
	var state: SceneState = MALL_HUB_SCENE.get_state()
	var card_script_path: String = (
		"res://game/scenes/mall/storefront_card.gd"
	)
	var seen_store_ids: Array[StringName] = []
	var card_count: int = 0

	for i: int in range(state.get_node_count()):
		var instance_scene: PackedScene = state.get_node_instance(i)
		if instance_scene != STOREFRONT_CARD_SCENE:
			continue
		card_count += 1
		var store_id: Variant = _get_node_property(state, i, &"store_id")
		if store_id != null:
			seen_store_ids.append(StringName(store_id))

	assert_eq(card_count, 5, "mall_hub.tscn must host five StorefrontCards")
	for expected: StringName in EXPECTED_STORE_IDS:
		assert_true(
			expected in seen_store_ids,
			"mall_hub.tscn missing StorefrontCard for %s" % expected,
		)


func test_mall_hub_has_no_player_avatar_node() -> void:
	var names: Array[StringName] = _collect_node_names(MALL_HUB_SCENE)
	assert_false(
		&"Player" in names,
		"mall_hub.tscn must not contain a Player avatar node",
	)
	var state: SceneState = MALL_HUB_SCENE.get_state()
	for i: int in range(state.get_node_count()):
		var instance: PackedScene = state.get_node_instance(i)
		if instance == null:
			continue
		assert_ne(
			instance.resource_path,
			"res://game/scenes/player/player.tscn",
			"mall_hub.tscn must not instance player.tscn",
		)
		assert_ne(
			instance.resource_path,
			"res://game/scenes/player/player_controller.tscn",
			"mall_hub.tscn must not instance player_controller.tscn",
		)


func test_storefront_card_has_area2d_and_subviewport() -> void:
	var names: Array[StringName] = _collect_node_names(STOREFRONT_CARD_SCENE)
	assert_true(
		&"ClickArea" in names,
		"StorefrontCard must expose a ClickArea (Area2D) for click input",
	)
	assert_true(
		&"Diorama" in names,
		"StorefrontCard must host a Diorama SubViewport",
	)
	assert_true(
		&"StockBar" in names,
		"StorefrontCard diorama must contain a StockBar",
	)
	assert_true(
		&"ReputationPips" in names,
		"StorefrontCard diorama must contain ReputationPips",
	)
	assert_true(
		&"IdleCustomer" in names,
		"StorefrontCard diorama must contain an IdleCustomer sprite",
	)


func test_storefront_card_emits_storefront_clicked_on_left_click() -> void:
	var card: StorefrontCard = STOREFRONT_CARD_SCENE.instantiate() as StorefrontCard
	card.store_id = &"retro_games"
	add_child_autofree(card)
	await wait_frames(1)
	watch_signals(EventBus)

	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	card._on_click_area_input(null, click, 0)

	assert_signal_emitted_with_parameters(
		EventBus, "storefront_clicked", [&"retro_games"],
	)
