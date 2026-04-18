## Tests AuthenticationSystem canonical provenance authentication contracts.
extends GutTest


const AUTHENTIC_ITEM_ID: StringName = &"signed_rookie_card"
const SUSPICIOUS_ITEM_ID: StringName = &"questionable_game_ball"
const AUTHENTIC_PRICE: float = 240.0
const SUSPICIOUS_PRICE: float = 180.0

var _auth: AuthenticationSystem


func before_each() -> void:
	ContentRegistry.clear_for_testing()
	_register_item(
		AUTHENTIC_ITEM_ID,
		"Signed Rookie Card",
		AUTHENTIC_PRICE,
		false
	)
	_register_item(
		SUSPICIOUS_ITEM_ID,
		"Questionable Game Ball",
		SUSPICIOUS_PRICE,
		true
	)
	_auth = AuthenticationSystem.new()


func after_each() -> void:
	ContentRegistry.clear_for_testing()


func test_authentic_item_accepted() -> void:
	var emissions: Array = []
	var capture: Callable = func(
		item_id: Variant, success: bool, price: Variant
	) -> void:
		emissions.append([item_id, success, price])
	EventBus.authentication_completed.connect(capture)

	var result: bool = _auth.request_authentication(AUTHENTIC_ITEM_ID)

	EventBus.authentication_completed.disconnect(capture)
	assert_true(result, "request_authentication should accept item")
	assert_eq(emissions.size(), 1, "completion signal should fire once")
	assert_eq(emissions[0][0], AUTHENTIC_ITEM_ID)
	assert_true(emissions[0][1], "completion should be successful")
	assert_almost_eq(
		float(emissions[0][2]),
		AUTHENTIC_PRICE,
		0.001,
		"authentic item should keep full asking price"
	)


func test_suspicious_item_price_reduced() -> void:
	var prices: Array[float] = []
	var capture: Callable = func(
		_item_id: Variant, _success: bool, price: Variant
	) -> void:
		prices.append(float(price))
	EventBus.authentication_completed.connect(capture)

	var result: bool = _auth.request_authentication(SUSPICIOUS_ITEM_ID)

	EventBus.authentication_completed.disconnect(capture)
	assert_true(result, "request_authentication should process item")
	assert_eq(prices.size(), 1, "completion signal should fire once")
	assert_almost_eq(
		prices[0],
		SUSPICIOUS_PRICE * 0.5,
		0.001,
		"suspicious item should emit half asking price"
	)


func test_reject_emits_rejected_signal() -> void:
	var rejected_ids: Array[StringName] = []
	var capture: Callable = func(item_id: StringName) -> void:
		rejected_ids.append(item_id)
	EventBus.authentication_rejected.connect(capture)

	var result: bool = _auth.reject_authentication(AUTHENTIC_ITEM_ID)

	EventBus.authentication_rejected.disconnect(capture)
	assert_true(result, "reject_authentication should return true")
	assert_eq(rejected_ids.size(), 1, "rejected signal should fire once")
	assert_eq(
		rejected_ids[0],
		AUTHENTIC_ITEM_ID,
		"rejected signal should carry canonical item id"
	)


func test_double_authenticate_no_op() -> void:
	assert_true(
		_auth.request_authentication(AUTHENTIC_ITEM_ID),
		"first authentication should succeed"
	)

	watch_signals(EventBus)
	var result: bool = _auth.request_authentication(AUTHENTIC_ITEM_ID)

	assert_false(result, "second authentication should return false")
	assert_signal_not_emitted(
		EventBus,
		"authentication_completed",
		"second authentication should not emit completion"
	)


func test_signals_use_canonical_ids() -> void:
	var completed_ids: Array = []
	var rejected_ids: Array = []
	var capture_completed: Callable = func(
		item_id: Variant, _success: bool, _price: Variant
	) -> void:
		completed_ids.append(item_id)
	var capture_rejected: Callable = func(item_id: StringName) -> void:
		rejected_ids.append(item_id)
	EventBus.authentication_completed.connect(capture_completed)
	EventBus.authentication_rejected.connect(capture_rejected)

	_auth.request_authentication("Signed Rookie Card")
	_auth.reject_authentication("Questionable Game Ball")

	EventBus.authentication_completed.disconnect(capture_completed)
	EventBus.authentication_rejected.disconnect(capture_rejected)
	assert_eq(completed_ids.size(), 1)
	assert_eq(rejected_ids.size(), 1)
	_assert_canonical_id(completed_ids[0], AUTHENTIC_ITEM_ID)
	_assert_canonical_id(rejected_ids[0], SUSPICIOUS_ITEM_ID)


func _register_item(
	item_id: StringName,
	display_name: String,
	base_price: float,
	is_suspicious: bool
) -> void:
	ContentRegistry.register_entry(
		{
			"id": String(item_id),
			"display_name": display_name,
			"base_price": base_price,
			"store_type": "sports",
			"suspicious_chance": 1.0 if is_suspicious else 0.0,
		},
		"item"
	)


func _assert_canonical_id(
	actual: Variant, expected: StringName
) -> void:
	assert_eq(
		typeof(actual),
		TYPE_STRING_NAME,
		"emitted ID should be a StringName"
	)
	assert_eq(actual, expected, "emitted ID should be canonical")
	assert_eq(
		String(actual),
		String(actual).to_snake_case(),
		"canonical ID should be snake_case"
	)
	assert_eq(
		ContentRegistry.resolve(String(actual)),
		expected,
		"canonical ID should resolve through ContentRegistry"
	)
