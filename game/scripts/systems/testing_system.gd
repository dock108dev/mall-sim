## Manages the retro game item testing workflow for consoles and cartridges.
class_name TestingSystem
extends Node

const STORE_TYPE: String = "retro_games"
const DEFAULT_TESTING_DURATION: float = 2.0
const DEFAULT_WORKING_CHANCE: float = 0.8
const DEFAULT_WORKING_MULTIPLIER: float = 1.25
const DEFAULT_NOT_WORKING_MULTIPLIER: float = 0.4
const TESTABLE_CATEGORIES: PackedStringArray = [
	"cartridges", "consoles",
]

var _inventory_system: InventorySystem = null
var _testing_duration: float = DEFAULT_TESTING_DURATION
var _working_chance: float = DEFAULT_WORKING_CHANCE
var _tested_working_multiplier: float = DEFAULT_WORKING_MULTIPLIER
var _tested_not_working_multiplier: float = DEFAULT_NOT_WORKING_MULTIPLIER
var _active_test_instance_id: String = ""
var _test_timer: Timer = null


func initialize(inventory: InventorySystem) -> void:
	_inventory_system = inventory
	_load_config()
	_setup_timer()


## Returns true if the item can be tested.
func can_test(item: ItemInstance) -> bool:
	if not item or not item.definition:
		return false
	if item.definition.store_type != STORE_TYPE:
		return false
	if item.tested:
		return false
	if item.definition.category not in TESTABLE_CATEGORIES:
		return false
	if _active_test_instance_id != "":
		return false
	return true


## Starts testing an item. Returns true if testing began.
func start_test(instance_id: String) -> bool:
	if not _inventory_system:
		push_error("TestingSystem: inventory system not initialized")
		return false
	if _active_test_instance_id != "":
		push_warning("TestingSystem: already testing '%s'" % _active_test_instance_id)
		return false
	var item: ItemInstance = _inventory_system.get_item(instance_id)
	if not can_test(item):
		return false
	_active_test_instance_id = instance_id
	_test_timer.start(_testing_duration)
	EventBus.item_testing_started.emit(instance_id, _testing_duration)
	EventBus.notification_requested.emit(
		"Testing: %s..." % item.definition.item_name
	)
	return true


## Returns true if an item is currently being tested.
func is_testing() -> bool:
	return _active_test_instance_id != ""


## Returns the instance_id of the item currently being tested.
func get_active_test_id() -> String:
	return _active_test_instance_id


## Returns the tested_working_multiplier from config.
func get_working_multiplier() -> float:
	return _tested_working_multiplier


## Returns the tested_not_working_multiplier from config.
func get_not_working_multiplier() -> float:
	return _tested_not_working_multiplier


## Returns the testing duration in seconds.
func get_testing_duration() -> float:
	return _testing_duration


func _setup_timer() -> void:
	_test_timer = Timer.new()
	_test_timer.one_shot = true
	_test_timer.timeout.connect(_on_test_timer_timeout)
	add_child(_test_timer)


func _load_config() -> void:
	var retro_cfg: Dictionary = DataLoader.get_retro_games_config()
	if not retro_cfg.is_empty():
		_apply_retro_config(retro_cfg)
		return
	_load_config_from_store_entry()


func _apply_retro_config(cfg: Dictionary) -> void:
	_testing_duration = float(
		cfg.get("testing_duration_seconds", DEFAULT_TESTING_DURATION)
	)
	_tested_working_multiplier = float(
		cfg.get("tested_working_multiplier", DEFAULT_WORKING_MULTIPLIER)
	)
	_tested_not_working_multiplier = float(
		cfg.get("tested_not_working_multiplier", DEFAULT_NOT_WORKING_MULTIPLIER)
	)


func _load_config_from_store_entry() -> void:
	var entry: Dictionary = ContentRegistry.get_entry(&"retro_games")
	if entry.is_empty():
		return
	var config: Variant = entry.get("testing_config", {})
	if config is not Dictionary:
		return
	var cfg: Dictionary = config as Dictionary
	_testing_duration = float(cfg.get("testing_duration", DEFAULT_TESTING_DURATION))
	_working_chance = float(cfg.get("working_chance", DEFAULT_WORKING_CHANCE))
	_tested_working_multiplier = float(
		cfg.get("tested_working_multiplier", DEFAULT_WORKING_MULTIPLIER)
	)
	_tested_not_working_multiplier = float(
		cfg.get("tested_not_working_multiplier", DEFAULT_NOT_WORKING_MULTIPLIER)
	)


func _on_test_timer_timeout() -> void:
	if _active_test_instance_id.is_empty():
		return
	var instance_id: String = _active_test_instance_id
	_active_test_instance_id = ""

	if not _inventory_system:
		return
	var item: ItemInstance = _inventory_system.get_item(instance_id)
	if not item:
		push_warning("TestingSystem: item '%s' missing at test completion" % instance_id)
		return

	var roll: float = randf()
	var result: String = "tested_working" if roll <= _working_chance else "tested_not_working"
	item.tested = true
	item.test_result = result

	var success: bool = result == "tested_working"
	EventBus.item_test_completed.emit(instance_id, result)
	EventBus.item_tested.emit(instance_id, success)
	EventBus.inventory_changed.emit()

	var status_text: String = "Working" if success else "Not Working"
	EventBus.notification_requested.emit(
		"Test complete: %s — %s" % [item.definition.item_name, status_text]
	)
