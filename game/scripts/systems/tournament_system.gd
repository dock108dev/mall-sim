## Manages PocketCreatures tournament hosting, cooldowns, and participant spawning.
class_name TournamentSystem
extends Node


enum TournamentSize { SMALL, LARGE }
enum TournamentState { IDLE, SCHEDULED, ACTIVE, RESOLVED }

const SMALL_COST: float = 30.0
const LARGE_COST: float = 50.0
const DEFAULT_PRIZE_AMOUNT: float = 100.0
const COOLDOWN_DAYS: int = 3
const MIN_PARTICIPANTS: int = 6
const MAX_PARTICIPANTS: int = 12
const REP_REWARD_MIN: float = 3.0
const REP_REWARD_MAX: float = 5.0
const PURCHASE_PROB_BOOST: float = 0.25
const STORE_TYPE: String = "pocket_creatures"

## Reputation tier thresholds that scale participant count.
const TIER_PARTICIPANT_BONUS: Dictionary = {
	ReputationSystemSingleton.ReputationTier.NOTORIOUS: 0,
	ReputationSystemSingleton.ReputationTier.UNREMARKABLE: 2,
	ReputationSystemSingleton.ReputationTier.REPUTABLE: 4,
	ReputationSystemSingleton.ReputationTier.LEGENDARY: 6,
}

var _economy_system: EconomySystem = null
var _reputation_system: ReputationSystem = null
var _customer_system: CustomerSystem = null
var _fixture_placement_system: FixturePlacementSystem = null
var _data_loader: DataLoader = null

var _is_active: bool = false
var _state: TournamentState = TournamentState.IDLE
var _scheduled_days: Array[int] = []
var _active_scheduled_day: int = -1
var _cooldown_remaining: int = 0
var _participant_count: int = 0
var _tournament_revenue: float = 0.0
var _current_size: TournamentSize = TournamentSize.SMALL


func initialize(
	economy: EconomySystem,
	reputation: ReputationSystem,
	customer: CustomerSystem,
	fixture_placement: FixturePlacementSystem,
	data_loader: DataLoader
) -> void:
	_economy_system = economy
	_reputation_system = reputation
	_customer_system = customer
	_fixture_placement_system = fixture_placement
	_data_loader = data_loader
	_apply_state({})
	EventBus.day_started.connect(_on_day_started)
	EventBus.day_phase_changed.connect(_on_day_phase_changed)
	EventBus.item_sold.connect(_on_item_sold)


## Returns true if a tournament table fixture is placed in the store.
func has_tournament_table() -> bool:
	if not _fixture_placement_system:
		return false
	var all_fixtures: Dictionary = (
		_fixture_placement_system.get_all_occupied_cells()
	)
	var checked_ids: Dictionary = {}
	for cell: Vector2i in all_fixtures:
		var fixture_id: String = all_fixtures[cell] as String
		if checked_ids.has(fixture_id):
			continue
		checked_ids[fixture_id] = true
		var data: Dictionary = (
			_fixture_placement_system.get_fixture_data(fixture_id)
		)
		if data.get("fixture_type", "") == "tournament_table":
			return true
	return false


## Returns true if the player can host a tournament right now.
func can_host_tournament() -> bool:
	if _is_active:
		return false
	if _cooldown_remaining > 0:
		return false
	if not has_tournament_table():
		return false
	if GameManager.get_active_store_id() != STORE_TYPE:
		return false
	return true


## Returns why a tournament cannot be hosted, or empty if it can.
func get_block_reason() -> String:
	if _is_active:
		return "Tournament already in progress"
	if _cooldown_remaining > 0:
		return "Cooldown: %d day(s) remaining" % _cooldown_remaining
	if not has_tournament_table():
		return "Place a Tournament Table fixture first"
	if GameManager.get_active_store_id() != STORE_TYPE:
		return "Must be in the PocketCreatures store"
	var cost: float = _get_cost(TournamentSize.SMALL)
	if _economy_system and _economy_system.get_cash() < cost:
		return "Insufficient funds (need $%.0f)" % cost
	return ""


## Returns the cost for a given tournament size.
func _get_cost(size: TournamentSize) -> float:
	if size == TournamentSize.LARGE:
		return LARGE_COST
	return SMALL_COST


## Starts a tournament of the given size. Returns true on success.
func start_tournament(size: TournamentSize) -> bool:
	if not can_host_tournament():
		return false

	var cost: float = _get_cost(size)
	if not _economy_system:
		return false
	if _economy_system.get_cash() < cost:
		EventBus.notification_requested.emit(
			"Insufficient funds to host tournament"
		)
		return false

	if not _economy_system.deduct_cash(cost, "Tournament hosting"):
		return false

	_current_size = size
	_is_active = true
	_state = TournamentState.ACTIVE
	_tournament_revenue = 0.0
	_participant_count = _calculate_participant_count()

	EventBus.tournament_started.emit(
		_participant_count, cost
	)
	EventBus.notification_requested.emit(
		"Tournament started! %d participants expected." % _participant_count
	)

	_spawn_tournament_customers()
	return true


## Schedules a tournament to begin when day_started emits the matching day.
func schedule_tournament(day: int) -> bool:
	if day < 0:
		push_warning(
			"TournamentSystem: cannot schedule tournament for day %d" % day
		)
		return false
	if _scheduled_days.has(day):
		return false

	_scheduled_days.append(day)
	_scheduled_days.sort()
	if not _is_active:
		_state = TournamentState.SCHEDULED
	return true


## Returns true when a tournament is scheduled for the given day.
func is_tournament_scheduled(day: int) -> bool:
	return _scheduled_days.has(day)


## Returns a copy of scheduled tournament days.
func get_scheduled_tournament_days() -> Array[int]:
	return _scheduled_days.duplicate()


## Returns the current tournament lifecycle state.
func get_state() -> TournamentState:
	return _state


## Resolves the active tournament, emits the winner contract, and awards prize.
func resolve_tournament(
	winner_id: StringName = &"participant_1",
	prize_amount: float = DEFAULT_PRIZE_AMOUNT
) -> bool:
	if not _is_active:
		return false
	if winner_id.is_empty() or prize_amount <= 0.0:
		return false

	if _economy_system:
		_economy_system.add_cash(prize_amount, "Tournament prize")
	EventBus.tournament_resolved.emit(winner_id, prize_amount)
	_complete_tournament()
	return true


## Returns the number of cooldown days remaining.
func get_cooldown_remaining() -> int:
	return _cooldown_remaining


## Returns true if a tournament is currently active.
func is_active() -> bool:
	return _is_active


## Returns the current participant count for an active tournament.
func get_participant_count() -> int:
	return _participant_count


## Serializes tournament state for saving.
func get_save_data() -> Dictionary:
	return {
		"is_active": _is_active,
		"cooldown_remaining": _cooldown_remaining,
		"participant_count": _participant_count,
		"tournament_revenue": _tournament_revenue,
		"current_size": _current_size,
		"state": _state,
		"scheduled_days": _scheduled_days.duplicate(),
		"active_scheduled_day": _active_scheduled_day,
	}


## Restores tournament state from saved data.
func load_save_data(data: Dictionary) -> void:
	_apply_state(data)


func _apply_state(data: Dictionary) -> void:
	_is_active = bool(data.get("is_active", false))
	_state = int(data.get(
		"state",
		TournamentState.ACTIVE if _is_active else TournamentState.IDLE
	)) as TournamentState
	_scheduled_days = _restore_scheduled_days(data.get("scheduled_days", []))
	if (
		not _is_active
		and _state == TournamentState.IDLE
		and not _scheduled_days.is_empty()
	):
		_state = TournamentState.SCHEDULED
	_active_scheduled_day = int(data.get("active_scheduled_day", -1))
	_cooldown_remaining = int(data.get("cooldown_remaining", 0))
	_participant_count = int(data.get("participant_count", 0))
	_tournament_revenue = float(
		data.get("tournament_revenue", 0.0)
	)
	_current_size = int(
		data.get("current_size", TournamentSize.SMALL)
	) as TournamentSize


func _restore_scheduled_days(raw_days: Variant) -> Array[int]:
	var restored: Array[int] = []
	if raw_days is Array:
		for raw_day: Variant in raw_days:
			var day: int = int(raw_day)
			if day >= 0 and not restored.has(day):
				restored.append(day)
	restored.sort()
	return restored


func _calculate_participant_count() -> int:
	var base: int = MIN_PARTICIPANTS
	if _reputation_system:
		var tier: ReputationSystemSingleton.ReputationTier = _reputation_system.get_tier()
		var bonus: int = TIER_PARTICIPANT_BONUS.get(tier, 0) as int
		base += bonus
	return mini(base, MAX_PARTICIPANTS)


func _spawn_tournament_customers() -> void:
	if not _customer_system or not _data_loader:
		return
	var profiles: Array[CustomerTypeDefinition] = (
		_data_loader.get_customer_types_for_store(STORE_TYPE)
	)
	if profiles.is_empty():
		return

	var competitive_profiles: Array[CustomerTypeDefinition] = []
	for p: CustomerTypeDefinition in profiles:
		if p.id == "pc_competitive_player" or p.id == "pc_pack_cracker":
			competitive_profiles.append(p)

	if competitive_profiles.is_empty():
		competitive_profiles = profiles

	for i: int in range(_participant_count):
		var profile: CustomerTypeDefinition = (
			competitive_profiles[i % competitive_profiles.size()]
		)
		_customer_system.spawn_customer(profile, STORE_TYPE)


func _complete_tournament() -> void:
	if not _is_active:
		return

	_is_active = false
	_state = TournamentState.RESOLVED
	_active_scheduled_day = -1
	_cooldown_remaining = COOLDOWN_DAYS

	var rep_gain: float = lerpf(
		REP_REWARD_MIN, REP_REWARD_MAX,
		float(_participant_count - MIN_PARTICIPANTS)
		/ float(MAX_PARTICIPANTS - MIN_PARTICIPANTS)
	)

	if _reputation_system:
		_reputation_system.add_reputation(STORE_TYPE, rep_gain)

	EventBus.tournament_completed.emit(
		_participant_count, _tournament_revenue
	)
	EventBus.notification_requested.emit(
		"Tournament complete! %d participants, $%.2f revenue, +%.1f rep"
		% [_participant_count, _tournament_revenue, rep_gain]
	)

	_participant_count = 0
	_tournament_revenue = 0.0


func _on_day_started(_day: int) -> void:
	if _cooldown_remaining > 0:
		_cooldown_remaining -= 1
	if not _is_active and _scheduled_days.has(_day):
		_start_scheduled_tournament(_day)
	elif not _is_active and _cooldown_remaining == 0 and _scheduled_days.is_empty():
		_state = TournamentState.IDLE


func _start_scheduled_tournament(day: int) -> void:
	_scheduled_days.erase(day)
	_active_scheduled_day = day
	_is_active = true
	_state = TournamentState.ACTIVE
	_tournament_revenue = 0.0
	_participant_count = _calculate_participant_count()
	EventBus.tournament_started.emit(_participant_count, 0.0)
	_spawn_tournament_customers()


func _on_day_phase_changed(new_phase: int) -> void:
	if not _is_active:
		return
	# Tournament runs MIDDAY to AFTERNOON; complete at AFTERNOON end
	if new_phase == TimeSystem.DayPhase.EVENING:
		_complete_tournament()


func _on_item_sold(
	_item_id: String, price: float, _category: String
) -> void:
	if _is_active:
		_tournament_revenue += price
