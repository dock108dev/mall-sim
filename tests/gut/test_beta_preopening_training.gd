extends GutTest

const SCENE_PATH: String = "res://game/scenes/stores/retro_games.tscn"

var _root: Node3D


func before_each() -> void:
	BetaRunState.reset_new_run()
	InputFocus._reset_for_tests()
	ModalQueue._reset_for_tests()
	var scene: PackedScene = load(SCENE_PATH)
	assert_not_null(scene, "retro_games.tscn must load")
	if scene == null:
		return
	_root = scene.instantiate() as Node3D
	add_child(_root)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame


func after_each() -> void:
	ModalQueue._reset_for_tests()
	InputFocus._reset_for_tests()
	if is_instance_valid(_root):
		_root.free()
	_root = null
	BetaRunState.reset_new_run()


func test_new_game_enters_preopening_training_before_day_one() -> void:
	var controller: Node = _controller()
	assert_not_null(controller)
	if controller == null:
		return
	assert_false(BetaRunState.preopening_complete)
	assert_eq(
		String(controller.current_stage()),
		"training_talk_manager",
		"New Game must start with the pre-opening manager beat, not real Day 1"
	)
	assert_eq(Array(_active_targets()), ["BetaDayOneCustomer"])


func test_training_walks_required_mechanics_before_open_store() -> void:
	var controller: Node = _controller()
	if controller == null:
		return
	controller.on_beta_customer_interacted()
	await get_tree().process_frame
	assert_eq(String(controller.current_stage()), "training_check_register")
	assert_eq(Array(_active_targets()), ["BetaDayEndTrigger"])

	controller.on_beta_register_interacted()
	await get_tree().process_frame
	assert_eq(String(controller.current_stage()), "training_back_room_inventory")
	assert_eq(Array(_active_targets()), ["BetaBackroomPickup"])

	controller.on_beta_backroom_pickup_interacted()
	await get_tree().process_frame
	assert_eq(String(controller.current_stage()), "training_stock_shelf")
	assert_true(BetaRunState.carrying_stock)
	assert_eq(Array(_active_targets()), ["BetaRestockShelf"])

	controller.on_beta_restock_interacted()
	await get_tree().process_frame
	assert_eq(String(controller.current_stage()), "training_practice_customer")
	assert_false(BetaRunState.carrying_stock)
	assert_eq(Array(_active_targets()), ["BetaDayOneCustomer"])


func test_open_store_transitions_to_real_day_one_customer() -> void:
	var controller: Node = _controller()
	if controller == null:
		return
	controller.set("_stage", BetaDayOneController.STAGE_TRAINING_OPEN_STORE)
	controller.set("_objectives", controller.get("_training_objectives"))
	controller.call("_apply_objective_gating")

	controller.on_beta_register_interacted()
	await get_tree().process_frame

	assert_true(BetaRunState.preopening_complete)
	assert_eq(String(controller.current_stage()), "talk_to_customer")
	assert_eq(Array(_active_targets()), ["BetaDayOneCustomer"])


func test_manager_proxy_uses_blocky_readable_silhouette() -> void:
	var proxy: Node = _root.get_node_or_null("BetaDayOneCustomer/CustomerProxy")
	assert_not_null(proxy, "Training manager/customer proxy must exist")
	if proxy == null:
		return
	for part_name: String in ["Body", "Head", "ArmLeft", "ArmRight"]:
		var part: MeshInstance3D = proxy.get_node_or_null(part_name) as MeshInstance3D
		assert_not_null(part, "Proxy must include %s for a readable silhouette" % part_name)
		if part != null:
			assert_true(
				part.mesh is BoxMesh,
				"%s must use a BoxMesh so the NPC does not read as a capsule placeholder"
					% part_name
			)


func _controller() -> Node:
	return get_tree().get_first_node_in_group("beta_day_one_controller")


func _active_targets() -> PackedStringArray:
	var names := PackedStringArray()
	var controller: Node = _controller()
	var store_root: Node = _root
	if controller != null and controller.get_parent() != null:
		store_root = controller.get_parent()
	for node_name: String in [
		"BetaDayOneCustomer",
		"BetaBackroomPickup",
		"BetaRestockShelf",
		"BetaDayEndTrigger",
	]:
		var interactable: Interactable = (
			store_root.get_node_or_null("%s/Interactable" % node_name) as Interactable
		)
		if interactable != null and interactable.enabled:
			names.append(node_name)
	names.sort()
	return names
