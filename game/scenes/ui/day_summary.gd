## Full-screen day summary overlay shown at end of each day.
## Rendered on its own CanvasLayer at layer=12 so it sits above
## tutorial_overlay (layer=10) and the hub/game_world UI (layer=5/10).
## See docs/audits/phase0-ui-integrity.md P1.4.
class_name DaySummary
extends CanvasLayer


signal continue_pressed
signal dismissed
signal review_inventory_requested

const OVERLAY_FADE_DURATION: float = 0.2
const OVERLAY_TARGET_ALPHA: float = 0.9
const PANEL_DELAY: float = 0.05
const STAT_STAGGER_DELAY: float = 0.05
const CONTINUE_FADE_DELAY: float = 0.2
const CONTINUE_FADE_DURATION: float = 0.15
const RECORD_PULSE_SCALE: float = 1.05
const TIER_CHANGE_COLOR := Color(1.0, 0.84, 0.0)
const NET_PROFIT_POSITIVE_COLOR := Color(0.2, 0.8, 0.2)
const NET_PROFIT_NEGATIVE_COLOR := Color(0.9, 0.2, 0.2)
const NET_PROFIT_ZERO_COLOR := Color(1.0, 1.0, 1.0)
const REVENUE_DELTA_POSITIVE_COLOR := Color(0.35, 0.85, 0.35)
const REVENUE_DELTA_NEGATIVE_COLOR := Color(0.9, 0.45, 0.45)
const SECONDARY_BUTTON_MODULATE := Color(1.0, 1.0, 1.0, 0.65)

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

@onready var _overlay: ColorRect = $Root/Overlay
@onready var _panel: PanelContainer = $Root/Panel
@onready var _day_label: Label = $Root/Panel/Margin/VBox/DayLabel
@onready var _revenue_label: Label = $Root/Panel/Margin/VBox/RevenueLabel
@onready var _rent_label: Label = $Root/Panel/Margin/VBox/RentLabel
@onready var _expenses_label: Label = $Root/Panel/Margin/VBox/ExpensesLabel
@onready var _profit_label: Label = $Root/Panel/Margin/VBox/ProfitLabel
@onready var _items_sold_label: Label = $Root/Panel/Margin/VBox/ItemsSoldLabel
@onready var _top_item_label: Label = (
	$Root/Panel/Margin/VBox/TopItemLabel
)
@onready var _haggle_label: Label = $Root/Panel/Margin/VBox/HaggleLabel
@onready var _late_fee_label: Label = $Root/Panel/Margin/VBox/LateFeeLabel
@onready var _warranty_revenue_label: Label = (
	$Root/Panel/Margin/VBox/WarrantyRevenueLabel
)
@onready var _warranty_claims_label: Label = (
	$Root/Panel/Margin/VBox/WarrantyClaimsLabel
)
@onready var _customers_served_label: Label = (
	$Root/Panel/Margin/VBox/CustomersServedLabel
)
@onready var _satisfaction_label: Label = (
	$Root/Panel/Margin/VBox/SatisfactionLabel
)
@onready var _reputation_delta_label: Label = (
	$Root/Panel/Margin/VBox/ReputationDeltaLabel
)
@onready var _tier_change_label: Label = (
	$Root/Panel/Margin/VBox/TierChangeLabel
)
@onready var _staff_wages_label: Label = (
	$Root/Panel/Margin/VBox/StaffWagesLabel
)
@onready var _seasonal_event_label: Label = (
	$Root/Panel/Margin/VBox/SeasonalEventLabel
)
@onready var _button_row: HBoxContainer = (
	$Root/Panel/Margin/VBox/ButtonRow
)
@onready var _review_inventory_button: Button = (
	$Root/Panel/Margin/VBox/ButtonRow/ReviewInventoryButton
)
@onready var _continue_button: Button = (
	$Root/Panel/Margin/VBox/ButtonRow/ContinueButton
)


func _ready() -> void:
	visible = false
	_overlay.visible = false
	_panel.visible = false
	_continue_button.pressed.connect(_on_continue_pressed)
	_review_inventory_button.pressed.connect(
		_on_review_inventory_pressed
	)
	_create_discrepancy_label()
	_create_overdue_count_label()
	_create_narrative_labels()
	_create_electronics_labels()
	_apply_headline_order()
	_style_secondary_actions()
	EventBus.performance_report_ready.connect(
		_on_performance_report_ready
	)
	EventBus.day_closed.connect(_on_day_closed_payload)
	EventBus.grading_day_summary.connect(_on_grading_day_summary)


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
	}
	_current_day = day
	_day_label.text = tr("DAY_SUMMARY_TITLE") % day
	_apply_revenue_headline(revenue)
	_rent_label.text = tr("DAY_SUMMARY_RENT") % rent
	_expenses_label.text = tr("DAY_SUMMARY_EXPENSES") % expenses
	_set_net_profit_display(net_profit)
	_items_sold_label.text = tr("DAY_SUMMARY_ITEMS_SOLD") % items_sold
	_set_warranty_display(warranty_revenue, warranty_claims)
	_set_seasonal_display(seasonal_impact)
	_set_discrepancy_display(discrepancy)
	_set_staff_wages_display(staff_wages)
	_tier_change_label.visible = false
	_haggle_label.visible = false
	_late_fee_label.visible = false
	if _overdue_count_label:
		_overdue_count_label.visible = false
	if _grading_label:
		_grading_label.visible = false
	_apply_record_highlights(revenue, net_profit, items_sold)
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
	)


## Hides the summary panel with close animation.
func hide_summary() -> void:
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
		_top_item_label, _haggle_label, _late_fee_label,
		_customers_served_label, _satisfaction_label,
		_reputation_delta_label, _tier_change_label,
		_staff_wages_label,
		_warranty_revenue_label, _warranty_claims_label,
		_seasonal_event_label,
	]
	if _discrepancy_label:
		stat_labels.append(_discrepancy_label)
	if _overdue_count_label:
		stat_labels.append(_overdue_count_label)
	if _warranty_attach_label:
		stat_labels.append(_warranty_attach_label)
	if _demo_status_label:
		stat_labels.append(_demo_status_label)
	if _grading_label:
		stat_labels.append(_grading_label)
	if _story_beat_label:
		stat_labels.append(_story_beat_label)
	if _forward_hook_label:
		stat_labels.append(_forward_hook_label)
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
			"font_color", NET_PROFIT_POSITIVE_COLOR
		)
	elif _last_net_profit < 0.0:
		_profit_label.add_theme_color_override(
			"font_color", NET_PROFIT_NEGATIVE_COLOR
		)
	else:
		_profit_label.add_theme_color_override(
			"font_color", NET_PROFIT_ZERO_COLOR
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
	var base: String = tr("DAY_SUMMARY_REVENUE") % revenue
	if not _has_previous_day_revenue:
		_revenue_label.text = base
		_revenue_label.remove_theme_color_override("font_color")
		return
	var delta: float = revenue - _previous_day_revenue
	var delta_text: String
	var delta_color: Color
	if delta > 0.0:
		delta_text = "  (+$%.2f vs yesterday)" % delta
		delta_color = REVENUE_DELTA_POSITIVE_COLOR
	elif delta < 0.0:
		delta_text = "  (-$%.2f vs yesterday)" % absf(delta)
		delta_color = REVENUE_DELTA_NEGATIVE_COLOR
	else:
		delta_text = "  (flat vs yesterday)"
		delta_color = NET_PROFIT_ZERO_COLOR
	_revenue_label.text = base + delta_text
	_revenue_label.add_theme_color_override("font_color", delta_color)


## Hoist the top-seller and forward-hook rows above the detail dump
## so headline signals are visible without scrolling (ISSUE-012).
func _apply_headline_order() -> void:
	var vbox: VBoxContainer = $Root/Panel/Margin/VBox
	var anchor_index: int = _profit_label.get_index() + 1
	if is_instance_valid(_top_item_label):
		vbox.move_child(_top_item_label, anchor_index)
		anchor_index += 1
	if is_instance_valid(_forward_hook_label):
		vbox.move_child(_forward_hook_label, anchor_index)


## Visually de-emphasize the review-inventory action so the
## Continue CTA reads as the single primary action (ISSUE-012).
func _style_secondary_actions() -> void:
	_review_inventory_button.custom_minimum_size = Vector2(160, 36)
	_review_inventory_button.flat = true
	_review_inventory_button.modulate = SECONDARY_BUTTON_MODULATE
	_review_inventory_button.focus_mode = Control.FOCUS_NONE
	_continue_button.custom_minimum_size = Vector2(240, 56)


func _kill_all_tweens() -> void:
	PanelAnimator.kill_tween(_anim_tween)
	PanelAnimator.kill_tween(_overlay_tween)
	PanelAnimator.kill_tween(_stagger_tween)
	PanelAnimator.kill_tween(_continue_tween)
	for control: Control in _get_animated_controls():
		PanelAnimator.kill_control_tween(control)


func _reset_animated_controls() -> void:
	for control: Control in _get_animated_controls():
		control.modulate = Color.WHITE
		control.scale = Vector2.ONE


func _set_net_profit_display(net_profit: float) -> void:
	_last_net_profit = net_profit
	if net_profit > 0.0:
		_profit_label.text = "NET PROFIT: +$%.2f" % net_profit
		_profit_label.add_theme_color_override(
			"font_color", UIThemeConstants.get_positive_color()
		)
	elif net_profit < 0.0:
		_profit_label.text = "NET LOSS: -$%.2f" % absf(net_profit)
		_profit_label.add_theme_color_override(
			"font_color", NET_PROFIT_NEGATIVE_COLOR
		)
	else:
		_profit_label.text = "NET PROFIT: $0.00"
		_profit_label.add_theme_color_override(
			"font_color", NET_PROFIT_ZERO_COLOR
		)


func _set_warranty_display(
	warranty_revenue: float, warranty_claims: float
) -> void:
	var has_warranty_data: bool = (
		warranty_revenue > 0.0 or warranty_claims > 0.0
	)
	_warranty_revenue_label.visible = has_warranty_data
	_warranty_claims_label.visible = has_warranty_data
	if has_warranty_data:
		_warranty_revenue_label.text = (
			tr("DAY_SUMMARY_WARRANTY_REV") % warranty_revenue
		)
		_warranty_claims_label.text = (
			tr("DAY_SUMMARY_WARRANTY_CLAIMS") % warranty_claims
		)


func _set_seasonal_display(seasonal_impact: String) -> void:
	var has_seasonal: bool = not seasonal_impact.is_empty()
	_seasonal_event_label.visible = has_seasonal
	if has_seasonal:
		_seasonal_event_label.text = (
			tr("DAY_SUMMARY_SEASONAL") % seasonal_impact
		)


func _set_staff_wages_display(wages: float) -> void:
	var has_wages: bool = wages > 0.0
	_staff_wages_label.visible = has_wages
	if has_wages:
		_staff_wages_label.text = "Staff Wages: -$%.2f" % wages


func _set_late_fee_display(amount: float) -> void:
	var has_fees: bool = amount > 0.0
	_late_fee_label.visible = has_fees
	if has_fees:
		_late_fee_label.text = "Late Fees Collected: +$%.2f" % amount


func _create_overdue_count_label() -> void:
	_overdue_count_label = Label.new()
	_overdue_count_label.name = "OverdueCountLabel"
	_overdue_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overdue_count_label.visible = false
	var vbox: VBoxContainer = $Root/Panel/Margin/VBox
	vbox.add_child(_overdue_count_label)
	vbox.move_child(
		_overdue_count_label, _late_fee_label.get_index() + 1
	)


func _set_overdue_count_display(count: int) -> void:
	if not _overdue_count_label:
		return
	_overdue_count_label.visible = count > 0
	if count > 0:
		_overdue_count_label.text = "Overdue Rentals: %d" % count
		_overdue_count_label.add_theme_color_override(
			"font_color", Color(0.9, 0.7, 0.3)
		)


func _set_haggle_display(wins: int, losses: int) -> void:
	var total: int = wins + losses
	_haggle_label.visible = total > 0
	if total > 0:
		_haggle_label.text = (
			"Haggling: %d won / %d lost" % [wins, losses]
		)


func _set_tier_change_display(
	delta: float, tier_name: String
) -> void:
	if tier_name.is_empty():
		_tier_change_label.visible = false
		return
	_tier_change_label.visible = true
	var direction: String = "promoted" if delta > 0.0 else "demoted"
	_tier_change_label.text = (
		"Tier %s: %s!" % [direction, tier_name]
	)
	_tier_change_label.add_theme_color_override(
		"font_color", TIER_CHANGE_COLOR
	)
	PanelAnimator.pulse_scale(_tier_change_label, 1.08)


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


## Receives the day_closed payload to refresh per-store revenue display.
func _on_day_closed_payload(_day: int, summary: Dictionary) -> void:
	_update_store_revenue_display(
		summary.get("store_revenue", {})
	)


func _create_discrepancy_label() -> void:
	_discrepancy_label = Label.new()
	_discrepancy_label.name = "DiscrepancyLabel"
	_discrepancy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_discrepancy_label.visible = false
	_discrepancy_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_discrepancy_label.tooltip_text = tr("DAY_SUMMARY_CLICK_REPORT")
	_discrepancy_label.gui_input.connect(_on_discrepancy_input)
	var vbox: VBoxContainer = $Root/Panel/Margin/VBox
	var idx: int = _seasonal_event_label.get_index() + 1
	vbox.add_child(_discrepancy_label)
	vbox.move_child(_discrepancy_label, idx)


func _set_discrepancy_display(discrepancy: float) -> void:
	if not _discrepancy_label:
		return
	var has_discrepancy: bool = absf(discrepancy) > 0.001
	_discrepancy_label.visible = has_discrepancy
	if has_discrepancy:
		var sign_str: String = "+" if discrepancy > 0.0 else ""
		_discrepancy_label.text = (
			tr("DAY_SUMMARY_UNACCOUNTED") % [sign_str, discrepancy]
		)
		_discrepancy_label.add_theme_color_override(
			"font_color", Color(0.9, 0.7, 0.3)
		)


func _create_electronics_labels() -> void:
	var vbox: VBoxContainer = $Root/Panel/Margin/VBox
	_warranty_attach_label = Label.new()
	_warranty_attach_label.name = "WarrantyAttachLabel"
	_warranty_attach_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warranty_attach_label.visible = false
	vbox.add_child(_warranty_attach_label)

	_demo_status_label = Label.new()
	_demo_status_label.name = "DemoStatusLabel"
	_demo_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_demo_status_label.visible = false
	vbox.add_child(_demo_status_label)


func _set_warranty_attach_display(attach_rate: float, demo_active: bool) -> void:
	var has_attach: bool = attach_rate > 0.0
	_warranty_attach_label.visible = has_attach
	if has_attach:
		_warranty_attach_label.text = (
			"Warranty Attach Rate: %.0f%%" % (attach_rate * 100.0)
		)
	_demo_status_label.visible = true
	if demo_active:
		var contribution: float = float(
			_last_summary_args.get("demo_contribution_revenue", 0.0)
		)
		if contribution > 0.0:
			_demo_status_label.text = (
				"Demo Unit: Active — Contribution: +$%.2f" % contribution
			)
		else:
			_demo_status_label.text = "Demo Unit: Active"
		_demo_status_label.add_theme_color_override(
			"font_color", UIThemeConstants.get_positive_color()
		)
	else:
		_demo_status_label.text = "Demo Unit: Inactive"
		_demo_status_label.remove_theme_color_override("font_color")


func _create_grading_label() -> void:
	var vbox: VBoxContainer = $Root/Panel/Margin/VBox
	_grading_label = Label.new()
	_grading_label.name = "GradingLabel"
	_grading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_grading_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_grading_label.add_theme_color_override(
		"font_color", Color(0.78, 0.85, 0.60)
	)
	_grading_label.visible = false
	vbox.add_child(_grading_label)


func _set_grading_display(pending_count: int, returned: Array) -> void:
	var lines: Array[String] = []
	for entry: Variant in returned:
		if entry is Dictionary:
			var d: Dictionary = entry as Dictionary
			lines.append(
				"ACC Grade: %s — %d (%s)"
				% [
					str(d.get("card_name", d.get("card_id", "?"))),
					int(d.get("grade", 0)),
					str(d.get("grade_label", "")),
				]
			)
	if pending_count > 0:
		lines.append(
			"%d card%s pending ACC grading" % [
				pending_count,
				"s" if pending_count != 1 else "",
			]
		)
	if lines.is_empty():
		if _grading_label:
			_grading_label.visible = false
		return
	if _grading_label:
		_grading_label.text = "\n".join(lines)
		_grading_label.visible = true


func _on_grading_day_summary(pending_count: int, returned: Array) -> void:
	_set_grading_display(pending_count, returned)


func _create_narrative_labels() -> void:
	_create_grading_label()
	var vbox: VBoxContainer = $Root/Panel/Margin/VBox
	_story_beat_label = Label.new()
	_story_beat_label.name = "StoryBeatLabel"
	_story_beat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_story_beat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_story_beat_label.add_theme_color_override(
		"font_color", Color(0.85, 0.80, 0.70)
	)
	_story_beat_label.visible = false
	vbox.add_child(_story_beat_label)

	_forward_hook_label = Label.new()
	_forward_hook_label.name = "ForwardHookLabel"
	_forward_hook_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_forward_hook_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_forward_hook_label.add_theme_color_override(
		"font_color", Color(0.60, 0.80, 0.95)
	)
	_forward_hook_label.visible = false
	vbox.add_child(_forward_hook_label)


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
	_set_haggle_display(report.haggle_wins, report.haggle_losses)
	_set_late_fee_display(report.late_fee_income)
	_set_overdue_count_display(report.overdue_items_count)
	_set_warranty_display(
		report.warranty_revenue, report.warranty_claim_costs
	)
	_last_summary_args["demo_contribution_revenue"] = (
		report.demo_contribution_revenue
	)
	_set_warranty_attach_display(
		report.warranty_attach_rate, report.electronics_demo_active
	)
	if report.tier_changed:
		_set_tier_change_display(
			report.reputation_delta, report.new_tier_name
		)
	else:
		_tier_change_label.visible = false
	# Milestone completions are shown by the standalone `milestone_card`
	# slide-in notification — no longer rendered inside this summary (P1.5).


func _on_continue_pressed() -> void:
	_emit_day_acknowledged_on_hide = true
	hide_summary()
	EventBus.next_day_confirmed.emit()
	continue_pressed.emit()


func _on_review_inventory_pressed() -> void:
	hide_summary()
	review_inventory_requested.emit()
