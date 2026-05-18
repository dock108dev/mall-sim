## Verifies EventLog autoload schema for the four BRAINDUMP-corrected hooks:
## item_stocked / item_removed_from_shelf produce [STOCK] entries with the full
## location + count schema; customer_state_changed and customer_left produce
## distinct [CUSTOMER] entries (state_change vs customer_exit).
extends GutTest


func before_each() -> void:
	EventLog.clear()
	EventLog.set_broadcast_enabled(true)


func after_each() -> void:
	EventLog.clear()
	EventLog.set_broadcast_enabled(true)


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


func test_day_started_emits_day_entry() -> void:
	EventBus.day_started.emit(3)
	var entries: Array[Dictionary] = EventLog.recent(8)
	assert_gt(entries.size(), 0, "day_started must produce a log entry")
	var entry: Dictionary = entries[entries.size() - 1]
	assert_eq(entry.get("tag"), "[DAY]", "day_started tag must be [DAY]")
	assert_eq(entry.get("action"), "day_started", "action must be 'day_started'")
	var params: Dictionary = entry.get("params", {})
	assert_eq(int(params.get("day", -1)), 3, "day param must be carried")


func test_money_changed_emits_stat_entry_with_delta() -> void:
	EventBus.money_changed.emit(100.0, 175.0)
	var entries: Array[Dictionary] = EventLog.recent(8)
	assert_gt(entries.size(), 0, "money_changed must produce a log entry")
	var entry: Dictionary = entries[entries.size() - 1]
	assert_eq(entry.get("tag"), "[STAT]", "money_changed tag must be [STAT]")
	assert_eq(entry.get("action"), "stat_changed", "action must be 'stat_changed'")
	var params: Dictionary = entry.get("params", {})
	assert_eq(String(params.get("stat", "")), "money", "stat field must be 'money'")
	assert_almost_eq(
		float(params.get("old_value", -1.0)), 100.0, 0.001,
		"old_value must carry the pre-mutation amount"
	)
	assert_almost_eq(
		float(params.get("new_value", -1.0)), 175.0, 0.001,
		"new_value must carry the post-mutation amount"
	)
	assert_almost_eq(
		float(params.get("delta", 0.0)), 75.0, 0.001,
		"delta must be new_value - old_value"
	)


func test_gameplay_ready_emits_system_game_started_entry() -> void:
	EventBus.gameplay_ready.emit()
	var entries: Array[Dictionary] = EventLog.recent(8)
	assert_gt(entries.size(), 0, "gameplay_ready must produce a log entry")
	var entry: Dictionary = entries[entries.size() - 1]
	assert_eq(entry.get("tag"), "[SYSTEM]", "gameplay_ready tag must be [SYSTEM]")
	assert_eq(
		entry.get("action"), "game_started",
		"gameplay_ready action must be 'game_started'"
	)


func test_modal_opened_and_closed_emit_distinct_modal_entries() -> void:
	EventBus.modal_opened.emit(&"BetaDecisionCardPanel")
	EventBus.modal_closed.emit(&"BetaDecisionCardPanel")
	var entries: Array[Dictionary] = EventLog.recent(8)
	assert_eq(entries.size(), 2, "open + close must produce two entries")
	var opened: Dictionary = entries[entries.size() - 2]
	var closed: Dictionary = entries[entries.size() - 1]
	assert_eq(opened.get("tag"), "[MODAL]", "modal_opened tag must be [MODAL]")
	assert_eq(
		opened.get("action"), "modal_opened",
		"first entry must be modal_opened"
	)
	assert_eq(closed.get("tag"), "[MODAL]", "modal_closed tag must be [MODAL]")
	assert_eq(
		closed.get("action"), "modal_closed",
		"second entry must be modal_closed"
	)
	assert_eq(
		String(opened.get("params", {}).get("modal_id", "")),
		"BetaDecisionCardPanel",
		"modal_id must be carried as a String"
	)


func test_objective_completed_emits_objective_entry_with_label() -> void:
	EventBus.objective_completed.emit(&"talk_to_customer", "Customer served.")
	var entries: Array[Dictionary] = EventLog.recent(8)
	assert_gt(entries.size(), 0, "objective_completed must produce a log entry")
	var entry: Dictionary = entries[entries.size() - 1]
	assert_eq(
		entry.get("tag"), "[OBJECTIVE]",
		"objective_completed tag must be [OBJECTIVE]"
	)
	assert_eq(
		entry.get("action"), "objective_completed",
		"action must be 'objective_completed'"
	)
	var params: Dictionary = entry.get("params", {})
	assert_eq(
		String(params.get("objective_id", "")), "talk_to_customer",
		"objective_id must be carried"
	)
	assert_eq(
		String(params.get("label", "")), "Customer served.",
		"past-tense label must be carried verbatim"
	)


func test_event_logged_broadcast_fires_with_formatted_message() -> void:
	# The on-screen log surface subscribes to EventBus.event_logged and never
	# touches the ring buffer. Verify player-facing activity lands with the
	# formatted string the panel renders.
	var captured: Array = []
	var sink := func(tag: String, message: String) -> void:
		captured.append({"tag": tag, "message": message})
	EventBus.event_logged.connect(sink)
	EventBus.objective_completed.emit(&"close_day", "Day closed.")
	EventBus.event_logged.disconnect(sink)
	assert_eq(captured.size(), 1, "broadcast must fire once per _record call")
	assert_eq(String(captured[0]["tag"]), "[OBJECTIVE]")
	assert_eq(
		String(captured[0]["message"]), "Day closed.",
		"formatted message for objective_completed must be the past-tense label"
	)


func test_customer_state_changes_stay_out_of_player_feed() -> void:
	var captured: Array = []
	var sink := func(tag: String, message: String) -> void:
		captured.append({"tag": tag, "message": message})
	var customer: Node = Node.new()
	add_child_autofree(customer)
	EventBus.event_logged.connect(sink)
	EventBus.customer_state_changed.emit(customer, Customer.State.BROWSING)
	EventBus.event_logged.disconnect(sink)
	var entries: Array[Dictionary] = EventLog.recent(8)
	assert_eq(captured.size(), 0, "FSM state names must not reach the player feed")
	assert_eq(entries.size(), 1, "state_change must remain in the debug timeline")
	assert_eq(entries[0].get("action"), "state_change")


func test_modal_lifecycle_stays_out_of_player_feed() -> void:
	var captured: Array = []
	var sink := func(tag: String, message: String) -> void:
		captured.append({"tag": tag, "message": message})
	EventBus.event_logged.connect(sink)
	EventBus.modal_opened.emit(&"CanvasLayer/DecisionCard")
	EventBus.modal_closed.emit(&"CanvasLayer/DecisionCard")
	EventBus.event_logged.disconnect(sink)
	var entries: Array[Dictionary] = EventLog.recent(8)
	assert_eq(captured.size(), 0, "modal node names must not reach the player feed")
	assert_eq(entries.size(), 2, "modal lifecycle entries must remain debuggable")
	assert_eq(entries[0].get("action"), "modal_opened")
	assert_eq(entries[1].get("action"), "modal_closed")


func test_day_one_player_activity_events_reach_player_feed() -> void:
	var captured: Array = []
	var sink := func(tag: String, message: String) -> void:
		captured.append({"tag": tag, "message": message})
	EventBus.event_logged.connect(sink)
	EventBus.objective_completed.emit(&"talk_to_customer", "Customer served.")
	EventBus.money_changed.emit(50.0, 150.0)
	EventBus.objective_completed.emit(&"back_room_inventory", "Delivery checked.")
	EventBus.objective_completed.emit(&"stock_shelf", "Shelf stocked.")
	EventBus.event_logged.disconnect(sink)
	assert_eq(captured.size(), 4, "Day-1 loop beats must reach the player feed")
	assert_eq(String(captured[0]["message"]), "Customer served.")
	assert_eq(String(captured[1]["message"]), "Money +$100.00.")
	assert_eq(String(captured[2]["message"]), "Delivery checked.")
	assert_eq(String(captured[3]["message"]), "Shelf stocked.")


func test_zero_money_delta_does_not_reach_player_feed() -> void:
	var captured: Array = []
	var sink := func(tag: String, message: String) -> void:
		captured.append({"tag": tag, "message": message})
	EventBus.event_logged.connect(sink)
	EventBus.money_changed.emit(100.0, 100.0)
	EventBus.event_logged.disconnect(sink)
	var entries: Array[Dictionary] = EventLog.recent(8)
	assert_eq(captured.size(), 0, "zero-delta money changes must not add feed rows")
	assert_eq(entries.size(), 1, "zero-delta stats remain available to debug logs")


func test_empty_objective_label_does_not_reach_player_feed() -> void:
	var captured: Array = []
	var sink := func(tag: String, message: String) -> void:
		captured.append({"tag": tag, "message": message})
	EventBus.event_logged.connect(sink)
	EventBus.objective_completed.emit(&"empty_copy", "   ")
	EventBus.event_logged.disconnect(sink)
	var entries: Array[Dictionary] = EventLog.recent(8)
	assert_eq(captured.size(), 0, "blank objective copy must not add feed rows")
	assert_eq(entries.size(), 1, "blank-label objective entries remain debuggable")


func test_unknown_actions_do_not_reach_player_feed() -> void:
	var captured: Array = []
	var sink := func(tag: String, message: String) -> void:
		captured.append({"tag": tag, "message": message})
	EventBus.event_logged.connect(sink)
	EventLog._record("[SYSTEM]", "system", "res://debug/path", "filesystem_scan", {})
	EventBus.event_logged.disconnect(sink)
	var entries: Array[Dictionary] = EventLog.recent(8)
	assert_eq(captured.size(), 0, "unmapped action tokens must not reach the feed")
	assert_eq(entries.size(), 1, "unmapped actions remain in the debug timeline")
	assert_eq(entries[0].get("action"), "filesystem_scan")


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
