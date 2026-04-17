## Tests CustomerSystem shopper LOD throttling and distance-based AI tiers.
extends GutTest


class LODTrackingCustomerSystem:
	extends CustomerSystem

	var lod_update_calls: int = 0

	func _update_shopper_lod() -> void:
		lod_update_calls += 1


func after_each() -> void:
	CameraManager.active_camera = null


func test_lod_updates_run_at_most_once_per_second() -> void:
	var tracking_system := LODTrackingCustomerSystem.new()
	add_child_autofree(tracking_system)
	tracking_system._in_mall_hallway = false

	tracking_system._process(0.4)
	tracking_system._process(0.59)
	assert_eq(tracking_system.lod_update_calls, 0)

	tracking_system._process(0.01)
	assert_eq(tracking_system.lod_update_calls, 1)

	tracking_system._process(2.5)
	assert_eq(tracking_system.lod_update_calls, 2)


func test_update_shopper_lod_assigns_detail_by_distance() -> void:
	var _player: PlayerController = _make_lod_player(Vector3.ZERO)
	var full: ShopperAI = _make_lod_shopper(Vector3(10, 0, 0))
	var simple: ShopperAI = _make_lod_shopper(Vector3(40, 0, 0))
	var minimal: ShopperAI = _make_lod_shopper(Vector3(80, 0, 0))
	var system := CustomerSystem.new()
	add_child_autofree(system)

	system._update_shopper_lod()

	assert_eq(full.ai_detail, ShopperAI.AIDetail.FULL)
	assert_eq(simple.ai_detail, ShopperAI.AIDetail.SIMPLE)
	assert_eq(minimal.ai_detail, ShopperAI.AIDetail.MINIMAL)


func _make_lod_player(position: Vector3) -> PlayerController:
	var controller := PlayerController.new()
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	controller.add_child(camera)
	add_child_autofree(controller)
	controller.global_position = position
	CameraManager.register_camera(camera)
	return controller


func _make_lod_shopper(position: Vector3) -> ShopperAI:
	var shopper := ShopperAI.new()
	var agent := MallWaypointAgent.new()
	agent.name = "MallWaypointAgent"
	shopper.add_child(agent)
	add_child_autofree(shopper)
	shopper.global_position = position
	return shopper
