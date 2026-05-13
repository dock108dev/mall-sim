class_name BetaDaySummaryPanel
extends ModalPanel

signal continue_pressed()
signal replay_pressed()
signal main_menu_pressed()

const _SECTION_HEADER_FONT_SIZE: int = 17
const _SECTION_SEPARATION: int = 18
const _AUDIT_TEXT_COLLAPSED: String = "Review Inventory ▸"
const _AUDIT_TEXT_EXPANDED: String = "Hide Inventory ▴"

var _title_label: Label
# Money section uses a RichTextLabel so the per-day cash block keeps its
# bolded headings (Starting Cash / Sales Today / Ending Cash) without
# pulling a theme font override per line.
var _metrics_label: RichTextLabel
var _customers_helped_label: Label
var _items_stocked_label: Label
var _sales_completed_label: Label
var _shelf_inventory_label: Label
var _backroom_inventory_label: Label
var _review_inventory_button: Button
var _audit_details: VBoxContainer
var _audit_shelf_label: Label
var _audit_backroom_label: Label
var _note_label: Label
var _hidden_thread_label: Label
var _reputation_label: Label
var _replay_button: Button
var _main_menu_button: Button
var _continue_button: Button


func _ready() -> void:
	layer = 81
	visible = false
	var blocker := ColorRect.new()
	blocker.color = BetaModalTheme.COLOR_BLOCKER
	blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(blocker)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(720, 660)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -360
	panel.offset_top = -330
	panel.offset_right = 360
	panel.offset_bottom = 330
	panel.add_theme_stylebox_override("panel", BetaModalTheme.make_panel_style())
	blocker.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", _SECTION_SEPARATION)
	panel.add_child(v)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 30)
	_title_label.add_theme_color_override(
		"font_color", BetaModalTheme.COLOR_TEXT_HEADER
	)
	v.add_child(_title_label)

	# ── Section A: MONEY ────────────────────────────────────────────────
	var money_section := _make_section(v, "MONEY")
	_metrics_label = RichTextLabel.new()
	_metrics_label.bbcode_enabled = true
	_metrics_label.fit_content = true
	_metrics_label.scroll_active = false
	_metrics_label.custom_minimum_size = Vector2(0, 90)
	_metrics_label.add_theme_color_override(
		"default_color", BetaModalTheme.COLOR_TEXT_PRIMARY
	)
	money_section.add_child(_metrics_label)

	# ── Section B: STORE PERFORMANCE ────────────────────────────────────
	var perf_section := _make_section(v, "STORE PERFORMANCE")
	_customers_helped_label = _make_body_label(perf_section)
	_items_stocked_label = _make_body_label(perf_section)
	_sales_completed_label = _make_body_label(perf_section)
	_shelf_inventory_label = _make_body_label(perf_section)
	_backroom_inventory_label = _make_body_label(perf_section)

	# Audit detail rows live inside the Store Performance section so the
	# expand keeps the rows near the metrics they elaborate on. Default
	# hidden on Day 1; the Review Inventory button below toggles visibility.
	_audit_details = VBoxContainer.new()
	_audit_details.add_theme_constant_override("separation", 4)
	_audit_details.visible = false
	perf_section.add_child(_audit_details)
	_audit_shelf_label = _make_body_label(_audit_details)
	_audit_shelf_label.add_theme_color_override(
		"font_color", BetaModalTheme.COLOR_TEXT_MUTED
	)
	_audit_backroom_label = _make_body_label(_audit_details)
	_audit_backroom_label.add_theme_color_override(
		"font_color", BetaModalTheme.COLOR_TEXT_MUTED
	)

	_review_inventory_button = Button.new()
	_review_inventory_button.text = _AUDIT_TEXT_COLLAPSED
	_review_inventory_button.custom_minimum_size = Vector2(0, 32)
	BetaModalTheme.apply_button_theme(_review_inventory_button)
	_review_inventory_button.pressed.connect(_on_review_inventory_pressed)
	perf_section.add_child(_review_inventory_button)

	# ── Section C: THE MARK ─────────────────────────────────────────────
	var mark_section := _make_section(v, "THE MARK")
	_note_label = Label.new()
	_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note_label.add_theme_color_override(
		"font_color", BetaModalTheme.COLOR_TEXT_PRIMARY
	)
	mark_section.add_child(_note_label)

	_hidden_thread_label = Label.new()
	_hidden_thread_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hidden_thread_label.add_theme_color_override(
		"font_color", BetaModalTheme.COLOR_TEXT_MUTED
	)
	mark_section.add_child(_hidden_thread_label)

	# ── Section D: REPUTATION ───────────────────────────────────────────
	var reputation_section := _make_section(v, "REPUTATION")
	_reputation_label = _make_body_label(reputation_section)

	# ── Button row ──────────────────────────────────────────────────────
	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 12)
	v.add_child(button_row)

	_replay_button = Button.new()
	_replay_button.text = "Replay Day 1"
	_replay_button.custom_minimum_size = Vector2(0, 48)
	_replay_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	BetaModalTheme.apply_button_theme(_replay_button)
	_replay_button.pressed.connect(_on_replay_pressed)
	button_row.add_child(_replay_button)

	_main_menu_button = Button.new()
	_main_menu_button.text = "Main Menu"
	_main_menu_button.custom_minimum_size = Vector2(0, 48)
	_main_menu_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	BetaModalTheme.apply_button_theme(_main_menu_button)
	_main_menu_button.pressed.connect(_on_main_menu_pressed)
	button_row.add_child(_main_menu_button)

	_continue_button = Button.new()
	_continue_button.text = "Continue to next day"
	_continue_button.custom_minimum_size = Vector2(0, 48)
	_continue_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	BetaModalTheme.apply_button_theme(_continue_button)
	_continue_button.pressed.connect(_on_continue_pressed)
	button_row.add_child(_continue_button)


# Adds a section to `parent` consisting of a header label and an inner
# VBoxContainer for body content. Returns the inner VBox so callers can
# append their section-specific labels into it.
func _make_section(parent: VBoxContainer, header_text: String) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)
	parent.add_child(section)

	var header := Label.new()
	header.text = header_text
	header.add_theme_font_size_override(
		"font_size", _SECTION_HEADER_FONT_SIZE
	)
	header.add_theme_color_override(
		"font_color", BetaModalTheme.COLOR_TEXT_HEADER
	)
	section.add_child(header)
	return section


func _make_body_label(parent: Container) -> Label:
	var label := Label.new()
	label.add_theme_color_override(
		"font_color", BetaModalTheme.COLOR_TEXT_PRIMARY
	)
	parent.add_child(label)
	return label


func show_summary(summary: Dictionary, is_final_day: bool = false) -> void:
	# Route through ModalQueue at DAY_SUMMARY priority so the summary opens
	# strictly after any higher-priority modal has closed. Payload-driven
	# setup runs in `_on_queued_open` so a deferred dispatch (queue busy
	# when `show_summary` is called) still renders the correct day's data.
	enqueue(
		ModalQueue.Priority.DAY_SUMMARY,
		{"summary": summary, "is_final_day": is_final_day},
	)


func _on_queued_open(payload: Dictionary) -> void:
	var summary: Dictionary = payload.get("summary", {}) as Dictionary
	var is_final_day: bool = bool(payload.get("is_final_day", false))
	var day: int = int(summary.get("day", 1))
	_title_label.text = "Day %d Summary" % day

	# Money — three lines: Starting Cash (carry-in), Sales Today (per-day
	# delta with explicit sign), Ending Cash (cumulative).
	var ending_cash: int = int(summary.get("cash", 0))
	var cash_delta: int = int(summary.get("cash_delta", 0))
	var starting_cash: int = int(
		summary.get("starting_cash", ending_cash - cash_delta)
	)
	var sales_today_str: String
	if cash_delta > 0:
		sales_today_str = "+$%d" % cash_delta
	elif cash_delta < 0:
		sales_today_str = "-$%d" % -cash_delta
	else:
		sales_today_str = "$0"
	# §F-S13 — `_metrics_label.bbcode_enabled = true`. The format template is
	# a hardcoded literal; the three bound values are an int, an
	# int-derived currency string, and an int. No content/save-derived
	# strings reach this sink. Future maintainers binding new fields here
	# must keep the binding integer-or-format-derived; for string fields
	# either render to `_note_label` (plain `Label`) instead, or escape
	# `[` → `[lb]` at the call site.
	_metrics_label.text = (
		"[b]Starting Cash:[/b] $%d\n"
		+ "[b]Sales Today:[/b] %s\n"
		+ "[b]Ending Cash:[/b] $%d"
	) % [starting_cash, sales_today_str, ending_cash]

	# Store Performance — visible volume / inventory rows. Shelf and
	# backroom remaining come from the controller (single source of truth);
	# omitted keys fall back to 0 so older callers still render the layout.
	_customers_helped_label.text = (
		"Customers Helped: %d" % int(summary.get("customers_helped", 0))
	)
	_items_stocked_label.text = (
		"Items Stocked: %d" % int(summary.get("items_stocked", 0))
	)
	_sales_completed_label.text = (
		"Sales Completed: %d" % int(summary.get("sales_completed", 0))
	)
	var shelf_remaining: int = int(
		summary.get("shelf_inventory_remaining", 0)
	)
	var backroom_remaining: int = int(
		summary.get("backroom_inventory_remaining", 0)
	)
	_shelf_inventory_label.text = "Shelf Inventory: %d" % shelf_remaining
	_backroom_inventory_label.text = (
		"Back Room Inventory: %d" % backroom_remaining
	)
	_audit_shelf_label.text = (
		"  • On-shelf count at close: %d" % shelf_remaining
	)
	_audit_backroom_label.text = (
		"  • Back room remaining at close: %d" % backroom_remaining
	)

	# Day 1 starts with audit fields collapsed behind the Review Inventory
	# button. Day 2+ has the audit rows shown by default and the toggle
	# button hidden — the player is past the introductory hand-holding.
	var is_day_one: bool = day <= 1
	_review_inventory_button.visible = is_day_one
	_audit_details.visible = not is_day_one
	if is_day_one:
		_review_inventory_button.text = _AUDIT_TEXT_COLLAPSED

	# The Mark — shift_note (grounded) preferred; hidden-thread note is the
	# muted second line so older payloads keep rendering and the ambient
	# hidden-thread reveal still has a slot when present.
	var shift_note: String = str(summary.get("shift_note", ""))
	_note_label.text = shift_note
	_note_label.visible = not shift_note.is_empty()
	var hidden_thread_note: String = str(
		summary.get("hidden_thread_note", "")
	)
	_hidden_thread_label.text = hidden_thread_note
	_hidden_thread_label.visible = not hidden_thread_note.is_empty()

	# Reputation — compact text row. Zero-delta days omit the row so the
	# section reads as "no change" rather than reporting "Reputation: +0".
	var reputation_delta: int = int(summary.get("reputation_delta", 0))
	if reputation_delta == 0:
		_reputation_label.text = ""
		_reputation_label.visible = false
	else:
		_reputation_label.text = "Reputation: %+d" % reputation_delta
		_reputation_label.visible = true

	if is_final_day:
		# Final-day copy must not read as "Continue" — there is no Day N+1
		# beyond the beta loop, and a forward-leaning verb here would
		# imply another shift is coming.
		_continue_button.text = "Finish shift"
	else:
		_continue_button.text = "Continue to next day"


func _on_review_inventory_pressed() -> void:
	# Toggle the audit detail rows in place. Handled entirely inside the
	# panel — the controller never sees the expand; it's a presentation
	# detail of the summary surface.
	var now_visible: bool = not _audit_details.visible
	_audit_details.visible = now_visible
	_review_inventory_button.text = (
		_AUDIT_TEXT_EXPANDED if now_visible else _AUDIT_TEXT_COLLAPSED
	)


func _on_continue_pressed() -> void:
	continue_pressed.emit()
	close()


func _on_replay_pressed() -> void:
	replay_pressed.emit()


func _on_main_menu_pressed() -> void:
	main_menu_pressed.emit()
