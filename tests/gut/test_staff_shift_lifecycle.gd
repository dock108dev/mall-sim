## Tests staff NPC shift lifecycle — spawn on day_started, despawn
## on day_ended, store transitions, and mid-day fire.
extends GutTest


var _manager: Node = null


func before_each() -> void:
	_manager = preload(
		"res://game/autoload/staff_manager.gd"
	).new()
	_manager._generate_initial_pool()


func after_each() -> void:
	if _manager:
		_manager.free()
		_manager = null


func test_active_npcs_starts_empty() -> void:
	assert_eq(_manager._active_npcs.size(), 0)


func test_spawn_skipped_when_no_active_store() -> void:
	_manager._spawn_staff_npcs()
	assert_eq(_manager._active_npcs.size(), 0)


func test_day_started_resets_tracking_dicts() -> void:
	_manager._daily_sales_per_store["test"] = 5
	_manager._stores_with_firing_today["test"] = true
	_manager._unpaid_staff_today["staff_1"] = true
	_manager._on_day_started(1)
	assert_eq(_manager._daily_sales_per_store.size(), 0)
	assert_eq(_manager._stores_with_firing_today.size(), 0)
	assert_eq(_manager._unpaid_staff_today.size(), 0)


func test_despawn_all_immediate_clears_dict() -> void:
	_manager._active_npcs["staff_1"] = null
	_manager._active_npcs["staff_2"] = null
	_manager._despawn_all_npcs_immediate()
	assert_eq(_manager._active_npcs.size(), 0)


func test_despawn_all_with_animation_clears_dict() -> void:
	_manager._active_npcs["staff_1"] = null
	_manager._active_npcs["staff_2"] = null
	_manager._despawn_all_npcs_with_animation()
	assert_eq(_manager._active_npcs.size(), 0)


func test_despawn_npc_immediate_removes_entry() -> void:
	_manager._active_npcs["staff_1"] = null
	_manager._active_npcs["staff_2"] = null
	_manager._despawn_npc_immediate("staff_1")
	assert_eq(_manager._active_npcs.size(), 1)
	assert_false(_manager._active_npcs.has("staff_1"))
	assert_true(_manager._active_npcs.has("staff_2"))


func test_despawn_npc_immediate_noop_for_unknown_id() -> void:
	_manager._active_npcs["staff_1"] = null
	_manager._despawn_npc_immediate("nonexistent")
	assert_eq(_manager._active_npcs.size(), 1)


func test_fire_staff_clears_active_npc_entry() -> void:
	var pool: Array = _manager.get_candidate_pool()
	var candidate_id: String = (pool[0] as StaffDefinition).staff_id
	_manager.hire_candidate(candidate_id, "test_store")
	_manager._active_npcs[candidate_id] = null
	_manager.fire_staff(candidate_id)
	assert_false(_manager._active_npcs.has(candidate_id))


func test_active_store_changed_clears_all_npcs() -> void:
	_manager._active_npcs["staff_1"] = null
	_manager._active_npcs["staff_2"] = null
	_manager._on_active_store_changed(&"new_store")
	assert_eq(_manager._active_npcs.size(), 0)


func test_hire_mid_day_does_not_spawn_npc() -> void:
	var pool: Array = _manager.get_candidate_pool()
	var candidate_id: String = (pool[0] as StaffDefinition).staff_id
	_manager.hire_candidate(candidate_id, "test_store")
	assert_false(
		_manager._active_npcs.has(candidate_id),
		"Hiring mid-day should not spawn NPC immediately"
	)


func test_get_active_store_scene_root_returns_null_without_tree() -> void:
	var result: Node = _manager._get_active_store_scene_root()
	assert_null(result)
