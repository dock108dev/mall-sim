## Full-screen day summary overlay shown at end of each day.
class_name DaySummary
extends Control


signal continue_pressed
signal dismissed
signal review_inventory_requested

const OVERLAY_FADE_DURATION: float = 0.2
const OVERLAY_TARGET_ALPHA: float = 0.6
const PANEL_DELAY: float = 0.05
const STAT_STAGGER_DELAY: float = 0.05
const CONTINUE_FADE_DELAY: float = 0.2
const CONTINUE_FADE_DURATION: float = 0.15
const RECORD_PULSE_SCALE: float = 1.05
const MILESTONE_BANNER_COLOR := Color(1.0, 0.84, 0.0)
const NET_PROFIT_POSITIVE_COLOR := Color(0.2, 0.8, 0.2)
const NET_PROFIT_NEGATIVE_COLOR := Color(0.9, 0.2, 0.2)
const NET_PROFIT_ZERO_COLOR := Color(1.0, 1.0, 1.0)

var _anim_tween: Tween
var _overlay_tween: Tween
var _stagger_tween: Tween
var _continue_tween: Tween
var _current_day: int = 0
var _discrepancy_label: Label
var _record_high_revenue: float = 0.0
var _record_high_profit: float = 0.0
var _record_high_items: int = 0
var _record_high_labels: Array[Label] = []
var _record_low_labels: Array[Label] = []
var _milestone_labels: Array[Label] = []
var _last_net_profit: float = 0.0
var _last_summary_args: Dictionary = {}
var _emit_day_acknowledged_on_hide: bool = false

@onready var _overlay: ColorRect = $Overlay
@onready var _panel: PanelContainer = $Panel
@onready var _day_label: Label = $Panel/Margin/VBox/DayLabel
@onready var _revenue_label: Label = $Panel/Margin/VBox/RevenueLabel
@onready var _rent_label: Label = $Panel/Margin/VBox/RentLabel
@onready var _expenses_label: Label = $Panel/Margin/VBox/ExpensesLabel
@onready var _profit_label: Label = $Panel/Margin/VBox/ProfitLabel
@onready var _items_sold_label: Label = $Panel/Margin/VBox/ItemsSoldLabel
@onready var _top_item_label: Label = (
	$Panel/Margin/VBox/TopItemLabel
)
@onready var _haggle_label: Label = $Panel/Margin/VBox/HaggleLabel
@onready var _late_fee_label: Label = $Panel/Margin/VBox/LateFeeLabel
@onready var _warranty_revenue_label: Label = (
	$Panel/Margin/VBox/WarrantyRevenueLabel
)
@onready var _warranty_claims_label: Label = (
	$Panel/Margin/VBox/WarrantyClaimsLabel
)
@onready var _customers_served_label: Label = (
	$Panel/Margin/VBox/CustomersServedLabel
)
@onready var _satisfaction_label: Label = (
	$Panel/Margin/VBox/SatisfactionLabel
)
@onready var _reputation_delta_label: Label = (
	$Panel/Margin/VBox/ReputationDeltaLabel
)
@onready var _tier_change_label: Label = (
	$Panel/Margin/VBox/TierChangeLabel
)
@onready var _staff_wages_label: Label = (
	$Panel/Margin/VBox/StaffWagesLabel
)
@onready var _seasonal_event_label: Label = (
	$Panel/Margin/VBox/SeasonalEventLabel
)
@onready var _milestone_container: VBoxContainer = (
	$Panel/Margin/VBox/MilestoneContainer
)
@onready var _button_row: HBoxContainer = (
	$Panel/Margin/VBox/ButtonRow
)
@onready var _review_inventory_button: Button = (
	$Panel/Margin/VBox/ButtonRow/ReviewInventoryButton
)
@onready var _continue_button: Button = (
	$Panel/Margin/VBox/ButtonRow/ContinueButton
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
	EventBus.performance_report_ready.connect(
		_on_performance_report_ready
	)


## Populates the summary with daily stats and shows the panel.
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
	_revenue_label.text = tr("DAY_SUMMARY_REVENUE") % revenue
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
	_clear_milestones()
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
	for child: Node in _milestone_container.get_children():
		if child is Label and child.visible:
			rows.append(child as Control)
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
	for child: Node in _milestone_container.get_children():
		if child is Label and child.visible:
			controls.append(child as Control)
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
		"font_color", MILESTONE_BANNER_COLOR
	)
	PanelAnimator.pulse_scale(_tier_change_label, 1.08)


func _set_milestone_display(
	milestones: Array[String],
) -> void:
	_clear_milestones()
	for milestone_name: String in milestones:
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.text = "Milestone: %s" % milestone_name
		label.add_theme_color_override(
			"font_color", MILESTONE_BANNER_COLOR
		)
		_milestone_container.add_child(label)
		_milestone_labels.append(label)


func _clear_milestones() -> void:
	for label: Label in _milestone_labels:
		if is_instance_valid(label):
			label.queue_free()
	_milestone_labels.clear()


func _create_discrepancy_label() -> void:
	_discrepancy_label = Label.new()
	_discrepancy_label.name = "DiscrepancyLabel"
	_discrepancy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_discrepancy_label.visible = false
	_discrepancy_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_discrepancy_label.tooltip_text = tr("DAY_SUMMARY_CLICK_REPORT")
	_discrepancy_label.gui_input.connect(_on_discrepancy_input)
	var vbox: VBoxContainer = $Panel/Margin/VBox
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
	_set_net_profit_display(report.profit)
	_customers_served_label.text = (
		"Customers Served: %d" % report.customers_served
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
		if report.top_item_quantity > 0:
			_top_item_label.text = (
				"Top Seller: %s (x%d)"
				% [report.top_item_sold, report.top_item_quantity]
			)
		else:
			_top_item_label.text = (
				"Top Seller: %s" % report.top_item_sold
			)
	_set_haggle_display(report.haggle_wins, report.haggle_losses)
	_set_late_fee_display(report.late_fee_income)
	_set_warranty_display(
		report.warranty_revenue, report.warranty_claim_costs
	)
	if report.tier_changed:
		_set_tier_change_display(
			report.reputation_delta, report.new_tier_name
		)
	else:
		_tier_change_label.visible = false
	_set_milestone_display(report.milestones_unlocked)


func _on_continue_pressed() -> void:
	_emit_day_acknowledged_on_hide = true
	hide_summary()
	EventBus.next_day_confirmed.emit()
	continue_pressed.emit()


func _on_review_inventory_pressed() -> void:
	hide_summary()
	review_inventory_requested.emit()
