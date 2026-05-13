## Verifies that the four beta-day panels documented in the BRAINDUMP §1
## modal-discipline section route through ModalQueue at the expected
## priorities, dedup repeated requests, and serialize so only one panel is
## visible at a time.
##
## Panels covered:
##   - BetaDaySummaryPanel   → DAY_SUMMARY priority
##   - BetaDecisionCardPanel → DAY_SUMMARY priority
##   - BetaManagerNotePanel  → VIC_NOTE priority
##
## MorningNotePanel (the global autoload) is intentionally excluded — it
## overrides open()/close() to skip the CTX_MODAL push because clock-in and
## other PRE_OPEN interactions must stay reachable while it's up. Routing
## it through ModalQueue would break that contract; the override is a
## deliberate non-blocking design and the test below documents it.
extends GutTest


const BetaDaySummaryPanelScript: GDScript = preload(
	"res://game/scripts/beta/beta_day_summary_panel.gd"
)
const BetaDecisionCardPanelScript: GDScript = preload(
	"res://game/scripts/beta/beta_decision_card_panel.gd"
)
const BetaManagerNotePanelScript: GDScript = preload(
	"res://game/scripts/beta/beta_manager_note_panel.gd"
)


var _focus: Node
var _queue: Node


func before_each() -> void:
	_focus = get_tree().root.get_node_or_null("InputFocus")
	_queue = get_tree().root.get_node_or_null("ModalQueue")
	assert_not_null(_focus, "InputFocus autoload required")
	assert_not_null(_queue, "ModalQueue autoload required")
	if _focus != null:
		_focus._reset_for_tests()
	if _queue != null:
		_queue._reset_for_tests()
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)


func after_each() -> void:
	if _queue != null and is_instance_valid(_queue):
		_queue._reset_for_tests()
	if _focus != null and is_instance_valid(_focus):
		_focus._reset_for_tests()


func _summary_payload() -> Dictionary:
	return {
		"day": 1,
		"cash": 0,
		"customers_helped": 0,
		"items_stocked": 0,
		"sales_completed": 0,
		"shift_note": "",
	}


func _event_payload() -> Dictionary:
	return {
		"id": "test_event",
		"title": "Test event",
		"body": "A confused customer asks a question.",
		"choices": [
			{"id": "yes", "label": "Help them", "effects": {"cash": 10}},
			{"id": "no", "label": "Refuse", "effects": {"reputation": -1}},
		],
	}


# ── BetaDaySummaryPanel routing ──────────────────────────────────────────────

func test_summary_show_routes_through_queue_at_day_summary_priority() -> void:
	var panel: BetaDaySummaryPanel = (
		BetaDaySummaryPanelScript.new() as BetaDaySummaryPanel
	)
	add_child_autofree(panel)
	# Block the queue with a TOAST-priority sentinel so the summary's
	# enqueue must wait — proving the show_summary call was queued, not
	# directly opened.
	var sentinel: ModalPanel = ModalPanel.new()
	add_child_autofree(sentinel)
	_queue.request_open(sentinel, _queue.Priority.TOAST)
	assert_eq(_queue.active_panel(), sentinel)

	panel.show_summary(_summary_payload())

	# Higher-priority DAY_SUMMARY entry must overtake the TOAST-priority
	# sentinel in the pending queue.
	assert_eq(_queue.pending_count(), 1,
		"summary must enqueue while sentinel is active, not bypass the queue")
	assert_false(panel.visible,
		"summary must stay invisible until the queue dispatches it")

	sentinel.close()
	assert_eq(_queue.active_panel(), panel,
		"DAY_SUMMARY entry must dispatch when the sentinel closes")
	assert_true(panel.visible)
	panel.close()


func test_summary_payload_renders_in_on_queued_open() -> void:
	# The summary populates labels in `_on_queued_open` so a deferred
	# dispatch (queue busy at show_summary time) still renders the right
	# day's data when the panel finally opens.
	var panel: BetaDaySummaryPanel = (
		BetaDaySummaryPanelScript.new() as BetaDaySummaryPanel
	)
	add_child_autofree(panel)
	var payload: Dictionary = _summary_payload()
	payload["day"] = 3

	panel.show_summary(payload)

	assert_true(panel.visible, "queue should dispatch immediately when idle")
	var title: Label = panel.get("_title_label") as Label
	assert_not_null(title)
	if title != null:
		assert_eq(title.text, "Day 3 Summary",
			"_on_queued_open must render the payload day in the title label")
	panel.close()


func test_summary_repeated_show_dedups_at_queue_layer() -> void:
	var panel: BetaDaySummaryPanel = (
		BetaDaySummaryPanelScript.new() as BetaDaySummaryPanel
	)
	add_child_autofree(panel)
	var baseline_depth: int = _focus.depth()

	panel.show_summary(_summary_payload())
	panel.show_summary(_summary_payload())
	panel.show_summary(_summary_payload())

	assert_eq(_focus.depth(), baseline_depth + 1,
		"repeated show_summary calls must dedup — not stack CTX_MODAL frames")
	assert_eq(_queue.pending_count(), 0,
		"dedup must not re-enqueue an already-active panel")
	panel.close()


# ── BetaDecisionCardPanel routing ────────────────────────────────────────────

func test_decision_show_event_routes_through_queue() -> void:
	var panel: BetaDecisionCardPanel = (
		BetaDecisionCardPanelScript.new() as BetaDecisionCardPanel
	)
	add_child_autofree(panel)
	var sentinel: ModalPanel = ModalPanel.new()
	add_child_autofree(sentinel)
	_queue.request_open(sentinel, _queue.Priority.TOAST)

	panel.show_event(_event_payload())

	# DAY_SUMMARY priority on the decision card must overtake the
	# TOAST-priority sentinel and queue ahead of it.
	assert_eq(_queue.pending_count(), 1,
		"decision must enqueue while sentinel is active")
	assert_false(panel.visible)

	sentinel.close()
	assert_eq(_queue.active_panel(), panel)
	assert_true(panel.visible)
	panel.close()


func test_decision_payload_renders_choices_in_on_queued_open() -> void:
	var panel: BetaDecisionCardPanel = (
		BetaDecisionCardPanelScript.new() as BetaDecisionCardPanel
	)
	add_child_autofree(panel)

	panel.show_event(_event_payload())

	assert_true(panel.visible)
	var choices_box: VBoxContainer = panel.get("_choices_box") as VBoxContainer
	assert_not_null(choices_box)
	if choices_box != null:
		assert_eq(choices_box.get_child_count(), 2,
			"_on_queued_open must rebuild the choice buttons from the payload")
	panel.close()


# ── BetaManagerNotePanel routing ─────────────────────────────────────────────

func test_vic_note_show_routes_through_queue_at_vic_note_priority() -> void:
	var panel: BetaManagerNotePanel = (
		BetaManagerNotePanelScript.new() as BetaManagerNotePanel
	)
	add_child_autofree(panel)
	# Decision card at DAY_SUMMARY blocks the queue; the VIC_NOTE entry
	# must wait for it to close.
	var blocker: BetaDecisionCardPanel = (
		BetaDecisionCardPanelScript.new() as BetaDecisionCardPanel
	)
	add_child_autofree(blocker)
	blocker.show_event(_event_payload())
	assert_eq(_queue.active_panel(), blocker)

	panel.show_note("Shift starts at nine. Don't be late.")

	assert_eq(_queue.pending_count(), 1,
		"vic note must enqueue while a DAY_SUMMARY-priority panel is active")
	assert_false(panel.visible,
		"vic note must stay hidden until the higher-priority panel closes")

	blocker.close()
	assert_eq(_queue.active_panel(), panel)
	assert_true(panel.visible)
	panel.close()


func test_vic_note_payload_renders_body_in_on_queued_open() -> void:
	var panel: BetaManagerNotePanel = (
		BetaManagerNotePanelScript.new() as BetaManagerNotePanel
	)
	add_child_autofree(panel)
	var body: String = "Body text supplied at show_note time."

	panel.show_note(body)

	assert_true(panel.visible)
	var body_label: RichTextLabel = panel.get("_body_label") as RichTextLabel
	assert_not_null(body_label)
	if body_label != null:
		assert_eq(body_label.text, body,
			"_on_queued_open must render the payload body verbatim")
	panel.close()


# ── Cross-panel serialization ────────────────────────────────────────────────

func test_summary_then_vic_note_dispatch_in_priority_order() -> void:
	# Day-N → Day-(N+1) hand-off: the summary closes, which drains the
	# next entry — Vic's note for the new day. Only one panel is ever
	# visible during the hand-off.
	var summary: BetaDaySummaryPanel = (
		BetaDaySummaryPanelScript.new() as BetaDaySummaryPanel
	)
	var vic_note: BetaManagerNotePanel = (
		BetaManagerNotePanelScript.new() as BetaManagerNotePanel
	)
	add_child_autofree(summary)
	add_child_autofree(vic_note)

	summary.show_summary(_summary_payload())
	vic_note.show_note("Day 2 starts now.")

	assert_eq(_queue.active_panel(), summary,
		"DAY_SUMMARY must dispatch first")
	assert_true(summary.visible)
	assert_false(vic_note.visible,
		"VIC_NOTE must stay hidden behind active DAY_SUMMARY")

	summary.close()

	assert_eq(_queue.active_panel(), vic_note,
		"closing summary must drain the queue to the vic note")
	assert_true(vic_note.visible)
	assert_false(summary.visible)
	vic_note.close()


# ── MorningNotePanel exemption (regression guard) ────────────────────────────

func test_morning_note_panel_does_not_push_ctx_modal() -> void:
	# Documented exemption: MorningNotePanel overrides open()/close() to
	# skip the CTX_MODAL push so clock-in and other PRE_OPEN interactions
	# stay reachable while the note is up. Routing it through ModalQueue at
	# VIC_NOTE priority would re-introduce the focus push and break the
	# pre-open flow. The autoload in production never calls enqueue(); this
	# test guards against a future refactor that flips the contract.
	var panel: Node = get_tree().root.get_node_or_null("MorningNotePanel")
	assert_not_null(panel,
		"MorningNotePanel autoload required for the exemption guard")
	if panel == null:
		return
	var baseline_depth: int = _focus.depth()
	panel.call(
		"show_note",
		"day1",
		"Test body — clock-in must remain reachable.",
		"Day 1",
		false,
	)
	assert_eq(_focus.depth(), baseline_depth,
		"MorningNotePanel must NOT push CTX_MODAL — its non-blocking "
		+ "design is intentional and depended on by the pre-open flow")
	assert_false(_queue.is_busy(),
		"MorningNotePanel must not occupy ModalQueue — global note panel "
		+ "is exempt from the queue (BetaManagerNotePanel handles the "
		+ "VIC_NOTE slot in beta runs)")
	panel.call("dismiss")
