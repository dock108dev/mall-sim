## Manages saving and loading game state to JSON files in user://.
class_name SaveManager
extends Node


const CURRENT_SAVE_VERSION: int = 1
const SAVE_DIR := "user://"
const SLOT_INDEX_PATH := "user://save_index.cfg"
const MAX_MANUAL_SLOTS: int = 3
const AUTO_SAVE_SLOT: int = 0
const MAX_SAVE_FILE_BYTES: int = 10485760

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
	EventBus.day_acknowledged.connect(_on_day_acknowledged)
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
	var read_result: Dictionary = _read_save_dictionary(
		path,
		"failed to open auto-save '%s' while recording ending — %s",
		"auto-save '%s' is too large to update safely",
		"failed to parse auto-save '%s' while recording ending — %s",
		"auto-save '%s' did not contain a dictionary while recording ending"
	)
	if not bool(read_result.get("ok", false)):
		return
	var save_data: Dictionary = read_result.get("data", {}) as Dictionary
	var metadata: Dictionary = save_data.get("metadata", {}) as Dictionary
	var save_metadata: Dictionary = (
		save_data.get("save_metadata", {}) as Dictionary
	)
	metadata["run_complete"] = true
	metadata["ending_id"] = String(ending_id)
	save_metadata["run_complete"] = true
	save_metadata["ending_id"] = String(ending_id)
	save_data["metadata"] = metadata
	save_data["save_metadata"] = save_metadata
	var write_error: Error = _write_save_file_atomic(
		path, JSON.stringify(save_data, "\t")
	)
	if write_error != OK:
		push_warning(
			"SaveManager: failed to update auto-save '%s' with ending metadata — %s"
			% [path, error_string(write_error)]
		)
		return
	_update_slot_index(AUTO_SAVE_SLOT, _build_slot_index_metadata(save_data))


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
	var write_error: Error = _write_save_file_atomic(path, json_string)
	if write_error != OK:
		push_warning(
			"SaveManager: failed to write '%s' — %s"
			% [path, error_string(write_error)]
		)
		return false

	_update_slot_index(slot, _build_slot_index_metadata(save_data))
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
		return _fail_load(slot, "No save file at '%s'" % path)
	var read_result: Dictionary = _read_save_dictionary(
		path,
		"Failed to open '%s' — %s",
		"Save file '%s' exceeds maximum supported size",
		"JSON parse error in '%s' at %s",
		"Save file '%s' root is not a Dictionary",
		true
	)
	if not bool(read_result.get("ok", false)):
		return _fail_load(slot, str(read_result.get("reason", "")))
	var save_data: Dictionary = read_result.get("data", {}) as Dictionary
	var save_version: int = int(save_data.get("save_version", 0))
	if save_version > CURRENT_SAVE_VERSION:
		return _fail_load(
			slot,
			"Save version %d is newer than supported version %d"
			% [save_version, CURRENT_SAVE_VERSION]
		)
	if save_version < CURRENT_SAVE_VERSION:
		push_warning(
			"SaveManager: migrating save version %d to %d"
			% [save_version, CURRENT_SAVE_VERSION]
		)
	save_data = _migrate_save(save_data)
	_distribute_save_data(save_data)
	return true


func slot_exists(slot: int) -> bool:
	if not _validate_slot(slot):
		return false
	return FileAccess.file_exists(_get_slot_path(slot))


## Returns preview metadata from a save slot without loading runtime state.
func get_slot_metadata(slot: int) -> Dictionary:
	if not _validate_slot(slot):
		return {}
	if not FileAccess.file_exists(_get_slot_path(slot)):
		return {}
	return _read_slot_metadata_from_save(slot)


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
	var active_store_id: StringName = _get_active_store_id_for_save()
	var preview_store_id: StringName = active_store_id
	if preview_store_id.is_empty():
		preview_store_id = _get_primary_owned_store_id()
	var preview_store_name: String = _get_preview_store_name(
		preview_store_id
	)
	var difficulty_data: Dictionary = DifficultySystemSingleton.get_save_data()
	var owned_slots_data: Dictionary = {}
	var owned_store_list: Array[String] = []
	if _store_state_manager:
		var slots: Dictionary[int, StringName] = _store_state_manager.owned_slots
		for idx: int in slots:
			var raw_store_id: String = String(slots[idx])
			var canonical: StringName = ContentRegistry.resolve(raw_store_id)
			if canonical.is_empty():
				canonical = StringName(raw_store_id)
			owned_slots_data[str(idx)] = String(canonical)
			owned_store_list.append(String(canonical))
	if owned_store_list.is_empty() and not GameManager.owned_stores.is_empty():
		for store_id: StringName in GameManager.owned_stores:
			owned_store_list.append(String(store_id))
			owned_slots_data[str(owned_store_list.size() - 1)] = String(store_id)

	var save_metadata: Dictionary = {
		"day": _time_system.current_day,
		"day_number": _time_system.current_day,
		"cash": _economy_system.get_cash(),
		"owned_stores": owned_store_list,
		"store_count": owned_store_list.size(),
		"saved_at": Time.get_datetime_string_from_system(true),
		"last_saved_at": Time.get_datetime_string_from_system(true),
		"timestamp": Time.get_datetime_string_from_system(true),
		"store_type": String(preview_store_id),
		"store_name": preview_store_name,
		"active_store_id": String(active_store_id),
		"play_time": _time_system.get_play_time_seconds(),
		"used_difficulty_downgrade": bool(
			difficulty_data.get("used_difficulty_downgrade", false)
		),
	}

	var data: Dictionary = {
		"save_version": CURRENT_SAVE_VERSION,
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

	if _progression_system:
		var prog_data: Variant = data.get("progression", {})
		if prog_data is Dictionary:
			_progression_system.load_save_data(
				prog_data as Dictionary
			)

	if _store_state_manager:
		var store_data: Variant = data.get("store_states", {})
		if store_data is Dictionary:
			_store_state_manager.load_save_data(
				store_data as Dictionary
			)
		_restore_owned_slots_with_fallback(_extract_owned_slots(data))
	else:
		_apply_loaded_owned_stores(_extract_owned_slots(data))
	_apply_loaded_active_store(data)

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


func _apply_loaded_active_store(data: Dictionary) -> void:
	var raw_active_store: String = _get_saved_active_store_id(data)
	var canonical: StringName = &""
	var has_explicit_active_store: bool = _has_saved_active_store_id(data)
	if not raw_active_store.is_empty():
		canonical = ContentRegistry.resolve(raw_active_store)
		if canonical.is_empty():
			push_warning(
				"SaveManager: unresolved active_store_id '%s' in save data"
				% raw_active_store
			)
	if canonical.is_empty() and not has_explicit_active_store:
		if not GameManager.owned_stores.is_empty():
			canonical = GameManager.owned_stores[0]
		else:
			canonical = GameManager.DEFAULT_STARTING_STORE
	if _store_state_manager:
		_store_state_manager.set_active_store(canonical)
	else:
		GameManager.current_store_id = canonical


func _get_saved_active_store_id(data: Dictionary) -> String:
	var save_metadata: Variant = data.get("save_metadata", {})
	if save_metadata is Dictionary:
		if (save_metadata as Dictionary).has("active_store_id"):
			return str(
				(save_metadata as Dictionary).get("active_store_id", "")
			)
		var save_store_type: String = str(
			(save_metadata as Dictionary).get("store_type", "")
		)
		if not save_store_type.is_empty():
			return save_store_type
	var metadata: Variant = data.get("metadata", {})
	if metadata is Dictionary:
		if (metadata as Dictionary).has("active_store_id"):
			return str((metadata as Dictionary).get("active_store_id", ""))
		return str((metadata as Dictionary).get("store_type", ""))
	return ""


func _has_saved_active_store_id(data: Dictionary) -> bool:
	var save_metadata: Variant = data.get("save_metadata", {})
	if save_metadata is Dictionary and (
		save_metadata as Dictionary
	).has("active_store_id"):
		return true
	var metadata: Variant = data.get("metadata", {})
	return metadata is Dictionary and (
		metadata as Dictionary
	).has("active_store_id")


func _migrate_save(data: Dictionary) -> Dictionary:
	var version: int = int(data.get("save_version", 0))
	while version < CURRENT_SAVE_VERSION:
		match version:
			0:
				data = _migrate_v0_to_v1(data)
			_:
				break
		version += 1
	data["owned_slots"] = _extract_owned_slots(data)
	if data.has("owned_stores"):
		data.erase("owned_stores")
	data["save_version"] = CURRENT_SAVE_VERSION
	return data


func _migrate_v0_to_v1(data: Dictionary) -> Dictionary:
	data["owned_slots"] = _extract_owned_slots(data)
	if data.has("owned_stores"):
		data.erase("owned_stores")
	var save_metadata: Dictionary = {}
	var existing_save_metadata: Variant = data.get("save_metadata", {})
	if existing_save_metadata is Dictionary:
		save_metadata = (existing_save_metadata as Dictionary).duplicate(true)
	var legacy_metadata: Variant = data.get("metadata", {})
	var legacy_metadata_dict: Dictionary = {}
	if legacy_metadata is Dictionary:
		legacy_metadata_dict = (legacy_metadata as Dictionary).duplicate(true)
	if not save_metadata.has("day"):
		save_metadata["day"] = int(legacy_metadata_dict.get("day_number", 1))
	if not save_metadata.has("day_number"):
		save_metadata["day_number"] = int(save_metadata.get("day", 1))
	if not save_metadata.has("cash"):
		var economy_data: Variant = data.get("economy", {})
		if economy_data is Dictionary:
			save_metadata["cash"] = float(
				(economy_data as Dictionary).get(
					"player_cash",
					(economy_data as Dictionary).get("current_cash", 0.0)
				)
			)
	if not save_metadata.has("owned_stores"):
		var owned_store_ids: Array[String] = []
		var migrated_slots: Dictionary = data.get("owned_slots", {}) as Dictionary
		for slot_key: Variant in migrated_slots:
			owned_store_ids.append(str(migrated_slots[slot_key]))
		save_metadata["owned_stores"] = owned_store_ids
	if not save_metadata.has("store_count"):
		var stores: Variant = save_metadata.get("owned_stores", [])
		save_metadata["store_count"] = (
			(stores as Array).size() if stores is Array else 0
		)
	if not save_metadata.has("saved_at"):
		save_metadata["saved_at"] = str(
			legacy_metadata_dict.get(
				"timestamp", Time.get_datetime_string_from_system(true)
			)
		)
	if not save_metadata.has("last_saved_at"):
		save_metadata["last_saved_at"] = str(
			save_metadata.get("saved_at", Time.get_datetime_string_from_system(true))
		)
	if not save_metadata.has("timestamp"):
		save_metadata["timestamp"] = str(
			legacy_metadata_dict.get("timestamp", save_metadata.get("saved_at", ""))
		)
	if not save_metadata.has("store_type"):
		save_metadata["store_type"] = str(
			legacy_metadata_dict.get("store_type", "")
		)
	if not save_metadata.has("active_store_id"):
		save_metadata["active_store_id"] = str(
			save_metadata.get("store_type", "")
		)
	if not save_metadata.has("play_time"):
		save_metadata["play_time"] = float(
			legacy_metadata_dict.get("play_time", 0.0)
		)
	if not save_metadata.has("used_difficulty_downgrade"):
		save_metadata["used_difficulty_downgrade"] = false
	data["save_metadata"] = save_metadata
	return data


func _extract_owned_slots(data: Dictionary) -> Dictionary:
	var raw_slots: Variant = data.get("owned_slots", null)
	if raw_slots is Dictionary:
		return (raw_slots as Dictionary).duplicate(true)
	if raw_slots is Array:
		push_warning(
			"SaveManager: migrating legacy owned_slots array during load"
		)
		return _migrate_legacy_owned_store_array(
			raw_slots as Array, "owned_slots"
		)

	var legacy_owned_stores: Variant = data.get("owned_stores", null)
	if legacy_owned_stores is Array:
		push_warning(
			"SaveManager: migrating legacy owned_stores array during load"
		)
		return _migrate_legacy_owned_store_array(
			legacy_owned_stores as Array, "owned_stores"
		)

	if raw_slots != null:
		push_warning(
			"SaveManager: expected Dictionary for owned_slots, got %s"
			% type_string(typeof(raw_slots))
		)
	return {}


func _migrate_legacy_owned_store_array(
	store_list: Array,
	source_field: String
) -> Dictionary:
	var store_ids: Array[StringName] = ContentRegistry.get_all_ids("store")
	var migrated_slots: Dictionary = {}
	for entry: Variant in store_list:
		var raw_store_id: String = str(entry)
		var canonical: StringName = ContentRegistry.resolve(raw_store_id)
		if canonical.is_empty():
			canonical = StringName(raw_store_id)
		var slot_index: int = store_ids.find(canonical)
		if slot_index < 0:
			slot_index = migrated_slots.size()
		migrated_slots[str(slot_index)] = String(canonical)
	return migrated_slots


func _apply_loaded_owned_stores(saved_slots: Dictionary) -> void:
	GameManager.owned_stores = []
	for key: Variant in saved_slots:
		var raw_store_id: String = str(saved_slots[key])
		var canonical: StringName = ContentRegistry.resolve(raw_store_id)
		if canonical.is_empty():
			canonical = StringName(raw_store_id)
		if canonical not in GameManager.owned_stores:
			GameManager.owned_stores.append(canonical)
	if GameManager.owned_stores.is_empty():
		GameManager.owned_stores = [
			GameManager.DEFAULT_STARTING_STORE
		]


func _get_active_store_id_for_save() -> StringName:
	if _store_state_manager:
		var active_store_id: StringName = _store_state_manager.active_store_id
		if not active_store_id.is_empty():
			return active_store_id
	var raw_store_id: String = String(GameManager.current_store_id)
	if raw_store_id.is_empty():
		return &""
	var canonical: StringName = ContentRegistry.resolve(raw_store_id)
	if canonical.is_empty():
		return StringName(raw_store_id)
	return canonical


func _get_preview_store_name(store_id: StringName) -> String:
	if store_id.is_empty():
		return ""
	if _store_state_manager:
		return _store_state_manager.get_store_name(store_id)
	if ContentRegistry.exists(String(store_id)):
		return ContentRegistry.get_display_name(store_id)
	return String(store_id)


func _get_primary_owned_store_id() -> StringName:
	if _store_state_manager and not _store_state_manager.owned_slots.is_empty():
		var slot_indices: Array[int] = []
		for slot_index: int in _store_state_manager.owned_slots:
			slot_indices.append(slot_index)
		slot_indices.sort()
		return _store_state_manager.owned_slots[slot_indices[0]]
	if not GameManager.owned_stores.is_empty():
		return GameManager.owned_stores[0]
	return GameManager.DEFAULT_STARTING_STORE


func _on_ending_triggered(
	ending_id: StringName, _final_stats: Dictionary
) -> void:
	mark_run_complete(ending_id)


func _on_day_ended(day: int) -> void:
	_pending_auto_save_day = day


func _on_day_acknowledged() -> void:
	if _pending_auto_save_day >= 0:
		save_game(AUTO_SAVE_SLOT)
		_pending_auto_save_day = -1


func _get_slot_path(slot: int) -> String:
	return SAVE_DIR + "save_slot_%d.json" % slot


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


func _fail_load(slot: int, reason: String) -> bool:
	push_warning("SaveManager: %s" % reason)
	EventBus.save_load_failed.emit(slot, reason)
	return false


func _get_reputation_system() -> ReputationSystem:
	if _reputation_ref:
		return _reputation_ref
	return ReputationSystemSingleton


## Returns metadata for all slots from the index without loading saves.
func get_all_slot_metadata() -> Dictionary:
	var config := ConfigFile.new()
	var load_err: Error = config.load(SLOT_INDEX_PATH)
	if load_err != OK:
		if FileAccess.file_exists(SLOT_INDEX_PATH):
			push_warning(
				"SaveManager: failed to load slot index '%s' — %s"
				% [SLOT_INDEX_PATH, error_string(load_err)]
			)
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
	var load_err: Error = config.load(SLOT_INDEX_PATH)
	if load_err != OK and FileAccess.file_exists(SLOT_INDEX_PATH):
		push_warning(
			"SaveManager: failed to load slot index '%s' for update — keeping index unchanged"
			% SLOT_INDEX_PATH
		)
		return
	var section: String = "slot_%d" % slot
	if config.has_section(section):
		config.erase_section(section)
	for key: String in metadata:
		config.set_value(section, key, metadata[key])
	var save_err: Error = config.save(SLOT_INDEX_PATH)
	if save_err != OK:
		push_warning(
			"SaveManager: failed to write slot index '%s' — %s"
			% [SLOT_INDEX_PATH, error_string(save_err)]
		)


func _remove_slot_from_index(slot: int) -> void:
	var config := ConfigFile.new()
	var load_err: Error = config.load(SLOT_INDEX_PATH)
	if load_err != OK:
		if FileAccess.file_exists(SLOT_INDEX_PATH):
			push_warning(
				"SaveManager: failed to load slot index '%s' for removal — keeping index unchanged"
				% SLOT_INDEX_PATH
			)
		return
	var section: String = "slot_%d" % slot
	if config.has_section(section):
		config.erase_section(section)
		var save_err: Error = config.save(SLOT_INDEX_PATH)
		if save_err != OK:
			push_warning(
				"SaveManager: failed to write slot index '%s' — %s"
				% [SLOT_INDEX_PATH, error_string(save_err)]
			)


func _ensure_save_dir() -> void:
	if SAVE_DIR == "user://":
		return
	if DirAccess.dir_exists_absolute(SAVE_DIR):
		return
	var err: Error = DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	if err != OK:
		push_warning(
			"SaveManager: failed to create '%s' — %s"
			% [SAVE_DIR, error_string(err)]
		)


func _write_save_file_atomic(path: String, contents: String) -> Error:
	var temp_path: String = "%s.tmp" % path
	if FileAccess.file_exists(temp_path):
		var cleanup_error: Error = DirAccess.remove_absolute(temp_path)
		if cleanup_error != OK:
			return cleanup_error

	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if not file:
		return FileAccess.get_open_error()
	file.store_string(contents)
	file.flush()
	file.close()

	var rename_error: Error = DirAccess.rename_absolute(temp_path, path)
	if rename_error != OK:
		DirAccess.remove_absolute(temp_path)
	return rename_error


func _read_save_dictionary(
	path: String,
	open_reason_template: String,
	too_large_reason_template: String,
	parse_reason_template: String,
	root_reason_template: String,
	include_parse_line: bool = false
) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		return _save_read_failure(
			open_reason_template
			% [path, error_string(FileAccess.get_open_error())]
		)
	if file.get_length() > MAX_SAVE_FILE_BYTES:
		file.close()
		return _save_read_failure(too_large_reason_template % path)
	var json_text: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_text)
	if parse_result != OK:
		var parse_context: String = json.get_error_message()
		if include_parse_line:
			parse_context = "line %d — %s" % [
				json.get_error_line(), parse_context
			]
		return _save_read_failure(
			parse_reason_template % [path, parse_context]
		)
	var data: Variant = json.data
	if data is not Dictionary:
		return _save_read_failure(root_reason_template % path)
	return {
		"ok": true,
		"data": data as Dictionary,
	}


func _save_read_failure(reason: String) -> Dictionary:
	push_warning("SaveManager: %s" % reason)
	return {
		"ok": false,
		"reason": reason,
	}


func _build_slot_index_metadata(save_data: Dictionary) -> Dictionary:
	var metadata: Dictionary = {}
	var save_metadata: Variant = save_data.get("save_metadata", {})
	if save_metadata is Dictionary:
		metadata = (save_metadata as Dictionary).duplicate(true)
	var legacy_metadata: Variant = save_data.get("metadata", {})
	if legacy_metadata is Dictionary:
		for key: String in legacy_metadata as Dictionary:
			if not metadata.has(key):
				metadata[key] = (legacy_metadata as Dictionary)[key]
	if not metadata.has("store_count"):
		var stores: Variant = metadata.get("owned_stores", [])
		metadata["store_count"] = (
			(stores as Array).size() if stores is Array else 0
		)
	if not metadata.has("last_saved_at"):
		metadata["last_saved_at"] = str(
			metadata.get("saved_at", metadata.get("timestamp", ""))
		)
	if not metadata.has("used_difficulty_downgrade"):
		var difficulty_data: Variant = save_data.get("difficulty", {})
		if difficulty_data is Dictionary:
			metadata["used_difficulty_downgrade"] = bool(
				(difficulty_data as Dictionary).get(
					"used_difficulty_downgrade", false
				)
			)
	if not metadata.has("store_name"):
		var raw_store_id: String = str(
			metadata.get("store_type", "")
		)
		if not raw_store_id.is_empty():
			if ContentRegistry.exists(raw_store_id):
				var canonical: StringName = ContentRegistry.resolve(
					raw_store_id
				)
				metadata["store_name"] = ContentRegistry.get_display_name(
					canonical
				)
			else:
				metadata["store_name"] = raw_store_id
	return metadata


func _read_slot_metadata_from_save(slot: int) -> Dictionary:
	var path: String = _get_slot_path(slot)
	var read_result: Dictionary = _read_save_dictionary(
		path,
		"failed to open save slot '%s' for metadata — %s",
		"save slot '%s' is too large for metadata preview",
		"failed to parse save slot '%s' for metadata — %s",
		"save slot '%s' did not contain a dictionary for metadata"
	)
	if not bool(read_result.get("ok", false)):
		return {}
	var save_data: Dictionary = read_result.get("data", {}) as Dictionary
	var save_metadata: Variant = save_data.get("save_metadata", {})
	if save_metadata is Dictionary:
		return _build_slot_index_metadata(save_data)
	var legacy_metadata: Variant = save_data.get("metadata", {})
	if legacy_metadata is Dictionary:
		return _build_slot_index_metadata(save_data)
	return {}


func _restore_owned_slots_with_fallback(saved_slots: Dictionary) -> void:
	_store_state_manager.restore_owned_slots(saved_slots)
	if _store_state_manager.owned_slots.size() == saved_slots.size():
		return
	var fallback_slots: Dictionary[int, StringName] = {}
	for key: Variant in saved_slots:
		fallback_slots[int(key)] = StringName(str(saved_slots[key]))
	_store_state_manager.owned_slots = fallback_slots
	var active_store_id: StringName = _store_state_manager.active_store_id
	GameManager.owned_stores = []
	var slot_indices: Array[int] = []
	for slot_index: int in fallback_slots:
		slot_indices.append(slot_index)
	slot_indices.sort()
	for slot_index: int in slot_indices:
		var store_id: StringName = fallback_slots[slot_index]
		if store_id not in GameManager.owned_stores:
			GameManager.owned_stores.append(store_id)
	if GameManager.owned_stores.is_empty():
		GameManager.owned_stores = [GameManager.DEFAULT_STARTING_STORE]
	_store_state_manager.active_store_id = active_store_id
	EventBus.owned_slots_restored.emit(_store_state_manager.owned_slots)
