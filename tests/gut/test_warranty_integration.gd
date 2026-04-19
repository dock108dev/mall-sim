## Tests warranty integration: PerformanceReport fields and signal tracking.
extends GutTest


func test_performance_report_warranty_fields_default_zero() -> void:
	var report := PerformanceReport.new()
	assert_eq(report.warranty_revenue, 0.0)
	assert_eq(report.warranty_claim_costs, 0.0)


func test_performance_report_serializes_warranty_fields() -> void:
	var report := PerformanceReport.new()
	report.warranty_revenue = 25.50
	report.warranty_claim_costs = 12.75
	var data: Dictionary = report.to_dict()
	assert_eq(data.get("warranty_revenue"), 25.50)
	assert_eq(data.get("warranty_claim_costs"), 12.75)


func test_performance_report_deserializes_warranty_fields() -> void:
	var data: Dictionary = {
		"warranty_revenue": 30.0,
		"warranty_claim_costs": 15.0,
	}
	var report: PerformanceReport = PerformanceReport.from_dict(data)
	assert_eq(report.warranty_revenue, 30.0)
	assert_eq(report.warranty_claim_costs, 15.0)


func test_performance_report_roundtrip_warranty() -> void:
	var original := PerformanceReport.new()
	original.warranty_revenue = 42.50
	original.warranty_claim_costs = 18.00
	original.day = 5
	var restored: PerformanceReport = PerformanceReport.from_dict(
		original.to_dict()
	)
	assert_eq(restored.warranty_revenue, 42.50)
	assert_eq(restored.warranty_claim_costs, 18.00)


func test_warranty_manager_eligibility_boundary() -> void:
	assert_false(
		WarrantyManager.is_eligible(49.99),
		"Price below threshold should not be eligible"
	)
	assert_true(
		WarrantyManager.is_eligible(50.0),
		"Price at threshold should be eligible"
	)
	assert_true(
		WarrantyManager.is_eligible(150.0),
		"Price above threshold should be eligible"
	)


func test_warranty_manager_fee_clamped() -> void:
	var fee_low: float = WarrantyManager.calculate_fee(100.0, 0.05)
	assert_almost_eq(fee_low, 15.0, 0.01)
	var fee_high: float = WarrantyManager.calculate_fee(100.0, 0.50)
	assert_almost_eq(fee_high, 25.0, 0.01)
	var fee_mid: float = WarrantyManager.calculate_fee(100.0, 0.20)
	assert_almost_eq(fee_mid, 20.0, 0.01)


func test_warranty_manager_add_and_daily_revenue() -> void:
	var wm := WarrantyManager.new()
	wm.reset_daily_totals()
	wm.add_warranty("item_a", 100.0, 20.0, 50.0, 1)
	assert_eq(wm.get_daily_warranty_revenue(), 20.0)
	assert_eq(wm.get_active_count(), 1)


func test_warranty_manager_save_load_roundtrip() -> void:
	var wm := WarrantyManager.new()
	wm.add_warranty("item_x", 80.0, 16.0, 40.0, 3)
	var data: Dictionary = wm.get_save_data()
	var wm2 := WarrantyManager.new()
	wm2.load_save_data(data)
	assert_eq(wm2.get_active_count(), 1)
	assert_eq(wm2.get_daily_warranty_revenue(), 16.0)


func test_warranty_offer_presented_signal_emitted_on_eligible_item() -> void:
	var controller := ElectronicsStoreController.new()
	add_child_autofree(controller)
	var presented_ids: Array[String] = []
	var cb: Callable = func(item_id: String) -> void:
		presented_ids.append(item_id)
	EventBus.warranty_offer_presented.connect(cb)
	controller.present_warranty_offer("item_abc", 120.0)
	assert_eq(presented_ids.size(), 1, "Signal should fire once for eligible price")
	assert_eq(presented_ids[0], "item_abc")
	EventBus.warranty_offer_presented.disconnect(cb)


func test_warranty_offer_not_emitted_below_price_threshold() -> void:
	var controller := ElectronicsStoreController.new()
	add_child_autofree(controller)
	var presented_ids: Array[String] = []
	var cb: Callable = func(item_id: String) -> void:
		presented_ids.append(item_id)
	EventBus.warranty_offer_presented.connect(cb)
	controller.present_warranty_offer("cheap_item", 30.0)
	assert_eq(
		presented_ids.size(), 0,
		"Signal must not fire for ineligible price"
	)
	EventBus.warranty_offer_presented.disconnect(cb)


func test_warranty_purchase_adds_to_manager_and_emits_signal() -> void:
	var wm := WarrantyManager.new()
	var purchased_ids: Array[String] = []
	var cb: Callable = func(item_id: String, _fee: float) -> void:
		purchased_ids.append(item_id)
	EventBus.warranty_purchased.connect(cb)
	wm.add_warranty("sold_item", 150.0, 30.0, 75.0, 1)
	EventBus.warranty_purchased.emit("sold_item", 30.0)
	assert_eq(wm.get_active_count(), 1)
	assert_eq(purchased_ids.size(), 1)
	assert_eq(purchased_ids[0], "sold_item")
	EventBus.warranty_purchased.disconnect(cb)
