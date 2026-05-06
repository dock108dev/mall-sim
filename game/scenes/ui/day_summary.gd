## Full-screen day summary overlay shown at end of each day. Rendered on the
## canonical MODAL band (UILayers.MODAL = 80) so it sits above the FP HUD,
## objective rail, and tutorial overlay. See docs/audits/phase0-ui-integrity.md.
class_name DaySummary
extends CanvasLayer


signal continue_pressed
signal dismissed
signal review_inventory_requested
signal mall_overview_requested
signal main_menu_requested

const OVERLAY_FADE_DURATION: float = 0.2
const OVERLAY_TARGET_ALPHA: float = 0.9
const PANEL_DELAY: float = 0.05
const STAT_STAGGER_DELAY: float = 0.05
const CONTINUE_FADE_DELAY: float = 0.2
const CONTINUE_FADE_DURATION: float = 0.15
const RECORD_PULSE_SCALE: float = 1.05
const HIDDEN_THREAD_DELAY: float = 1.8
const HIDDEN_THREAD_FADE_DURATION: float = 0.5
const HIDDEN_THREAD_COLOR: Color = Color(0.78, 0.72, 0.62, 0.85)
const TIER_CHANGE_COLOR := Color(1.0, 0.84, 0.0)
const SECONDARY_BUTTON_MODULATE := Color(1.0, 1.0, 1.0, 0.65)

## Per-archetype path subtext shown below ArchetypeLabel. Framed as a natural
## expansion (full Mallcore career path) rather than a paywall threat per
## BRAINDUMP §0.
const ARCHETYPE_SUBTEXT: Dictionary = {
	"The Mark": (
		"In the full Mallcore, your starting path would be: Fall Guy."
	),
	"The Warm Body": (
		"In the full Mallcore, your starting path would be: Sales Floor."
	),
	"The Floor Walker": (
		"In the full Mallcore, your starting path would be: Floor Lead."
	),
	"The Paper Trail": (
		"In the full Mallcore, your starting path would be: Assistant Manager."
	),
	"The Company Person": (
		"In the full Mallcore, your starting path would be: Regional Liaison."
	),
}

## Framed/fired ending copy shown when the player completes a shift without
## flagging anything Regional expected them to notice (BRAINDUMP §11).
const MARK_FIRED_NOTE: String = (
	"You completed the shift without flagging anything Regional expected you "
	+ "to notice. That makes you either harmless, unlucky, or useful to "
	+ "blame. Vic says not to come in tomorrow."
)

var _anim_tween: Tween
var _overlay_tween: Tween
var _stagger_tween: Tween
var _continue_tween: Tween
var _grading_label: Label
var _current_day: int = 0
var _discrepancy_label: Label
var _overdue_count_label: Label
var _story_beat_label: Label
var _forward_hook_label: Label
var _warranty_attach_label: Label
var _demo_status_label: Label
var _total_customers_label: Label
var _customer_breakdown_label: Label
var _record_high_revenue: float = 0.0
var _record_high_profit: float = 0.0
var _record_high_items: int = 0
var _record_high_labels: Array[Label] = []
var _record_low_labels: Array[Label] = []
var _store_revenue_labels: Array[Label] = []
var _last_net_profit: float = 0.0
var _last_summary_args: Dictionary = {}
var _emit_day_acknowledged_on_hide: bool = false
var _previous_day_revenue: float = -1.0
var _has_previous_day_revenue: bool = false
var _last_report: PerformanceReport = null
var _prev_report: PerformanceReport = null
var _focus_pushed: bool = false
var _hidden_thread_timer: Timer
var _hidden_thread_tween: Tween
var _auto_advance: DaySummaryAutoAdvance = null
var _pending_hidden_thread_text: String = ""
var _vic_comment_label: Label
var _pending_vic_comment: String = ""

@onready var _overlay: ColorRect = $Root/Overlay
@onready var _panel: PanelContainer = $Root/Panel
@onready var _day_label: Label = $Root/Panel/Margin/VBox/DayLabel
@onready var _revenue_label: Label = $Root/Panel/Margin/VBox/RevenueLabel
@onready var _rent_label: Label = $Root/Panel/Margin/VBox/RentLabel
@onready var _expenses_label: Label = $Root/Panel/Margin/VBox/ExpensesLabel
@onready var _profit_label: Label = $Root/Panel/Margin/VBox/ProfitLabel
@onready var _items_sold_label: Label = $Root/Panel/Margin/VBox/ItemsSoldLabel
@onready var _inventory_remaining_label: Label = $Root/Panel/Margin/VBox/InventoryRemainingLabel
@onready var _backroom_inventory_label: Label = $Root/Panel/Margin/VBox/BackroomInventoryLabel
@onready var _shelf_inventory_label: Label = $Root/Panel/Margin/VBox/ShelfInventoryLabel
@onready var _cash_balance_label: Label = $Root/Panel/Margin/VBox/CashBalanceLabel
@onready var _top_item_label: Label = $Root/Panel/Margin/VBox/TopItemLabel
@onready var _haggle_label: Label = $Root/Panel/Margin/VBox/HaggleLabel
@onready var _late_fee_label: Label = $Root/Panel/Margin/VBox/LateFeeLabel
@onready var _warranty_revenue_label: Label = $Root/Panel/Margin/VBox/WarrantyRevenueLabel
@onready var _warranty_claims_label: Label = $Root/Panel/Margin/VBox/WarrantyClaimsLabel
@onready var _customers_served_label: Label = $Root/Panel/Margin/VBox/CustomersServedLabel
@onready var _satisfaction_label: Label = $Root/Panel/Margin/VBox/SatisfactionLabel
@onready var _reputation_delta_label: Label = $Root/Panel/Margin/VBox/ReputationDeltaLabel
@onready var _tier_change_label: Label = $Root/Panel/Margin/VBox/TierChangeLabel
@onready var _staff_wages_label: Label = $Root/Panel/Margin/VBox/StaffWagesLabel
@onready var _seasonal_event_label: Label = $Root/Panel/Margin/VBox/SeasonalEventLabel
@onready var _employee_metrics_header: Label = $Root/Panel/Margin/VBox/EmployeeMetricsHeader
@onready var _customer_satisfaction_label: Label = $Root/Panel/Margin/VBox/CustomerSatisfactionLabel
@onready var _customer_satisfaction_bar: ProgressBar = (
	$Root/Panel/Margin/VBox/CustomerSatisfactionBar
)
@onready var _employee_trust_label: Label = $Root/Panel/Margin/VBox/EmployeeTrustLabel
@onready var _employee_trust_bar: ProgressBar = $Root/Panel/Margin/VBox/EmployeeTrustBar
@onready var _manager_trust_label: Label = $Root/Panel/Margin/VBox/ManagerTrustLabel
@onready var _manager_trust_bar: ProgressBar = $Root/Panel/Margin/VBox/ManagerTrustBar
@onready var _mistakes_label: Label = $Root/Panel/Margin/VBox/MistakesLabel
@onready var _inventory_variance_label: Label = $Root/Panel/Margin/VBox/InventoryVarianceLabel
@onready var _discrepancies_label: Label = $Root/Panel/Margin/VBox/DiscrepanciesLabel
@onready var _hidden_thread_separator: HSeparator = $Root/Panel/Margin/VBox/HiddenThreadSeparator
@onready var _hidden_thread_label: Label = $Root/Panel/Margin/VBox/HiddenThreadLabel
@onready var _archetype_separator: HSeparator = $Root/Panel/Margin/VBox/ArchetypeSeparator
@onready var _archetype_label: Label = $Root/Panel/Margin/VBox/ArchetypeLabel
@onready var _archetype_subtext_label: Label = $Root/Panel/Margin/VBox/ArchetypeSubtextLabel
@onready var _floor_awareness_row: HBoxContainer = $Root/Panel/Margin/VBox/FloorAwarenessRow
@onready var _floor_stars_label: Label = $Root/Panel/Margin/VBox/FloorAwarenessRow/FloorStarsLabel
@onready var _attention_separator: HSeparator = $Root/Panel/Margin/VBox/AttentionSeparator
@onready var _attention_notes_label: Label = $Root/Panel/Margin/VBox/AttentionNotesLabel
@onready var _auto_advance_bar: ProgressBar = $Root/Panel/Margin/VBox/AutoAdvanceBar
@onready var _auto_advance_label: Label = $Root/Panel/Margin/VBox/AutoAdvanceLabel
@onready var _button_row: HBoxContainer = $Root/Panel/Margin/VBox/ButtonRow
@onready var _review_inventory_button: Button = (
	$Root/Panel/Margin/VBox/ButtonRow/ReviewInventoryButton
)
@onready var _mall_overview_button: Button = $Root/Panel/Margin/VBox/ButtonRow/MallOverviewButton
@onready var _main_menu_button: Button = $Root/Panel/Margin/VBox/ButtonRow/MainMenuButton
@onready var _replay_button: Button = $Root/Panel/Margin/VBox/ButtonRow/ReplayButton
@onready var _continue_button: Button = $Root/Panel/Margin/VBox/ButtonRow/ContinueButton


func _ready() -> void:
	visible = false
	_overlay.visible = false
	_panel.visible = false
	_continue_button.pressed.connect(_on_continue_pressed)
	_review_inventory_button.pressed.connect(
		_on_review_inventory_pressed
	)
	_mall_overview_button.pressed.connect(_on_mall_overview_pressed)
	_main_menu_button.pressed.connect(_on_main_menu_pressed)
	_replay_button.pressed.connect(_on_replay_pressed)
	_create_discrepancy_label()
	_create_overdue_count_label()
	_create_narrative_labels()
	_create_electronics_labels()
	_create_customer_breakdown_labels()
	DaySummaryDisplay.apply_headline_order(
		_revenue_label, _top_item_label, _forward_hook_label
	)
	DaySummaryDisplay.apply_secondary_button_style(
		_review_inventory_button, _continue_button
	)
	_init_auto_advance_timers()
	_style_metric_bars()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.mouse_entered.connect(_on_panel_mouse_entered)
	_panel.mouse_exited.connect(_on_panel_mouse_exited)
	# Defaults so headless test paths render a defined state.
	_apply_employee_metrics_defaults()
	EventBus.performance_report_ready.connect(
		_on_performance_report_ready
	)
	EventBus.day_closed.connect(_on_day_closed_payload)
	EventBus.grading_day_summary.connect(_on_grading_day_summary)
	EventBus.manager_end_of_day_comment.connect(
		_on_manager_end_of_day_comment
	)


## Populates the summary with daily stats and shows the panel.
# gdlint:ignore=function-arguments-number
func show_summary(
	day: int,
	revenue: float,
	expenses: float,
	net_profit: float,
	items_sold: int,
	rent: float = 0.0,
	warranty_revenue: float = 0.0,
	warranty_claims: float = 0.0,
	seasonal_impact: String = "",
	discrepancy: float = 0.0,
	staff_wages: float = 0.0,
	archetype: String = "",
	floor_stars: int = 1,
	attention_notes: Array = [],
) -> void:
	if not _last_summary_args.is_empty():
		var prev_day: int = int(_last_summary_args.get("day", 0))
		if prev_day > 0 and prev_day != day:
			_previous_day_revenue = float(
				_last_summary_args.get("revenue", 0.0)
			)
			_has_previous_day_revenue = true
	_last_summary_args = {
		"day": day, "revenue": revenue, "expenses": expenses,
		"net_profit": net_profit, "items_sold": items_sold,
		"rent": rent, "warranty_revenue": warranty_revenue,
		"warranty_claims": warranty_claims,
		"seasonal_impact": seasonal_impact,
		"discrepancy": discrepancy, "staff_wages": staff_wages,
		"archetype": archetype, "floor_stars": floor_stars,
		"attention_notes": attention_notes,
	}
	_current_day = day
	_day_label.text = tr("DAY_SUMMARY_TITLE") % day
	_apply_revenue_headline(revenue)
	_rent_label.text = tr("DAY_SUMMARY_RENT") % rent
	_expenses_label.text = tr("DAY_SUMMARY_EXPENSES") % expenses
	_set_net_profit_display(net_profit)
	_items_sold_label.text = tr("DAY_SUMMARY_ITEMS_SOLD") % items_sold
	_set_warranty_display(warranty_revenue, warranty_claims)
	DaySummaryDisplay.set_seasonal_display(_seasonal_event_label, seasonal_impact)
	_set_discrepancy_display(discrepancy)
	DaySummaryDisplay.set_staff_wages_display(_staff_wages_label, staff_wages)
	_tier_change_label.visible = false
	_haggle_label.visible = false
	_late_fee_label.visible = false
	if _overdue_count_label:
		_overdue_count_label.visible = false
	if _grading_label:
		_grading_label.visible = false
	_apply_vic_comment_display()
	_apply_archetype_display(archetype)
	_apply_floor_stars_display(floor_stars)
	_apply_attention_notes_display(attention_notes)
	_apply_record_highlights(revenue, net_profit, items_sold)
	_push_modal_focus()
	_start_auto_advance(day)
	_animate_open()


## Re-shows the last day summary if available.
func show_last() -> void:
	if _last_summary_args.is_empty():
		return
	show_summary(
		_last_summary_args.get("day", 0),
		_last_summary_args.get("revenue", 0.0),
		_last_summary_args.get("expenses", 0.0),
		_last_summary_args.get("net_profit", 0.0),
		_last_summary_args.get("items_sold", 0),
		_last_summary_args.get("rent", 0.0),
		_last_summary_args.get("warranty_revenue", 0.0),
		_last_summary_args.get("warranty_claims", 0.0),
		_last_summary_args.get("seasonal_impact", ""),
		_last_summary_args.get("discrepancy", 0.0),
		_last_summary_args.get("staff_wages", 0.0),
		_last_summary_args.get("archetype", ""),
		_last_summary_args.get("floor_stars", 1),
		_last_summary_args.get("attention_notes", []),
	)


## Hides the summary panel and pops CTX_MODAL immediately so the FP cursor
## recapture fires before the close animation completes.
func hide_summary() -> void:
	_pop_modal_focus()
	_stop_auto_advance()
	if _hidden_thread_timer != null:
		_hidden_thread_timer.stop()
	_kill_all_tweens()
	_anim_tween = PanelAnimator.modal_close(_panel)
	_overlay_tween = _panel.create_tween()
	_overlay_tween.tween_property(
		_overlay, "color:a", 0.0, PanelAnimator.MODAL_DURATION
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_overlay_tween.tween_callback(func() -> void:
		_reset_animated_controls()
		visible = false
		_overlay.visible = false
		dismissed.emit()
		if _emit_day_acknowledged_on_hide:
			_emit_day_acknowledged_on_hide = false
			EventBus.day_acknowledged.emit()
	)


## Defensive cleanup so a summary removed mid-display does not strand a
## CTX_MODAL frame on InputFocus.
func _exit_tree() -> void:
	if _focus_pushed:
		_pop_modal_focus()


func _push_modal_focus() -> void:
	if _focus_pushed:
		return
	InputFocus.push_context(InputFocus.CTX_MODAL)
	_focus_pushed = true


func _pop_modal_focus() -> void:
	if not _focus_pushed:
		return
	# Defensive: if the topmost frame is no longer CTX_MODAL, a sibling pushed
	# without going through this contract. Surface it via push_error AND skip
	# the pop so we don't corrupt someone else's frame. Mirrors InventoryPanel
	# / CheckoutPanel.
	if InputFocus.current() != InputFocus.CTX_MODAL:
		push_error(
			(
				"DaySummary.hide_summary: expected CTX_MODAL on top, got %s — "
				+ "leaving stack untouched to avoid corrupting sibling frame"
			)
			% String(InputFocus.current())
		)
		_focus_pushed = false
		return
	InputFocus.pop_context()
	_focus_pushed = false


## Test seam — clears _focus_pushed without calling pop_context.
func _reset_for_tests() -> void:
	_focus_pushed = false


func _animate_open() -> void:
	_kill_all_tweens()
	visible = true
	_reset_animated_controls()

	_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_overlay.visible = true
	_overlay_tween = _overlay.create_tween()
	_overlay_tween.tween_property(
		_overlay, "color:a", OVERLAY_TARGET_ALPHA, OVERLAY_FADE_DURATION
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	_panel.visible = false
	_button_row.modulate = Color.TRANSPARENT

	_anim_tween = _panel.create_tween()
	_anim_tween.tween_interval(PANEL_DELAY)
	_anim_tween.tween_callback(_start_panel_open)


func _start_panel_open() -> void:
	_anim_tween = PanelAnimator.modal_open(_panel)
	_anim_tween.finished.connect(
		_on_panel_open_finished, CONNECT_ONE_SHOT
	)


func _on_panel_open_finished() -> void:
	var stat_rows: Array[Control] = _get_visible_stat_rows()
	_stagger_tween = PanelAnimator.stagger_fade_in(
		stat_rows, STAT_STAGGER_DELAY
	)
	if _stagger_tween:
		_stagger_tween.finished.connect(
			_on_stat_rows_finished, CONNECT_ONE_SHOT
		)
		return
	_on_stat_rows_finished()


func _get_visible_stat_rows() -> Array[Control]:
	var rows: Array[Control] = []
	for label: Control in _get_stat_row_candidates():
		if label.visible:
			rows.append(label)
	for store_label: Label in _store_revenue_labels:
		if is_instance_valid(store_label) and store_label.visible:
			rows.append(store_label)
	return rows


func _get_stat_row_candidates() -> Array[Control]:
	var stat_labels: Array[Control] = [
		_day_label, _revenue_label, _rent_label,
		_expenses_label, _profit_label, _items_sold_label,
		_inventory_remaining_label,
		_backroom_inventory_label, _shelf_inventory_label,
		_cash_balance_label,
		_top_item_label, _haggle_label, _late_fee_label,
		_customers_served_label, _satisfaction_label,
		_reputation_delta_label, _tier_change_label,
		_staff_wages_label,
		_warranty_revenue_label, _warranty_claims_label,
		_seasonal_event_label,
	]
	var optional: Array = [
		_discrepancy_label, _overdue_count_label, _warranty_attach_label,
		_demo_status_label, _grading_label, _story_beat_label,
		_forward_hook_label, _employee_metrics_header,
		_customer_satisfaction_label, _customer_satisfaction_bar,
		_employee_trust_label, _employee_trust_bar,
		_manager_trust_label, _manager_trust_bar,
		_mistakes_label, _inventory_variance_label, _discrepancies_label,
		_total_customers_label, _customer_breakdown_label,
		_vic_comment_label,
		_archetype_label, _archetype_subtext_label, _floor_awareness_row,
		_attention_notes_label,
	]
	for control: Control in optional:
		if control:
			stat_labels.append(control)
	return stat_labels


func _on_stat_rows_finished() -> void:
	_animate_record_labels()
	_continue_tween = _button_row.create_tween()
	_continue_tween.tween_interval(CONTINUE_FADE_DELAY)
	_continue_tween.tween_property(
		_button_row, "modulate", Color.WHITE, CONTINUE_FADE_DURATION
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _get_animated_controls() -> Array[Control]:
	var controls: Array[Control] = _get_stat_row_candidates()
	controls.append(_button_row)
	return controls


func _apply_record_highlights(
	revenue: float, net_profit: float, items_sold: int
) -> void:
	_reset_stat_colors()
	_record_high_labels.clear()
	_record_low_labels.clear()
	var is_record_revenue: bool = revenue > _record_high_revenue
	var is_record_profit: bool = net_profit > _record_high_profit
	var is_record_items: bool = items_sold > _record_high_items
	var is_record_low_profit: bool = (
		_current_day > 1 and net_profit < 0.0
	)
	if is_record_revenue and revenue > 0.0:
		_record_high_revenue = revenue
		_highlight_record_high(_revenue_label)
	if is_record_profit and net_profit > 0.0:
		_record_high_profit = net_profit
		_highlight_record_high(_profit_label)
	if is_record_items and items_sold > 0:
		_record_high_items = items_sold
		_highlight_record_high(_items_sold_label)
	if is_record_low_profit:
		_highlight_record_low(_profit_label)


func _highlight_record_high(label: Label) -> void:
	label.add_theme_color_override(
		"font_color", UIThemeConstants.get_positive_color()
	)
	_record_high_labels.append(label)


func _highlight_record_low(label: Label) -> void:
	label.add_theme_color_override(
		"font_color", UIThemeConstants.get_negative_color()
	)
	_record_low_labels.append(label)


func _animate_record_labels() -> void:
	for label: Label in _record_high_labels:
		PanelAnimator.pulse_scale(label, RECORD_PULSE_SCALE)


func _reset_stat_colors() -> void:
	var labels: Array[Label] = [
		_revenue_label, _profit_label, _items_sold_label,
	]
	for label: Label in labels:
		label.remove_theme_color_override("font_color")
	_apply_net_profit_color()


func _apply_net_profit_color() -> void:
	if _last_net_profit > 0.0:
		_profit_label.add_theme_color_override(
			"font_color", DaySummaryContent.NET_PROFIT_POSITIVE_COLOR
		)
	elif _last_net_profit < 0.0:
		_profit_label.add_theme_color_override(
			"font_color", DaySummaryContent.NET_PROFIT_NEGATIVE_COLOR
		)
	else:
		_profit_label.add_theme_color_override(
			"font_color", DaySummaryContent.NET_PROFIT_ZERO_COLOR
		)


func _build_customers_text(served: int) -> String:
	var base: String = "Customers Served: %d" % served
	if _prev_report == null:
		return base
	var delta: int = served - _prev_report.customers_served
	if delta > 0:
		return base + "  (+%d vs yesterday)" % delta
	if delta < 0:
		return base + "  (-%d vs yesterday)" % absi(delta)
	return base + "  (flat vs yesterday)"


func _apply_revenue_headline(revenue: float) -> void:
	DaySummaryContent.apply_revenue_headline(
		_revenue_label, revenue,
		_previous_day_revenue, _has_previous_day_revenue,
	)





func _kill_all_tweens() -> void:
	PanelAnimator.kill_tween(_anim_tween)
	PanelAnimator.kill_tween(_overlay_tween)
	PanelAnimator.kill_tween(_stagger_tween)
	PanelAnimator.kill_tween(_continue_tween)
	PanelAnimator.kill_tween(_hidden_thread_tween)
	for control: Control in _get_animated_controls():
		PanelAnimator.kill_control_tween(control)


func _reset_animated_controls() -> void:
	for control: Control in _get_animated_controls():
		control.modulate = Color.WHITE
		control.scale = Vector2.ONE


func _set_net_profit_display(net_profit: float) -> void:
	_last_net_profit = net_profit
	DaySummaryContent.set_net_profit(_profit_label, net_profit)
	DaySummaryDisplay.apply_profit_color(_profit_label, net_profit)





func _create_overdue_count_label() -> void:
	_overdue_count_label = DaySummaryLabels.create_overdue_count(
		$Root/Panel/Margin/VBox, _late_fee_label
	)











## Updates per-store revenue breakdown labels from the day_closed payload.
func _update_store_revenue_display(store_revenue: Dictionary) -> void:
	for label: Label in _store_revenue_labels:
		if is_instance_valid(label):
			label.queue_free()
	_store_revenue_labels.clear()
	if store_revenue.is_empty():
		return
	var vbox: VBoxContainer = $Root/Panel/Margin/VBox
	var insert_after: int = _revenue_label.get_index() + 1
	for store_id: String in store_revenue:
		var rev: float = store_revenue[store_id]
		if rev <= 0.0:
			continue
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.text = "  %s: $%.2f" % [store_id.capitalize(), rev]
		vbox.add_child(label)
		vbox.move_child(label, insert_after)
		insert_after += 1
		_store_revenue_labels.append(label)


## Receives the day_closed payload to refresh per-store revenue display
## and the end-of-day inventory total. Missing keys fall back to safe
## defaults so legacy/test payloads that omit fields render without crashing.
func _on_day_closed_payload(_day: int, summary: Dictionary) -> void:
	_update_store_revenue_display(summary.get("store_revenue", {}))
	var remaining: int = int(summary.get("inventory_remaining", 0))
	_inventory_remaining_label.text = (
		tr("DAY_SUMMARY_INVENTORY_REMAINING") % remaining
	)
	var backroom_remaining: int = int(
		summary.get("backroom_inventory_remaining", 0)
	)
	_backroom_inventory_label.text = (
		tr("DAY_SUMMARY_BACKROOM_INVENTORY") % backroom_remaining
	)
	var shelf_remaining: int = int(summary.get("shelf_inventory_remaining", 0))
	_shelf_inventory_label.text = (
		tr("DAY_SUMMARY_SHELF_INVENTORY") % shelf_remaining
	)
	if summary.has("customers_served"):
		var served: int = int(summary["customers_served"])
		_customers_served_label.text = _build_customers_text(served)
	var cash_balance: float = float(summary.get("net_cash", 0.0))
	_cash_balance_label.text = (
		tr("DAY_SUMMARY_CASH_BALANCE") % cash_balance
	)
	var shift_summary: Dictionary = summary.get("shift_summary", {})
	_set_customer_breakdown_display(shift_summary)


func _create_discrepancy_label() -> void:
	_discrepancy_label = DaySummaryLabels.create_discrepancy(
		$Root/Panel/Margin/VBox, _seasonal_event_label, _on_discrepancy_input
	)


func _set_discrepancy_display(discrepancy: float) -> void:
	DaySummaryContent.set_discrepancy(_discrepancy_label, discrepancy)


func _create_electronics_labels() -> void:
	var labels: Array = DaySummaryLabels.create_electronics(
		$Root/Panel/Margin/VBox
	)
	_warranty_attach_label = labels[0]
	_demo_status_label = labels[1]


func _create_customer_breakdown_labels() -> void:
	var labels: Array = DaySummaryLabels.create_customer_breakdown(
		$Root/Panel/Margin/VBox, _customers_served_label
	)
	_total_customers_label = labels[0]
	_customer_breakdown_label = labels[1]


## Populates the total-customers label and the per-reason breakdown from a
## shift_summary sub-dict carrying the customers_happy / customers_no_stock /
## customers_timeout / customers_price keys. Hides both labels when no
## customers were tracked so legacy/test payloads still render cleanly.
func _set_customer_breakdown_display(shift_summary: Dictionary) -> void:
	if _total_customers_label == null or _customer_breakdown_label == null:
		return
	var happy: int = int(shift_summary.get("customers_happy", 0))
	var no_stock: int = int(shift_summary.get("customers_no_stock", 0))
	var timeout: int = int(shift_summary.get("customers_timeout", 0))
	var price: int = int(shift_summary.get("customers_price", 0))
	var total: int = happy + no_stock + timeout + price
	if total <= 0:
		_total_customers_label.visible = false
		_customer_breakdown_label.visible = false
		return
	_total_customers_label.visible = true
	_total_customers_label.text = "Total Customers: %d" % total
	var lines: Array[String] = []
	if happy > 0:
		lines.append("  Happy (purchased): %d" % happy)
	if no_stock > 0:
		lines.append("  Walked — no stock: %d" % no_stock)
	if timeout > 0:
		lines.append("  Walked — out of patience: %d" % timeout)
	if price > 0:
		lines.append("  Walked — price too high: %d" % price)
	if lines.is_empty():
		_customer_breakdown_label.visible = false
		return
	_customer_breakdown_label.visible = true
	_customer_breakdown_label.text = "\n".join(lines)


func _create_grading_label() -> void:
	_grading_label = DaySummaryLabels.create_grading($Root/Panel/Margin/VBox)


func _set_grading_display(pending_count: int, returned: Array) -> void:
	DaySummaryContent.set_grading(_grading_label, pending_count, returned)


func _on_grading_day_summary(pending_count: int, returned: Array) -> void:
	_set_grading_display(pending_count, returned)


func _on_manager_end_of_day_comment(_id: String, body: String) -> void:
	_pending_vic_comment = body


func _apply_vic_comment_display() -> void:
	if _vic_comment_label == null:
		return
	if _pending_vic_comment.is_empty():
		_vic_comment_label.visible = false
		return
	_vic_comment_label.text = "— Vic: \"%s\"" % _pending_vic_comment
	_vic_comment_label.visible = true
	_pending_vic_comment = ""


func _create_narrative_labels() -> void:
	_create_grading_label()
	_vic_comment_label = DaySummaryLabels.create_vic_comment(
		$Root/Panel/Margin/VBox
	)
	var labels: Array = DaySummaryLabels.create_narrative(
		$Root/Panel/Margin/VBox
	)
	_story_beat_label = labels[0]
	_forward_hook_label = labels[1]


func _set_narrative_display(
	story_beat: String, forward_hook: String
) -> void:
	var has_beat: bool = not story_beat.is_empty()
	_story_beat_label.visible = has_beat
	if has_beat:
		_story_beat_label.text = story_beat

	var has_hook: bool = not forward_hook.is_empty()
	_forward_hook_label.visible = has_hook
	if has_hook:
		_forward_hook_label.text = "Tomorrow: %s" % forward_hook


func _on_discrepancy_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			EventBus.discrepancy_noticed.emit(_current_day)
			_discrepancy_label.text += tr("DAY_SUMMARY_NOTED")
			_discrepancy_label.mouse_filter = (
				Control.MOUSE_FILTER_IGNORE
			)


func _on_performance_report_ready(
	report: PerformanceReport
) -> void:
	if _last_report != null and report.day != _last_report.day:
		_prev_report = _last_report
	_last_report = report
	_set_net_profit_display(report.profit)
	_customers_served_label.text = _build_customers_text(
		report.customers_served
	)
	var sat_pct: float = report.satisfaction_rate * 100.0
	_satisfaction_label.text = "Satisfaction: %.0f%%" % sat_pct
	var sign_str: String = "+" if report.reputation_delta >= 0.0 else ""
	_reputation_delta_label.text = (
		"Reputation: %s%.1f" % [sign_str, report.reputation_delta]
	)
	var has_top_item: bool = not report.top_item_sold.is_empty()
	_top_item_label.visible = has_top_item
	if has_top_item:
		if report.top_item_price > 0.0:
			_top_item_label.text = (
				"Best Sale: %s — $%.2f"
				% [report.top_item_sold, report.top_item_price]
			)
		elif report.top_item_quantity > 0:
			_top_item_label.text = (
				"Top Seller: %s (x%d)"
				% [report.top_item_sold, report.top_item_quantity]
			)
		else:
			_top_item_label.text = (
				"Top Seller: %s" % report.top_item_sold
			)
	_set_narrative_display(report.story_beat, report.forward_hook)
	DaySummaryDisplay.set_haggle_display(_haggle_label, report.haggle_wins, report.haggle_losses)
	DaySummaryDisplay.set_late_fee_display(_late_fee_label, report.late_fee_income)
	DaySummaryDisplay.set_overdue_count_display(_overdue_count_label, report.overdue_items_count)
	DaySummaryDisplay.set_warranty_display(
		_warranty_revenue_label, _warranty_claims_label,
		report.warranty_revenue, report.warranty_claim_costs
	)
	_last_summary_args["demo_contribution_revenue"] = (
		report.demo_contribution_revenue
	)
	DaySummaryDisplay.set_warranty_attach_display(
		_warranty_attach_label, _demo_status_label,
		report.warranty_attach_rate, report.electronics_demo_active,
		report.demo_contribution_revenue
	)
	if report.tier_changed:
		DaySummaryDisplay.set_tier_change_display(
			_tier_change_label, report.reputation_delta, report.new_tier_name
		)
		PanelAnimator.pulse_scale(_tier_change_label, 1.08)
	else:
		_tier_change_label.visible = false
	_apply_employee_metrics(report)


func _apply_attention_notes_display(notes: Array) -> void:
	DaySummaryDisplay.apply_attention_notes_display(
		_attention_separator, _attention_notes_label, notes
	)


func _on_continue_pressed() -> void:
	_emit_day_acknowledged_on_hide = true
	hide_summary()
	EventBus.next_day_confirmed.emit()
	continue_pressed.emit()


## Restarts Day 1 by routing through GameManager.start_new_game(), which
## resets session state and reloads the gameplay scene. This is the primary
## replay CTA in the single-day beta context.
func _on_replay_pressed() -> void:
	hide_summary()
	GameManager.start_new_game()


func _on_review_inventory_pressed() -> void:
	hide_summary()
	review_inventory_requested.emit()


## Advances the day and routes the player back to the mall overview.
## Mirrors `_on_continue_pressed` so wages/milestones/save/advance fire.
func _on_mall_overview_pressed() -> void:
	_emit_day_acknowledged_on_hide = true
	hide_summary()
	EventBus.next_day_confirmed.emit()
	mall_overview_requested.emit()


## Routes the player back to the main menu without advancing the day.
## Skips next_day_confirmed — wages/milestones/save must NOT fire on quit.
func _on_main_menu_pressed() -> void:
	hide_summary()
	main_menu_requested.emit()


func _init_auto_advance_timers() -> void:
	_auto_advance = DaySummaryAutoAdvance.new()
	_auto_advance.setup(self, _auto_advance_bar, _auto_advance_label)
	_auto_advance.triggered.connect(_on_continue_pressed)
	_hidden_thread_timer = Timer.new()
	_hidden_thread_timer.one_shot = true
	_hidden_thread_timer.wait_time = HIDDEN_THREAD_DELAY
	_hidden_thread_timer.timeout.connect(_on_hidden_thread_timeout)
	add_child(_hidden_thread_timer)


func _style_metric_bars() -> void:
	for bar: ProgressBar in [
		_customer_satisfaction_bar,
		_employee_trust_bar,
		_manager_trust_bar,
	]:
		DaySummaryMetrics.apply_bar_style(bar, 0.0)
	_auto_advance_bar.add_theme_color_override(
		"font_color", Color.TRANSPARENT
	)


func _apply_employee_metrics_defaults() -> void:
	DaySummaryMetrics.set_metric_bar(
		_customer_satisfaction_label,
		_customer_satisfaction_bar,
		"Customer Satisfaction",
		1.0,
	)
	DaySummaryMetrics.set_metric_bar(
		_employee_trust_label, _employee_trust_bar, "Employee Trust", 0.0
	)
	DaySummaryMetrics.set_metric_bar(
		_manager_trust_label, _manager_trust_bar, "Manager Trust", 0.0
	)
	_mistakes_label.text = "Mistakes: 0"
	_inventory_variance_label.text = "Inventory Variance: 0.0%"
	_discrepancies_label.text = "Discrepancies Flagged: 0"
	_hidden_thread_label.text = ""
	_hidden_thread_label.visible = false
	_hidden_thread_separator.visible = false
	_hidden_thread_label.add_theme_color_override(
		"font_color", HIDDEN_THREAD_COLOR
	)


func _apply_employee_metrics(report: PerformanceReport) -> void:
	DaySummaryMetrics.set_metric_bar(
		_customer_satisfaction_label,
		_customer_satisfaction_bar,
		"Customer Satisfaction",
		report.customer_satisfaction,
	)
	DaySummaryMetrics.set_metric_bar(
		_employee_trust_label,
		_employee_trust_bar,
		"Employee Trust",
		report.employee_trust,
	)
	DaySummaryMetrics.set_metric_bar(
		_manager_trust_label,
		_manager_trust_bar,
		"Manager Trust",
		report.manager_trust,
	)
	_mistakes_label.text = "Mistakes: %d" % report.mistakes_count
	_inventory_variance_label.text = (
		"Inventory Variance: %.1f%%"
		% (report.inventory_variance * 100.0)
	)
	_discrepancies_label.text = (
		"Discrepancies Flagged: %d" % report.discrepancies_flagged
	)
	_schedule_hidden_thread(report.hidden_thread_consequence_text)


## Routes the hidden-thread consequence text into the deferred reveal.
## Called by DayCycleController immediately after `show_summary` so the timer
## starts relative to when the panel was shown — keeping the "realize" moment
## aligned with the player's read of the rest of the summary.
func set_hidden_thread_text(text: String) -> void:
	_schedule_hidden_thread(text)


func _schedule_hidden_thread(text: String) -> void:
	_pending_hidden_thread_text = text
	PanelAnimator.kill_tween(_hidden_thread_tween)
	_hidden_thread_label.visible = false
	_hidden_thread_separator.visible = false
	_hidden_thread_label.modulate.a = 1.0
	if _hidden_thread_timer != null:
		_hidden_thread_timer.stop()
	if text.is_empty():
		return
	if _hidden_thread_timer != null:
		_hidden_thread_timer.start(HIDDEN_THREAD_DELAY)


func _on_hidden_thread_timeout() -> void:
	if _pending_hidden_thread_text.is_empty():
		return
	_hidden_thread_label.text = _pending_hidden_thread_text
	_hidden_thread_separator.visible = true
	_hidden_thread_label.modulate.a = 0.0
	_hidden_thread_label.visible = true
	PanelAnimator.kill_tween(_hidden_thread_tween)
	_hidden_thread_tween = _hidden_thread_label.create_tween()
	_hidden_thread_tween.tween_property(
		_hidden_thread_label, "modulate:a", 1.0, HIDDEN_THREAD_FADE_DURATION
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _start_auto_advance(day: int) -> void:
	if _auto_advance != null:
		_auto_advance.start(day)


func _on_panel_mouse_entered() -> void:
	if _auto_advance != null:
		_auto_advance.pause()


func _on_panel_mouse_exited() -> void:
	if _auto_advance != null:
		_auto_advance.resume()


func _stop_auto_advance() -> void:
	if _auto_advance != null:
		_auto_advance.stop()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not _continue_button.visible or _continue_button.disabled:
		return
	# `interact` is the in-store E key — accept it as the "advance to next day"
	# shortcut. Mouse / button presses still fire the standard handlers.
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_on_continue_pressed()
