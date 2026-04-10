## Controller for the sports memorabilia store. Manages season cycle and authentication.
class_name SportsMemorabiliaController
extends StoreController

const STORE_ID: String = "sports_memorabilia"

var _season_cycle: SeasonCycleSystem = SeasonCycleSystem.new()
var _authentication: AuthenticationSystem = AuthenticationSystem.new()


func _ready() -> void:
	store_type = STORE_ID
	super._ready()
	EventBus.day_started.connect(_on_day_started)


## Initializes both the season cycle and authentication systems.
func initialize(starting_day: int) -> void:
	_season_cycle.initialize(starting_day)


## Initializes the authentication system with required references.
func initialize_authentication(
	inventory: InventorySystem, economy: EconomySystem
) -> void:
	_authentication.initialize(inventory, economy)


## Returns the SeasonCycleSystem for external wiring (EconomySystem, etc.).
func get_season_cycle() -> SeasonCycleSystem:
	return _season_cycle


## Returns the AuthenticationSystem for UI dialog wiring.
func get_authentication_system() -> AuthenticationSystem:
	return _authentication


## Serializes sports-memorabilia-specific state for saving.
func get_save_data() -> Dictionary:
	return {
		"season_cycle": _season_cycle.get_save_data(),
		"authentication": _authentication.get_save_data(),
	}


## Restores sports-memorabilia-specific state from saved data.
func load_save_data(data: Dictionary) -> void:
	var cycle_data: Variant = data.get("season_cycle", {})
	if cycle_data is Dictionary:
		_season_cycle.load_save_data(cycle_data as Dictionary)
	var auth_data: Variant = data.get("authentication", {})
	if auth_data is Dictionary:
		_authentication.load_save_data(auth_data as Dictionary)


func _on_day_started(day: int) -> void:
	_season_cycle.process_day(day)
