## Section-restructure coverage for BetaDaySummaryPanel.
##
## After the 4-section restructure the panel splits Money, Store
## Performance, The Mark, and Reputation/Trust into discrete subtrees;
## adds a Review Inventory toggle that hides audit detail rows on Day 1;
## and ships Replay Day 1 + Main Menu buttons alongside Continue. These
## tests cover the structural invariants and the new signal surface.
extends GutTest


const BetaDaySummaryPanelScript: GDScript = preload(
	"res://game/scripts/beta/beta_day_summary_panel.gd"
)


var _focus: Node
var _queue: Node
var _panel: BetaDaySummaryPanel


func before_each() -> void:
	_focus = get_tree().root.get_node_or_null("InputFocus")
	_queue = get_tree().root.get_node_or_null("ModalQueue")
	assert_not_null(_focus, "InputFocus autoload required")
	assert_not_null(_queue, "ModalQueue autoload required")
	if _focus != null:
		_focus._reset_for_tests()
	if _queue != null:
		_queue._reset_for_tests()
	_panel = BetaDaySummaryPanelScript.new() as BetaDaySummaryPanel
	add_child_autofree(_panel)


func after_each() -> void:
	if is_instance_valid(_panel):
		_panel._reset_for_tests()
	if _queue != null and is_instance_valid(_queue):
		_queue._reset_for_tests()
	if _focus != null and is_instance_valid(_focus):
		_focus._reset_for_tests()


func _summary_payload(day: int = 1) -> Dictionary:
	return {
		"day": day,
		"cash": 0,
		"cash_delta": 0,
		"starting_cash": 0,
		"customers_helped": 0,
		"items_stocked": 0,
		"sales_completed": 0,
		"shelf_inventory_remaining": 0,
		"backroom_inventory_remaining": 0,
		"shift_note": "",
		"hidden_thread_note": "",
		"reputation_delta": 0,
	}


# ── Store Performance section rendering ────────────────────────────────────

func test_store_perf_renders_shelf_and_backroom_inventory() -> void:
	var payload: Dictionary = _summary_payload()
	payload["customers_helped"] = 2
	payload["items_stocked"] = 5
	payload["sales_completed"] = 1
	payload["shelf_inventory_remaining"] = 5
	payload["backroom_inventory_remaining"] = 0

	_panel.show_summary(payload)

	var shelf_label: Label = _panel.get("_shelf_inventory_label") as Label
	var backroom_label: Label = (
		_panel.get("_backroom_inventory_label") as Label
	)
	assert_not_null(shelf_label, "Panel must own _shelf_inventory_label")
	assert_not_null(backroom_label, "Panel must own _backroom_inventory_label")
	if shelf_label == null or backroom_label == null:
		return
	assert_true(
		shelf_label.text.contains("Shelf Inventory") and shelf_label.text.contains("5"),
		"Shelf row must render shelf_inventory_remaining; got: '%s'"
		% shelf_label.text
	)
	assert_true(
		backroom_label.text.contains("Back Room Inventory")
		and backroom_label.text.contains("0"),
		"Back room row must render backroom_inventory_remaining; got: '%s'"
		% backroom_label.text
	)


func test_store_perf_renders_pickup_only_state() -> void:
	# Player picked up the delivery but did not stock the shelf — back
	# room carries the delivery quantity, shelf is empty.
	var payload: Dictionary = _summary_payload()
	payload["shelf_inventory_remaining"] = 0
	payload["backroom_inventory_remaining"] = 5

	_panel.show_summary(payload)

	var shelf_label: Label = _panel.get("_shelf_inventory_label") as Label
	var backroom_label: Label = (
		_panel.get("_backroom_inventory_label") as Label
	)
	assert_true(shelf_label.text.contains("0"))
	assert_true(backroom_label.text.contains("5"))


# ── Day 1 audit expand ─────────────────────────────────────────────────────

func test_audit_details_hidden_by_default_on_day_one() -> void:
	_panel.show_summary(_summary_payload(1))

	var details: VBoxContainer = _panel.get("_audit_details") as VBoxContainer
	var button: Button = _panel.get("_review_inventory_button") as Button
	assert_not_null(details, "Panel must own _audit_details VBox")
	assert_not_null(button, "Panel must own _review_inventory_button")
	if details == null or button == null:
		return
	assert_false(
		details.visible,
		"Day 1 must start with audit details hidden behind the expand"
	)
	assert_true(button.visible, "Day 1 must show the Review Inventory button")
	assert_eq(
		button.text, "Review Inventory ▸",
		"Initial Day 1 button text must read 'Review Inventory ▸'"
	)


func test_review_inventory_press_toggles_audit_visibility() -> void:
	_panel.show_summary(_summary_payload(1))
	var details: VBoxContainer = _panel.get("_audit_details") as VBoxContainer
	var button: Button = _panel.get("_review_inventory_button") as Button
	if details == null or button == null:
		return

	_panel._on_review_inventory_pressed()

	assert_true(details.visible, "First press must expand the audit rows")
	assert_eq(
		button.text, "Hide Inventory ▴",
		"Expanded state must read 'Hide Inventory ▴'"
	)

	_panel._on_review_inventory_pressed()

	assert_false(details.visible, "Second press must collapse the rows")
	assert_eq(button.text, "Review Inventory ▸")


func test_day_two_shows_audit_details_without_expand_button() -> void:
	_panel.show_summary(_summary_payload(2))

	var details: VBoxContainer = _panel.get("_audit_details") as VBoxContainer
	var button: Button = _panel.get("_review_inventory_button") as Button
	if details == null or button == null:
		return
	assert_true(
		details.visible,
		"Day 2+ must show audit details by default — no introductory hide"
	)
	assert_false(
		button.visible,
		"Day 2+ must hide the Review Inventory expand button"
	)


# ── The Mark section ───────────────────────────────────────────────────────

func test_mark_section_note_autowraps() -> void:
	var note: Label = _panel.get("_note_label") as Label
	assert_not_null(note)
	if note == null:
		return
	assert_eq(
		note.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART,
		"The Mark body text must use autowrap so prose reads as a sentence, "
		+ "not a single overflowing line"
	)


func test_mark_section_renders_hidden_thread_note_when_present() -> void:
	var payload: Dictionary = _summary_payload()
	payload["hidden_thread_note"] = "You noticed something off in the store."

	_panel.show_summary(payload)

	var thread: Label = _panel.get("_hidden_thread_label") as Label
	assert_not_null(thread, "Panel must own _hidden_thread_label")
	if thread == null:
		return
	assert_true(thread.visible)
	assert_eq(thread.text, "You noticed something off in the store.")


func test_mark_section_hides_hidden_thread_label_when_empty() -> void:
	# An older payload without the hidden-thread key collapses the row so
	# the Mark section doesn't carry a phantom empty line.
	_panel.show_summary(_summary_payload())

	var thread: Label = _panel.get("_hidden_thread_label") as Label
	if thread == null:
		return
	assert_false(
		thread.visible,
		"Empty hidden_thread_note must hide the row, not leave a blank line"
	)


# ── Reputation section ─────────────────────────────────────────────────────

func test_reputation_section_uses_compact_text_no_progress_bars() -> void:
	# Defends the "compact text rows — no ProgressBar nodes for beta"
	# invariant. The panel walks itself looking for any ProgressBar and
	# fails if it finds one, since the production day-summary's bars are
	# intentionally absent from the beta surface.
	_panel.show_summary(_summary_payload())
	assert_false(
		_has_progress_bar_descendant(_panel),
		"Beta day summary must not contain any ProgressBar nodes"
	)


func _has_progress_bar_descendant(node: Node) -> bool:
	if node is ProgressBar:
		return true
	for child: Node in node.get_children():
		if _has_progress_bar_descendant(child):
			return true
	return false


# ── Continue / Finish button copy ──────────────────────────────────────────

func test_continue_button_reads_finish_shift_on_final_day() -> void:
	_panel.show_summary(_summary_payload(), true)
	var continue_button: Button = _panel.get("_continue_button") as Button
	assert_not_null(continue_button)
	if continue_button == null:
		return
	assert_eq(
		continue_button.text, "Finish shift",
		"Final-day copy must read 'Finish shift', not 'Continue to next day'"
	)


func test_continue_button_reads_continue_to_next_day_when_not_final() -> void:
	_panel.show_summary(_summary_payload(), false)
	var continue_button: Button = _panel.get("_continue_button") as Button
	if continue_button == null:
		return
	assert_eq(continue_button.text, "Continue to next day")


# ── Replay / Main Menu signal surface ──────────────────────────────────────

func test_replay_button_emits_replay_pressed_signal() -> void:
	_panel.show_summary(_summary_payload())
	var replay_button: Button = _panel.get("_replay_button") as Button
	assert_not_null(replay_button, "Panel must own a _replay_button")
	if replay_button == null:
		return
	watch_signals(_panel)

	replay_button.pressed.emit()

	assert_signal_emitted(_panel, "replay_pressed")


func test_main_menu_button_emits_main_menu_pressed_signal() -> void:
	_panel.show_summary(_summary_payload())
	var main_menu_button: Button = _panel.get("_main_menu_button") as Button
	assert_not_null(main_menu_button, "Panel must own a _main_menu_button")
	if main_menu_button == null:
		return
	watch_signals(_panel)

	main_menu_button.pressed.emit()

	assert_signal_emitted(_panel, "main_menu_pressed")


# ── Section header typography ──────────────────────────────────────────────

func test_section_headers_use_brand_header_color_and_size() -> void:
	# Pulls the four section headers out by walking the visible label tree
	# and verifies they share the warm-gold header color and the documented
	# 16–18px section size, so a theme tweak in BetaModalTheme propagates
	# uniformly and no header drifts to body color.
	_panel.show_summary(_summary_payload())
	var expected_titles: Array[String] = [
		"MONEY", "STORE PERFORMANCE", "THE MARK", "REPUTATION"
	]
	var found: Array[String] = []
	for label: Label in _collect_labels(_panel):
		if expected_titles.has(label.text):
			found.append(label.text)
			var color: Color = label.get_theme_color("font_color")
			assert_eq(
				color, BetaModalTheme.COLOR_TEXT_HEADER,
				"Section header '%s' must use COLOR_TEXT_HEADER" % label.text
			)
			var size: int = label.get_theme_font_size("font_size")
			assert_between(
				size, 16, 18,
				"Section header '%s' must render at 16–18px; got %d"
				% [label.text, size]
			)
	for title: String in expected_titles:
		assert_true(
			found.has(title),
			"Section '%s' header must be present in the panel tree" % title
		)


func _collect_labels(node: Node) -> Array[Label]:
	var out: Array[Label] = []
	for child: Node in node.get_children():
		if child is Label:
			out.append(child as Label)
		out.append_array(_collect_labels(child))
	return out
