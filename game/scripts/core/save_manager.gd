## Manages saving and loading game state to JSON files in user://saves/.
class_name SaveManager
extends Node


const CURRENT_SAVE_VERSION: int = 2
const SAVE_DIR := "user://saves/"
const SLOT_INDEX_PATH := "user://save_index.cfg"
const MAX_MANUAL_SLOTS: int = 3
const AUTO_SAVE_SLOT: int = 0

var _economy_system: EconomySystem
var _order_system: OrderSystem
var _inventory_system: InventorySystem
var _time_system: TimeSystem
var _reputation_ref: ReputationSystem
var _store_state_manager: StoreStateManager
var _progression_system: ProgressionSystem
var _milestone_system: MilestoneSystem
var _refurbishment_system: RefurbishmentSystem
var _rental_system: VideoRentalStoreController
var _trend_system: TrendSystem
var _market_event_system: MarketEventSystem
var _fixture_placement_system: FixturePlacementSystem
var _tournament_system: TournamentSystem
var _meta_shift_system: MetaShiftSystem
var _seasonal_event_system: SeasonalEventSystem
var _random_event_system: RandomEventSystem
var _staff_system: StaffSystem
var _tutorial_system: TutorialSystem
var _season_cycle_system: SeasonCycleSystem
var _secret_thread_manager: SecretThreadManager
var _secret_thread_system: SecretThreadSystem
var _ambient_moments_system: AmbientMomentsSystem
var _ending_evaluator: EndingEvaluatorSystem
var _store_upgrade_system: StoreUpgradeSystem
var _completion_tracker: CompletionTracker
var _performance_report_system: PerformanceReportSystem
var _unlock_system: UnlockSystem
var _onboarding_system: OnboardingSystem
var _pending_auto_save_day: int = -1


func initialize(
	economy: EconomySystem,
	inventory: InventorySystem,
	time: TimeSystem,
) -> void:
	_economy_system = economy
	_inventory_system = inventory
	_time_system = time
	_ensure_save_dir()


## Sets the ReputationSystem reference for testing.
func set_reputation_system(system: ReputationSystem) -> void:
	_reputation_ref = system


## Sets the OrderSystem reference for save/load.
func set_order_system(system: OrderSystem) -> void:
	_order_system = system


## Sets the StoreStateManager reference for multi-store save/load.
func set_store_state_manager(manager: StoreStateManager) -> void:
	_store_state_manager = manager
	_ensure_save_dir()
	EventBus.day_ended.connect(_on_day_ended)
	EventBus.next_day_confirmed.connect(_on_next_day_confirmed)
	EventBus.ending_triggered.connect(_on_ending_triggered)


## Sets the ProgressionSystem reference for milestone save/load.
func set_progression_system(system: ProgressionSystem) -> void:
	_progression_system = system


func set_milestone_system(system: MilestoneSystem) -> void:
	_milestone_system = system


## Sets the RefurbishmentSystem reference for save/load.
func set_refurbishment_system(
	system: RefurbishmentSystem
) -> void:
	_refurbishment_system = system


## Sets the TrendSystem reference for save/load.
func set_trend_system(system: TrendSystem) -> void:
	_trend_system = system


## Sets the MarketEventSystem reference for save/load.
func set_market_event_system(
	system: MarketEventSystem
) -> void:
	_market_event_system = system


## Sets the FixturePlacementSystem reference for save/load.
func set_fixture_placement_system(
	system: FixturePlacementSystem
) -> void:
	_fixture_placement_system = system


## Sets the TournamentSystem reference for save/load.
func set_tournament_system(
	system: TournamentSystem
) -> void:
	_tournament_system = system


## Sets the MetaShiftSystem reference for save/load.
func set_meta_shift_system(
	system: MetaShiftSystem
) -> void:
	_meta_shift_system = system


## Sets the SeasonalEventSystem reference for save/load.
func set_seasonal_event_system(
	system: SeasonalEventSystem
) -> void:
	_seasonal_event_system = system


## Sets the RandomEventSystem reference for save/load.
func set_random_event_system(
	system: RandomEventSystem
) -> void:
	_random_event_system = system


## Sets the VideoRentalStoreController reference for save/load.
func set_rental_system(
	system: VideoRentalStoreController
) -> void:
	_rental_system = system


## Sets the StaffSystem reference for save/load.
func set_staff_system(system: StaffSystem) -> void:
	_staff_system = system


## Sets the TutorialSystem reference for save/load.
func set_tutorial_system(system: TutorialSystem) -> void:
	_tutorial_system = system


## Sets the SeasonCycleSystem reference for save/load.
func set_season_cycle_system(system: SeasonCycleSystem) -> void:
	_season_cycle_system = system


## Sets the SecretThreadManager reference for save/load.
func set_secret_thread_manager(
	manager: SecretThreadManager
) -> void:
	_secret_thread_manager = manager


## Sets the SecretThreadSystem reference for save/load.
func set_secret_thread_system(
	system: SecretThreadSystem
) -> void:
	_secret_thread_system = system


## Sets the AmbientMomentsSystem reference for save/load.
func set_ambient_moments_system(
	system: AmbientMomentsSystem
) -> void:
	_ambient_moments_system = system


## Sets the EndingEvaluatorSystem reference for save/load.
func set_ending_evaluator(
	evaluator: EndingEvaluatorSystem
) -> void:
	_ending_evaluator = evaluator


## Sets the StoreUpgradeSystem reference for save/load.
func set_store_upgrade_system(
	system: StoreUpgradeSystem
) -> void:
	_store_upgrade_system = system


## Sets the CompletionTracker reference for save/load.
func set_completion_tracker(
	tracker: CompletionTracker
) -> void:
	_completion_tracker = tracker


## Sets the PerformanceReportSystem reference for save/load.
func set_performance_report_system(
	system: PerformanceReportSystem
) -> void:
	_performance_report_system = system


func set_unlock_system(system: UnlockSystem) -> void:
	_unlock_system = system


## Sets the OnboardingSystem reference for save/load.
func set_onboarding_system(system: OnboardingSystem) -> void:
	_onboarding_system = system


## Flags the current auto-save slot as a completed run, preventing
## further auto-saves from overwriting the ending state.
func mark_run_complete(ending_id: StringName) -> void:
	_pending_auto_save_day = -1
	if not _systems_ready():
		return
	var path: String = _get_slot_path(AUTO_SAVE_SLOT)
	if not FileAccess.file_exists(path):
		return
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return
	file.close()
	var data: Variant = json.data
	if data is not Dictionary:
		return
	var save_data: Dictionary = data as Dictionary
	var metadata: Dictionary = save_data.get("metadata", {}) as Dictionary
	metadata["run_complete"] = true
	metadata["ending_id"] = String(ending_id)
	save_data["metadata"] = metadata
	var out_file: FileAccess = FileAccess.open(
		path, FileAccess.WRITE
	)
	if not out_file:
		return
	out_file.store_string(JSON.stringify(save_data, "\t"))
	out_file.close()
	_update_slot_index(AUTO_SAVE_SLOT, metadata)


func save_game(slot: int) -> bool:
	if not _validate_slot(slot):
		return false
	if not _systems_ready():
		push_warning("SaveManager: systems not initialized")
		return false
	_ensure_save_dir()

	var save_data: Dictionary = _collect_save_data()
	var path: String = _get_slot_path(slot)

	var json_string: String = JSON.stringify(save_data, "\t")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_warning(
			"SaveManager: failed to open '%s' for writing — %s"
			% [path, error_string(FileAccess.get_open_error())]
		)
		return false

	file.store_string(json_string)
	file.close()

	var index_meta: Dictionary = {}
	var sm: Variant = save_data.get("save_metadata", {})
	if sm is Dictionary:
		index_meta = (sm as Dictionary).duplicate()
	var legacy: Variant = save_data.get("metadata", {})
	if legacy is Dictionary:
		for key: String in legacy as Dictionary:
			if not index_meta.has(key):
				index_meta[key] = (legacy as Dictionary)[key]
	_update_slot_index(slot, index_meta)
	EventBus.notification_requested.emit("Game saved.")
	return true


func load_game(slot: int) -> bool:
	if not _validate_slot(slot):
		return false
	if not _systems_ready():
		push_warning("SaveManager: systems not initialized")
		return false

	var path: String = _get_slot_path(slot)
	if not FileAccess.file_exists(path):
		var reason: String = "No save file at '%s'" % path
		push_warning("SaveManager: %s" % reason)
		EventBus.save_load_failed.emit(slot, reason)
		return false

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		var reason: String = (
			"Failed to open '%s' — %s"
			% [path, error_string(FileAccess.get_open_error())]
		)
		push_warning("SaveManager: %s" % reason)
		EventBus.save_load_failed.emit(slot, reason)
		return false

	var json_string: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result: Error = json.parse(json_string)
	if parse_result != OK:
		var reason: String = (
			"JSON parse error in '%s' at line %d — %s"
			% [path, json.get_error_line(), json.get_error_message()]
		)
		push_warning("SaveManager: %s" % reason)
		EventBus.save_load_failed.emit(slot, reason)
		return false

	var data: Variant = json.data
	if data is not Dictionary:
		var reason: String = "Save file root is not a Dictionary"
		push_warning("SaveManager: %s" % reason)
		EventBus.save_load_failed.emit(slot, reason)
		return false

	var save_data: Dictionary = data as Dictionary
	save_data = _migrate_save(save_data)
	_distribute_save_data(save_data)
	return true


func slot_exists(slot: int) -> bool:
	if not _validate_slot(slot):
		return false
	return FileAccess.file_exists(_get_slot_path(slot))


func get_slot_metadata(slot: int) -> Dictionary:
	if not slot_exists(slot):
		return {}

	var path: String = _get_slot_path(slot)
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}

	var json_string: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(json_string) != OK:
		return {}

	var data: Variant = json.data
	if data is not Dictionary:
		return {}

	var save_dict: Dictionary = data as Dictionary
	var preview: Variant = save_dict.get("save_metadata", {})
	var result: Dictionary = {}
	if preview is Dictionary and not (preview as Dictionary).is_empty():
		result = (preview as Dictionary).duplicate()
	else:
		result = (save_dict.get("metadata", {}) as Dictionary).duplicate()

	var difficulty: Variant = save_dict.get("difficulty", {})
	if difficulty is Dictionary:
		result["used_difficulty_downgrade"] = (
			(difficulty as Dictionary).get("used_difficulty_downgrade", false)
		)
	return result


func delete_save(slot: int) -> bool:
	if not _validate_slot(slot):
		return false
	var path: String = _get_slot_path(slot)
	if not FileAccess.file_exists(path):
		return false
	var err: Error = DirAccess.remove_absolute(path)
	if err != OK:
		push_warning(
			"SaveManager: failed to delete '%s' — %s"
			% [path, error_string(err)]
		)
		return false
	_remove_slot_from_index(slot)
	return true


func _collect_save_data() -> Dictionary:
	var metadata: Dictionary = {
		"timestamp": Time.get_datetime_string_from_system(true),
		"day_number": _time_system.current_day,
		"store_type": GameManager.current_store_id,
		"play_time": _time_system.get_play_time_seconds(),
	}

	var owned_slots_data: Dictionary = {}
	var owned_store_list: Array[String] = []
	if _store_state_manager:
		var slots: Dictionary = _store_state_manager.owned_slots
		for idx: int in slots:
			var store_id: String = String(slots[idx])
			owned_slots_data[str(idx)] = store_id
			owned_store_list.append(store_id)

	var save_metadata: Dictionary = {
		"day": _time_system.current_day,
		"cash": _economy_system.get_cash(),
		"owned_stores": owned_store_list,
		"saved_at": Time.get_datetime_string_from_system(true),
	}

	var data: Dictionary = {
		"save_version": CURRENT_SAVE_VERSION,
		"metadata": metadata,
		"save_metadata": save_metadata,
		"time": _time_system.get_save_data(),
		"economy": _economy_system.get_save_data(),
		"inventory": _inventory_system.get_save_data(),
		"reputation": _get_reputation_system().get_save_data(),
		"owned_slots": owned_slots_data,
	}

	if _order_system:
		data["ordering"] = _order_system.get_save_data()

	if _store_state_manager:
		data["store_states"] = _store_state_manager.get_save_data()

	if _progression_system:
		data["progression"] = _progression_system.get_save_data()

	if _milestone_system:
		data["milestones"] = _milestone_system.get_save_data()

	if _refurbishment_system:
		data["refurbishment"] = _refurbishment_system.get_save_data()

	if _rental_system:
		data["rental"] = _rental_system.get_save_data()

	if _trend_system:
		data["trends"] = _trend_system.get_save_data()

	if _market_event_system:
		data["market_events"] = _market_event_system.get_save_data()

	if _fixture_placement_system:
		data["fixtures"] = _fixture_placement_system.get_save_data()

	if _tournament_system:
		data["tournament"] = _tournament_system.get_save_data()

	if _meta_shift_system:
		data["meta_shift"] = _meta_shift_system.get_save_data()

	if _seasonal_event_system:
		data["seasonal_events"] = (
			_seasonal_event_system.get_save_data()
		)

	if _random_event_system:
		data["random_events"] = (
			_random_event_system.get_save_data()
		)

	if _staff_system:
		data["staff"] = _staff_system.get_save_data()

	if _tutorial_system:
		data["tutorial"] = _tutorial_system.get_save_data()

	if _season_cycle_system:
		data["season_cycle"] = _season_cycle_system.get_save_data()

	if _secret_thread_manager:
		var secret_data: Dictionary = (
			_secret_thread_manager.get_save_data()
		)
		if not secret_data.is_empty():
			data["secret_state"] = secret_data

	if _secret_thread_system:
		data["secret_threads"] = (
			_secret_thread_system.get_save_data()
		)

	if _ambient_moments_system:
		data["ambient_moments"] = (
			_ambient_moments_system.get_save_data()
		)

	if _ending_evaluator:
		var ending_data: Dictionary = (
			_ending_evaluator.get_save_data()
		)
		if not ending_data.is_empty():
			data["ending"] = ending_data

	if _store_upgrade_system:
		data["store_upgrades"] = (
			_store_upgrade_system.get_save_data()
		)

	if _completion_tracker:
		data["completion"] = (
			_completion_tracker.get_save_data()
		)

	if _performance_report_system:
		data["performance_reports"] = (
			_performance_report_system.get_save_data()
		)

	if _unlock_system:
		data["unlocks"] = _unlock_system.get_save_data()

	if _onboarding_system:
		data["onboarding_progress"] = _onboarding_system.get_save_data()

	data["difficulty"] = DifficultySystemSingleton.get_save_data()

	return data


func _distribute_save_data(data: Dictionary) -> void:
	var time_data: Variant = data.get("time", {})
	if time_data is Dictionary:
		_time_system.load_save_data(time_data as Dictionary)

	var economy_data: Variant = data.get("economy", {})
	if economy_data is Dictionary:
		_economy_system.load_save_data(economy_data as Dictionary)

	var inventory_data: Variant = data.get("inventory", {})
	if inventory_data is Dictionary:
		_inventory_system.load_save_data(inventory_data as Dictionary)

	var reputation_data: Variant = data.get("reputation", {})
	if reputation_data is Dictionary:
		_get_reputation_system().load_save_data(reputation_data as Dictionary)

	if _order_system:
		var ordering_data: Variant = data.get("ordering", {})
		if ordering_data is Dictionary:
			_order_system.load_save_data(
				ordering_data as Dictionary
			)

	if _store_state_manager:
		var store_data: Variant = data.get("store_states", {})
		if store_data is Dictionary:
			_store_state_manager.load_save_data(
				store_data as Dictionary
			)
		var saved_slots: Variant = data.get("owned_slots", {})
		if saved_slots is Dictionary:
			_store_state_manager.restore_owned_slots(
				saved_slots as Dictionary
			)
	else:
		var saved_slots: Variant = data.get("owned_slots", {})
		if saved_slots is Dictionary and not (saved_slots as Dictionary).is_empty():
			GameManager.owned_stores = []
			for key: Variant in saved_slots:
				var canonical: StringName = ContentRegistry.resolve(
					str(saved_slots[key])
				)
				if not canonical.is_empty():
					if canonical not in GameManager.owned_stores:
						GameManager.owned_stores.append(canonical)
		if GameManager.owned_stores.is_empty():
			GameManager.owned_stores = [
				GameManager.DEFAULT_STARTING_STORE
			]

	if _progression_system:
		var prog_data: Variant = data.get("progression", {})
		if prog_data is Dictionary:
			_progression_system.load_save_data(
				prog_data as Dictionary
			)

	if _milestone_system:
		var ms_data: Variant = data.get("milestones", {})
		if ms_data is Dictionary:
			_milestone_system.load_state(ms_data as Dictionary)

	if _refurbishment_system:
		var refurb_data: Variant = data.get("refurbishment", {})
		if refurb_data is Dictionary:
			_refurbishment_system.load_save_data(
				refurb_data as Dictionary
			)

	if _rental_system:
		var rental_data: Variant = data.get("rental", {})
		if rental_data is Dictionary:
			_rental_system.load_save_data(
				rental_data as Dictionary
			)

	if _trend_system:
		var trend_data: Variant = data.get("trends", {})
		if trend_data is Dictionary:
			_trend_system.load_save_data(
				trend_data as Dictionary
			)

	if _market_event_system:
		var market_event_data: Variant = data.get(
			"market_events", {}
		)
		if market_event_data is Dictionary:
			_market_event_system.load_save_data(
				market_event_data as Dictionary
			)

	if _fixture_placement_system:
		var fixture_data: Variant = data.get("fixtures", {})
		if fixture_data is Dictionary:
			_fixture_placement_system.load_save_data(
				fixture_data as Dictionary
			)

	if _tournament_system:
		var tournament_data: Variant = data.get("tournament", {})
		if tournament_data is Dictionary:
			_tournament_system.load_save_data(
				tournament_data as Dictionary
			)

	if _meta_shift_system:
		var meta_shift_data: Variant = data.get("meta_shift", {})
		if meta_shift_data is Dictionary:
			_meta_shift_system.load_save_data(
				meta_shift_data as Dictionary
			)

	if _seasonal_event_system:
		var seasonal_data: Variant = data.get(
			"seasonal_events", {}
		)
		if seasonal_data is Dictionary:
			_seasonal_event_system.load_save_data(
				seasonal_data as Dictionary
			)

	if _random_event_system:
		var random_data: Variant = data.get(
			"random_events", {}
		)
		if random_data is Dictionary:
			_random_event_system.load_save_data(
				random_data as Dictionary
			)

	if _staff_system:
		var staff_data: Variant = data.get("staff", {})
		if staff_data is Dictionary:
			_staff_system.load_save_data(
				staff_data as Dictionary
			)

	if _tutorial_system:
		var tutorial_data: Variant = data.get("tutorial", {})
		if tutorial_data is Dictionary:
			_tutorial_system.load_save_data(
				tutorial_data as Dictionary
			)

	if _season_cycle_system:
		var cycle_data: Variant = data.get("season_cycle", {})
		if cycle_data is Dictionary:
			_season_cycle_system.load_save_data(
				cycle_data as Dictionary
			)

	if _secret_thread_manager:
		var secret_data: Variant = data.get("secret_state", {})
		if secret_data is Dictionary:
			_secret_thread_manager.load_save_data(
				secret_data as Dictionary
			)

	if _secret_thread_system:
		var thread_sys_data: Variant = data.get(
			"secret_threads", {}
		)
		if thread_sys_data is Dictionary:
			_secret_thread_system.load_state(
				thread_sys_data as Dictionary
			)

	if _ambient_moments_system:
		var ambient_data: Variant = data.get(
			"ambient_moments", {}
		)
		if ambient_data is Dictionary:
			_ambient_moments_system.load_save_data(
				ambient_data as Dictionary
			)

	if _ending_evaluator:
		var ending_data: Variant = data.get("ending", {})
		if ending_data is Dictionary:
			_ending_evaluator.load_state(
				ending_data as Dictionary
			)

	if _store_upgrade_system:
		var upgrade_data: Variant = data.get(
			"store_upgrades", {}
		)
		if upgrade_data is Dictionary:
			_store_upgrade_system.load_save_data(
				upgrade_data as Dictionary
			)

	if _completion_tracker:
		var completion_data: Variant = data.get(
			"completion", {}
		)
		if completion_data is Dictionary:
			_completion_tracker.load_save_data(
				completion_data as Dictionary
			)

	if _performance_report_system:
		var perf_data: Variant = data.get(
			"performance_reports", {}
		)
		if perf_data is Dictionary:
			_performance_report_system.load_save_data(
				perf_data as Dictionary
			)

	if _unlock_system:
		var unlock_data: Variant = data.get("unlocks", {})
		if unlock_data is Dictionary:
			_unlock_system.load_state(
				unlock_data as Dictionary
			)

	if _onboarding_system:
		var onboarding_data: Variant = data.get(
			"onboarding_progress", {}
		)
		if onboarding_data is Dictionary:
			_onboarding_system.load_save_data(
				onboarding_data as Dictionary
			)

	var difficulty_data: Variant = data.get("difficulty", {})
	if difficulty_data is Dictionary:
		DifficultySystemSingleton.load_save_data(
			difficulty_data as Dictionary
		)


func _migrate_save(data: Dictionary) -> Dictionary:
	var version: int = int(data.get("save_version", 1))
	if version < 2:
		data = _migrate_v1_to_v2(data)
	data["save_version"] = CURRENT_SAVE_VERSION
	return data


func _migrate_v1_to_v2(data: Dictionary) -> Dictionary:
	var old_stores: Variant = data.get("owned_stores", [])
	if old_stores is Array:
		var store_ids: Array = ContentRegistry.get_all_ids("store")
		var slots: Dictionary = {}
		for entry: Variant in old_stores:
			var canonical: StringName = ContentRegistry.resolve(
				str(entry)
			)
			if canonical.is_empty():
				continue
			var idx: int = store_ids.find(canonical)
			if idx >= 0:
				slots[str(idx)] = String(canonical)
			else:
				push_error(
					"SaveManager: v1 migration — cannot map '%s' to slot"
					% entry
				)
		data["owned_slots"] = slots
		data.erase("owned_stores")
	return data


func _on_ending_triggered(
	ending_id: StringName, _final_stats: Dictionary
) -> void:
	mark_run_complete(ending_id)


func _on_day_ended(day: int) -> void:
	_pending_auto_save_day = day


func _on_next_day_confirmed() -> void:
	if _pending_auto_save_day >= 0:
		save_game(AUTO_SAVE_SLOT)
		_pending_auto_save_day = -1


func _get_slot_path(slot: int) -> String:
	if slot == AUTO_SAVE_SLOT:
		return SAVE_DIR + "auto_save.json"
	return SAVE_DIR + "slot_%d.json" % slot


func _validate_slot(slot: int) -> bool:
	if slot < AUTO_SAVE_SLOT or slot > MAX_MANUAL_SLOTS:
		push_warning(
			"SaveManager: invalid slot %d (valid: %d–%d)"
			% [slot, AUTO_SAVE_SLOT, MAX_MANUAL_SLOTS]
		)
		return false
	return true


func _systems_ready() -> bool:
	return (
		_economy_system != null
		and _inventory_system != null
		and _time_system != null
	)


func _get_reputation_system() -> ReputationSystem:
	if _reputation_ref:
		return _reputation_ref
	return ReputationSystemSingleton


## Returns metadata for all slots from the index without loading saves.
func get_all_slot_metadata() -> Dictionary:
	var config := ConfigFile.new()
	if config.load(SLOT_INDEX_PATH) != OK:
		return {}
	var result: Dictionary = {}
	for section: String in config.get_sections():
		if not section.begins_with("slot_"):
			continue
		var slot_num: int = int(section.trim_prefix("slot_"))
		var meta: Dictionary = {}
		for key: String in config.get_section_keys(section):
			meta[key] = config.get_value(section, key)
		result[slot_num] = meta
	return result


func _update_slot_index(slot: int, metadata: Dictionary) -> void:
	var config := ConfigFile.new()
	config.load(SLOT_INDEX_PATH)
	var section: String = "slot_%d" % slot
	for key: String in metadata:
		config.set_value(section, key, metadata[key])
	config.save(SLOT_INDEX_PATH)


func _remove_slot_from_index(slot: int) -> void:
	var config := ConfigFile.new()
	if config.load(SLOT_INDEX_PATH) != OK:
		return
	var section: String = "slot_%d" % slot
	if config.has_section(section):
		config.erase_section(section)
		config.save(SLOT_INDEX_PATH)


func _ensure_save_dir() -> void:
	if DirAccess.dir_exists_absolute(SAVE_DIR):
		return
	var err: Error = DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	if err != OK:
		push_warning(
			"SaveManager: failed to create '%s' — %s"
			% [SAVE_DIR, error_string(err)]
		)
