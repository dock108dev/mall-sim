## Verifies the 11 BRAINDUMP debug fields the AuditOverlay surfaces:
## Day, Time, Phase, Money, Customers, SoldToday, OnShelves, BackRoom,
## ActiveObjective, OpenModal, QueuedModals.
##
## These tests exercise the data-source wiring without spinning up a full
## GameWorld. The overlay must read OpenModal from `ModalQueue` (the
## single source of truth for active-modal state), and shelf/back-room
## counts must update off the beta count signals on EventBus.
extends GutTest


func before_each() -> void:
	DataLoaderSingleton.load_all()
	# Reset modal state so prior tests don't leak open panels into the
	# canonical-read assertions below. InputFocus pairs with ModalQueue —
	# panels push CTX_MODAL on dispatch and the reset must clear both.
	InputFocus._reset_for_tests()
	ModalQueue._reset_for_tests()


func after_each() -> void:
	InputFocus._reset_for_tests()
	ModalQueue._reset_for_tests()
	# Hide overlay if a test left it visible.
	if AuditOverlay.visible:
		AuditOverlay.toggle()


func test_braindump_labels_exist() -> void:
	# All 11 BRAINDUMP labels must be built so the panel can display them.
	assert_not_null(AuditOverlay._label_day, "Day label missing")
	assert_not_null(AuditOverlay._label_time, "Time label missing")
	assert_not_null(AuditOverlay._label_phase, "Phase label missing")
	assert_not_null(AuditOverlay._label_money, "Money label missing")
	assert_not_null(AuditOverlay._label_customers, "Customers label missing")
	assert_not_null(AuditOverlay._label_sold_today, "SoldToday label missing")
	assert_not_null(AuditOverlay._label_on_shelves, "OnShelves label missing")
	assert_not_null(AuditOverlay._label_back_room, "BackRoom label missing")
	assert_not_null(AuditOverlay._label_active_objective, "ActiveObjective label missing")
	assert_not_null(AuditOverlay._label_open_modal, "OpenModal label missing")
	assert_not_null(AuditOverlay._label_queued_modals, "QueuedModals label missing")


func test_day_field_reflects_beta_run_state() -> void:
	var prior_day: int = BetaRunState.day
	BetaRunState.day = 7
	AuditOverlay._refresh_braindump_fields("none", 0)
	assert_eq(
		AuditOverlay._label_day.text,
		"Day: 7",
		"Day field must mirror BetaRunState.day"
	)
	BetaRunState.day = prior_day


func test_shelf_count_signal_updates_label() -> void:
	EventBus.beta_shelf_count_changed.emit(4)
	AuditOverlay._refresh_braindump_fields("none", 0)
	assert_eq(
		AuditOverlay._label_on_shelves.text,
		"OnShelves: 4",
		"OnShelves field must reflect beta_shelf_count_changed signal"
	)


func test_back_room_count_signal_updates_label() -> void:
	EventBus.beta_backroom_count_changed.emit(3)
	AuditOverlay._refresh_braindump_fields("none", 0)
	assert_eq(
		AuditOverlay._label_back_room.text,
		"BackRoom: 3",
		"BackRoom field must reflect beta_backroom_count_changed signal"
	)


func test_open_modal_reads_from_modal_queue_canonical_source() -> void:
	# ModalQueue.active_panel() is the single source of truth for the
	# "OpenModal" field — the overlay must surface the queue's active panel
	# name without maintaining any shadow stack of its own.
	var panel := ModalPanel.new()
	panel.name = "TestPanel"
	add_child_autofree(panel)
	ModalQueue.request_open(panel, ModalQueue.Priority.TUTORIAL, {})

	AuditOverlay._refresh_braindump_fields(AuditOverlay._active_modal_name(), 0)
	assert_eq(
		AuditOverlay._label_open_modal.text,
		"OpenModal: TestPanel",
		"OpenModal must read from ModalQueue active panel"
	)

	# Close the panel so autofree's _exit_tree doesn't auto-pop an
	# unreleased CTX_MODAL frame (push_error noise in the test log).
	panel.close()


func test_open_modal_reports_none_when_idle() -> void:
	ModalQueue._reset_for_tests()
	AuditOverlay._refresh_braindump_fields(AuditOverlay._active_modal_name(), 0)
	assert_eq(
		AuditOverlay._label_open_modal.text,
		"OpenModal: none",
		"OpenModal must report 'none' when no modal is active"
	)


func test_queued_modals_count_reflects_modal_queue_pending() -> void:
	# Place an active panel + two queued panels of lower priority.
	var active := ModalPanel.new()
	active.name = "Active"
	add_child_autofree(active)
	ModalQueue.request_open(active, ModalQueue.Priority.DAY_SUMMARY, {})

	var pending_a := ModalPanel.new()
	pending_a.name = "PendingA"
	add_child_autofree(pending_a)
	ModalQueue.request_open(pending_a, ModalQueue.Priority.TOAST, {})

	var pending_b := ModalPanel.new()
	pending_b.name = "PendingB"
	add_child_autofree(pending_b)
	ModalQueue.request_open(pending_b, ModalQueue.Priority.TOAST, {})

	AuditOverlay._refresh_braindump_fields(
		AuditOverlay._active_modal_name(), ModalQueue.pending_count()
	)
	assert_eq(
		AuditOverlay._label_queued_modals.text,
		"QueuedModals: 2",
		"QueuedModals must mirror ModalQueue.pending_count()"
	)

	# Drain the active + queued panels through `close()` so each `_exit_tree`
	# on autofree finds an already-released CTX_MODAL frame.
	active.close()
	pending_a.close()
	pending_b.close()


func test_phase_name_covers_all_day_phases() -> void:
	# Spot-check the enum-to-name map so renaming a DayPhase value can't
	# silently drop a label to "UNKNOWN" without test failure.
	assert_eq(AuditOverlay._phase_name(TimeSystem.DayPhase.PRE_OPEN), "PRE_OPEN")
	assert_eq(AuditOverlay._phase_name(TimeSystem.DayPhase.MORNING_RAMP), "MORNING_RAMP")
	assert_eq(AuditOverlay._phase_name(TimeSystem.DayPhase.MIDDAY_RUSH), "MIDDAY_RUSH")
	assert_eq(AuditOverlay._phase_name(TimeSystem.DayPhase.AFTERNOON), "AFTERNOON")
	assert_eq(AuditOverlay._phase_name(TimeSystem.DayPhase.EVENING), "EVENING")
	assert_eq(AuditOverlay._phase_name(TimeSystem.DayPhase.LATE_EVENING), "LATE_EVENING")


func test_fields_degrade_gracefully_without_beta_controller() -> void:
	# Without a BetaDayOneController in the tree, customer/sales/objective
	# fields must show "—" instead of asserting or printing 0 (which would
	# mask the missing data source).
	AuditOverlay._refresh_braindump_fields("none", 0)
	assert_eq(AuditOverlay._label_customers.text, "Customers: —")
	assert_eq(AuditOverlay._label_sold_today.text, "SoldToday: —")
	assert_eq(AuditOverlay._label_active_objective.text, "ActiveObjective: —")


func test_money_field_falls_back_to_beta_run_state_cash() -> void:
	# Without an EconomySystem in the tree, Money must mirror BetaRunState.cash.
	var prior_cash: int = BetaRunState.cash
	BetaRunState.cash = 250
	AuditOverlay._refresh_braindump_fields("none", 0)
	assert_eq(
		AuditOverlay._label_money.text,
		"Money: $250",
		"Money field must fall back to BetaRunState.cash without EconomySystem"
	)
	BetaRunState.cash = prior_cash
