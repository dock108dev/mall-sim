## Leader/follower group model for group-archetype NPCs.
class_name ShopperGroup
extends RefCounted

const REGROUP_DISTANCE: float = 2.5
const CATCHUP_SPEED_MULT: float = 1.3
const FORMATION_BASE_RADIUS: float = 1.2
const FORMATION_RADIUS_INCREMENT: float = 0.3
const LEADER_SCORE_WEIGHT: float = 1.5
const SCORE_DIVISOR_OFFSET: float = 0.5
const RELUCTANT_ENERGY_THRESHOLD: float = 0.3

var leader: ShopperAI = null
var followers: Array[ShopperAI] = []
var group_mood: float = 0.5
var _member_exit_handlers: Dictionary = {}


func add_member(shopper: ShopperAI) -> void:
	if shopper == null or not is_instance_valid(shopper):
		push_warning("ShopperGroup: attempted to add an invalid shopper.")
		return
	if shopper == leader:
		return
	if followers.has(shopper):
		return
	_register_member_exit_handler(shopper)
	if leader == null and followers.is_empty():
		leader = shopper
	else:
		followers.append(shopper)


func assign_leader() -> void:
	_assign_leader()


func _assign_leader() -> void:
	var all: Array[ShopperAI] = get_all_members()
	if all.is_empty():
		leader = null
		followers.clear()
		return
	var best: ShopperAI = all[0]
	var highest_social: float = _get_social_need(best)
	for i: int in range(1, all.size()):
		var member: ShopperAI = all[i]
		var sn: float = _get_social_need(member)
		if sn > highest_social:
			highest_social = sn
			best = member
	leader = best
	followers.clear()
	for member: ShopperAI in all:
		if member != leader:
			followers.append(member)


func get_all_members() -> Array[ShopperAI]:
	var result: Array[ShopperAI] = []
	if leader and is_instance_valid(leader):
		result.append(leader)
	for f: ShopperAI in followers:
		if is_instance_valid(f):
			result.append(f)
	return result


func get_member_count() -> int:
	return get_all_members().size()


func get_formation_offset(follower_index: int) -> Vector3:
	var count: int = followers.size()
	if count <= 0:
		return Vector3.ZERO
	var angle: float = TAU * float(follower_index) / float(count) + PI
	var radius: float = (
		FORMATION_BASE_RADIUS
		+ FORMATION_RADIUS_INCREMENT * float(follower_index)
	)
	return Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)


func get_formation_world_position(follower_index: int) -> Vector3:
	if not leader or not is_instance_valid(leader):
		return Vector3.ZERO
	return leader.global_position + get_formation_offset(follower_index)


func should_follower_catch_up(follower_index: int) -> bool:
	if follower_index < 0 or follower_index >= followers.size():
		return false
	var follower: ShopperAI = followers[follower_index]
	if not is_instance_valid(follower):
		return false
	var slot_pos: Vector3 = get_formation_world_position(follower_index)
	var diff: Vector3 = slot_pos - follower.global_position
	diff.y = 0.0
	return diff.length() > REGROUP_DISTANCE


func score_group_action(action: String) -> float:
	if not leader or not is_instance_valid(leader):
		return 0.0
	var total: float = leader._score_action(action) * LEADER_SCORE_WEIGHT
	for follower: ShopperAI in followers:
		if is_instance_valid(follower):
			total += follower._score_action(action)
	var member_count: float = float(get_member_count())
	return total / (member_count + SCORE_DIVISOR_OFFSET)


func has_reluctant_companion_override() -> bool:
	for member: ShopperAI in get_all_members():
		if not is_instance_valid(member):
			continue
		if not member.personality:
			continue
		if member.personality.personality_type != (
			PersonalityData.PersonalityType.RELUCTANT_COMPANION
		):
			continue
		if member.needs.energy < RELUCTANT_ENERGY_THRESHOLD:
			return true
	return false


func remove_member(shopper: ShopperAI) -> void:
	if shopper == null:
		return
	_unregister_member_exit_handler(shopper)
	if shopper.shopper_group == self:
		shopper.shopper_group = null
	if shopper == leader:
		leader = null
		followers.erase(shopper)
		if not followers.is_empty():
			_promote_next_leader()
	else:
		followers.erase(shopper)


func _promote_next_leader() -> void:
	var remaining: Array[ShopperAI] = []
	for f: ShopperAI in followers:
		if is_instance_valid(f):
			remaining.append(f)
	if remaining.is_empty():
		leader = null
		followers.clear()
		return
	var best: ShopperAI = remaining[0]
	var highest_social: float = _get_social_need(best)
	for i: int in range(1, remaining.size()):
		var member: ShopperAI = remaining[i]
		var sn: float = _get_social_need(member)
		if sn > highest_social:
			highest_social = sn
			best = member
	leader = best
	followers.clear()
	for member: ShopperAI in remaining:
		if member != leader:
			followers.append(member)


func _get_social_need(shopper: ShopperAI) -> float:
	if not shopper or not is_instance_valid(shopper):
		return 0.0
	if shopper.needs:
		return shopper.needs.social
	if not shopper.personality:
		return 0.0
	return shopper.personality.social_need_baseline


func _register_member_exit_handler(shopper: ShopperAI) -> void:
	var shopper_id: int = shopper.get_instance_id()
	if _member_exit_handlers.has(shopper_id):
		return
	var exit_handler: Callable = _on_member_tree_exiting.bind(shopper)
	_member_exit_handlers[shopper_id] = exit_handler
	if not shopper.tree_exiting.is_connected(exit_handler):
		shopper.tree_exiting.connect(exit_handler, CONNECT_ONE_SHOT)


func _unregister_member_exit_handler(shopper: ShopperAI) -> void:
	if not is_instance_valid(shopper):
		return
	var shopper_id: int = shopper.get_instance_id()
	if not _member_exit_handlers.has(shopper_id):
		return
	var exit_handler: Callable = _member_exit_handlers[shopper_id]
	if shopper.tree_exiting.is_connected(exit_handler):
		shopper.tree_exiting.disconnect(exit_handler)
	_member_exit_handlers.erase(shopper_id)


func _on_member_tree_exiting(shopper: ShopperAI) -> void:
	remove_member(shopper)
