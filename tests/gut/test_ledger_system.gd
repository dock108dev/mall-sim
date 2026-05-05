## Verifies LedgerSystem subscribes to canonical mutation signals, builds a
## per-transaction record set keyed by day, anchors `day_closed` payloads as
## persistent day records, and reconciles ledger revenue against the anchor.
extends GutTest


var _time: TimeSystem


func before_each() -> void:
	LedgerSystem.clear()
	_time = TimeSystem.new()
	add_child_autofree(_time)
	_time.current_day = 1
	LedgerSystem.initialize(_time)


func after_each() -> void:
	LedgerSystem.clear()
	LedgerSystem.initialize(null)


func test_customer_purchased_records_sale_entry_with_full_fields() -> void:
	EventBus.customer_purchased.emit(
		&"retro_games", &"sku_123", 49.99, &"customer_a"
	)
	var sales: Array[Dictionary] = LedgerSystem.get_sales_for_day(1)
	assert_eq(sales.size(), 1, "customer_purchased must produce one sale entry")
	var entry: Dictionary = sales[0]
	assert_eq(entry.get("kind"), &"sale", "kind must be &\"sale\"")
	assert_eq(String(entry.get("item_id", "")), "sku_123", "item_id carried")
	assert_eq(
		String(entry.get("store_id", "")), "retro_games", "store_id carried"
	)
	assert_almost_eq(
		float(entry.get("price", 0.0)), 49.99, 0.001, "price carried"
	)
	assert_eq(
		String(entry.get("customer_id", "")), "customer_a", "customer_id carried"
	)
	assert_eq(int(entry.get("day", -1)), 1, "day stamped from TimeSystem")


func test_item_stocked_records_stock_entry_with_shelf_id() -> void:
	EventBus.item_stocked.emit("sku_456", "shelf_a3")
	var entries: Array[Dictionary] = LedgerSystem.get_entries_for_day(1)
	assert_eq(entries.size(), 1, "item_stocked must produce one stock entry")
	var entry: Dictionary = entries[0]
	assert_eq(entry.get("kind"), &"stock", "kind must be &\"stock\"")
	assert_eq(String(entry.get("item_id", "")), "sku_456", "item_id carried")
	assert_eq(
		String(entry.get("detail", "")), "shelf_a3",
		"shelf_id carried in detail"
	)


func test_day_closed_payload_stored_as_anchor_record() -> void:
	var payload: Dictionary = {
		"day": 1,
		"total_revenue": 125.50,
		"net_profit": 25.0,
		"items_sold": 3,
		"customers_served": 4,
	}
	EventBus.day_closed.emit(1, payload)
	var rec: Dictionary = LedgerSystem.get_day_record(1)
	assert_false(rec.is_empty(), "day record stored on day_closed")
	assert_almost_eq(
		float(rec.get("total_revenue", 0.0)), 125.50, 0.01,
		"anchor preserves total_revenue"
	)
	# Mutating the source payload must not bleed into the stored record.
	payload["total_revenue"] = 999.0
	var rec_after: Dictionary = LedgerSystem.get_day_record(1)
	assert_almost_eq(
		float(rec_after.get("total_revenue", 0.0)), 125.50, 0.01,
		"anchor record is a defensive copy"
	)


func test_validate_against_anchor_matches_when_ledger_sums_to_anchor() -> void:
	EventBus.customer_purchased.emit(&"retro_games", &"a", 50.0, &"c1")
	EventBus.customer_purchased.emit(&"retro_games", &"b", 75.50, &"c2")
	var payload: Dictionary = {
		"day": 1,
		"total_revenue": 125.50,
		"net_profit": 0.0,
		"items_sold": 2,
	}
	EventBus.day_closed.emit(1, payload)

	var v: Dictionary = LedgerSystem.validate_against_anchor(1)
	assert_true(bool(v.get("match", false)), "match=true when sums align")
	assert_almost_eq(float(v.get("delta", -1.0)), 0.0, 0.01, "delta near zero")
	assert_almost_eq(
		float(v.get("ledger_revenue", -1.0)), 125.50, 0.01,
		"ledger_revenue is the sum of sale prices"
	)
	assert_almost_eq(
		float(v.get("anchor_revenue", -1.0)), 125.50, 0.01,
		"anchor_revenue is read from the day_closed payload"
	)


func test_validate_against_anchor_no_match_when_revenue_diverges() -> void:
	EventBus.customer_purchased.emit(&"retro_games", &"a", 50.0, &"c1")
	EventBus.day_closed.emit(1, {"day": 1, "total_revenue": 75.0})
	var v: Dictionary = LedgerSystem.validate_against_anchor(1)
	assert_false(bool(v.get("match", true)), "match=false when sums diverge")
	assert_almost_eq(
		float(v.get("delta", 0.0)), 25.0, 0.01,
		"delta reflects divergence"
	)


func test_get_sales_for_day_filters_kind_sale_only() -> void:
	EventBus.customer_purchased.emit(&"s", &"a", 10.0, &"c1")
	EventBus.item_stocked.emit("b", "shelf")
	EventBus.defective_item_received.emit("c")
	var sales: Array[Dictionary] = LedgerSystem.get_sales_for_day(1)
	assert_eq(sales.size(), 1, "only sale entries returned")
	assert_eq(sales[0].get("kind"), &"sale")


func test_day_started_clears_intra_day_entries_but_preserves_day_records() -> void:
	# Day 1: emit a sale and close the day to seed both buffers.
	EventBus.customer_purchased.emit(&"s", &"a", 10.0, &"c1")
	EventBus.day_closed.emit(1, {"day": 1, "total_revenue": 10.0})
	assert_eq(LedgerSystem.get_entries_for_day(1).size(), 1, "day-1 entry seeded")
	assert_false(
		LedgerSystem.get_day_record(1).is_empty(), "day-1 record seeded"
	)

	# Roll to day 2.
	_time.current_day = 2
	EventBus.day_started.emit(2)

	assert_eq(
		LedgerSystem.get_entries_for_day(1).size(), 0,
		"intra-day entries cleared on day_started"
	)
	assert_false(
		LedgerSystem.get_day_record(1).is_empty(),
		"day records persist across day rollover"
	)


func test_get_debug_dump_includes_entries_and_anchor() -> void:
	EventBus.customer_purchased.emit(&"retro_games", &"sku_x", 12.0, &"c1")
	EventBus.day_closed.emit(1, {
		"day": 1, "total_revenue": 12.0, "net_profit": 4.0,
		"items_sold": 1, "customers_served": 1,
	})
	var dump: String = LedgerSystem.get_debug_dump(1)
	assert_true(dump.contains("LEDGER DAY 1"), "dump has day header")
	assert_true(dump.contains("sale"), "dump includes sale row")
	assert_true(dump.contains("sku_x"), "dump includes item_id")
	assert_true(dump.contains("DAY CLOSE ANCHOR"), "dump includes anchor section")


func test_order_delivered_records_receive_entry_per_item() -> void:
	EventBus.order_delivered.emit(
		&"retro_games",
		[{"item_id": "sku_1"}, {"item_id": "sku_2"}],
	)
	var entries: Array[Dictionary] = LedgerSystem.get_entries_for_day(1)
	assert_eq(entries.size(), 2, "one receive entry per delivered item")
	for e: Dictionary in entries:
		assert_eq(e.get("kind"), &"receive", "kind=receive on delivery")
		assert_eq(String(e.get("store_id", "")), "retro_games", "store_id carried")
