## Controller for the PocketCreatures card shop.
class_name PocketCreaturesStoreController
extends StoreController

const STORE_ID: String = "pocket_creatures"

var pack_opening_system: PackOpeningSystem = null
var tournament_system: TournamentSystem = null
var meta_shift_system: MetaShiftSystem = null
var trade_system: TradeSystem = null


func _ready() -> void:
	store_type = STORE_ID
	super._ready()


## Initializes the pack opening system with required references.
func initialize_pack_system(
	data_loader: DataLoader,
	inventory_system: InventorySystem
) -> void:
	pack_opening_system = PackOpeningSystem.new()
	pack_opening_system.initialize(data_loader, inventory_system)


## Sets the tournament system reference for hosting tournaments.
func set_tournament_system(system: TournamentSystem) -> void:
	tournament_system = system


## Sets the meta shift system reference for competitive meta tracking.
func set_meta_shift_system(system: MetaShiftSystem) -> void:
	meta_shift_system = system


## Initializes the trade system for Trader customer card swaps.
func initialize_trade_system(
	data_loader: DataLoader,
	inventory_system: InventorySystem,
	economy_system: EconomySystem,
	reputation_system: ReputationSystem,
) -> void:
	trade_system = TradeSystem.new()
	trade_system.initialize(
		data_loader, inventory_system,
		economy_system, reputation_system,
	)


## Sets the trade panel UI reference on the trade system.
func set_trade_panel(panel: TradePanel) -> void:
	if trade_system:
		trade_system.set_trade_panel(panel)


## Returns true if a meta shift is currently active.
func is_meta_shift_active() -> bool:
	if not meta_shift_system:
		return false
	return meta_shift_system.is_shift_active()


## Returns cards currently rising in the meta.
func get_meta_rising_cards() -> Array[Dictionary]:
	if not meta_shift_system:
		return []
	return meta_shift_system.get_rising_cards()


## Returns cards currently falling in the meta.
func get_meta_falling_cards() -> Array[Dictionary]:
	if not meta_shift_system:
		return []
	return meta_shift_system.get_falling_cards()


## Returns true if the player can host a tournament.
func can_host_tournament() -> bool:
	if not tournament_system:
		return false
	return tournament_system.can_host_tournament()


## Returns the reason a tournament cannot be hosted.
func get_tournament_block_reason() -> String:
	if not tournament_system:
		return "Tournament system not available"
	return tournament_system.get_block_reason()


## Starts a small tournament ($30). Returns true on success.
func host_small_tournament() -> bool:
	if not tournament_system:
		return false
	return tournament_system.start_tournament(
		TournamentSystem.TournamentSize.SMALL
	)


## Starts a large tournament ($50). Returns true on success.
func host_large_tournament() -> bool:
	if not tournament_system:
		return false
	return tournament_system.start_tournament(
		TournamentSystem.TournamentSize.LARGE
	)


## Returns true if the given item is an openable booster pack.
func is_openable_pack(item: ItemInstance) -> bool:
	if not pack_opening_system:
		return false
	return pack_opening_system.is_booster_pack(item)


## Opens a booster pack and returns the generated cards.
func open_pack(
	pack_instance_id: String
) -> Array[ItemInstance]:
	if not pack_opening_system:
		push_warning(
			"PocketCreaturesStoreController: pack system not set"
		)
		return []
	return pack_opening_system.open_pack(pack_instance_id)
