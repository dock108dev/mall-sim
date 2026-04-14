## Manages the staff candidate pool, hiring registry, staff lifecycle,
## daily payroll, morale events, quit triggers, and in-store NPC spawning.
extends Node

const _STAFF_NPC_SCENE: PackedScene = preload(
	"res://game/scenes/characters/staff_npc.tscn"
)

const POOL_SIZE: int = 8
const ROTATION_INTERVAL_DAYS: int = 3
const ROTATION_COUNT: int = 2

const STORE_CAPACITY: Dictionary = {
	"small": 2,
	"medium": 3,
	"large": 4,
}

const MORALE_PAID_BONUS: float = 0.05
const MORALE_NOT_PAID_PENALTY: float = -0.20
const MORALE_HIGH_SALES_BONUS: float = 0.03
const MORALE_NO_SALES_PENALTY: float = -0.05
const MORALE_WITNESSED_FIRING_PENALTY: float = -0.08
const MORALE_QUIT_THRESHOLD: float = 0.15
const MORALE_QUIT_CONSECUTIVE_DAYS: int = 2
const HIGH_SALES_THRESHOLD: int = 5

const FIRST_NAMES: PackedStringArray = [
	"Alex", "Jordan", "Casey", "Morgan", "Riley",
	"Taylor", "Dakota", "Avery", "Quinn", "Skyler",
	"Jamie", "Reese", "Drew", "Harper", "Finley",
	"Emery", "Rowan", "Blake", "Sage", "Peyton",
]

const LAST_NAMES: PackedStringArray = [
	"Smith", "Chen", "Garcia", "Patel", "Kim",
	"Jones", "Nguyen", "Brown", "Lopez", "Davis",
	"Wilson", "Moore", "Clark", "Hall", "Young",
	"Adams", "Baker", "Reed", "Ross", "Ward",
]

var _candidate_pool: Array[StaffDefinition] = []
var _staff_registry: Dictionary = {}
var _active_npcs: Dictionary = {}
var _next_id: int = 0
var _days_since_rotation: int = 0
var _daily_sales_per_store: Dictionary = {}
var _stores_with_firing_today: Dictionary = {}
var _unpaid_staff_today: Dictionary = {}


func _ready() -> void:
	_generate_initial_pool()
	EventBus.day_started.connect(_on_day_started)
	EventBus.day_ended.connect(_on_day_ended)
	EventBus.item_sold.connect(_on_item_sold)
	EventBus.staff_fired.connect(_on_staff_fired_tracked)
	EventBus.active_store_changed.connect(_on_active_store_changed)


func get_candidate_pool() -> Array[StaffDefinition]:
	return _candidate_pool


func get_staff_registry() -> Dictionary:
	return _staff_registry


func get_staff_for_store(store_id: String) -> Array[StaffDefinition]:
	var result: Array[StaffDefinition] = []
	for staff: StaffDefinition in _staff_registry.values():
		if staff.assigned_store_id == store_id:
			result.append(staff)
	return result


func get_staff_count_for_store(store_id: String) -> int:
	return get_staff_for_store(store_id).size()


func hire_candidate(
	candidate_id: String, store_id: String
) -> bool:
	var candidate: StaffDefinition = _find_candidate(candidate_id)
	if not candidate:
		push_error(
			"StaffManager: candidate '%s' not found" % candidate_id
		)
		return false
	if _is_store_at_capacity(store_id):
		push_warning(
			"StaffManager: store '%s' at staff capacity" % store_id
		)
		return false
	_candidate_pool.erase(candidate)
	candidate.assigned_store_id = store_id
	_staff_registry[candidate.staff_id] = candidate
	EventBus.staff_hired.emit(candidate.staff_id, store_id)
	return true


func fire_staff(staff_id: String) -> void:
	if not _staff_registry.has(staff_id):
		push_error(
			"StaffManager: staff '%s' not in registry" % staff_id
		)
		return
	var staff: StaffDefinition = _staff_registry[staff_id]
	var store_id: String = staff.assigned_store_id
	_despawn_npc_immediate(staff_id)
	_staff_registry.erase(staff_id)
	EventBus.staff_fired.emit(staff_id, store_id)


func quit_staff(staff_id: String) -> void:
	if not _staff_registry.has(staff_id):
		push_error(
			"StaffManager: staff '%s' not in registry" % staff_id
		)
		return
	var staff: StaffDefinition = _staff_registry[staff_id]
	var staff_name: String = staff.display_name
	var store_id: String = staff.assigned_store_id
	_staff_registry.erase(staff_id)
	EventBus.staff_quit.emit(staff_id)
	var store_name: String = _get_store_display_name(store_id)
	var toast_msg: String = "%s quit! %s is now understaffed." % [
		staff_name, store_name
	]
	EventBus.toast_requested.emit(toast_msg, &"staff", 4.0)


func get_max_staff_for_store(store_id: String) -> int:
	var size: String = _get_store_size(store_id)
	return STORE_CAPACITY.get(size, 2) as int


func get_save_data() -> Dictionary:
	var pool_data: Array[Dictionary] = []
	for candidate: StaffDefinition in _candidate_pool:
		pool_data.append(_serialize_staff(candidate))
	var registry_data: Dictionary = {}
	for id: String in _staff_registry:
		var staff: StaffDefinition = _staff_registry[id]
		registry_data[id] = _serialize_staff(staff)
	return {
		"candidate_pool": pool_data,
		"staff_registry": registry_data,
		"next_id": _next_id,
		"days_since_rotation": _days_since_rotation,
	}


func load_save_data(data: Dictionary) -> void:
	_candidate_pool.clear()
	_staff_registry.clear()
	_next_id = int(data.get("next_id", 0))
	_days_since_rotation = int(data.get("days_since_rotation", 0))
	var pool_raw: Variant = data.get("candidate_pool", [])
	if pool_raw is Array:
		for entry: Variant in pool_raw:
			if entry is Dictionary:
				_candidate_pool.append(
					_deserialize_staff(entry as Dictionary)
				)
	var reg_raw: Variant = data.get("staff_registry", {})
	if reg_raw is Dictionary:
		for id: String in reg_raw:
			var entry: Variant = (reg_raw as Dictionary)[id]
			if entry is Dictionary:
				var staff: StaffDefinition = _deserialize_staff(
					entry as Dictionary
				)
				_staff_registry[staff.staff_id] = staff


func get_daily_sales_for_store(store_id: String) -> int:
	return _daily_sales_per_store.get(store_id, 0) as int


func _on_day_started(_day: int) -> void:
	_daily_sales_per_store = {}
	_stores_with_firing_today = {}
	_unpaid_staff_today = {}
	_spawn_staff_npcs()


func _on_item_sold(
	_item_id: String, _price: float, _category: String
) -> void:
	var store_id: String = GameManager.current_store_id
	if store_id.is_empty():
		return
	var current: int = _daily_sales_per_store.get(store_id, 0) as int
	_daily_sales_per_store[store_id] = current + 1


func _on_staff_fired_tracked(
	_staff_id: String, store_id: String
) -> void:
	_stores_with_firing_today[store_id] = true


func _on_day_ended(_day: int) -> void:
	_despawn_all_npcs_with_animation()
	_run_payroll()
	_run_morale_ticks()
	_check_quit_triggers()
	_increment_seniority()
	_days_since_rotation += 1
	if _days_since_rotation >= ROTATION_INTERVAL_DAYS:
		_rotate_candidates()
		_days_since_rotation = 0


func _run_payroll() -> void:
	_unpaid_staff_today = {}
	var sorted_staff: Array[StaffDefinition] = _get_staff_sorted_by_seniority()
	var total_paid: float = 0.0
	var wage_mult: float = DifficultySystemSingleton.get_modifier(&"staff_wage_multiplier")
	for staff: StaffDefinition in sorted_staff:
		var wage: float = staff.daily_wage * wage_mult
		if wage <= 0.0:
			continue
		if _can_afford(wage):
			_deduct_wage(wage, staff.staff_id)
			total_paid += wage
		else:
			_unpaid_staff_today[staff.staff_id] = true
			EventBus.staff_not_paid.emit(staff.staff_id)
			_apply_morale_delta(staff, MORALE_NOT_PAID_PENALTY)
	if total_paid > 0.0:
		EventBus.staff_wages_paid.emit(total_paid)


func _run_morale_ticks() -> void:
	var decay_mult: float = DifficultySystemSingleton.get_modifier(&"morale_decay_multiplier")
	for staff: StaffDefinition in _staff_registry.values():
		var delta: float = 0.0
		if not _was_not_paid(staff.staff_id):
			delta += MORALE_PAID_BONUS
		var store_id: String = staff.assigned_store_id
		var store_sales: int = get_daily_sales_for_store(store_id)
		if store_sales >= HIGH_SALES_THRESHOLD:
			delta += MORALE_HIGH_SALES_BONUS
		elif store_sales == 0:
			delta += MORALE_NO_SALES_PENALTY
		if _stores_with_firing_today.has(store_id):
			delta += MORALE_WITNESSED_FIRING_PENALTY
		if delta < 0.0:
			delta *= decay_mult
		if delta != 0.0:
			_apply_morale_delta(staff, delta)


func _check_quit_triggers() -> void:
	var quit_threshold: float = DifficultySystemSingleton.get_modifier(&"staff_quit_threshold")
	var quitters: Array[String] = []
	for staff: StaffDefinition in _staff_registry.values():
		if staff.morale < quit_threshold:
			staff.consecutive_low_morale_days += 1
		else:
			staff.consecutive_low_morale_days = 0
		if (
			staff.morale < quit_threshold
			and staff.consecutive_low_morale_days >= MORALE_QUIT_CONSECUTIVE_DAYS
		):
			quitters.append(staff.staff_id)
	for staff_id: String in quitters:
		quit_staff(staff_id)


func _increment_seniority() -> void:
	for staff: StaffDefinition in _staff_registry.values():
		staff.seniority_days += 1


func _get_staff_sorted_by_seniority() -> Array[StaffDefinition]:
	var staff_list: Array[StaffDefinition] = []
	for staff: StaffDefinition in _staff_registry.values():
		staff_list.append(staff)
	staff_list.sort_custom(func(a: StaffDefinition, b: StaffDefinition) -> bool:
		return a.seniority_days > b.seniority_days
	)
	return staff_list


func _can_afford(amount: float) -> bool:
	var result: Array = []
	EventBus.payroll_cash_check.emit(amount, result)
	if result.is_empty():
		return false
	return result[0] as bool


func _deduct_wage(amount: float, staff_id: String) -> void:
	var result: Array = []
	EventBus.payroll_cash_deduct.emit(
		amount, "Wage: %s" % staff_id, result
	)


func _was_not_paid(staff_id: String) -> bool:
	return _unpaid_staff_today.has(staff_id)


func _apply_morale_delta(
	staff: StaffDefinition, delta: float
) -> void:
	staff.morale = clampf(staff.morale + delta, 0.0, 1.0)
	EventBus.staff_morale_changed.emit(
		staff.staff_id, staff.morale
	)


func _on_active_store_changed(_store_id: StringName) -> void:
	_despawn_all_npcs_immediate()


func _spawn_staff_npcs() -> void:
	var store_id: String = GameManager.current_store_id
	if store_id.is_empty():
		return

	var store_root: Node = _get_active_store_scene_root()
	if store_root == null:
		return

	var config: StoreStaffConfig = store_root.get_node_or_null(
		"StoreStaffConfig"
	) as StoreStaffConfig
	if config == null:
		push_warning(
			"StoreStaffConfig not found — staff will not spawn."
		)
		return

	var assigned: Array[StaffDefinition] = get_staff_for_store(store_id)
	for staff_def: StaffDefinition in assigned:
		var npc: StaffNPC = _STAFF_NPC_SCENE.instantiate()
		store_root.add_child(npc)
		npc.initialize(staff_def, config)
		npc.begin_shift()
		_active_npcs[staff_def.staff_id] = npc


func _despawn_all_npcs_with_animation() -> void:
	for npc: StaffNPC in _active_npcs.values():
		if is_instance_valid(npc):
			npc.end_shift()
	_active_npcs.clear()


func _despawn_all_npcs_immediate() -> void:
	for npc: StaffNPC in _active_npcs.values():
		if is_instance_valid(npc):
			npc.queue_free()
	_active_npcs.clear()


func _despawn_npc_immediate(staff_id: String) -> void:
	if not _active_npcs.has(staff_id):
		return
	var npc: StaffNPC = _active_npcs[staff_id]
	if is_instance_valid(npc):
		npc.queue_free()
	_active_npcs.erase(staff_id)


func _get_active_store_scene_root() -> Node:
	var config: StoreStaffConfig = _find_store_staff_config(
		get_tree().root
	)
	if config:
		return config.get_parent()
	return null


func _find_store_staff_config(root: Node) -> StoreStaffConfig:
	for child: Node in root.get_children():
		if child is StoreStaffConfig:
			return child
		var found: StoreStaffConfig = _find_store_staff_config(child)
		if found:
			return found
	return null


func _rotate_candidates() -> void:
	var to_remove: int = mini(ROTATION_COUNT, _candidate_pool.size())
	for i: int in range(to_remove):
		var idx: int = randi_range(0, _candidate_pool.size() - 1)
		_candidate_pool.remove_at(idx)
	var to_add: int = POOL_SIZE - _candidate_pool.size()
	for i: int in range(to_add):
		_candidate_pool.append(_generate_candidate())


func _generate_initial_pool() -> void:
	_candidate_pool.clear()
	for i: int in range(POOL_SIZE):
		_candidate_pool.append(_generate_candidate())


func _generate_candidate() -> StaffDefinition:
	var staff: StaffDefinition = StaffDefinition.new()
	_next_id += 1
	staff.staff_id = "staff_%d" % _next_id
	staff.display_name = _random_name()
	staff.role = _random_role()
	staff.skill_level = _weighted_skill_level()
	staff.morale = StaffDefinition.DEFAULT_MORALE
	return staff


func _random_name() -> String:
	var first: String = FIRST_NAMES[randi_range(
		0, FIRST_NAMES.size() - 1
	)]
	var last: String = LAST_NAMES[randi_range(
		0, LAST_NAMES.size() - 1
	)]
	return "%s %s" % [first, last]


func _random_role() -> StaffDefinition.StaffRole:
	var roles: Array[int] = [
		StaffDefinition.StaffRole.CASHIER,
		StaffDefinition.StaffRole.STOCKER,
		StaffDefinition.StaffRole.GREETER,
	]
	return roles[randi_range(0, roles.size() - 1)] as StaffDefinition.StaffRole


func _weighted_skill_level() -> int:
	var roll: float = randf()
	if roll < 0.5:
		return 1
	if roll < 0.85:
		return 2
	return 3


func _find_candidate(candidate_id: String) -> StaffDefinition:
	for candidate: StaffDefinition in _candidate_pool:
		if candidate.staff_id == candidate_id:
			return candidate
	return null


func _is_store_at_capacity(store_id: String) -> bool:
	var current: int = get_staff_count_for_store(store_id)
	var max_allowed: int = get_max_staff_for_store(store_id)
	return current >= max_allowed


func _get_store_size(store_id: String) -> String:
	if not ContentRegistry:
		return "small"
	var entry: Dictionary = ContentRegistry.get_entry(
		ContentRegistry.resolve(store_id)
	)
	if entry.is_empty():
		return "small"
	return entry.get("size_category", "small") as String


func _get_store_display_name(store_id: String) -> String:
	if store_id.is_empty():
		return "Unknown Store"
	if not ContentRegistry:
		return store_id.capitalize()
	var canonical: StringName = ContentRegistry.resolve(store_id)
	if canonical.is_empty():
		return store_id.capitalize()
	var display: String = ContentRegistry.get_display_name(canonical)
	if display.is_empty():
		return store_id.capitalize()
	return display


func _serialize_staff(staff: StaffDefinition) -> Dictionary:
	return {
		"staff_id": staff.staff_id,
		"display_name": staff.display_name,
		"role": staff.role,
		"skill_level": staff.skill_level,
		"morale": staff.morale,
		"daily_wage": staff.daily_wage,
		"seniority_days": staff.seniority_days,
		"consecutive_low_morale_days":
			staff.consecutive_low_morale_days,
		"assigned_store_id": staff.assigned_store_id,
	}


func _deserialize_staff(data: Dictionary) -> StaffDefinition:
	var staff: StaffDefinition = StaffDefinition.new()
	staff.staff_id = data.get("staff_id", "") as String
	staff.display_name = data.get("display_name", "") as String
	staff.role = int(data.get("role", 0)) as StaffDefinition.StaffRole
	staff.skill_level = int(data.get("skill_level", 1))
	staff.morale = float(data.get("morale", StaffDefinition.DEFAULT_MORALE))
	staff.seniority_days = int(data.get("seniority_days", 0))
	staff.consecutive_low_morale_days = int(
		data.get("consecutive_low_morale_days", 0)
	)
	staff.assigned_store_id = data.get(
		"assigned_store_id", ""
	) as String
	return staff
