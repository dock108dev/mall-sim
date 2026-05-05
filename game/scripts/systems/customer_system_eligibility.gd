## Spawn-pool / archetype-gate / weight logic for CustomerSystem. Pulled out so
## the per-roll eligibility math (VIP unlock, defective-sale and shady-regular
## gates, platform shortage / late-afternoon weight bias) lives next to its
## own constants rather than spanning the in-store customer file.
##
## State (spawn pool cache, dirty bit, vip-validation flag, per-day archetype
## counts) is held on the parent CustomerSystem and accessed via the held
## reference. Construct with `CustomerSpawnEligibility.new(customer_system)`.
class_name CustomerSpawnEligibility
extends RefCounted

const VIP_CUSTOMER_ID: StringName = &"vip_customer"
const VIP_UNLOCK_ID: StringName = &"vip_customer_events"

const ARCHETYPE_ANGRY_RETURN: StringName = &"angry_return_customer"
const ARCHETYPE_SHADY_REGULAR: StringName = &"shady_regular"
const SHADY_REGULAR_DAILY_CAP: int = 1
## Multiplier applied to shady_regular spawn weight in the AFTERNOON DayPhase
## (the closing-hour "low traffic, staff distracted" window).
const SHADY_REGULAR_LATE_AFTERNOON_WEIGHT: float = 3.0

var _cs: Node = null


func _init(customer_system: Node) -> void:
	_cs = customer_system


## Returns the current pool of spawnable customer profiles.
## VIP_CUSTOMER is included only when vip_customer_events is unlocked.
func get_spawn_pool() -> Array[CustomerTypeDefinition]:
	if _cs._spawn_pool_dirty:
		_rebuild_spawn_pool()
	return _cs._spawn_pool_cache


## Returns true when the supplied profile may currently spawn at this store.
## Applies the per-day archetype gates:
##   - angry_return_customer: requires defective_sale_occurred earlier today.
##   - shady_regular: capped at SHADY_REGULAR_DAILY_CAP per day.
## Profiles without an archetype_id (or with an unrecognized one) always pass.
func is_profile_currently_spawnable(
	profile: CustomerTypeDefinition
) -> bool:
	if profile == null:
		return false
	var archetype: StringName = profile.archetype_id
	if archetype == ARCHETYPE_ANGRY_RETURN:
		return _cs._defective_sale_today
	if archetype == ARCHETYPE_SHADY_REGULAR:
		var spawned: int = int(
			_cs._archetype_spawn_count_today.get(archetype, 0)
		)
		return spawned < SHADY_REGULAR_DAILY_CAP
	return true


## Returns the spawn-weight multiplier for the supplied profile under current
## conditions. Combines:
##   - PlatformSystem shortage boost (driven by platform_affinities).
##   - shady_regular phase bias (3× during AFTERNOON, the closing-hour window).
## Always returns >= 0.0; profiles that are gate-rejected return 0.0.
func get_profile_spawn_weight(
	profile: CustomerTypeDefinition
) -> float:
	if profile == null:
		return 0.0
	if not is_profile_currently_spawnable(profile):
		return 0.0
	var weight: float = profile.spawn_weight
	if weight <= 0.0:
		weight = 1.0
	var platform_system: Node = _cs.get_node_or_null(
		"/root/PlatformSystem"
	)
	if platform_system != null and platform_system.has_method(
		"get_spawn_weight_modifier"
	):
		weight *= float(
			platform_system.get_spawn_weight_modifier(profile)
		)
	var customization: Node = _cs.get_node_or_null(
		"/root/StoreCustomizationSystem"
	)
	if customization != null and customization.has_method(
		"get_spawn_weight_bonus"
	):
		weight *= float(
			customization.call("get_spawn_weight_bonus", profile.archetype_id)
		)
	if (
		profile.archetype_id == ARCHETYPE_SHADY_REGULAR
		and _cs._current_day_phase == int(TimeSystem.DayPhase.AFTERNOON)
	):
		weight *= SHADY_REGULAR_LATE_AFTERNOON_WEIGHT
	return weight


## Picks a profile from the supplied list using current spawn weights and
## archetype gates. Returns null if no candidate is currently eligible.
func pick_spawn_profile(
	profiles: Array
) -> CustomerTypeDefinition:
	var candidates: Array[CustomerTypeDefinition] = []
	var weights: Array[float] = []
	var total: float = 0.0
	for entry: Variant in profiles:
		var profile: CustomerTypeDefinition = (
			entry as CustomerTypeDefinition
		)
		if profile == null:
			continue
		var weight: float = get_profile_spawn_weight(profile)
		if weight <= 0.0:
			continue
		candidates.append(profile)
		weights.append(weight)
		total += weight
	if candidates.is_empty() or total <= 0.0:
		return null
	var roll: float = randf() * total
	var running: float = 0.0
	for index: int in range(candidates.size()):
		running += weights[index]
		if roll <= running:
			return candidates[index]
	return candidates[candidates.size() - 1]


func record_archetype_spawn(profile: CustomerTypeDefinition) -> void:
	if profile == null or profile.archetype_id == &"":
		return
	var archetype: StringName = profile.archetype_id
	var count: int = int(
		_cs._archetype_spawn_count_today.get(archetype, 0)
	)
	_cs._archetype_spawn_count_today[archetype] = count + 1


func mark_pool_dirty() -> void:
	_cs._spawn_pool_dirty = true


func validate_vip_type() -> void:
	if not GameManager.data_loader:
		return
	for profile: CustomerTypeDefinition in (
		GameManager.data_loader.get_all_customers()
	):
		if StringName(profile.id) == VIP_CUSTOMER_ID:
			_cs._vip_type_valid = true
			return
	push_warning(
		"CustomerSystem: VIP customer type '%s' not found in registry"
		% VIP_CUSTOMER_ID
	)


func _rebuild_spawn_pool() -> void:
	_cs._spawn_pool_cache = []
	if not GameManager.data_loader:
		_cs._spawn_pool_dirty = false
		return
	var vip_included: bool = (
		_cs._vip_type_valid and UnlockSystemSingleton.is_unlocked(VIP_UNLOCK_ID)
	)
	for profile: CustomerTypeDefinition in (
		GameManager.data_loader.get_all_customers()
	):
		if StringName(profile.id) == VIP_CUSTOMER_ID:
			if vip_included:
				_cs._spawn_pool_cache.append(profile)
		else:
			_cs._spawn_pool_cache.append(profile)
	_cs._spawn_pool_dirty = false
