## Tests CompletionTracker criterion tracking, save/load, and signal emission.
extends GutTest


var _tracker: CompletionTracker
var _data_loader: DataLoader


func before_each() -> void:
	_data_loader = DataLoader.new()
	_data_loader.load_all_content()
	_tracker = CompletionTracker.new()
	add_child_autofree(_tracker)
	_tracker.initialize(_data_loader)


func test_initial_completion_is_zero() -> void:
	var pct: float = _tracker.get_completion_percentage()
	assert_eq(pct, 0.0, "Initial completion should be 0%")


func test_get_completion_data_returns_14_criteria() -> void:
	var data: Array[Dictionary] = _tracker.get_completion_data()
	assert_eq(
		data.size(), 14,
		"Should return exactly 14 criteria"
	)


func test_criterion_structure() -> void:
	var data: Array[Dictionary] = _tracker.get_completion_data()
	for criterion: Dictionary in data:
		assert_has(criterion, "id")
		assert_has(criterion, "label")
		assert_has(criterion, "current")
		assert_has(criterion, "required")
		assert_has(criterion, "complete")


func test_store_leased_updates_criterion() -> void:
	EventBus.store_leased.emit(0, "sports_memorabilia")
	EventBus.store_leased.emit(1, "retro_games")
	var data: Array[Dictionary] = _tracker.get_completion_data()
	var stores_criterion: Dictionary = data[0]
	assert_eq(
		stores_criterion["id"], &"all_5_stores_opened"
	)
	assert_eq(stores_criterion["current"], 2.0)
	assert_eq(stores_criterion["complete"], false)


func test_all_stores_opened_completes() -> void:
	EventBus.store_leased.emit(0, "sports_memorabilia")
	EventBus.store_leased.emit(1, "retro_games")
	EventBus.store_leased.emit(2, "video_rental")
	EventBus.store_leased.emit(3, "pocket_creatures")
	EventBus.store_leased.emit(4, "consumer_electronics")
	var data: Array[Dictionary] = _tracker.get_completion_data()
	assert_eq(data[0]["complete"], true)


func test_item_sold_tracks_cash() -> void:
	EventBus.item_sold.emit("test_item", 500.0, "test")
	EventBus.item_sold.emit("test_item2", 300.0, "test")
	var data: Array[Dictionary] = _tracker.get_completion_data()
	var cash_criterion: Dictionary = _find_criterion(
		data, &"total_cash_earned"
	)
	assert_eq(cash_criterion["current"], 800.0)


func test_tournament_completed_increments() -> void:
	EventBus.tournament_completed.emit(8, 500.0)
	var data: Array[Dictionary] = _tracker.get_completion_data()
	var tournament: Dictionary = _find_criterion(
		data, &"tournaments_hosted"
	)
	assert_eq(tournament["current"], 1.0)
	assert_eq(tournament["complete"], true)


func test_authentication_only_counts_genuine() -> void:
	EventBus.authentication_completed.emit("item1", true)
	EventBus.authentication_completed.emit("item2", false)
	EventBus.authentication_completed.emit("item3", true)
	var data: Array[Dictionary] = _tracker.get_completion_data()
	var auth: Dictionary = _find_criterion(
		data, &"authentications_completed"
	)
	assert_eq(auth["current"], 2.0)


func test_refurbishment_only_counts_success() -> void:
	EventBus.refurbishment_completed.emit("item1", true, "good")
	EventBus.refurbishment_completed.emit("item2", false, "poor")
	var data: Array[Dictionary] = _tracker.get_completion_data()
	var refurb: Dictionary = _find_criterion(
		data, &"refurbishments_completed"
	)
	assert_eq(refurb["current"], 1.0)


func test_rental_catalog_tracks_max() -> void:
	EventBus.item_rented.emit("t1", 5.0, "standard")
	EventBus.item_rented.emit("t2", 5.0, "standard")
	EventBus.item_rented.emit("t3", 5.0, "standard")
	EventBus.rental_returned.emit("t1", false)
	var data: Array[Dictionary] = _tracker.get_completion_data()
	var rental: Dictionary = _find_criterion(
		data, &"rental_catalog_size"
	)
	assert_eq(
		rental["current"], 3.0,
		"Should track max simultaneous rentals"
	)


func test_warranty_requires_purchase_then_claim() -> void:
	EventBus.warranty_claim_triggered.emit("item1", 50.0)
	var data: Array[Dictionary] = _tracker.get_completion_data()
	var warranty: Dictionary = _find_criterion(
		data, &"warranty_claimed"
	)
	assert_eq(
		warranty["complete"], false,
		"Claim without prior purchase should not count"
	)

	EventBus.warranty_purchased.emit("item2", 10.0)
	EventBus.warranty_claim_triggered.emit("item2", 50.0)
	data = _tracker.get_completion_data()
	warranty = _find_criterion(data, &"warranty_claimed")
	assert_eq(warranty["complete"], true)


func test_save_and_load_round_trip() -> void:
	EventBus.store_leased.emit(0, "sports_memorabilia")
	EventBus.item_sold.emit("test", 1000.0, "test")
	EventBus.tournament_completed.emit(8, 500.0)
	EventBus.authentication_completed.emit("a1", true)

	var save_data: Dictionary = _tracker.get_save_data()

	var restored: CompletionTracker = CompletionTracker.new()
	add_child_autofree(restored)
	restored.initialize(_data_loader)
	restored.load_save_data(save_data)

	var original: Array[Dictionary] = (
		_tracker.get_completion_data()
	)
	var loaded: Array[Dictionary] = (
		restored.get_completion_data()
	)

	for i: int in range(original.size()):
		assert_eq(
			loaded[i]["current"], original[i]["current"],
			"Criterion %s should match after load" % original[i]["id"]
		)
		assert_eq(
			loaded[i]["complete"], original[i]["complete"],
			"Complete flag for %s should match" % original[i]["id"]
		)


func test_completion_percentage_formula() -> void:
	EventBus.store_leased.emit(0, "sports_memorabilia")
	EventBus.store_leased.emit(1, "retro_games")
	EventBus.store_leased.emit(2, "video_rental")
	EventBus.store_leased.emit(3, "pocket_creatures")
	EventBus.store_leased.emit(4, "consumer_electronics")

	EventBus.tournament_completed.emit(8, 500.0)

	var pct: float = _tracker.get_completion_percentage()
	var expected: float = 2.0 / 14.0 * 100.0
	assert_almost_eq(pct, expected, 0.01)


func test_duplicate_store_lease_not_double_counted() -> void:
	EventBus.store_leased.emit(0, "sports_memorabilia")
	EventBus.store_leased.emit(1, "sports_memorabilia")
	var data: Array[Dictionary] = _tracker.get_completion_data()
	assert_eq(data[0]["current"], 1.0)


func _find_criterion(
	data: Array[Dictionary], id: StringName
) -> Dictionary:
	for criterion: Dictionary in data:
		if criterion["id"] == id:
			return criterion
	return {}
