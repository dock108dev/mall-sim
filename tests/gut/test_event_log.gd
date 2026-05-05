## Verifies EventLog autoload schema for the four BRAINDUMP-corrected hooks:
## item_stocked / item_removed_from_shelf produce [STOCK] entries with the full
## location + count schema; customer_state_changed and customer_left produce
## distinct [CUSTOMER] entries (state_change vs customer_exit).
extends GutTest


func before_each() -> void:
	EventLog.clear()


func after_each() -> void:
	EventLog.clear()


func test_item_stocked_emits_stock_entry_with_location_and_count_schema() -> void:
	EventBus.item_stocked.emit("retro_console", "shelf_a2")
	var entries: Array[Dictionary] = EventLog.recent(8)
	assert_gt(entries.size(), 0, "item_stocked must produce at least one log entry")
	var entry: Dictionary = entries[entries.size() - 1]
	assert_eq(entry.get("tag"), "[STOCK]", "tag must be [STOCK]")
	assert_eq(entry.get("action"), "stock", "action must be 'stock' for stocking")
	var params: Dictionary = entry.get("params", {})
	assert_eq(params.get("item_id"), "retro_console", "item_id must be carried")
	assert_eq(
		params.get("from_location"), "backroom",
		"stocking from_location must be 'backroom'"
	)
	assert_eq(
		params.get("to_location"), "shelf:shelf_a2",
		"stocking to_location must be 'shelf:<slot_id>'"
	)
	var count_before: int = int(params.get("count_before", -1))
	var count_after: int = int(params.get("count_after", -1))
	assert_eq(
		count_after, count_before + 1,
		"stocking count_after must be count_before + 1 (N → N+1)"
	)


func test_item_removed_from_shelf_emits_stock_entry_for_sale_removal() -> void:
	EventBus.item_removed_from_shelf.emit("instance_42", "shelf_b1")
	var entries: Array[Dictionary] = EventLog.recent(8)
	assert_gt(entries.size(), 0, "item_removed_from_shelf must produce a log entry")
	var entry: Dictionary = entries[entries.size() - 1]
	assert_eq(entry.get("tag"), "[STOCK]", "removal tag must be [STOCK]")
	var params: Dictionary = entry.get("params", {})
	assert_eq(params.get("item_id"), "instance_42", "item_id must be carried")
	assert_eq(
		params.get("from_location"), "shelf:shelf_b1",
		"sale removal from_location must be 'shelf:<slot_id>'"
	)
	assert_eq(
		params.get("to_location"), "sold",
		"sale removal to_location must be 'sold'"
	)
	assert_eq(int(params.get("count_before", -1)), 1, "removal count_before must be 1")
	assert_eq(int(params.get("count_after", -1)), 0, "removal count_after must be 0")


func test_customer_state_changed_emits_customer_state_change_entry() -> void:
	var customer: Node = Node.new()
	add_child_autofree(customer)
	# Prime the state cache with an initial transition so subsequent transitions
	# carry a concrete from_state.
	EventBus.customer_state_changed.emit(customer, Customer.State.BROWSING)
	EventBus.customer_state_changed.emit(customer, Customer.State.DECIDING)
	var entries: Array[Dictionary] = EventLog.recent(8)
	assert_gt(entries.size(), 1, "two transitions must produce two log entries")
	var latest: Dictionary = entries[entries.size() - 1]
	assert_eq(latest.get("tag"), "[CUSTOMER]", "transition tag must be [CUSTOMER]")
	assert_eq(
		latest.get("action"), "state_change",
		"transition action must be 'state_change'"
	)
	var expected_actor: String = "customer:%d" % customer.get_instance_id()
	assert_eq(
		String(latest.get("actor", "")), expected_actor,
		"actor must encode the customer instance id"
	)
	var params: Dictionary = latest.get("params", {})
	assert_eq(
		String(params.get("from_state", "")), "BROWSING",
		"from_state must be the previous transition's target"
	)
	assert_eq(
		String(params.get("to_state", "")), "DECIDING",
		"to_state must be the new state name"
	)


func test_customer_left_emits_distinct_customer_exit_entry() -> void:
	# state_change and customer_exit must produce distinct entries.
	var customer: Node = Node.new()
	add_child_autofree(customer)
	EventBus.customer_state_changed.emit(customer, Customer.State.LEAVING)
	EventBus.customer_left.emit({
		"customer_id": customer.get_instance_id(),
		"satisfied": false,
		"reason": &"price_too_high",
	})
	var entries: Array[Dictionary] = EventLog.recent(8)
	assert_eq(entries.size(), 2, "both signals must produce one entry each")

	var transition: Dictionary = entries[entries.size() - 2]
	var exit_entry: Dictionary = entries[entries.size() - 1]

	assert_eq(transition.get("action"), "state_change",
		"first entry must come from customer_state_changed")
	assert_eq(exit_entry.get("tag"), "[CUSTOMER]",
		"customer_left tag must be [CUSTOMER]")
	assert_eq(exit_entry.get("action"), "customer_exit",
		"customer_left action must be 'customer_exit', not 'state_change'")
	assert_ne(
		String(transition.get("action", "")),
		String(exit_entry.get("action", "")),
		"the two signals must produce distinct actions"
	)
	var params: Dictionary = exit_entry.get("params", {})
	assert_false(bool(params.get("satisfied", true)),
		"customer_exit must carry the satisfied flag")
	assert_eq(String(params.get("reason", "")), "price_too_high",
		"customer_exit must carry the reason field when present")


func test_all_six_customer_state_transitions_log_distinct_state_changes() -> void:
	# Covers BROWSING → DECIDING → PURCHASING → LEAVING and also DECIDING →
	# LEAVING / WAITING_IN_QUEUE / ENTERING transitions to ensure every
	# Customer.State transition produces a [CUSTOMER] state_change entry.
	var customer: Node = Node.new()
	add_child_autofree(customer)
	var sequence: Array[int] = [
		Customer.State.ENTERING,
		Customer.State.BROWSING,
		Customer.State.DECIDING,
		Customer.State.PURCHASING,
		Customer.State.WAITING_IN_QUEUE,
		Customer.State.LEAVING,
	]
	for state: int in sequence:
		EventBus.customer_state_changed.emit(customer, state)
	var entries: Array[Dictionary] = EventLog.recent(16)
	assert_eq(entries.size(), sequence.size(),
		"each state transition must produce one [CUSTOMER] entry")
	for entry: Dictionary in entries:
		assert_eq(entry.get("tag"), "[CUSTOMER]",
			"every transition entry must be tagged [CUSTOMER]")
		assert_eq(entry.get("action"), "state_change",
			"every transition action must be 'state_change'")
