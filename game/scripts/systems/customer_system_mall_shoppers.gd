## Mall-hallway ShopperAI manager. Pulled out of CustomerSystem so the
## hallway shopper spawning, LOD update, and graceful-exit flows live next
## to each other instead of being interleaved with in-store customer logic.
##
## All state that the rest of CustomerSystem reads (active count, scene ref,
## archetype weights, hallway flag) stays on the CustomerSystem instance —
## this helper reaches through the held reference. Construct it with
## `CustomerMallShoppers.new(customer_system)`.
class_name CustomerMallShoppers
extends RefCounted

var _cs: Node = null


func _init(customer_system: Node) -> void:
	_cs = customer_system


func update_lod() -> void:
	var lod_origin: Node3D = _get_shopper_lod_origin()
	if lod_origin == null:
		return
	var player_pos: Vector3 = lod_origin.global_position
	var shoppers: Array[Node] = _cs.get_tree().get_nodes_in_group("shoppers")
	for node: Node in shoppers:
		var shopper: ShopperAI = node as ShopperAI
		if not shopper or not is_instance_valid(shopper):
			continue
		var dist: float = player_pos.distance_to(shopper.global_position)
		var new_detail: ShopperAI.AIDetail
		if dist < ShopperAI.FULL_AI_RADIUS:
			new_detail = ShopperAI.AIDetail.FULL
		elif dist < ShopperAI.SIMPLE_AI_RADIUS:
			new_detail = ShopperAI.AIDetail.SIMPLE
		else:
			new_detail = ShopperAI.AIDetail.MINIMAL
		shopper.ai_detail = new_detail


func update_mall_shoppers() -> void:
	if not _cs._in_mall_hallway:
		return
	var target: int = _cs.get_spawn_target()
	if _cs._active_mall_shopper_count < target:
		_try_spawn_mall_shopper(target - _cs._active_mall_shopper_count)
	elif _cs._active_mall_shopper_count > target:
		if not despawn_one_leaving_shopper():
			request_one_shopper_leave()


func request_one_shopper_leave() -> void:
	var shoppers: Array[Node] = _cs.get_tree().get_nodes_in_group("shoppers")
	for node: Node in shoppers:
		var shopper: ShopperAI = node as ShopperAI
		if not shopper or not is_instance_valid(shopper):
			continue
		if shopper.current_state == ShopperAI.ShopperState.LEAVING:
			continue
		shopper.request_leave()
		return


func despawn_one_leaving_shopper() -> bool:
	var shoppers: Array[Node] = _cs.get_tree().get_nodes_in_group("shoppers")
	for node: Node in shoppers:
		var shopper: ShopperAI = node as ShopperAI
		if not shopper or not is_instance_valid(shopper):
			continue
		if shopper.current_state != ShopperAI.ShopperState.LEAVING:
			continue
		shopper.queue_free()
		_cs._decrement_active_mall_shopper_count()
		return true
	return false


func request_all_shoppers_leave() -> void:
	var shoppers: Array[Node] = _cs.get_tree().get_nodes_in_group("shoppers")
	for node: Node in shoppers:
		var shopper: ShopperAI = node as ShopperAI
		if not shopper or not is_instance_valid(shopper):
			continue
		if shopper.current_state == ShopperAI.ShopperState.LEAVING:
			continue
		shopper.request_leave()


func despawn_all_mall_shoppers() -> void:
	var shoppers: Array[Node] = _cs.get_tree().get_nodes_in_group("shoppers")
	for node: Node in shoppers:
		if is_instance_valid(node):
			node.queue_free()


# ── Internals ────────────────────────────────────────────────────────────────


func _get_shopper_lod_origin() -> Node3D:
	var active_camera: Camera3D = CameraManager.get_active_camera()
	if active_camera == null:
		return null
	var camera_parent: Node = active_camera.get_parent()
	if camera_parent is Node3D:
		return camera_parent as Node3D
	return active_camera


func _try_spawn_mall_shopper(spawn_capacity: int = -1) -> void:
	var tracked_count: int = maxi(
		_cs._active_mall_shopper_count, _get_live_mall_shopper_count()
	)
	var remaining_capacity: int = _cs.max_customers_in_mall - tracked_count
	if spawn_capacity >= 0:
		remaining_capacity = mini(remaining_capacity, spawn_capacity)
	if remaining_capacity <= 0:
		return
	if not _cs._shopper_scene:
		return
	var spawn_pos: Vector3 = _find_exit_waypoint_position()
	if spawn_pos == Vector3.ZERO:
		return
	var weights: Dictionary = _cs._current_archetype_weights
	var archetype: PersonalityData.PersonalityType = (
		ShopperArchetypeConfig.weighted_random_select(weights)
	)
	if ShopperArchetypeConfig.is_group_archetype(archetype):
		_spawn_shopper_group(archetype, spawn_pos, remaining_capacity)
	else:
		_spawn_solo_shopper(archetype, spawn_pos)


func _spawn_solo_shopper(
	archetype: PersonalityData.PersonalityType,
	spawn_pos: Vector3,
) -> void:
	var shopper: ShopperAI = _cs._shopper_scene.instantiate() as ShopperAI
	if not shopper:
		push_error("CustomerSystem: failed to instantiate ShopperAI")
		return
	shopper.personality = (
		ShopperArchetypeConfig.create_personality(archetype)
	)
	_cs.add_child(shopper)
	shopper.initialize(spawn_pos)
	_cs._active_mall_shopper_count += 1


func _spawn_shopper_group(
	archetype: PersonalityData.PersonalityType,
	spawn_pos: Vector3,
	spawn_capacity: int,
) -> void:
	var size_range: Vector2i = (
		ShopperArchetypeConfig.get_group_size_range(archetype)
	)
	var group_size: int = randi_range(size_range.x, size_range.y)
	var remaining_capacity: int = (
		_cs.max_customers_in_mall - _cs._active_mall_shopper_count
	)
	remaining_capacity = mini(remaining_capacity, spawn_capacity)
	group_size = mini(group_size, remaining_capacity)
	if group_size < 2:
		return
	var group: ShopperGroup = ShopperGroup.new()
	for i: int in range(group_size):
		var shopper: ShopperAI = (
			_cs._shopper_scene.instantiate() as ShopperAI
		)
		if not shopper:
			push_error("CustomerSystem: failed to instantiate group member")
			continue
		shopper.personality = (
			ShopperArchetypeConfig.create_personality(archetype)
		)
		var offset: Vector3 = Vector3(
			randf_range(-0.5, 0.5), 0.0, randf_range(-0.5, 0.5)
		)
		_cs.add_child(shopper)
		group.add_member(shopper)
		shopper.shopper_group = group
		shopper.initialize(spawn_pos + offset)
		_cs._active_mall_shopper_count += 1
	group.assign_leader()


func _find_exit_waypoint_position() -> Vector3:
	var waypoints: Array[Node] = _cs.get_tree().get_nodes_in_group(
		"mall_waypoints"
	)
	var exits: Array[MallWaypoint] = []
	for node: Node in waypoints:
		var wp: MallWaypoint = node as MallWaypoint
		if wp and wp.waypoint_type == MallWaypoint.WaypointType.EXIT:
			exits.append(wp)
	if exits.is_empty():
		push_warning("CustomerSystem: No EXIT waypoints found for spawning")
		return Vector3.ZERO
	return exits.pick_random().global_position


func _get_live_mall_shopper_count() -> int:
	if not _cs.is_inside_tree():
		return 0
	var count: int = 0
	for node: Node in _cs.get_tree().get_nodes_in_group("shoppers"):
		if is_instance_valid(node):
			count += 1
	return count
