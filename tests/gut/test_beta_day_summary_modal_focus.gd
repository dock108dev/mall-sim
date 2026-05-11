## BetaDaySummaryPanel inherits from ModalPanel and is the only authority for
## input focus during the close-day → summary flow. Verifies that show_summary
## pushes exactly one CTX_MODAL frame and that close round-trips depth back to
## the pre-modal baseline (the dual-system desync this consolidation fixes).
extends GutTest


const BetaDaySummaryPanelScript: GDScript = preload(
	"res://game/scripts/beta/beta_day_summary_panel.gd"
)


var _focus: Node
var _panel: BetaDaySummaryPanel


func before_each() -> void:
	_focus = get_tree().root.get_node_or_null("InputFocus")
	assert_not_null(_focus, "InputFocus autoload required")
	if _focus != null:
		_focus._reset_for_tests()
	_panel = BetaDaySummaryPanelScript.new() as BetaDaySummaryPanel
	add_child_autofree(_panel)


func after_each() -> void:
	if is_instance_valid(_panel):
		_panel._reset_for_tests()
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


func test_show_summary_pushes_ctx_modal_once() -> void:
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var baseline: int = _focus.depth()

	_panel.show_summary(_summary_payload())

	assert_eq(
		_focus.depth(), baseline + 1,
		"show_summary must push exactly one CTX_MODAL frame"
	)
	assert_eq(_focus.current(), InputFocus.CTX_MODAL)
	assert_true(_panel._focus_pushed)


func test_close_returns_focus_depth_to_baseline() -> void:
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var baseline: int = _focus.depth()
	_panel.show_summary(_summary_payload())

	_panel.close()

	assert_eq(
		_focus.depth(), baseline,
		"InputFocus.depth() must equal the pre-modal value after close — this is the desync fix's primary invariant"
	)
	assert_eq(_focus.current(), InputFocus.CTX_STORE_GAMEPLAY)
	assert_false(_panel._focus_pushed)


func test_continue_pressed_pops_ctx_modal() -> void:
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var baseline: int = _focus.depth()
	_panel.show_summary(_summary_payload())

	_panel._on_continue_pressed()

	assert_eq(
		_focus.depth(), baseline,
		"Continue button click must pop the CTX_MODAL frame"
	)
	assert_eq(_focus.current(), InputFocus.CTX_STORE_GAMEPLAY)


func test_repeated_show_summary_does_not_leak_frames() -> void:
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var baseline: int = _focus.depth()

	_panel.show_summary(_summary_payload())
	_panel.show_summary(_summary_payload())

	assert_eq(
		_focus.depth(), baseline + 1,
		"Repeated show_summary must not push duplicate frames (ModalPanel guard)"
	)


# ── Reputation line rendering ──────────────────────────────────────────────
# Per-day reputation delta surfaces only when the player's choices actually
# moved the needle. A zero-delta day shows nothing rather than 'Reputation:
# +0', which read as noise in playtest.

func test_reputation_line_omitted_when_delta_is_zero() -> void:
	var payload: Dictionary = _summary_payload()
	payload["reputation_delta"] = 0

	_panel.show_summary(payload)

	var label: RichTextLabel = _panel.get("_metrics_label") as RichTextLabel
	assert_not_null(label, "Panel must own a _metrics_label")
	if label == null:
		return
	assert_false(
		label.text.contains("Reputation"),
		"Zero-delta day must omit the Reputation line entirely; got: '%s'"
		% label.text
	)


func test_reputation_line_renders_positive_delta_with_plus_sign() -> void:
	var payload: Dictionary = _summary_payload()
	payload["reputation_delta"] = 2

	_panel.show_summary(payload)

	var label: RichTextLabel = _panel.get("_metrics_label") as RichTextLabel
	assert_not_null(label)
	if label == null:
		return
	assert_true(
		label.text.contains("Reputation:") and label.text.contains("+2"),
		"Positive delta must render as 'Reputation: +N'; got: '%s'" % label.text
	)


func test_reputation_line_renders_negative_delta() -> void:
	var payload: Dictionary = _summary_payload()
	payload["reputation_delta"] = -3

	_panel.show_summary(payload)

	var label: RichTextLabel = _panel.get("_metrics_label") as RichTextLabel
	assert_not_null(label)
	if label == null:
		return
	assert_true(
		label.text.contains("Reputation:") and label.text.contains("-3"),
		"Negative delta must render as 'Reputation: -N'; got: '%s'" % label.text
	)


# ── Narrative shift-note rendering ─────────────────────────────────────────
# A short flavor sentence sits between the metrics block and the Continue
# button so each day's summary lands as a story beat, not a receipt.

# ── Cash block rendering ───────────────────────────────────────────────────
# The summary breaks cash into three lines: Starting Cash (carry-in), Sales
# Today (per-day delta with sign), and Ending Cash (cumulative total). This
# replaces a single 'Cash:' line so a tutorial-day sale ($0 → $15) reads as
# a transaction rather than a mystery jump in a cumulative number.

func test_cash_block_renders_three_lines_with_positive_delta() -> void:
	var payload: Dictionary = _summary_payload()
	payload["cash"] = 15
	payload["cash_delta"] = 15
	payload["starting_cash"] = 0

	_panel.show_summary(payload)

	var label: RichTextLabel = _panel.get("_metrics_label") as RichTextLabel
	assert_not_null(label)
	if label == null:
		return
	assert_true(
		label.text.contains("Starting Cash:") and label.text.contains("$0"),
		"Starting Cash line must render the carry-in balance; got: '%s'" % label.text
	)
	assert_true(
		label.text.contains("Sales Today:") and label.text.contains("+$15"),
		"Sales Today must render positive delta with explicit + sign; got: '%s'"
		% label.text
	)
	assert_true(
		label.text.contains("Ending Cash:") and label.text.contains("$15"),
		"Ending Cash line must render cumulative total; got: '%s'" % label.text
	)
	assert_false(
		label.text.contains("[b]Cash:[/b]"),
		"Old single-line 'Cash:' label must be gone after the three-line refactor"
	)


func test_cash_block_renders_zero_delta_as_dollar_zero() -> void:
	var payload: Dictionary = _summary_payload()
	payload["cash"] = 0
	payload["cash_delta"] = 0
	payload["starting_cash"] = 0

	_panel.show_summary(payload)

	var label: RichTextLabel = _panel.get("_metrics_label") as RichTextLabel
	assert_not_null(label)
	if label == null:
		return
	assert_true(
		label.text.contains("Sales Today:") and label.text.contains("$0"),
		"Zero-delta day must still render Sales Today: $0 to ground the layout; got: '%s'"
		% label.text
	)


func test_cash_block_renders_negative_delta_with_minus_sign() -> void:
	var payload: Dictionary = _summary_payload()
	payload["cash"] = 5
	payload["cash_delta"] = -10
	payload["starting_cash"] = 15

	_panel.show_summary(payload)

	var label: RichTextLabel = _panel.get("_metrics_label") as RichTextLabel
	assert_not_null(label)
	if label == null:
		return
	assert_true(
		label.text.contains("Starting Cash:") and label.text.contains("$15"),
		"Starting Cash must reflect the carry-in; got: '%s'" % label.text
	)
	assert_true(
		label.text.contains("Sales Today:") and label.text.contains("-$10"),
		"Negative delta must render with explicit minus sign; got: '%s'" % label.text
	)
	assert_true(
		label.text.contains("Ending Cash:") and label.text.contains("$5"),
		"Ending Cash must reflect cumulative total; got: '%s'" % label.text
	)


func test_cash_block_derives_starting_cash_when_key_omitted() -> void:
	# Older callers may pass only 'cash' and 'cash_delta'. The panel must
	# derive starting_cash = cash - cash_delta so callers don't break.
	var payload: Dictionary = _summary_payload()
	payload["cash"] = 33
	payload["cash_delta"] = 18
	payload.erase("starting_cash")

	_panel.show_summary(payload)

	var label: RichTextLabel = _panel.get("_metrics_label") as RichTextLabel
	assert_not_null(label)
	if label == null:
		return
	assert_true(
		label.text.contains("Starting Cash:") and label.text.contains("$15"),
		"Panel must derive starting_cash = cash - cash_delta when key is missing; got: '%s'"
		% label.text
	)


func test_shift_note_renders_between_metrics_and_continue_button() -> void:
	var payload: Dictionary = _summary_payload()
	payload["shift_note"] = "The store still feels half-asleep, but the register works."

	_panel.show_summary(payload)

	var note: Label = _panel.get("_note_label") as Label
	assert_not_null(note, "Panel must own a _note_label between metrics and continue")
	if note == null:
		return
	assert_eq(
		note.text,
		"The store still feels half-asleep, but the register works.",
		"shift_note from the summary payload must render verbatim on the note label"
	)
