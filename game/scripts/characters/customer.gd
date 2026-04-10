## 3D customer NPC that navigates the store, browses items, and makes purchases.
class_name Customer
extends CharacterBody3D

enum State {
	ENTERING,
	BROWSING,
	DECIDING,
	PURCHASING,
	WAITING_IN_QUEUE,
	LEAVING,
}

signal despawn_requested(customer: Customer)

const MOVE_SPEED: float = 2.0
const MOVE_TO_NEXT_SHELF_CHANCE: float = 0.5
const INVESTOR_MAX_MARKET_RATIO: float = 0.8
const TESTED_BONUS: float = 0.25
const DISAPPOINTED_CHANCE: float = 0.05
const DEMO_CATEGORY_BONUS: float = 0.20
const CONDITION_RANKS: Dictionary = {
	"poor": 0,
	"fair": 1,
	"good": 2,
	"near_mint": 3,
	"mint": 4,
}

var profile: CustomerProfile = null
var current_state: State = State.ENTERING
var patience_timer: float = 0.0
var browse_timer: float = 0.0

var _store_controller: StoreController = null
var _inventory_system: InventorySystem = null
var _visited_slots: Array[Node] = []
var _desired_item: ItemInstance = null
var _desired_item_slot: Node = null
var _current_target_slot: Node = null
var _exit_position: Vector3 = Vector3.ZERO
var _register_position: Vector3 = Vector3.ZERO
var _initialized: bool = false
var _time_paused: bool = false

@onready var _navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var _body_mesh: MeshInstance3D = $BodyMesh
@onready var _head_mesh: MeshInstance3D = $HeadMesh
@onready var _animation_player: AnimationPlayer = $AnimationPlayer
@onready var _animator: CustomerAnimator = $CustomerAnimator


func _ready() -> void:
	_randomize_body_color()
	EventBus.speed_changed.connect(_on_speed_changed)
	_navigation_agent.velocity_computed.connect(
		_on_velocity_computed
	)


## Sets up the customer with a profile, store, and inventory references.
func initialize(
	p_profile: CustomerProfile,
	store_controller: StoreController,
	inventory_system: InventorySystem
) -> void:
	profile = p_profile
	_store_controller = store_controller
	_inventory_system = inventory_system
	patience_timer = p_profile.patience * 120.0
	_reset_browse_timer()
	current_state = State.ENTERING
	_cache_navigation_targets()
	_navigate_to_random_shelf()
	_animator.initialize(_animation_player)
	_animator.play_for_state(State.ENTERING)
	_initialized = true


func _physics_process(delta: float) -> void:
	if not _initialized or _time_paused:
		return
	match current_state:
		State.ENTERING:
			_process_entering()
		State.BROWSING:
			_process_browsing(delta)
		State.DECIDING:
			_process_deciding()
		State.PURCHASING:
			_process_purchasing(delta)
		State.WAITING_IN_QUEUE:
			_process_waiting_in_queue(delta)
		State.LEAVING:
			_process_leaving()
	_move_along_path()


## Returns the item the customer wants to buy, or null.
func get_desired_item() -> ItemInstance:
	return _desired_item


## Returns the shelf slot holding the desired item, or null.
func get_desired_item_slot() -> Node:
	return _desired_item_slot


## Called by CheckoutSystem when checkout completes (accept or decline).
func complete_purchase() -> void:
	_desired_item = null
	_desired_item_slot = null
	_transition_to(State.LEAVING)


## Called by RegisterQueue to place this customer in a queue position.
func enter_queue(queue_position: Vector3) -> void:
	current_state = State.WAITING_IN_QUEUE
	_animator.play_for_state(State.WAITING_IN_QUEUE)
	_navigation_agent.target_position = queue_position


## Called by RegisterQueue when this customer advances to register.
func advance_to_register() -> void:
	current_state = State.PURCHASING
	_animator.play_for_state(State.PURCHASING)
	_navigation_agent.target_position = _register_position


## Called by CheckoutSystem when the queue is full.
func reject_from_queue() -> void:
	_transition_to(State.LEAVING)


func _process_entering() -> void:
	if _navigation_agent.is_navigation_finished():
		_transition_to(State.BROWSING)


func _process_browsing(delta: float) -> void:
	patience_timer -= delta
	if patience_timer <= 0.0:
		_transition_to_deciding_or_leaving()
		return
	if not _navigation_agent.is_navigation_finished():
		return
	browse_timer -= delta
	if browse_timer > 0.0:
		return
	_evaluate_current_shelf()
	_reset_browse_timer()
	if randf() < MOVE_TO_NEXT_SHELF_CHANCE:
		if _navigate_to_random_shelf():
			return
	if _desired_item:
		_transition_to(State.DECIDING)
		return
	if not _navigate_to_random_shelf():
		_transition_to(State.LEAVING)


func _process_deciding() -> void:
	if not _desired_item:
		_transition_to(State.LEAVING)
		return
	var willing_to_pay: float = _get_willingness_to_pay()
	var item_price: float = _desired_item.set_price
	if item_price <= 0.0:
		item_price = _desired_item.get_current_value()
	if item_price > willing_to_pay:
		_transition_to(State.LEAVING)
		return
	var match_quality: float = _calculate_match_quality(_desired_item)
	var buy_chance: float = profile.purchase_probability_base * match_quality
	if _desired_item.tested:
		if randf() < DISAPPOINTED_CHANCE:
			_transition_to(State.LEAVING)
			return
		buy_chance *= (1.0 + TESTED_BONUS)
	buy_chance *= _get_demo_bonus(_desired_item)
	if randf() > buy_chance:
		_transition_to(State.LEAVING)
		return
	_transition_to(State.PURCHASING)


func _process_purchasing(delta: float) -> void:
	if _navigation_agent.is_navigation_finished():
		patience_timer -= delta
		if patience_timer <= 0.0:
			_transition_to(State.LEAVING)


func _process_waiting_in_queue(delta: float) -> void:
	patience_timer -= delta
	if patience_timer <= 0.0:
		_transition_to(State.LEAVING)


func _process_leaving() -> void:
	if _navigation_agent.is_navigation_finished():
		despawn_requested.emit(self)


func _transition_to(new_state: State) -> void:
	current_state = new_state
	_animator.play_for_state(new_state)
	match new_state:
		State.PURCHASING:
			_navigate_to_register()
			var data: Dictionary = _build_customer_data()
			EventBus.customer_ready_to_purchase.emit(data)
		State.LEAVING:
			_navigate_to_exit()


func _transition_to_deciding_or_leaving() -> void:
	if _desired_item:
		_transition_to(State.DECIDING)
	else:
		_transition_to(State.LEAVING)


func _move_along_path() -> void:
	if _navigation_agent.is_navigation_finished():
		velocity = Vector3.ZERO
		return
	var next_pos: Vector3 = _navigation_agent.get_next_path_position()
	var direction: Vector3 = next_pos - global_position
	direction.y = 0.0
	direction = direction.normalized()
	var desired: Vector3 = direction * MOVE_SPEED
	if _navigation_agent.avoidance_enabled:
		_navigation_agent.set_velocity(desired)
	else:
		velocity = desired
		move_and_slide()


func _cache_navigation_targets() -> void:
	if not _store_controller:
		return
	var entry: Area3D = _store_controller.get_entry_area()
	if entry:
		_exit_position = entry.global_position
	var register: Area3D = _store_controller.get_register_area()
	if register:
		_register_position = register.global_position


func _navigate_to_random_shelf() -> bool:
	if not _store_controller:
		return false
	var occupied: Array[Node] = _store_controller.get_occupied_slots()
	var unvisited: Array[Node] = []
	for slot: Node in occupied:
		if slot not in _visited_slots:
			unvisited.append(slot)
	if unvisited.is_empty():
		return false
	var preferred: Array[Node] = _filter_preferred_slots(unvisited)
	var target: Node = (
		preferred.pick_random() if not preferred.is_empty()
		else unvisited.pick_random()
	)
	_current_target_slot = target
	_visited_slots.append(target)
	var target_3d: Node3D = target as Node3D
	if target_3d:
		_navigation_agent.target_position = target_3d.global_position
	return true


func _navigate_to_register() -> void:
	_navigation_agent.target_position = _register_position


func _navigate_to_exit() -> void:
	_navigation_agent.target_position = _exit_position


func _evaluate_current_shelf() -> void:
	if not _current_target_slot or not _inventory_system:
		return
	var slot_id: String = str(_current_target_slot.get("slot_id"))
	if slot_id.is_empty():
		return
	var location: String = "shelf:%s" % slot_id
	var items: Array[ItemInstance] = (
		_inventory_system.get_items_at_location(location)
	)
	for item: ItemInstance in items:
		if not _is_item_desirable(item):
			continue
		if not _desired_item:
			_desired_item = item
			_desired_item_slot = _current_target_slot
		elif _score_item(item) > _score_item(_desired_item):
			_desired_item = item
			_desired_item_slot = _current_target_slot


func _is_item_desirable(item: ItemInstance) -> bool:
	if not item.definition or not profile:
		return false
	if item.is_demo:
		return false
	var item_price: float = item.set_price
	if item_price <= 0.0:
		item_price = item.get_current_value()
	if item_price < profile.budget_range[0]:
		return false
	if item_price > profile.budget_range[1]:
		return false
	if _is_bargain_only_buyer():
		var market_value: float = item.get_current_value()
		var ratio: float = profile.max_price_to_market_ratio
		if ratio >= 1.0:
			ratio = INVESTOR_MAX_MARKET_RATIO
		if market_value > 0.0 and item_price > market_value * ratio:
			return false
	var category_match: bool = _matches_categories(item)
	var tag_match: bool = _matches_tags(item)
	if not category_match and not tag_match:
		return randf() < profile.impulse_buy_chance
	return true


func _matches_categories(item: ItemInstance) -> bool:
	if profile.preferred_categories.is_empty():
		return true
	return item.definition.category in profile.preferred_categories


func _matches_tags(item: ItemInstance) -> bool:
	if profile.preferred_tags.is_empty():
		return true
	for tag: String in item.definition.tags:
		if tag in profile.preferred_tags:
			return true
	return false


func _score_item(item: ItemInstance) -> float:
	if not item.definition:
		return 0.0
	var score: float = item.get_current_value()
	if item.definition.category in profile.preferred_categories:
		score *= 1.5
	for tag: String in item.definition.tags:
		if tag in profile.preferred_tags:
			score *= 1.2
			break
	score *= _get_condition_score(item.condition)
	return score


func _get_willingness_to_pay() -> float:
	if not _desired_item or not profile:
		return 0.0
	var budget_max: float = profile.budget_range[1]
	var item_value: float = _desired_item.get_current_value()
	# Lower sensitivity means willing to pay more above market value
	var tolerance: float = 2.0 - profile.price_sensitivity
	var max_acceptable: float = item_value * tolerance
	return minf(budget_max, max_acceptable)


func _is_bargain_only_buyer() -> bool:
	if not profile:
		return false
	return (
		"investor" in profile.id
		or "dealer" in profile.id
		or "reseller" in profile.id
	)


## Returns 0.5-1.5 based on how well item condition matches preference.
func _get_condition_score(item_condition: String) -> float:
	var pref_rank: int = CONDITION_RANKS.get(
		profile.condition_preference, 2
	)
	var item_rank: int = CONDITION_RANKS.get(item_condition, 2)
	var diff: int = item_rank - pref_rank
	if diff >= 0:
		return 1.0 + minf(diff * 0.1, 0.5)
	return maxf(0.5, 1.0 + diff * 0.2)


## Returns match quality 0.5-1.5 based on category, tag, and condition fit.
func _calculate_match_quality(item: ItemInstance) -> float:
	if not item.definition:
		return 0.5
	var quality: float = 1.0
	if _matches_categories(item):
		quality += 0.2
	if _matches_tags(item):
		quality += 0.15
	quality += _get_meta_shift_bonus(item)
	var cond_score: float = _get_condition_score(item.condition)
	quality *= cond_score
	return clampf(quality, 0.5, 1.5)


## Returns the demo station purchase probability multiplier.
## Items in the same category as an active demo unit get +20%.
func _get_demo_bonus(item: ItemInstance) -> float:
	if not item.definition or not _store_controller:
		return 1.0
	if not _store_controller is ElectronicsStoreController:
		return 1.0
	var elec_ctrl: ElectronicsStoreController = (
		_store_controller as ElectronicsStoreController
	)
	if elec_ctrl.has_active_demo_for_category(item.definition.category):
		return 1.0 + DEMO_CATEGORY_BONUS
	return 1.0


## Returns a bonus for competitive players when an item is meta-spiking.
func _get_meta_shift_bonus(item: ItemInstance) -> float:
	if not profile or not _store_controller:
		return 0.0
	if profile.id != "pc_competitive_player":
		return 0.0
	if not _store_controller is PocketCreaturesStoreController:
		return 0.0
	var pc_ctrl: PocketCreaturesStoreController = (
		_store_controller as PocketCreaturesStoreController
	)
	if not pc_ctrl.is_meta_shift_active():
		return 0.0
	var rising: Array[Dictionary] = pc_ctrl.get_meta_rising_cards()
	for entry: Dictionary in rising:
		if entry.get("item_id", "") == item.definition.id:
			return 0.3
	return 0.0


## Returns slots containing items matching preferred categories.
func _filter_preferred_slots(slots: Array[Node]) -> Array[Node]:
	if profile.preferred_categories.is_empty() or not _inventory_system:
		return []
	var preferred: Array[Node] = []
	for slot: Node in slots:
		var slot_id: String = str(slot.get("slot_id"))
		if slot_id.is_empty():
			continue
		var location: String = "shelf:%s" % slot_id
		var items: Array[ItemInstance] = (
			_inventory_system.get_items_at_location(location)
		)
		for item: ItemInstance in items:
			if not item.definition:
				continue
			if item.definition.category in profile.preferred_categories:
				preferred.append(slot)
				break
	return preferred


func _reset_browse_timer() -> void:
	browse_timer = randf_range(
		profile.browse_time_range[0],
		profile.browse_time_range[1]
	)


func _build_customer_data() -> Dictionary:
	return {
		"customer_id": get_instance_id(),
		"profile_id": profile.id if profile else "",
		"profile_name": profile.name if profile else "",
		"desired_item_id": (
			_desired_item.instance_id if _desired_item else ""
		),
	}


func _randomize_body_color() -> void:
	if not _body_mesh:
		return
	var base_hue: float = randf()
	var saturation: float = randf_range(0.3, 0.7)
	var value_v: float = randf_range(0.5, 0.9)
	var body_color := Color.from_hsv(base_hue, saturation, value_v)
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = body_color
	_body_mesh.material_override = body_material
	var head_material := StandardMaterial3D.new()
	head_material.albedo_color = body_color.lightened(0.2)
	_head_mesh.material_override = head_material


func _on_velocity_computed(safe_velocity: Vector3) -> void:
	velocity = safe_velocity
	move_and_slide()


func _on_speed_changed(new_speed: float) -> void:
	_time_paused = new_speed <= 0.0
	if _animation_player:
		_animation_player.speed_scale = new_speed if new_speed > 0.0 else 0.0
