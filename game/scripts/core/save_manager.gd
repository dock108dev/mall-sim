## Manages saving and loading game state to JSON files in user://saves/.
class_name SaveManager
extends Node


const CURRENT_SAVE_VERSION: int = 1
const SAVE_DIR := "user://saves/"
const MAX_MANUAL_SLOTS: int = 3
const AUTO_SAVE_SLOT: int = 0

var _economy_system: EconomySystem
var _ordering_system: OrderingSystem
var _inventory_system: InventorySystem
var _time_system: TimeSystem
var _reputation_system: ReputationSystem
var _store_state_manager: StoreStateManager
var _progression_system: ProgressionSystem
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
var _ambient_moments_system: AmbientMomentsSystem
var _ending_evaluator: EndingEvaluator


func initialize(
	economy: EconomySystem,
	inventory: InventorySystem,
	time: TimeSystem,
	reputation: ReputationSystem,
) -> void:
	_economy_system = economy
	_inventory_system = inventory
	_time_system = time
	_reputation_system = reputation


## Sets the OrderingSystem reference for save/load.
func set_ordering_system(system: OrderingSystem) -> void:
	_ordering_system = system


## Sets the StoreStateManager reference for multi-store save/load.
func set_store_state_manager(manager: StoreStateManager) -> void:
	_store_state_manager = manager
	_ensure_save_dir()
	EventBus.day_ended.connect(_on_day_ended)


## Sets the ProgressionSystem reference for milestone save/load.
func set_progression_system(system: ProgressionSystem) -> void:
	_progression_system = system


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


## Sets the AmbientMomentsSystem reference for save/load.
func set_ambient_moments_system(
	system: AmbientMomentsSystem
) -> void:
	_ambient_moments_system = system


## Sets the EndingEvaluator reference for save/load.
func set_ending_evaluator(
	evaluator: EndingEvaluator
) -> void:
	_ending_evaluator = evaluator


func save_game(slot: int) -> bool:
	if not _validate_slot(slot):
		return false
	if not _systems_ready():
		push_warning("SaveManager: systems not initialized")
		return false

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
		push_warning("SaveManager: no save file at '%s'" % path)
		return false

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning(
			"SaveManager: failed to open '%s' — %s"
			% [path, error_string(FileAccess.get_open_error())]
		)
		return false

	var json_string: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result: Error = json.parse(json_string)
	if parse_result != OK:
		push_warning(
			"SaveManager: JSON parse error in '%s' at line %d — %s"
			% [path, json.get_error_line(), json.get_error_message()]
		)
		return false

	var data: Variant = json.data
	if data is not Dictionary:
		push_warning("SaveManager: save file root is not a Dictionary")
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
	return save_dict.get("metadata", {}) as Dictionary


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
	return true


func _collect_save_data() -> Dictionary:
	var metadata: Dictionary = {
		"timestamp": Time.get_datetime_string_from_system(true),
		"day_number": _time_system.current_day,
		"store_type": GameManager.current_store_id,
		"play_time": _time_system.get_play_time_seconds(),
	}

	var data: Dictionary = {
		"save_version": CURRENT_SAVE_VERSION,
		"metadata": metadata,
		"time": _time_system.get_save_data(),
		"economy": _economy_system.get_save_data(),
		"inventory": _inventory_system.get_save_data(),
		"reputation": _reputation_system.get_save_data(),
		"owned_stores": GameManager.owned_stores.duplicate(),
	}

	if _ordering_system:
		data["ordering"] = _ordering_system.get_save_data()

	if _store_state_manager:
		data["store_states"] = _store_state_manager.get_save_data()

	if _progression_system:
		data["progression"] = _progression_system.get_save_data()

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
		_reputation_system.load_save_data(reputation_data as Dictionary)

	if _ordering_system:
		var ordering_data: Variant = data.get("ordering", {})
		if ordering_data is Dictionary:
			_ordering_system.load_save_data(
				ordering_data as Dictionary
			)

	var saved_stores: Variant = data.get("owned_stores", [])
	if saved_stores is Array:
		GameManager.owned_stores = []
		for entry: Variant in saved_stores:
			GameManager.owned_stores.append(str(entry))
	if GameManager.owned_stores.is_empty():
		GameManager.owned_stores = [GameManager.DEFAULT_STARTING_STORE]

	if _store_state_manager:
		var store_data: Variant = data.get("store_states", {})
		if store_data is Dictionary:
			_store_state_manager.load_save_data(
				store_data as Dictionary
			)

	if _progression_system:
		var prog_data: Variant = data.get("progression", {})
		if prog_data is Dictionary:
			_progression_system.load_save_data(
				prog_data as Dictionary
			)

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
			_ending_evaluator.load_save_data(
				ending_data as Dictionary
			)


func _migrate_save(data: Dictionary) -> Dictionary:
	var version: int = int(data.get("save_version", 1))
	if version < CURRENT_SAVE_VERSION:
		data["save_version"] = CURRENT_SAVE_VERSION
	return data


func _on_day_ended(_day: int) -> void:
	save_game(AUTO_SAVE_SLOT)


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
		and _reputation_system != null
	)


func _ensure_save_dir() -> void:
	if DirAccess.dir_exists_absolute(SAVE_DIR):
		return
	var err: Error = DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	if err != OK:
		push_warning(
			"SaveManager: failed to create '%s' — %s"
			% [SAVE_DIR, error_string(err)]
		)
