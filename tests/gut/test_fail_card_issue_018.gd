## ISSUE-018: Full-screen fail diagnostic card.
##
## We drive the FailCard autoload directly (the integration path from
## StoreDirector._fail is exercised separately by unit tests that hit the
## unknown-id path; here we focus on the card's own contract: visible,
## InputFocus pushed/popped, AuditLog emits SHOWN + DISMISSED).
extends GutTest


const STORE_ID: StringName = &"phantom_store"
const INV: StringName = &"content_instantiated"
const REASON: String = "StoreContent has zero children"


func before_each() -> void:
	InputFocus._reset_for_tests()
	AuditLog.clear()
	if FailCard.is_showing():
		FailCard.dismiss()


func after_each() -> void:
	if FailCard.is_showing():
		FailCard.dismiss()
	InputFocus._reset_for_tests()


func test_show_failure_makes_card_visible() -> void:
	assert_false(FailCard.is_showing(), "card starts hidden")
	FailCard.show_failure(STORE_ID, INV, REASON)
	assert_true(FailCard.is_showing(), "card visible after show_failure")


func test_show_failure_pushes_modal_focus_context() -> void:
	InputFocus.push_context(InputFocus.CTX_MALL_HUB)
	var depth_before: int = InputFocus.depth()

	FailCard.show_failure(STORE_ID, INV, REASON)

	assert_eq(
		InputFocus.current(),
		InputFocus.CTX_MODAL,
		"FailCard push makes CTX_MODAL topmost"
	)
	assert_eq(
		InputFocus.depth(),
		depth_before + 1,
		"FailCard pushed exactly one context"
	)

	FailCard.dismiss()

	assert_eq(
		InputFocus.current(),
		InputFocus.CTX_MALL_HUB,
		"dismiss pops back to prior context"
	)
	assert_eq(
		InputFocus.depth(),
		depth_before,
		"dismiss restores prior stack depth"
	)


func test_show_emits_fail_card_shown_audit_checkpoint() -> void:
	watch_signals(AuditLog)
	FailCard.show_failure(STORE_ID, INV, REASON)
	assert_signal_emitted(
		AuditLog, "checkpoint_failed",
		"FAIL_CARD_SHOWN is emitted as an AuditLog FAIL checkpoint"
	)
	var found_shown: bool = false
	for entry in AuditLog.recent(8):
		if (
			entry.get("status", "") == "FAIL"
			and entry.get("checkpoint", &"") == FailCard.CHECKPOINT_SHOWN
		):
			found_shown = true
			break
	assert_true(found_shown, "AuditLog recorded fail_card_shown checkpoint")


func test_dismiss_emits_fail_card_dismissed_audit_checkpoint() -> void:
	FailCard.show_failure(STORE_ID, INV, REASON)
	watch_signals(AuditLog)
	FailCard.dismiss()

	assert_signal_emitted(
		AuditLog, "checkpoint_passed",
		"FAIL_CARD_DISMISSED fires on dismiss"
	)
	var found_dismissed: bool = false
	for entry in AuditLog.recent(8):
		if (
			entry.get("status", "") == "PASS"
			and entry.get("checkpoint", &"") == FailCard.CHECKPOINT_DISMISSED
		):
			found_dismissed = true
			break
	assert_true(found_dismissed, "AuditLog recorded fail_card_dismissed checkpoint")


func test_card_shown_signal_carries_store_id_and_invariant() -> void:
	watch_signals(FailCard)
	FailCard.show_failure(STORE_ID, INV, REASON)
	assert_signal_emitted_with_parameters(
		FailCard, "card_shown", [STORE_ID, INV, REASON]
	)


func test_mall_gameplay_input_suppressed_while_card_visible() -> void:
	# Mall pushes its gameplay context, then FailCard raises. Consumers gate
	# on InputFocus.current() — the topmost context being CTX_MODAL (not
	# CTX_MALL_HUB) is what halts mall-hub input.
	InputFocus.push_context(InputFocus.CTX_MALL_HUB)
	FailCard.show_failure(STORE_ID, INV, REASON)
	assert_ne(
		InputFocus.current(),
		InputFocus.CTX_MALL_HUB,
		"mall hub is no longer the active input context"
	)
	assert_eq(
		InputFocus.current(),
		InputFocus.CTX_MODAL,
		"FailCard's modal context is on top, suppressing gameplay input"
	)
	FailCard.dismiss()
	assert_eq(
		InputFocus.current(),
		InputFocus.CTX_MALL_HUB,
		"mall hub input resumes after dismiss"
	)
