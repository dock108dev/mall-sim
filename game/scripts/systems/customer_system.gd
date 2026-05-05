## Manages active customer NPCs within stores and mall-wide ShopperAI spawning.
class_name CustomerSystem
extends Node

const MAX_CUSTOMERS_SMALL: int = 5
const MAX_CUSTOMERS_MEDIUM: int = 8
const CUSTOMER_SCENE_PATH: String = (
	"res://game/scenes/characters/customer.tscn"
)
const SHOPPER_SCENE_PATH: String = (
	"res://game/scenes/characters/shopper_ai.tscn"
)
const POOL_SIZE: int = 12
const STAGGER_SLOTS: int = 8
const SPAWN_CHECK_INTERVAL: float = Constants.SECONDS_PER_GAME_MINUTE
const LOD_UPDATE_INTERVAL: float = 1.0
## Base entry conversion probability applied only when a greeter is assigned.
const BASE_ENTRY_CONVERSION: float = 0.85
const GREETER_ENTRY_BONUS: float = 0.2
const GREETER_BROWSE_BONUS: float = 0.15
## Cross-store traffic formula: for each adjacent store whose budget_multiplier
## (from ReputationSystem) exceeds CROSS_STORE_REP_THRESHOLD (1.2 = REPUTABLE tier),
## add CROSS_STORE_BROWSE_BONUS to the spawned customer's browse_mult.
const CROSS_STORE_REP_THRESHOLD: float = 1.2
const CROSS_STORE_BROWSE_BONUS: float = 0.15

# Hours 17–21 are unreachable on a default-day cycle: the day ends at
# STORE_CLOSE_HOUR (17), so spawn-target lookups for hours past 16 never
# happen in normal play. The entries are kept so the existing LERP from
# HOUR_DENSITY[16] toward HOUR_DENSITY[17] still drives the closing-hour
# ramp, and so the LATE_EVENING extended-hours unlock (which extends the
# day to hour 24) can still consume hours 17–21 if it ships.
const HOUR_DENSITY: Dictionary = {
	9: 0.1,
	10: 0.25,
	11: 0.55,
	12: 0.85,
	13: 0.75,
	14: 0.4,
	15: 0.35,
	16: 0.5,
	17: 0.8,
	18: 0.7,
	19: 0.45,
	20: 0.2,
	21: 0.0,
}

const DAY_OF_WEEK_MODIFIERS: Array[float] = [
	0.7, 0.75, 0.8, 0.85, 1.1, 1.3, 1.0,
]

## Day 1 reliability: after the gate opens we start a one-shot fallback timer
## so the player sees a customer within DAY1_FORCED_SPAWN_FALLBACK_SECONDS
## even when the hour-density loop rolls poorly.
const DAY1_FORCED_SPAWN_FALLBACK_SECONDS: float = 12.0

## Mirrors `CustomerSpawnEligibility.SHADY_REGULAR_LATE_AFTERNOON_WEIGHT` so
## callers (tests + balance tuning) can keep referring to
## `CustomerSystem.SHADY_REGULAR_LATE_AFTERNOON_WEIGHT` while the runtime
## implementation lives in the spawn-eligibility helper. Keep these two
## values in sync.
const SHADY_REGULAR_LATE_AFTERNOON_WEIGHT: float = 3.0

@export var max_customers_in_mall: int = 30

var _active_customers: Array[Customer] = []
var _customer_pool: Array[Customer] = []
var _spawn_pool_cache: Array[CustomerTypeDefinition] = []
var _spawn_pool_dirty: bool = true
var _vip_type_valid: bool = false
var _customer_scene: PackedScene = null
var _shopper_scene: PackedScene = null
var _store_controller: StoreController = null
var _inventory_system: InventorySystem = null
var _reputation_system: ReputationSystem = null
var _performance_manager: PerformanceManager = null
var _store_id: String = ""
var _market_event_system: MarketEventSystem = null
var _cached_greeter: StaffDefinition = null
var _max_customers: int = MAX_CUSTOMERS_SMALL
var _next_stagger_index: int = 0

var _active_mall_shopper_count: int = 0
var _in_mall_hallway: bool = true
var _current_hour: int = Constants.STORE_OPEN_HOUR
var _hour_elapsed: float = 0.0
var _time_scale: float = 1.0
var _spawn_check_timer: float = 0.0
var _lod_timer: float = 0.0
var _current_day_of_week: int = 0
var _seasonal_density_modifier: float = 1.0
var _current_archetype_weights: Dictionary = (
	ShopperArchetypeConfig.WEIGHTS_MORNING
)
var _active_event_spawn_modifier: float = 1.0
var _active_event_intent_modifier: float = 1.0
## Tracks per-event modifiers so multiple concurrent events compose correctly.
var _active_event_modifiers: Dictionary = {}
var _adjacent_store_ids: Array[String] = []
## Tracks whether the first Day 1 customer (any path: forced-spawn timer or
## hour-density loop) has spawned. Reset on day_started.
var _day1_first_customer_spawned: bool = false
## Day 1 spawn gate: blocks all customer spawns on Day 1 until at least one
## item has been stocked on a shelf. Set by `_on_item_stocked` and re-derived
## from InventorySystem on first spawn attempt so loaded saves where stocking
## already happened do not re-block spawns.
var _day1_spawn_unlocked: bool = false
var _day1_forced_spawn_timer: Timer = null

## Tracks whether at least one defective sale has been observed earlier in the
## current day. Gates angry_return_customer spawns. Reset on day_started.
var _defective_sale_today: bool = false
## Per-archetype spawn counters for the current day. Resets on day_started.
var _archetype_spawn_count_today: Dictionary = {}
## Per-day leave-reason counters keyed by reason bucket name. Reset on
## day_started, incremented in despawn_customer. Surfaces via get_leave_counts()
## for the day-summary "failed customer reasons" breakdown.
var _leave_counts: Dictionary = {
	"happy": 0,
	"no_stock": 0,
	"timeout": 0,
	"price": 0,
}
## Cached current day phase (TimeSystem.DayPhase int) so spawn-weight rules can
## consult phase without re-fetching from TimeSystem every roll.
var _current_day_phase: int = 0
## Mall-hallway ShopperAI manager. Owns LOD updates, spawn-target tracking,
## and graceful-exit flows. Constructed in `_ready` so the helper sees the
## fully-built CustomerSystem state.
var _mall_shoppers: CustomerMallShoppers = null
## Spawn-pool / archetype-gate / weight helper. Owns the per-roll eligibility
## math; constructed in `_ready` so it can read the fully-built state.
var _eligibility: CustomerSpawnEligibility = null


func _ready() -> void:
	_mall_shoppers = CustomerMallShoppers.new(self)
	_eligibility = CustomerSpawnEligibility.new(self)
	_day1_forced_spawn_timer = Timer.new()
	_day1_forced_spawn_timer.name = "Day1ForcedSpawnTimer"
	_day1_forced_spawn_timer.one_shot = true
	_day1_forced_spawn_timer.wait_time = DAY1_FORCED_SPAWN_FALLBACK_SECONDS
	_day1_forced_spawn_timer.timeout.connect(
		_on_day1_forced_spawn_timer_timeout
	)
	add_child(_day1_forced_spawn_timer)


func initialize(
	store_controller: StoreController = null,
	inventory_system: InventorySystem = null,
	reputation_system: ReputationSystem = null
) -> void:
	_despawn_all_customers()
	_clear_pool()

	_store_controller = store_controller
	_inventory_system = inventory_system
	_reputation_system = reputation_system

	_customer_scene = load(CUSTOMER_SCENE_PATH) as PackedScene
	if not _customer_scene:
		push_error("CustomerSystem: failed to load customer scene")
		return

	_shopper_scene = load(SHOPPER_SCENE_PATH) as PackedScene
	if not _shopper_scene:
		push_error("CustomerSystem: failed to load shopper scene")
		return

	_connect_signals()
	_spawn_pool_cache = []
	_spawn_pool_dirty = true
	_vip_type_valid = false
	if _eligibility != null:
		_eligibility.validate_vip_type()


func set_performance_manager(manager: PerformanceManager) -> void:
	_performance_manager = manager


func _process(delta: float) -> void:
	if _time_scale <= 0.0:
		return
	var scaled_delta: float = delta * _time_scale
	_hour_elapsed += scaled_delta
	_spawn_check_timer += scaled_delta
	while _spawn_check_timer >= SPAWN_CHECK_INTERVAL:
		_spawn_check_timer -= SPAWN_CHECK_INTERVAL
		_update_mall_shoppers()
	_lod_timer += delta
	if _lod_timer >= LOD_UPDATE_INTERVAL:
		_lod_timer -= LOD_UPDATE_INTERVAL
		_update_shopper_lod()


## Proxy hooks so test subclasses can override and instrument the per-tick
## mall-shopper / LOD work. The helper holds the implementation; these methods
## are the dispatch points _process calls each frame.
func _update_mall_shoppers() -> void:
	if _mall_shoppers != null:
		_mall_shoppers.update_mall_shoppers()


func _update_shopper_lod() -> void:
	if _mall_shoppers != null:
		_mall_shoppers.update_lod()


func _try_spawn_mall_shopper(spawn_capacity: int = -1) -> void:
	if _mall_shoppers != null:
		_mall_shoppers._try_spawn_mall_shopper(spawn_capacity)


func _spawn_shopper_group(
	archetype: PersonalityData.PersonalityType,
	spawn_pos: Vector3,
	spawn_capacity: int,
) -> void:
	if _mall_shoppers != null:
		_mall_shoppers._spawn_shopper_group(
			archetype, spawn_pos, spawn_capacity
		)


func _physics_process(_delta: float) -> void:
	if not _performance_manager or _active_customers.is_empty():
		return
	var total_script: float = 0.0
	var total_nav: float = 0.0
	var total_anim: float = 0.0
	for customer: Customer in _active_customers:
		total_script += customer.last_script_time_ms
		total_nav += customer.last_nav_time_ms
		total_anim += customer.last_anim_time_ms
	_performance_manager.record_npc_frame(
		total_script, total_nav, total_anim,
		_active_customers.size()
	)


func spawn_customer(
	profile: CustomerTypeDefinition, store_id: String = ""
) -> void:
	if _is_day1_spawn_blocked():
		return
	if profile != null and not _eligibility.is_profile_currently_spawnable(profile):
		return
	if _active_customers.size() >= _max_customers:
		push_warning(
			"CustomerSystem: max customers reached, ignoring spawn"
		)
		return

	var used_store_id: String = store_id
	if used_store_id.is_empty():
		used_store_id = _store_id

	var greeter: StaffDefinition = _get_greeter_for_store(used_store_id)
	if greeter:
		var conversion: float = minf(
			1.0,
			BASE_ENTRY_CONVERSION * (
				1.0 + GREETER_ENTRY_BONUS * greeter.performance_multiplier()
			)
		)
		if randf() > conversion:
			return

	var customer: Customer = _acquire_customer()
	if not customer:
		push_error(
			"CustomerSystem: failed to acquire customer from pool"
		)
		return

	var spawn_pos: Vector3 = _get_spawn_position()
	if not customer.is_inside_tree():
		add_child(customer)
	customer.global_position = spawn_pos
	customer.visible = true
	customer.set_physics_process(true)
	customer.set_process(true)
	customer.stagger_offset = (
		float(_next_stagger_index) / float(STAGGER_SLOTS)
	)
	_next_stagger_index = (
		(_next_stagger_index + 1) % STAGGER_SLOTS
	)
	var budget_mult: float = 1.0
	if _reputation_system:
		budget_mult = _reputation_system.get_budget_multiplier(used_store_id)
	budget_mult *= DifficultySystemSingleton.get_modifier(&"customer_budget_multiplier")
	var browse_mult: float = 1.0
	if greeter:
		browse_mult = 1.0 + GREETER_BROWSE_BONUS * greeter.performance_multiplier()
	if _reputation_system and not _adjacent_store_ids.is_empty():
		for adj_id: String in _adjacent_store_ids:
			if _reputation_system.get_budget_multiplier(adj_id) > CROSS_STORE_REP_THRESHOLD:
				browse_mult += CROSS_STORE_BROWSE_BONUS
	customer.initialize(
		profile, _store_controller, _inventory_system,
		budget_mult, browse_mult
	)
	customer.despawn_requested.connect(_on_customer_despawn_requested)
	_active_customers.append(customer)
	_eligibility.record_archetype_spawn(profile)

	if (
		GameManager.get_current_day() == 1
		and not _day1_first_customer_spawned
	):
		_day1_first_customer_spawned = true
		if (
			_day1_forced_spawn_timer != null
			and not _day1_forced_spawn_timer.is_stopped()
		):
			_day1_forced_spawn_timer.stop()

	var customer_data: Dictionary = {
		"customer_id": customer.get_instance_id(),
		"profile_id": profile.id,
		"profile_name": profile.customer_name,
		"store_id": used_store_id,
	}
	EventBus.customer_entered.emit(customer_data)
	if greeter:
		EventBus.customer_greeted.emit(
			StringName(str(customer.get_instance_id())),
			StringName(used_store_id)
		)


func despawn_customer(customer_node: Node) -> void:
	if not customer_node:
		push_warning("CustomerSystem: tried to despawn null customer")
		return

	var customer: Customer = customer_node as Customer
	if not customer:
		push_warning("CustomerSystem: node is not a Customer")
		return

	var customer_data: Dictionary = {
		"customer_id": customer.get_instance_id(),
		"profile_id": customer.profile.id if customer.profile else "",
		"profile_name": (
			customer.profile.customer_name if customer.profile else ""
		),
		"store_id": _store_id,
		"satisfied": customer._made_purchase,
		"reason": customer.get_leave_reason(),
	}

	if customer.despawn_requested.is_connected(
		_on_customer_despawn_requested
	):
		customer.despawn_requested.disconnect(
			_on_customer_despawn_requested
		)
	_active_customers.erase(customer)
	_increment_leave_count(customer.get_leave_reason())
	_release_customer(customer)
	EventBus.customer_left.emit(customer_data)


func get_active_customers() -> Array[Customer]:
	return _active_customers


func get_active_customer_count() -> int:
	return _active_customers.size()


func get_active_mall_shopper_count() -> int:
	return _active_mall_shopper_count


## Returns a copy of the per-day leave-reason counters keyed by reason bucket
## ("happy", "no_stock", "timeout", "price"). Drives the day-summary
## "failed customer reasons" breakdown and the derived "total customers"
## label. Resets on day_started.
func get_leave_counts() -> Dictionary:
	return _leave_counts.duplicate()


func _reset_leave_counts() -> void:
	_leave_counts = {
		"happy": 0,
		"no_stock": 0,
		"timeout": 0,
		"price": 0,
	}


func _increment_leave_count(reason: StringName) -> void:
	var bucket: String = ""
	match reason:
		&"purchase_complete":
			bucket = "happy"
		&"no_matching_item":
			bucket = "no_stock"
		&"patience_expired":
			bucket = "timeout"
		&"price_too_high":
			bucket = "price"
	if bucket.is_empty():
		# §F-149 — The four cases above mirror every value `Customer._leave_with`
		# can stamp on `_leave_reason`; an unknown reason here means a new code
		# path in `customer.gd` introduced a leave reason without updating this
		# match. Silently dropping it would leave the day-summary "failed
		# customer reasons" breakdown under-counted (and the derived total
		# customers count off), so surface the regression as a warning instead
		# of letting the bucket disappear.
		push_warning(
			"CustomerSystem: unmapped leave reason `%s` — day-summary breakdown will undercount."
			% String(reason)
		)
		return
	_leave_counts[bucket] = int(_leave_counts.get(bucket, 0)) + 1


func set_inventory_system(system: InventorySystem) -> void:
	_inventory_system = system


func set_market_event_system(system: MarketEventSystem) -> void:
	_market_event_system = system


## Returns the current pool of spawnable customer profiles. Thin delegate to
## CustomerSpawnEligibility so callers (tests, mall spawner) keep their
## existing entry point.
func get_spawn_pool() -> Array[CustomerTypeDefinition]:
	return _eligibility.get_spawn_pool()


## Returns true when the supplied profile may currently spawn at this store.
func is_profile_currently_spawnable(
	profile: CustomerTypeDefinition
) -> bool:
	return _eligibility.is_profile_currently_spawnable(profile)


## Returns the spawn-weight multiplier for the supplied profile under current
## conditions.
func get_profile_spawn_weight(
	profile: CustomerTypeDefinition
) -> float:
	return _eligibility.get_profile_spawn_weight(profile)


## Picks a profile from the supplied list using current spawn weights and
## archetype gates. Returns null if no candidate is currently eligible.
func pick_spawn_profile(
	profiles: Array
) -> CustomerTypeDefinition:
	return _eligibility.pick_spawn_profile(profiles)


## Returns purchase intent for a category, incorporating market event bonuses
## and the current difficulty purchase_probability_multiplier.
func get_purchase_intent_for_category(
	p_profile: CustomerTypeDefinition,
	category: StringName,
) -> float:
	var base_intent: float = p_profile.purchase_probability_base
	if _market_event_system:
		var demand_mult: float = (
			_market_event_system.get_category_demand_multiplier(category)
		)
		if demand_mult > 1.0:
			base_intent += (demand_mult - 1.0) * base_intent
	var purchase_mult: float = DifficultySystemSingleton.get_modifier(
		&"purchase_probability_multiplier"
	)
	return clampf(
		base_intent * purchase_mult * _active_event_intent_modifier, 0.0, 1.0
	)


func set_store_id(store_id: String) -> void:
	_store_id = store_id
	_update_max_customers()
	_refresh_cached_greeter()


func get_spawn_target() -> int:
	var fractional_hour: float = _get_fractional_hour()
	var density: float = _interpolate_density(fractional_hour)
	var dow_modifier: float = DAY_OF_WEEK_MODIFIERS[
		_current_day_of_week
	]
	var traffic_mult: float = DifficultySystemSingleton.get_modifier(
		&"foot_traffic_multiplier"
	)
	var raw_target: float = (
		density * float(max_customers_in_mall)
		* dow_modifier * _seasonal_density_modifier
		* traffic_mult * _active_event_spawn_modifier
	)
	return mini(roundi(raw_target), max_customers_in_mall)


func _clear_pool() -> void:
	for customer: Customer in _customer_pool:
		if is_instance_valid(customer):
			customer.queue_free()
	_customer_pool.clear()


func _connect_signals() -> void:
	if not EventBus.day_ended.is_connected(_on_day_ended):
		EventBus.day_ended.connect(_on_day_ended)
	if not EventBus.reputation_changed.is_connected(
		_on_reputation_changed
	):
		EventBus.reputation_changed.connect(_on_reputation_changed)
	if not EventBus.hour_changed.is_connected(_on_hour_changed):
		EventBus.hour_changed.connect(_on_hour_changed)
	if not EventBus.day_started.is_connected(_on_day_started):
		EventBus.day_started.connect(_on_day_started)
	if not EventBus.store_entered.is_connected(_on_store_entered):
		EventBus.store_entered.connect(_on_store_entered)
	if not EventBus.active_store_changed.is_connected(
		_on_active_store_changed
	):
		EventBus.active_store_changed.connect(_on_active_store_changed)
	if not EventBus.customer_left.is_connected(_on_customer_left):
		EventBus.customer_left.connect(_on_customer_left)
	if not EventBus.speed_changed.is_connected(_on_speed_changed):
		EventBus.speed_changed.connect(_on_speed_changed)
	if not EventBus.day_phase_changed.is_connected(
		_on_day_phase_changed
	):
		EventBus.day_phase_changed.connect(_on_day_phase_changed)
	if not EventBus.staff_hired.is_connected(_on_staff_roster_changed):
		EventBus.staff_hired.connect(_on_staff_roster_changed)
	if not EventBus.staff_fired.is_connected(_on_staff_roster_changed):
		EventBus.staff_fired.connect(_on_staff_roster_changed)
	if not EventBus.staff_quit.is_connected(_on_staff_quit):
		EventBus.staff_quit.connect(_on_staff_quit)
	if not EventBus.staff_morale_changed.is_connected(
		_on_staff_morale_changed
	):
		EventBus.staff_morale_changed.connect(_on_staff_morale_changed)
	if not EventBus.seasonal_multipliers_updated.is_connected(
		_on_seasonal_multipliers_updated
	):
		EventBus.seasonal_multipliers_updated.connect(
			_on_seasonal_multipliers_updated
		)
	if not EventBus.unlock_granted.is_connected(_on_unlock_granted):
		EventBus.unlock_granted.connect(_on_unlock_granted)
	if not EventBus.market_event_active.is_connected(_on_market_event_active):
		EventBus.market_event_active.connect(_on_market_event_active)
	if not EventBus.market_event_expired.is_connected(_on_market_event_expired):
		EventBus.market_event_expired.connect(_on_market_event_expired)
	if not EventBus.item_stocked.is_connected(_on_item_stocked):
		EventBus.item_stocked.connect(_on_item_stocked)
	if not EventBus.defective_sale_occurred.is_connected(
		_on_defective_sale_occurred
	):
		EventBus.defective_sale_occurred.connect(_on_defective_sale_occurred)
	if not EventBus.checkout_declined.is_connected(_on_checkout_declined):
		EventBus.checkout_declined.connect(_on_checkout_declined)


func _get_fractional_hour() -> float:
	var seconds_per_hour: float = (
		Constants.SECONDS_PER_GAME_MINUTE * Constants.MINUTES_PER_HOUR
	)
	var fraction: float = 0.0
	if seconds_per_hour > 0.0:
		fraction = clampf(_hour_elapsed / seconds_per_hour, 0.0, 1.0)
	return float(_current_hour) + fraction


func _interpolate_density(fractional_hour: float) -> float:
	var lower_hour: int = int(fractional_hour)
	var upper_hour: int = lower_hour + 1
	var t: float = fractional_hour - float(lower_hour)
	var lower_density: float = HOUR_DENSITY.get(lower_hour, 0.0)
	var upper_density: float = HOUR_DENSITY.get(upper_hour, 0.0)
	return lerpf(lower_density, upper_density, t)


func _update_max_customers() -> void:
	if not GameManager.data_loader or _store_id.is_empty():
		_max_customers = MAX_CUSTOMERS_SMALL
		return
	var store_def: StoreDefinition = (
		GameManager.data_loader.get_store(_store_id)
	)
	if not store_def:
		_max_customers = MAX_CUSTOMERS_SMALL
		return
	var size_cat: String = store_def.size_category
	if _reputation_system:
		_max_customers = _reputation_system.get_max_customers(
			size_cat, _store_id
		)
	elif size_cat == "medium" or size_cat == "large":
		_max_customers = MAX_CUSTOMERS_MEDIUM
	else:
		_max_customers = MAX_CUSTOMERS_SMALL


func _get_spawn_position() -> Vector3:
	if not _store_controller:
		return Vector3.ZERO
	var entry: Area3D = _store_controller.get_entry_area()
	if entry:
		return entry.global_position
	return Vector3.ZERO


func _on_customer_despawn_requested(customer: Customer) -> void:
	despawn_customer(customer)


func _on_reputation_changed(
	_changed_store_id: String, _old_score: float, _new_value: float
) -> void:
	_update_max_customers()


func _on_day_ended(_day: int) -> void:
	_despawn_all_customers()
	_mall_shoppers.despawn_all_mall_shoppers()
	_active_mall_shopper_count = 0
	_spawn_check_timer = 0.0
	_lod_timer = 0.0
	_hour_elapsed = 0.0


## §F-113 — Open the Day 1 spawn gate the moment any item lands on a shelf.
## Once set the flag is sticky for the run — subsequent unstock/sale events do
## not re-block spawns. The five silent-return guards below are race-condition
## checks for a one-shot timer schedule: a duplicate stock event, a customer
## already spawned, an active customer present, or a timer already running.
## All of these are legitimate "no-op, the system is already in the desired
## state" branches; warning would spam every stock action. The
## `_day1_forced_spawn_timer == null` arm is Tier-1 init paranoia (the timer
## is added in `_ready`); only headless test fixtures that bypass `_ready`
## would hit it, and they have no expectation of the forced-spawn fallback.
func _on_item_stocked(_item_id: String, _shelf_id: String) -> void:
	_day1_spawn_unlocked = true
	if GameManager.get_current_day() != 1:
		return
	if _day1_first_customer_spawned:
		return
	if not _active_customers.is_empty():
		return
	if _day1_forced_spawn_timer == null:
		return
	if not _day1_forced_spawn_timer.is_stopped():
		return
	_day1_forced_spawn_timer.start(DAY1_FORCED_SPAWN_FALLBACK_SECONDS)


## §F-113 — Day 1 fallback: if no customer has shown up via the hour-density
## loop within DAY1_FORCED_SPAWN_FALLBACK_SECONDS of the spawn gate opening,
## force one spawn so the demo loop is reliable. Cancelled by `spawn_customer`
## when an organic spawn lands first. Same race-guard rationale as
## `_on_item_stocked` above: each silent-return guards the timer-callback
## arrival from racing against the state it was scheduled to address (a sale
## already happened, day rolled over, a customer arrived organically). The
## `pool.is_empty()` arm is upstream-detected at content-load (CustomerTypes
## validator); reaching it here means a content-config regression that the
## boot validator already failed.
func _on_day1_forced_spawn_timer_timeout() -> void:
	if _day1_first_customer_spawned:
		return
	if not _day1_spawn_unlocked:
		return
	if GameManager.get_current_day() != 1:
		return
	if not _active_customers.is_empty():
		return
	var pool: Array[CustomerTypeDefinition] = _eligibility.get_spawn_pool()
	if pool.is_empty():
		return
	var profile: CustomerTypeDefinition = _eligibility.pick_spawn_profile(pool)
	if profile == null:
		return
	spawn_customer(profile, _store_id)


## Returns true when the Day 1 stocking gate should suppress this spawn.
##
## The gate is sticky: once unlocked it never re-locks for the run, so a sold
## item later in Day 1 does not re-block spawns. On a Day 1 save reloaded with
## items already on shelves, the InventorySystem inspection re-derives the
## unlocked state on the first spawn attempt without needing schema changes.
##
## §F-84 — Pass 12: the `_inventory_system == null` arm yields silently
## because it is the documented unit-test seam (mirrors §F-44 / §F-54
## autoload-test-seam pattern). Tests that drive `spawn_customer` directly
## without wiring `_inventory_system` rely on this fall-through; production
## code wires it via `initialize()` before any customer can spawn, so the
## branch is unreachable at runtime. Adding a warning here would only
## generate noise from the legitimate fixtures.
func _is_day1_spawn_blocked() -> bool:
	if _day1_spawn_unlocked:
		return false
	if _inventory_system == null:
		return false
	if GameManager.get_current_day() != 1:
		_day1_spawn_unlocked = true
		return false
	if not _inventory_system.get_shelf_items().is_empty():
		_day1_spawn_unlocked = true
		return false
	return true


func _on_day_started(day: int) -> void:
	_day1_first_customer_spawned = false
	if (
		_day1_forced_spawn_timer != null
		and not _day1_forced_spawn_timer.is_stopped()
	):
		_day1_forced_spawn_timer.stop()
	if day > 1:
		_day1_spawn_unlocked = true
	_active_mall_shopper_count = 0
	_current_hour = Constants.STORE_OPEN_HOUR
	_hour_elapsed = 0.0
	_spawn_check_timer = 0.0
	_lod_timer = 0.0
	_current_day_of_week = (day - 1) % 7
	_defective_sale_today = false
	_archetype_spawn_count_today.clear()
	_reset_leave_counts()
	_refresh_current_archetype_weights()


func _on_hour_changed(hour: int) -> void:
	_current_hour = hour
	_hour_elapsed = 0.0
	_refresh_current_archetype_weights()
	if hour >= Constants.STORE_CLOSE_HOUR:
		_mall_shoppers.request_all_shoppers_leave()


func _on_store_entered(_entered_store_id: StringName) -> void:
	_in_mall_hallway = false


func _on_active_store_changed(store_id: StringName) -> void:
	_in_mall_hallway = store_id.is_empty()


func _on_customer_left(customer_data: Dictionary) -> void:
	var customer_node: Node = customer_data.get("customer", null) as Node
	if customer_node == null:
		return
	if not (customer_node is ShopperAI) and not customer_node.is_in_group("shoppers"):
		return
	_decrement_active_mall_shopper_count()


func _on_store_opened(_opened_store_id: String) -> void:
	_on_store_entered(&"")


func _on_store_closed(_closed_store_id: String) -> void:
	_on_active_store_changed(&"")


func _on_customer_left_mall(
	_customer: Node, _satisfied: bool
) -> void:
	_decrement_active_mall_shopper_count()


func _decrement_active_mall_shopper_count() -> void:
	_active_mall_shopper_count = maxi(
		_active_mall_shopper_count - 1, 0
	)


func _on_seasonal_multipliers_updated(
	multipliers: Dictionary
) -> void:
	if multipliers.is_empty():
		_seasonal_density_modifier = 1.0
		return
	var total: float = 0.0
	var count: int = 0
	for store_id: String in multipliers:
		total += float(multipliers[store_id])
		count += 1
	if count > 0:
		_seasonal_density_modifier = total / float(count)
	else:
		_seasonal_density_modifier = 1.0


func _on_speed_changed(new_speed: float) -> void:
	_time_scale = new_speed


func _on_day_phase_changed(new_phase: int) -> void:
	_current_day_phase = new_phase
	_current_archetype_weights = (
		ShopperArchetypeConfig.get_weights_for_phase(new_phase)
	)


func _on_defective_sale_occurred(_item_id: String, _reason: String) -> void:
	_defective_sale_today = true


## Day 1 recovery: the player declined the sale at the register before the
## first sale completed. Re-open the spawn slot and re-arm the forced-spawn
## fallback so the next customer arrives within the documented window even
## when the hour-density loop has already burned its scripted slot. The first
## customer's despawn animation runs in parallel; the timer's existing
## `_active_customers.is_empty()` guard defers spawning until they have left.
func _on_checkout_declined(_customer: Node) -> void:
	if GameManager.get_current_day() != 1:
		return
	if GameState.get_flag(&"first_sale_complete"):
		return
	if _day1_forced_spawn_timer == null:
		# §F-144 — Reaching this branch on Day 1 pre-first-sale means the
		# forced-spawn timer was never instantiated by `_ready` /
		# `initialize`. The player just declined a sale and the rail is
		# rolling back to "wait for a customer" (ObjectiveDirector
		# §_on_checkout_declined), but no fallback timer will arm. Without
		# a log line the bug presents as "Day 1 stalls after declining the
		# first customer" — surface the Tier-3 init regression instead.
		push_warning(
			"CustomerSystem: Day-1 forced-spawn timer missing on "
			+ "checkout_declined; next customer will not auto-spawn."
		)
		return
	_day1_first_customer_spawned = false
	if not _day1_forced_spawn_timer.is_stopped():
		_day1_forced_spawn_timer.stop()
	_day1_forced_spawn_timer.start(DAY1_FORCED_SPAWN_FALLBACK_SECONDS)


func _despawn_all_customers() -> void:
	var to_remove: Array[Customer] = _active_customers.duplicate()
	for customer: Customer in to_remove:
		despawn_customer(customer)


func _refresh_cached_greeter() -> void:
	if _store_id.is_empty():
		_cached_greeter = null
		return
	_cached_greeter = null
	var staff: Array[StaffDefinition] = (
		StaffManager.get_staff_for_store(_store_id)
	)
	for s: StaffDefinition in staff:
		if s.role == StaffDefinition.StaffRole.GREETER:
			_cached_greeter = s
			return


func _get_greeter_for_store(
	store_id: String
) -> StaffDefinition:
	if store_id == _store_id:
		return _cached_greeter
	var staff: Array[StaffDefinition] = (
		StaffManager.get_staff_for_store(store_id)
	)
	for s: StaffDefinition in staff:
		if s.role == StaffDefinition.StaffRole.GREETER:
			return s
	return null


func _on_staff_roster_changed(
	_staff_id: String, store_id: String
) -> void:
	if store_id == _store_id:
		_refresh_cached_greeter()


func _on_staff_quit(_staff_id: String) -> void:
	_refresh_cached_greeter()


func _on_staff_morale_changed(
	_staff_id: String, _new_morale: float
) -> void:
	_refresh_cached_greeter()


func _on_market_event_active(event_id: StringName, modifier: Dictionary) -> void:
	_active_event_modifiers[event_id] = modifier
	_recalculate_event_modifiers()


func _on_market_event_expired(event_id: StringName) -> void:
	_active_event_modifiers.erase(event_id)
	_recalculate_event_modifiers()


func _recalculate_event_modifiers() -> void:
	var spawn_mult: float = 1.0
	var intent_mult: float = 1.0
	for mod: Dictionary in _active_event_modifiers.values():
		spawn_mult *= mod.get("spawn_rate_multiplier", 1.0) as float
		intent_mult *= mod.get("purchase_intent_multiplier", 1.0) as float
	_active_event_spawn_modifier = spawn_mult
	_active_event_intent_modifier = intent_mult


func _refresh_current_archetype_weights() -> void:
	_current_archetype_weights = (
		ShopperArchetypeConfig.get_weights_for_hour(_current_hour)
	)


func _on_unlock_granted(unlock_id: StringName) -> void:
	if unlock_id == CustomerSpawnEligibility.VIP_UNLOCK_ID:
		_eligibility.mark_pool_dirty()


func _acquire_customer() -> Customer:
	if not _customer_pool.is_empty():
		return _customer_pool.pop_back()
	if not _customer_scene:
		return null
	return _customer_scene.instantiate() as Customer


func _release_customer(customer: Customer) -> void:
	customer.visible = false
	customer.set_physics_process(false)
	customer.set_process(false)
	if _customer_pool.size() < POOL_SIZE:
		_customer_pool.append(customer)
	else:
		customer.queue_free()
