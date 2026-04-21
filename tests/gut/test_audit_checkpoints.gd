## Integration tests that instrument the five audit checkpoints via AuditOverlay.
## Each test emits the corresponding EventBus signal and verifies AuditOverlay records PASS.
extends GutTest


func before_each() -> void:
	DataLoaderSingleton.load_all()


func test_boot_complete_checkpoint() -> void:
	EventBus.boot_completed.emit()
	assert_true(
		AuditOverlay.get_results().get(&"boot_complete") == true,
		"boot_complete must record PASS after boot_completed signal"
	)


func test_store_entered_checkpoint() -> void:
	EventBus.store_entered.emit(&"retro_games")
	assert_true(
		AuditOverlay.get_results().get(&"store_entered") == true,
		"store_entered must record PASS after store_entered signal"
	)


func test_refurb_completed_checkpoint() -> void:
	EventBus.refurbishment_completed.emit("item_001", true, "excellent")
	assert_true(
		AuditOverlay.get_results().get(&"refurb_completed") == true,
		"refurb_completed must record PASS after refurbishment_completed signal"
	)


func test_transaction_completed_checkpoint() -> void:
	EventBus.transaction_completed.emit(25.0, true, "sale")
	assert_true(
		AuditOverlay.get_results().get(&"transaction_completed") == true,
		"transaction_completed must record PASS after transaction_completed signal"
	)


func test_day_closed_checkpoint() -> void:
	EventBus.day_closed.emit(1, {})
	assert_true(
		AuditOverlay.get_results().get(&"day_closed") == true,
		"day_closed must record PASS after day_closed signal"
	)


func test_customer_walked_checkpoint() -> void:
	EventBus.customer_left.emit({
		"satisfied": false,
		"reason": &"price_too_high",
	})
	assert_true(
		AuditOverlay.get_results().get(&"customer_walked") == true,
		"customer_walked must record PASS when unsatisfied with a reason"
	)


func test_all_checkpoints_pass_after_full_sequence() -> void:
	EventBus.boot_completed.emit()
	EventBus.store_entered.emit(&"retro_games")
	EventBus.panel_opened.emit("inventory")
	EventBus.item_stocked.emit("item_001", "shelf_a")
	EventBus.price_set.emit("item_001", 9.99)
	EventBus.refurbishment_completed.emit("item_001", true, "excellent")
	EventBus.transaction_completed.emit(25.0, true, "sale")
	EventBus.day_closed.emit(1, {})
	EventBus.customer_left.emit({
		"satisfied": false,
		"reason": &"no_matching_item",
	})
	assert_true(
		AuditOverlay.all_passed(),
		"all_passed() must return true after full checkpoint sequence"
	)
