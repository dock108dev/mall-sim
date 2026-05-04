## 3D customer NPC that navigates the store, browses items, and makes purchases.
class_name Customer
extends CharacterBody3D

signal despawn_requested(customer: Customer)

enum State {
	ENTERING,
	BROWSING,
	DECIDING,
	PURCHASING,
	WAITING_IN_QUEUE,
	LEAVING,
}

const MOVE_SPEED: float = 2.0
const MOVE_TO_NEXT_SHELF_CHANCE: float = 0.5
const INVESTOR_MAX_MARKET_RATIO: float = 0.8
const TESTED_BONUS: float = 0.25
const DISAPPOINTED_CHANCE: float = 0.05
## Navigation path recalculation interval in seconds.
const NAV_RECALC_INTERVAL: float = 0.2
## Squared arrival radius for direct waypoint-fallback movement (≈0.6m).
const WAYPOINT_ARRIVAL_DIST_SQ: float = 0.36
const CONDITION_RANKS: Dictionary = {
	"poor": 0,
	"fair": 1,
	"good": 2,
	"near_mint": 3,
	"mint": 4,
}

var profile: CustomerTypeDefinition = null
var current_state: State = State.ENTERING
var patience_timer: float = 0.0
var browse_timer: float = 0.0
## Frame stagger offset assigned by CustomerSystem (0.0 to 1.0).
var stagger_offset: float = 0.0
## Per-frame timing for profiling (set each _physics_process).
var last_script_time_ms: float = 0.0
var last_nav_time_ms: float = 0.0
var last_anim_time_ms: float = 0.0

var _store_controller: StoreController = null
var _inventory_system: InventorySystem = null
var _budget_multiplier: float = 1.0
var _browse_min_multiplier: float = 1.0
var _visited_slots: Array[Node] = []
var _desired_item: ItemInstance = null
var _desired_item_slot: Node = null
var _current_target_slot: Node = null
var _made_purchase: bool = false
## Set when transitioning to LEAVING; included in EventBus.customer_left (store NPCs).
var _leave_reason: StringName = &"patience_expired"
var _exit_position: Vector3 = Vector3.ZERO
var _register_position: Vector3 = Vector3.ZERO
var _initialized: bool = false
var _time_paused: bool = false
var _nav_recalc_timer: float = 0.0
var _cached_preferred_slots: Array[Node] = []
var _preferred_slots_dirty: bool = true
## Direct-movement fallback used when NavigationAgent3D / navmesh cannot resolve
## a path. Covers the BRAINDUMP Day-1 spawn → shelf → checkout → exit chain by
## driving move_and_slide toward the last target set by `_set_navigation_target`.
var _use_waypoint_fallback: bool = false
var _fallback_target: Vector3 = Vector3.ZERO
var _fallback_arrived: bool = true

@onready var _navigation_agent: NavigationAgent3D = (
	get_node_or_null("NavigationAgent3D") as NavigationAgent3D
)
@onready var _body_mesh: MeshInstance3D = (
	get_node_or_null("BodyMesh") as MeshInstance3D
)
@onready var _head_mesh: MeshInstance3D = (
	get_node_or_null("HeadMesh") as MeshInstance3D
)
@onready var _animation_player: AnimationPlayer = (
	get_node_or_null("AnimationPlayer") as AnimationPlayer
)
@onready var _animator: CustomerAnimator = (
	get_node_or_null("CustomerAnimator") as CustomerAnimator
)
@onready var _state_indicator: Node3D = (
	get_node_or_null("CustomerStateIndicator") as Node3D
)


func _ready() -> void:
	_randomize_body_color()
	EventBus.speed_changed.connect(_on_speed_changed)
	if _navigation_agent != null:
		_navigation_agent.velocity_computed.connect(
			_on_velocity_computed
		)


## Sets up the customer with a profile, store, and inventory references.
func initialize(
	p_profile: CustomerTypeDefinition,
	store_controller: StoreController,
	inventory_system: InventorySystem,
	budget_multiplier: float = 1.0,
	browse_min_multiplier: float = 1.0,
) -> void:
	profile = p_profile
	_store_controller = store_controller
	_inventory_system = inventory_system
	_budget_multiplier = budget_multiplier
	_browse_min_multiplier = browse_min_multiplier
	patience_timer = p_profile.patience * 120.0
	_reset_browse_timer()
	_set_state(State.ENTERING)
	_nav_recalc_timer = stagger_offset * NAV_RECALC_INTERVAL
	_preferred_slots_dirty = true
	_cached_preferred_slots.clear()
	_visited_slots.clear()
	_desired_item = null
	_desired_item_slot = null
	_current_target_slot = null
	_made_purchase = false
	_leave_reason = &"patience_expired"
	_cache_navigation_targets()
	_detect_navmesh_or_fallback()
	_navigate_to_random_shelf()
	if _animator != null:
		_animator.initialize(_animation_player)
		_animator.play_for_state(State.ENTERING)
	if _state_indicator:
		_state_indicator.initialize(self)
	_initialized = true


func _physics_process(delta: float) -> void:
	if not _initialized or _time_paused:
		return
	var t0: int = Time.get_ticks_usec()
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
	var t1: int = Time.get_ticks_usec()
	_move_along_path(delta)
	var t2: int = Time.get_ticks_usec()
	last_script_time_ms = float(t1 - t0) / 1000.0
	last_nav_time_ms = float(t2 - t1) / 1000.0
	# Animation cost is driven by AnimationPlayer internally per frame;
	# approximate from the animation update call inside _move_along_path.
	last_anim_time_ms = last_nav_time_ms * 0.15


## Returns the item the customer wants to buy, or null.
func get_desired_item() -> ItemInstance:
	return _desired_item


## Returns the shelf slot holding the desired item, or null.
func get_desired_item_slot() -> Node:
	return _desired_item_slot


## Reason code for EventBus.customer_left when this NPC despawns (see _leave_reason).
func get_leave_reason() -> StringName:
	return _leave_reason


## Called by CheckoutSystem when checkout completes (accept or decline).
func complete_purchase() -> void:
	_made_purchase = true
	_desired_item = null
	_desired_item_slot = null
	_leave_reason = &"purchase_complete"
	_transition_to(State.LEAVING)


## Called by RegisterQueue to place this customer in a queue position.
func enter_queue(queue_position: Vector3) -> void:
	_set_state(State.WAITING_IN_QUEUE)
	if _animator != null:
		_animator.play_for_state(State.WAITING_IN_QUEUE)
	_set_navigation_target(queue_position)


## Called by RegisterQueue when this customer advances to register.
func advance_to_register() -> void:
	_set_state(State.PURCHASING)
	if _animator != null:
		_animator.play_for_state(State.PURCHASING)
	_set_navigation_target(_register_position)


## Called by CheckoutSystem when the queue is full.
func reject_from_queue() -> void:
	_leave_with(&"patience_expired")


func _process_entering() -> void:
	if _is_navigation_finished():
		_transition_to(State.BROWSING)


func _process_browsing(delta: float) -> void:
	patience_timer -= delta
	if patience_timer <= 0.0:
		_transition_to_deciding_or_leaving()
		return
	if not _is_navigation_finished():
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
		_leave_with(&"no_matching_item")


func _process_deciding() -> void:
	if not _desired_item:
		_leave_with(&"no_matching_item")
		return
	var willing_to_pay: float = _get_willingness_to_pay()
	var item_price: float = _desired_item.player_set_price
	if item_price <= 0.0:
		item_price = _desired_item.get_current_value()
	if item_price > willing_to_pay:
		_leave_with(&"price_too_high")
		return
	if _is_first_sale_guarantee_active():
		if randf() < Constants.DAY1_PURCHASE_PROBABILITY:
			_transition_to(State.PURCHASING)
		else:
			_leave_with(&"no_matching_item")
		return
	var match_quality: float = _calculate_match_quality(_desired_item)
	var buy_chance: float = profile.purchase_probability_base * match_quality
	if _desired_item.tested:
		if randf() < DISAPPOINTED_CHANCE:
			_leave_with(&"no_matching_item")
			return
		buy_chance *= (1.0 + TESTED_BONUS)
	buy_chance *= _get_demo_bonus(_desired_item)
	buy_chance *= _get_rental_wear_appeal(_desired_item)
	if randf() > buy_chance:
		_leave_with(&"no_matching_item")
		return
	_transition_to(State.PURCHASING)


# The Day 1 tutorial loop must basically guarantee the first sale (BRAINDUMP
# Priority 6). The price ceiling above still applies — an absurd markup loses
# the sale — but the normal profile / match-quality / tested / demo / rental
# multipliers are bypassed so the player isn't randomly punished by a 0.7-base
# customer rolling against a low match score on the very first transaction.
func _is_first_sale_guarantee_active() -> bool:
	if GameManager.get_current_day() != 1:
		return false
	return not GameState.get_flag(&"first_sale_complete")


func _process_purchasing(delta: float) -> void:
	if _is_navigation_finished():
		patience_timer -= delta
		if patience_timer <= 0.0:
			_leave_with(&"patience_expired")


func _process_waiting_in_queue(delta: float) -> void:
	patience_timer -= delta
	if patience_timer <= 0.0:
		_leave_with(&"patience_expired")


func _process_leaving() -> void:
	if _is_navigation_finished():
		despawn_requested.emit(self)


func _transition_to(new_state: State) -> void:
	_set_state(new_state)
	if new_state == State.LEAVING and _animator != null:
		_animator.set_satisfied(_made_purchase)
	if _animator != null:
		_animator.play_for_state(new_state)
	match new_state:
		State.PURCHASING:
			_navigate_to_register()
			var data: Dictionary = _build_customer_data()
			EventBus.customer_ready_to_purchase.emit(data)
		State.LEAVING:
			_navigate_to_exit()


## Single write site for FSM state. Logs every transition in debug builds so the
## customer loop is observable without a UI change (per BRAINDUMP Priority 14).
## §F-106 — `OS.is_debug_build()` gate is the standard production-noise floor:
## release builds skip the print entirely (no string formatting / no IO), so
## the diagnostic carries zero cost in shipped builds. Same gate as §F-108
## interaction-ray telemetry and §F-58 retro_games F3 toggle.
func _set_state(new_state: State) -> void:
	var old_state: State = current_state
	current_state = new_state
	if OS.is_debug_build():
		print("[Customer %d] %s → %s" % [
			get_instance_id(),
			State.keys()[old_state],
			State.keys()[new_state],
		])
	EventBus.customer_state_changed.emit(self, new_state)


func _transition_to_deciding_or_leaving() -> void:
	if _desired_item:
		_transition_to(State.DECIDING)
	else:
		_leave_with(&"patience_expired")


func _leave_with(reason: StringName) -> void:
	_leave_reason = reason
	_transition_to(State.LEAVING)


func _move_along_path(delta: float) -> void:
	if _use_waypoint_fallback:
		_move_waypoint_fallback()
		return
	if _navigation_agent == null or _is_navigation_finished():
		velocity = Vector3.ZERO
		_update_animator_movement(velocity)
		return
	_nav_recalc_timer -= delta
	var next_pos: Vector3
	if _nav_recalc_timer <= 0.0:
		_nav_recalc_timer = NAV_RECALC_INTERVAL
		next_pos = _navigation_agent.get_next_path_position()
	else:
		# Between recalcs, continue toward current target
		next_pos = _navigation_agent.target_position
	var direction: Vector3 = next_pos - global_position
	direction.y = 0.0
	var dist_sq: float = direction.length_squared()
	if dist_sq < 0.01:
		velocity = Vector3.ZERO
		_update_animator_movement(velocity)
		return
	direction = direction.normalized()
	var desired: Vector3 = direction * MOVE_SPEED
	if _navigation_agent.avoidance_enabled:
		_navigation_agent.set_velocity(desired)
	else:
		velocity = desired
		move_and_slide()
	_update_animator_movement(velocity)


## Drives a customer through `_fallback_target` directly via move_and_slide,
## bypassing NavigationAgent3D when the navmesh is missing or cannot resolve a
## path. Each consecutive `_set_navigation_target` call advances the spawn →
## shelf → checkout → exit chain expected by the Day-1 vertical slice.
func _move_waypoint_fallback() -> void:
	if _fallback_arrived:
		velocity = Vector3.ZERO
		_update_animator_movement(velocity)
		return
	var to_target: Vector3 = _fallback_target - global_position
	to_target.y = 0.0
	var dist_sq: float = to_target.length_squared()
	if dist_sq < WAYPOINT_ARRIVAL_DIST_SQ:
		_fallback_arrived = true
		velocity = Vector3.ZERO
		_update_animator_movement(velocity)
		return
	velocity = to_target.normalized() * MOVE_SPEED
	move_and_slide()
	_update_animator_movement(velocity)


## Forces the customer onto the direct waypoint chain regardless of nav state.
## Call this when authoring a fixture without a navmesh, or when a runtime check
## proves the bake cannot reach the gameplay-critical targets.
func enable_waypoint_fallback() -> void:
	_use_waypoint_fallback = true
	_fallback_arrived = global_position.distance_squared_to(
		_fallback_target
	) < WAYPOINT_ARRIVAL_DIST_SQ


## Engages waypoint fallback when no NavigationAgent3D / NavigationRegion3D with
## a baked mesh is reachable from the current scene tree. Resolves the "navmesh
## absent or broken" gate from the BRAINDUMP Day-1 priority.
##
## §F-94 — Each fallback engagement emits a push_warning so a scene-wiring
## regression (missing NavigationAgent child, missing NavigationRegion sibling,
## empty navmesh after a bad bake) is visible in CI / dev console rather than
## silently degrading every customer in the store to direct-line movement.
## The warning is per-customer rather than once-per-scene because a partial
## regression (e.g. some customers fail to register an agent) would otherwise
## be hidden by the first emission.
func _detect_navmesh_or_fallback() -> void:
	if _navigation_agent == null:
		push_warning(
			(
				"Customer %d: NavigationAgent3D child missing; engaging "
				+ "direct-line waypoint fallback. Scene wiring regression "
				+ "(see §F-94)."
			)
			% get_instance_id()
		)
		enable_waypoint_fallback()
		return
	var region: NavigationRegion3D = _find_navigation_region()
	if region == null:
		push_warning(
			(
				"Customer %d: no NavigationRegion3D ancestor found; "
				+ "engaging direct-line waypoint fallback. Scene wiring "
				+ "regression (see §F-94)."
			)
			% get_instance_id()
		)
		enable_waypoint_fallback()
		return
	var nav_mesh: NavigationMesh = region.navigation_mesh
	if nav_mesh == null or nav_mesh.get_polygon_count() == 0:
		push_warning(
			(
				"Customer %d: NavigationRegion3D has %s; engaging "
				+ "direct-line waypoint fallback. Re-bake the navmesh "
				+ "(see §F-94)."
			)
			% [
				get_instance_id(),
				(
					"no NavigationMesh resource"
					if nav_mesh == null
					else "navmesh with 0 polygons"
				),
			]
		)
		enable_waypoint_fallback()


func _find_navigation_region() -> NavigationRegion3D:
	var node: Node = get_parent()
	while node != null:
		for child: Node in node.get_children():
			if child is NavigationRegion3D:
				return child as NavigationRegion3D
		node = node.get_parent()
	return null


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
		_set_navigation_target(target_3d.global_position)
	return true


func _navigate_to_register() -> void:
	_set_navigation_target(_register_position)


func _navigate_to_exit() -> void:
	_set_navigation_target(_exit_position)


func _evaluate_current_shelf() -> void:
	if not _current_target_slot or not _inventory_system:
		return
	_preferred_slots_dirty = true
	var slot_id: String = str(_current_target_slot.get("slot_id"))
	if slot_id.is_empty():
		return
	var location: String = "shelf:%s" % slot_id
	var items: Array[ItemInstance] = (
		_inventory_system.get_items_at_location(location)
	)
	# §F-86 — Pass 12: emits are guarded upstream by `_is_item_desirable`,
	# which rejects `item.definition == null` / null profile, so subscribers
	# (`AmbientMomentsSystem._on_customer_item_spotted`,
	# `TutorialSystem._on_customer_item_spotted`) can rely on a fully-formed
	# (Customer, ItemInstance) payload.
	for item: ItemInstance in items:
		if not _is_item_desirable(item):
			continue
		if not _desired_item:
			_desired_item = item
			_desired_item_slot = _current_target_slot
			EventBus.customer_item_spotted.emit(self, item)
		elif _score_item(item) > _score_item(_desired_item):
			_desired_item = item
			_desired_item_slot = _current_target_slot
			EventBus.customer_item_spotted.emit(self, item)


# gdlint:disable=max-returns
func _is_item_desirable(item: ItemInstance) -> bool:
	if not item.definition or not profile:
		return false
	if item.is_demo:
		return false
	var item_price: float = item.player_set_price
	if item_price <= 0.0:
		item_price = item.get_current_value()
	if item_price < profile.budget_range[0]:
		return false
	if item_price > profile.budget_range[1] * _budget_multiplier:
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


# gdlint:enable=max-returns
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
	var budget_max: float = profile.budget_range[1] * _budget_multiplier
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


## Returns the rental-tape wear appeal multiplier in [0.5, 1.0].
## Only rental tapes receive this multiplier; sale items return 1.0.
func _get_rental_wear_appeal(item: ItemInstance) -> float:
	if not item or not item.definition or not _store_controller:
		return 1.0
	if not _store_controller is VideoRentalStoreController:
		return 1.0
	var rental_ctrl: VideoRentalStoreController = (
		_store_controller as VideoRentalStoreController
	)
	if not rental_ctrl.is_rental_item(String(item.definition.category)):
		return 1.0
	return rental_ctrl.get_tape_appeal_factor(item)


## Returns the demo station purchase probability multiplier.
func _get_demo_bonus(item: ItemInstance) -> float:
	if not item.definition or not _store_controller:
		return 1.0
	if not _store_controller is ElectronicsStoreController:
		return 1.0
	var elec_ctrl: ElectronicsStoreController = (
		_store_controller as ElectronicsStoreController
	)
	if elec_ctrl.has_active_demo_for_category(item.definition.category):
		return 1.0 + elec_ctrl.get_demo_interest_bonus()
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


## Returns slots containing items matching preferred categories (cached).
func _filter_preferred_slots(slots: Array[Node]) -> Array[Node]:
	if profile.preferred_categories.is_empty() or not _inventory_system:
		return []
	var matched: Array[Node] = []
	if not _preferred_slots_dirty:
		for slot: Node in _cached_preferred_slots:
			if slot in slots:
				matched.append(slot)
		return matched
	_cached_preferred_slots.clear()
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
				_cached_preferred_slots.append(slot)
				break
	_preferred_slots_dirty = false
	for slot: Node in _cached_preferred_slots:
		if slot in slots:
			matched.append(slot)
	return matched


func _reset_browse_timer() -> void:
	browse_timer = randf_range(
		profile.browse_time_range[0] * _browse_min_multiplier,
		profile.browse_time_range[1]
	)


func _build_customer_data() -> Dictionary:
	return {
		"customer_id": get_instance_id(),
		"profile_id": profile.id if profile else "",
		"profile_name": profile.customer_name if profile else "",
		"desired_item_id": (
			str(_desired_item.instance_id) if _desired_item else ""
		),
	}


func _randomize_body_color() -> void:
	if not _body_mesh or not _head_mesh:
		return
	var base_hue: float = randf()
	var saturation: float = randf_range(0.3, 0.7)
	var value_v: float = randf_range(0.5, 0.9)
	var body_color := Color.from_hsv(base_hue, saturation, value_v)
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = body_color
	_body_mesh.material_override = body_material
	var skin_color := Color.from_hsv(
		randf_range(0.05, 0.12), randf_range(0.2, 0.5), randf_range(0.6, 0.9)
	)
	var skin_material := StandardMaterial3D.new()
	skin_material.albedo_color = skin_color
	_head_mesh.material_override = skin_material
	var pants_color := body_color.darkened(0.3)
	_apply_limb_materials(skin_material, pants_color)


func _apply_limb_materials(
	skin_material: StandardMaterial3D, pants_color: Color
) -> void:
	if _body_mesh == null:
		return
	var pants_material := StandardMaterial3D.new()
	pants_material.albedo_color = pants_color
	for child: Node in _body_mesh.get_children():
		if child is MeshInstance3D:
			var limb: MeshInstance3D = child as MeshInstance3D
			if limb.name.contains("Arm"):
				limb.material_override = skin_material
			elif limb.name.contains("Leg"):
				limb.material_override = pants_material


func _on_velocity_computed(safe_velocity: Vector3) -> void:
	velocity = safe_velocity
	move_and_slide()


func _is_navigation_finished() -> bool:
	if _use_waypoint_fallback:
		return _fallback_arrived
	if _navigation_agent == null:
		return true
	return _navigation_agent.is_navigation_finished()


func _set_navigation_target(target_position: Vector3) -> void:
	_fallback_target = target_position
	_fallback_arrived = global_position.distance_squared_to(
		target_position
	) < WAYPOINT_ARRIVAL_DIST_SQ
	if _use_waypoint_fallback or _navigation_agent == null:
		return
	_navigation_agent.target_position = target_position


func _update_animator_movement(current_velocity: Vector3) -> void:
	if _animator == null:
		return
	_animator.update_movement(current_velocity)


func _on_speed_changed(new_speed: float) -> void:
	_time_paused = new_speed <= 0.0
	if _animation_player:
		_animation_player.speed_scale = new_speed if new_speed > 0.0 else 0.0
