## Tests HaggleSession data class: state tracking, offer recording,
## gap ratio calculation, insult detection, and factory configuration.
extends GutTest


func _make_session(
	sticker: float = 100.0,
	perceived: float = 80.0,
	patience: float = 0.5,
	queue_count: int = 0,
) -> HaggleSession:
	var session: HaggleSession = HaggleSession.create(
		null, &"test_item", sticker, perceived,
		patience, queue_count,
	)
	return session


func test_initial_state() -> void:
	var session: HaggleSession = _make_session()
	assert_eq(session.state, HaggleSession.HaggleState.IDLE)
	assert_eq(session.outcome, HaggleSession.HaggleOutcome.PENDING)
	assert_eq(session.round_number, 0)
	assert_eq(session.offer_history.size(), 0)
	assert_eq(session.item_id, &"test_item")


func test_record_player_offer_appends_and_advances() -> void:
	var session: HaggleSession = _make_session()
	session.record_player_offer(90.0)
	assert_eq(session.offer_history.size(), 1)
	assert_eq(session.offer_history[0], 90.0)
	assert_eq(session.current_offer, 90.0)
	assert_eq(session.round_number, 1)

	session.record_player_offer(85.0)
	assert_eq(session.offer_history.size(), 2)
	assert_eq(session.current_offer, 85.0)
	assert_eq(session.round_number, 2)


func test_get_gap_ratio_positive() -> void:
	var session: HaggleSession = _make_session(100.0, 80.0)
	session.current_offer = 100.0
	assert_almost_eq(session.get_gap_ratio(), 0.25, 0.001)


func test_get_gap_ratio_at_perceived_value() -> void:
	var session: HaggleSession = _make_session(100.0, 80.0)
	session.current_offer = 80.0
	assert_almost_eq(session.get_gap_ratio(), 0.0, 0.001)


func test_get_gap_ratio_below_perceived_value() -> void:
	var session: HaggleSession = _make_session(100.0, 80.0)
	session.current_offer = 60.0
	assert_almost_eq(session.get_gap_ratio(), -0.25, 0.001)


func test_get_gap_ratio_zero_perceived_value() -> void:
	var session: HaggleSession = _make_session(100.0, 0.0)
	session.current_offer = 50.0
	assert_eq(session.get_gap_ratio(), 0.0)


func test_insult_detection_true() -> void:
	var session: HaggleSession = _make_session(100.0, 80.0)
	session.record_customer_offer(70.0)
	session.record_player_offer(90.0)
	session.record_customer_offer(55.0)
	session.record_player_offer(90.5)
	assert_true(session.is_insulting_counter())


func test_insult_detection_false_player_moved_enough() -> void:
	var session: HaggleSession = _make_session(100.0, 80.0)
	session.record_customer_offer(70.0)
	session.record_player_offer(90.0)
	session.record_customer_offer(55.0)
	session.record_player_offer(80.0)
	assert_false(session.is_insulting_counter())


func test_insult_detection_false_insufficient_offers() -> void:
	var session: HaggleSession = _make_session(100.0, 80.0)
	session.record_player_offer(90.0)
	assert_false(session.is_insulting_counter())


func test_insult_detection_false_no_customer_concession() -> void:
	var session: HaggleSession = _make_session(100.0, 80.0)
	session.record_customer_offer(70.0)
	session.record_player_offer(90.0)
	session.record_customer_offer(69.5)
	session.record_player_offer(90.1)
	assert_false(session.is_insulting_counter())


func test_max_rounds_high_patience() -> void:
	var session: HaggleSession = _make_session(100.0, 80.0, 0.9)
	assert_eq(session.max_rounds, 5)


func test_max_rounds_medium_patience() -> void:
	var session: HaggleSession = _make_session(100.0, 80.0, 0.5)
	assert_eq(session.max_rounds, 4)


func test_max_rounds_low_patience() -> void:
	var session: HaggleSession = _make_session(100.0, 80.0, 0.3)
	assert_eq(session.max_rounds, 3)


func test_max_rounds_very_low_patience() -> void:
	var session: HaggleSession = _make_session(100.0, 80.0, 0.1)
	assert_eq(session.max_rounds, 2)


func test_time_per_turn_no_queue() -> void:
	var session: HaggleSession = _make_session(100.0, 80.0, 1.0, 0)
	assert_almost_eq(
		session.time_per_turn, HaggleSession.TIME_PER_TURN_MAX, 0.01
	)


func test_time_per_turn_min_patience() -> void:
	var session: HaggleSession = _make_session(100.0, 80.0, 0.0, 0)
	assert_almost_eq(
		session.time_per_turn, HaggleSession.TIME_PER_TURN_MIN, 0.01
	)


func test_time_per_turn_queue_reduction() -> void:
	var no_queue: HaggleSession = _make_session(100.0, 80.0, 0.5, 0)
	var with_queue: HaggleSession = _make_session(100.0, 80.0, 0.5, 2)
	var expected: float = no_queue.time_per_turn * 0.7
	assert_almost_eq(with_queue.time_per_turn, expected, 0.01)


func test_time_per_turn_queue_of_one_no_reduction() -> void:
	var no_queue: HaggleSession = _make_session(100.0, 80.0, 0.5, 0)
	var queue_one: HaggleSession = _make_session(100.0, 80.0, 0.5, 1)
	assert_almost_eq(
		queue_one.time_per_turn, no_queue.time_per_turn, 0.01
	)


func test_enums_cover_all_states() -> void:
	assert_eq(HaggleSession.HaggleState.IDLE, 0)
	assert_eq(HaggleSession.HaggleState.EVALUATE, 1)
	assert_eq(HaggleSession.HaggleState.PLAYER_TURN, 2)
	assert_eq(HaggleSession.HaggleState.CUSTOMER_TURN, 3)
	assert_eq(HaggleSession.HaggleState.SALE_COMPLETE, 4)
	assert_eq(HaggleSession.HaggleState.WALKAWAY, 5)

	assert_eq(HaggleSession.HaggleOutcome.PENDING, 0)
	assert_eq(HaggleSession.HaggleOutcome.SALE, 1)
	assert_eq(HaggleSession.HaggleOutcome.WALKAWAY, 2)
