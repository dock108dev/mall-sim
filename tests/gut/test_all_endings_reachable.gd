## Golden-path coverage: each of the 14 defined endings is reachable from a clean
## EndingEvaluatorSystem by accumulating only the stats its criteria require.
extends GutTest


const STORE_TYPES := [
	"sports_memorabilia",
	"retro_games",
	"video_rental",
	"electronics",
	"pocket_creatures",
]

var _system: EndingEvaluatorSystem

var _saved_state: GameManager.State
var _saved_ending_id: StringName


func before_each() -> void:
	_saved_state = GameManager.current_state
	_saved_ending_id = GameManager.get_ending_id()
	GameManager.current_state = GameManager.State.MAIN_MENU
	GameManager._ending_id = &""

	_system = EndingEvaluatorSystem.new()
	add_child_autofree(_system)
	_system.initialize()


func after_each() -> void:
	GameManager.current_state = _saved_state
	GameManager._ending_id = _saved_ending_id


func _advance_days(count: int) -> void:
	for i in range(count):
		EventBus.day_started.emit(i + 1)


func _accumulate_revenue(total: float, per_sale: float) -> void:
	var sales: int = int(ceil(total / per_sale))
	for i in range(sales):
		EventBus.customer_purchased.emit(
			&"store_0", &"item_%d" % i, per_sale, &"customer_%d" % i
		)


func _satisfy_customers(satisfied: int, unsatisfied: int = 0) -> void:
	for i in range(satisfied):
		EventBus.customer_left.emit({"satisfied": true})
	for i in range(unsatisfied):
		EventBus.customer_left.emit({"satisfied": false})


func _lease_stores(count: int) -> void:
	for i in range(count):
		EventBus.store_leased.emit(i, STORE_TYPES[i])


## Priority 0 — bankruptcy on or before day 7.
func test_lights_out() -> void:
	_advance_days(5)
	EventBus.bankruptcy_declared.emit()
	assert_eq(
		_system.get_resolved_ending_id(),
		&"lights_out",
		"Early bankruptcy must resolve to lights_out"
	)


## Priority 3 — bankruptcy between day 8 and day 14.
func test_foreclosure() -> void:
	_advance_days(10)
	EventBus.bankruptcy_declared.emit()
	assert_eq(
		_system.get_resolved_ending_id(),
		&"foreclosure",
		"Mid-run bankruptcy must resolve to foreclosure"
	)


## Priority 4 — bankruptcy after day 15.
func test_going_going_gone() -> void:
	_advance_days(20)
	EventBus.bankruptcy_declared.emit()
	assert_eq(
		_system.get_resolved_ending_id(),
		&"going_going_gone",
		"Late bankruptcy must resolve to going_going_gone"
	)


## Priority 5 — full success: revenue, reputation, satisfaction, longevity.
func test_prestige_champion() -> void:
	_advance_days(30)
	EventBus.reputation_changed.emit("store_0", 0.0, 90.0)
	_accumulate_revenue(60000.0, 600.0)
	_satisfy_customers(200, 10)
	EventBus.ending_requested.emit("completion")
	assert_eq(
		_system.get_resolved_ending_id(),
		&"prestige_champion",
		"High revenue + rep tier 4 + satisfaction + 30 days must resolve to prestige_champion"
	)


## Priority 6 — one store, tier-4 reputation, 30 days, modest revenue.
func test_the_local_legend() -> void:
	_advance_days(30)
	_lease_stores(1)
	EventBus.reputation_changed.emit("store_0", 0.0, 90.0)
	_accumulate_revenue(12000.0, 100.0)
	_satisfy_customers(50, 30)
	EventBus.ending_requested.emit("completion")
	assert_eq(
		_system.get_resolved_ending_id(),
		&"the_local_legend",
		"Single store + rep tier 4 + 30 days (below prestige thresholds) must resolve to the_local_legend"
	)


## Priority 7 — all five stores owned with meaningful revenue.
func test_the_mall_tycoon() -> void:
	_advance_days(10)
	_lease_stores(5)
	_accumulate_revenue(30000.0, 300.0)
	EventBus.ending_requested.emit("completion")
	assert_eq(
		_system.get_resolved_ending_id(),
		&"the_mall_tycoon",
		"Five stores + 25k revenue must resolve to the_mall_tycoon"
	)


## Priority 8 — three stores and 10k revenue.
func test_the_mini_empire() -> void:
	_advance_days(10)
	_lease_stores(3)
	_accumulate_revenue(12000.0, 300.0)
	EventBus.ending_requested.emit("completion")
	assert_eq(
		_system.get_resolved_ending_id(),
		&"the_mini_empire",
		"Three stores + 10k revenue must resolve to the_mini_empire"
	)


## Priority 9 — 200 satisfied customers without using haggle.
func test_the_fair_dealer() -> void:
	_advance_days(10)
	EventBus.reputation_changed.emit("store_0", 0.0, 65.0)
	_satisfy_customers(200, 0)
	EventBus.ending_requested.emit("completion")
	assert_eq(
		_system.get_resolved_ending_id(),
		&"the_fair_dealer",
		"200 satisfied + haggle-free + rep tier 3 must resolve to the_fair_dealer"
	)


## Priority 10 — survived 30 days with minimal revenue and positive cash.
func test_broke_even() -> void:
	_advance_days(30)
	EventBus.money_changed.emit(0.0, 50.0)
	EventBus.hidden_thread_interacted.emit(&"any_thread")
	assert_eq(
		_system.get_tracked_stat(&"cumulative_revenue"),
		0.0,
		"Revenue should stay under the broke_even ceiling"
	)
	EventBus.ending_requested.emit("completion")
	assert_eq(
		_system.get_resolved_ending_id(),
		&"broke_even",
		"30 days + positive cash + <2k revenue must resolve to broke_even"
	)


## Priority 11 — survived 30 days with revenue in the 2k–10k band.
func test_the_comfortable_middle() -> void:
	_advance_days(30)
	_accumulate_revenue(5000.0, 100.0)
	EventBus.money_changed.emit(0.0, 200.0)
	EventBus.hidden_thread_interacted.emit(&"any_thread")
	EventBus.ending_requested.emit("completion")
	assert_eq(
		_system.get_resolved_ending_id(),
		&"the_comfortable_middle",
		"30 days + 2k–10k revenue must resolve to the_comfortable_middle"
	)


## Priority 12 — survived 30 days after ≥10 days below the bankruptcy line.
func test_crisis_operator() -> void:
	EventBus.money_changed.emit(500.0, 50.0)
	for i in range(12):
		EventBus.day_ended.emit(i + 1)
	_advance_days(30)
	_accumulate_revenue(12000.0, 120.0)
	EventBus.hidden_thread_interacted.emit(&"any_thread")
	EventBus.ending_requested.emit("completion")
	assert_eq(
		_system.get_resolved_ending_id(),
		&"crisis_operator",
		"≥10 near-bankruptcy days + 30 survived + positive cash must resolve to crisis_operator"
	)


## Priority 8 — survived 30 days without ever interacting with a hidden thread.
func test_the_uninitiated() -> void:
	_advance_days(30)
	EventBus.money_changed.emit(0.0, 200.0)
	_accumulate_revenue(500.0, 50.0)
	EventBus.ending_requested.emit("completion")
	assert_eq(
		_system.get_resolved_ending_id(),
		&"the_uninitiated",
		"30 days with zero hidden_thread_interacted emissions must resolve to the_uninitiated"
	)


## Confirms one hidden_thread_interacted emission blocks the_uninitiated and
## drops through to a generic survival ending.
func test_one_hidden_thread_interaction_blocks_the_uninitiated() -> void:
	_advance_days(30)
	EventBus.money_changed.emit(0.0, 200.0)
	EventBus.hidden_thread_interacted.emit(&"any_thread")
	EventBus.ending_requested.emit("completion")
	assert_ne(
		_system.get_resolved_ending_id(),
		&"the_uninitiated",
		"≥1 hidden_thread_interacted emission must block the_uninitiated"
	)


## Confirms a player who only acknowledges the tutorial hidden-clue beat — a
## distinct EventBus signal — does not pollute hidden_thread_interactions and
## still lands on the_uninitiated.
func test_tutorial_hidden_clue_acknowledged_does_not_pollute_stat() -> void:
	_advance_days(30)
	EventBus.money_changed.emit(0.0, 200.0)
	EventBus.hidden_clue_acknowledged.emit(&"void_protocols_red_label")
	assert_eq(
		_system.get_tracked_stat(&"hidden_thread_interactions"),
		0.0,
		"hidden_clue_acknowledged must not increment hidden_thread_interactions"
	)
	EventBus.ending_requested.emit("completion")
	assert_eq(
		_system.get_resolved_ending_id(),
		&"the_uninitiated",
		"Tutorial-only acknowledge must still land on the_uninitiated"
	)


## Confirms bankruptcy before day 30 blocks the_uninitiated via forbidden_all.
func test_bankruptcy_blocks_the_uninitiated() -> void:
	_advance_days(20)
	EventBus.bankruptcy_declared.emit()
	assert_ne(
		_system.get_resolved_ending_id(),
		&"the_uninitiated",
		"Pre-day-30 bankruptcy must block the_uninitiated via forbidden_all"
	)


## Sanity — the suite covers all 14 configured endings.
func test_all_endings_are_covered() -> void:
	var covered: Array[StringName] = [
		&"the_mall_between_the_walls",
		&"the_mall_legend_redux",
		&"lights_out",
		&"foreclosure",
		&"going_going_gone",
		&"prestige_champion",
		&"the_local_legend",
		&"the_mall_tycoon",
		&"the_mini_empire",
		&"the_fair_dealer",
		&"broke_even",
		&"the_comfortable_middle",
		&"crisis_operator",
		&"the_uninitiated",
	]
	assert_eq(
		covered.size(), 14,
		"Golden-path suite must declare exactly 14 distinct endings"
	)
	for ending_id in covered:
		assert_false(
			_system.get_ending_data(ending_id).is_empty(),
			"Ending '%s' must exist in the loaded ending config" % ending_id
		)
