## Modal end-of-day summary panel showing revenue, expenses, wages, and net result.
class_name DaySummaryPanel
extends CanvasLayer

signal review_inventory_requested
signal dismissed

const ACKNOWLEDGE_DELAY: float = 1.0
const OVERLAY_FADE_DURATION: float = 0.2
const OVERLAY_TARGET_ALPHA: float = 0.6
const STAT_STAGGER_DELAY: float = 0.05
const NET_POSITIVE_COLOR := Color(0.2, 0.8, 0.2)
const NET_NEGATIVE_COLOR := Color(0.9, 0.2, 0.2)
const NET_ZERO_COLOR := Color(1.0, 1.0, 1.0)
const MILESTONE_COLOR := Color(1.0, 0.84, 0.0)
const RECORD_HIGH_FLASH_COLOR := Color(1.0, 0.84, 0.0)
const RECORD_LOW_FLASH_COLOR := Color(0.3, 0.6, 1.0)
const REPUTATION_UP := "\u2191"
const REPUTATION_DOWN := "\u2193"

var _anim_tween: Tween
var _overlay_tween: Tween
var _stagger_tween: Tween
var _delay_timer: SceneTreeTimer
var _current_day: int = 0
var _pending_report: PerformanceReport
## Optional panel opened directly when Review Inventory is pressed.
var inventory_panel: InventoryPanel = null
var _wages_this_day: float = 0.0
var _report_detail_labels: Array[Label] = []
var _record_high_rows: Array[Control] = []
var _record_low_rows: Array[Control] = []
var _pending_summary: Dictionary = {}
var _emit_day_acknowledged_on_close: bool = false

@onready var _overlay: ColorRect = $Overlay
@onready var _panel: PanelContainer = $Panel
@onready var _title_label: Label = $Panel/Margin/VBox/TitleLabel
@onready var _revenue_label: Label = $Panel/Margin/VBox/RevenueRow
@onready var _expenses_label: Label = $Panel/Margin/VBox/ExpensesRow
@onready var _wages_label: Label = $Panel/Margin/VBox/WagesRow
@onready var _net_label: Label = $Panel/Margin/VBox/NetRow
@onready var _reputation_container: VBoxContainer = (
	$Panel/Margin/VBox/ReputationContainer
)
@onready var _vbox: VBoxContainer = $Panel/Margin/VBox
@onready var _milestone_banner: Label = (
	$Panel/Margin/VBox/MilestoneBanner
)
@onready var _review_inventory_button: Button = (
	$Panel/Margin/VBox/ButtonRow/ReviewInventoryButton
)
@onready var _acknowledge_button: Button = (
	$Panel/Margin/VBox/ButtonRow/AcknowledgeButton
)

func _ready() -> void:
	visible = false
	_overlay.visible = false
	_panel.visible = false
	_milestone_banner.visible = false
	_create_report_detail_labels()
	_acknowledge_button.pressed.connect(_on_acknowledge_pressed)
	_review_inventory_button.pressed.connect(_on_review_inventory_pressed)
	EventBus.day_ended.connect(_on_day_ended)
	EventBus.performance_report_ready.connect(
		_on_performance_report_ready
	)
	EventBus.staff_wages_paid.connect(_on_staff_wages_paid)


## Populates the modal from an end-of-day summary dictionary and displays it.
func show_summary(summary: Dictionary) -> void:
	_pending_summary = summary.duplicate(true)
	_current_day = int(_pending_summary.get("day", _current_day))
	_apply_summary(_pending_summary)
	_animate_open()
	_disable_acknowledge_temporarily()


func _on_day_ended(day: int, summary: Dictionary = {}) -> void:
	_current_day = day
	if not summary.is_empty():
		show_summary(summary)
		return
	_populate_and_show()


func _on_performance_report_ready(report: PerformanceReport) -> void:
	_pending_report = report
	if visible:
		_apply_report(report)


func _on_staff_wages_paid(total_amount: float) -> void:
	_wages_this_day = total_amount


func _populate_and_show() -> void:
	if _pending_report:
		_apply_report(_pending_report)
	elif not _pending_summary.is_empty():
		_apply_summary(_pending_summary)
	else:
		_apply_summary({"day": _current_day})

	_animate_open()
	_disable_acknowledge_temporarily()


func _apply_report(report: PerformanceReport) -> void:
	var summary: Dictionary = report.to_dict()
	summary["net_profit"] = report.profit
	summary["staff_wages"] = _wages_this_day
	_apply_summary(summary)


func _apply_summary(summary: Dictionary) -> void:
	_current_day = int(summary.get("day", _current_day))
	var revenue: float = _get_summary_float(
		summary, ["revenue", "total_revenue"], 0.0
	)
	var expenses: float = _get_summary_float(
		summary, ["expenses", "total_expenses"], 0.0
	)
	var wages: float = _get_summary_float(
		summary, ["staff_wages", "wages_paid"], _wages_this_day
	)
	var net: float = _get_summary_float(summary, ["net_profit"], 0.0)

	_title_label.text = "Day %d Complete" % _current_day
	_revenue_label.text = "Revenue: $%.2f" % revenue
	_revenue_label.add_theme_color_override(
		"font_color", NET_POSITIVE_COLOR
	)
	_expenses_label.text = "Expenses: -$%.2f" % expenses
	_expenses_label.add_theme_color_override(
		"font_color", NET_NEGATIVE_COLOR
	)
	_wages_label.text = "Wages: -$%.2f" % wages
	_wages_label.add_theme_color_override(
		"font_color", NET_NEGATIVE_COLOR
	)
	_set_net_display(net)
	_set_net_color(net)
	_set_net_bold()
	var record_flags: Dictionary = _get_summary_dictionary(
		summary, "record_flags"
	)
	_capture_record_rows(record_flags)
	_populate_report_details(summary)
	_populate_reputation(summary)
	_populate_milestones(summary)


func _get_summary_float(
	summary: Dictionary, keys: Array[String], default_value: float
) -> float:
	for key: String in keys:
		if summary.has(key):
			return float(summary[key])
	return default_value


func _get_summary_int(
	summary: Dictionary, keys: Array[String], default_value: int
) -> int:
	for key: String in keys:
		if summary.has(key):
			return int(summary[key])
	return default_value


func _get_summary_string(
	summary: Dictionary, keys: Array[String], default_value: String
) -> String:
	for key: String in keys:
		if summary.has(key):
			return str(summary[key])
	return default_value


func _get_summary_dictionary(summary: Dictionary, key: String) -> Dictionary:
	var value: Variant = summary.get(key, {})
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


func _get_summary_array(summary: Dictionary, keys: Array[String]) -> Array:
	for key: String in keys:
		var value: Variant = summary.get(key, [])
		if value is Array:
			return (value as Array).duplicate(true)
	return []


func _set_net_color(net: float) -> void:
	if net > 0.0:
		_net_label.add_theme_color_override(
			"font_color", NET_POSITIVE_COLOR
		)
	elif net < 0.0:
		_net_label.add_theme_color_override(
			"font_color", NET_NEGATIVE_COLOR
		)
	else:
		_net_label.add_theme_color_override(
			"font_color", NET_ZERO_COLOR
		)


func _set_net_display(net: float) -> void:
	if net > 0.0:
		_net_label.text = "NET PROFIT: +$%.2f" % net
	elif net < 0.0:
		_net_label.text = "NET LOSS: -$%.2f" % absf(net)
	else:
		_net_label.text = "NET PROFIT: $0.00"


func _set_net_bold() -> void:
	_net_label.add_theme_font_size_override("font_size", 22)


func _populate_reputation(summary: Dictionary) -> void:
	_clear_reputation()
	var rows: Array = _get_summary_array(
		summary, ["reputation_by_store", "reputation_deltas"]
	)
	if not rows.is_empty():
		for entry: Variant in rows:
			if entry is Dictionary:
				_add_reputation_row(entry as Dictionary)
		return

	var tier_changed: bool = bool(summary.get("tier_changed", false))
	var reputation_delta: float = _get_summary_float(
		summary, ["reputation_delta"], 0.0
	)
	if not tier_changed:
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var sign_str: String = (
			REPUTATION_UP if reputation_delta > 0.0
			else REPUTATION_DOWN if reputation_delta < 0.0
			else "-"
		)
		label.text = "Reputation: %s %.1f" % [
			sign_str, reputation_delta
		]
		_reputation_container.add_child(label)
		return
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var arrow: String = (
		REPUTATION_UP if reputation_delta >= 0.0
		else REPUTATION_DOWN
	)
	var new_tier_name: String = _get_summary_string(
		summary, ["new_tier_name", "tier_name"], ""
	)
	label.text = "Reputation: %s %s" % [arrow, new_tier_name]
	label.add_theme_color_override(
		"font_color", UIThemeConstants.get_positive_color()
		if reputation_delta >= 0.0
		else UIThemeConstants.get_negative_color()
	)
	_reputation_container.add_child(label)
	PanelAnimator.pulse_scale(label, 1.08)


func _add_reputation_row(entry: Dictionary) -> void:
	var store_name: String = _get_summary_string(
		entry, ["store_name", "store_id"], "Store"
	)
	var delta: float = _get_summary_float(entry, ["delta"], 0.0)
	var sign_str: String = "+" if delta >= 0.0 else ""
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text = "%s Reputation: %s%.1f" % [store_name, sign_str, delta]
	_reputation_container.add_child(label)
	if bool(entry.get("tier_changed", false)):
		var banner := Label.new()
		banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		banner.text = "%s Tier: %s" % [
			store_name, str(entry.get("new_tier_name", "Changed"))
		]
		banner.add_theme_color_override("font_color", MILESTONE_COLOR)
		_reputation_container.add_child(banner)
		PanelAnimator.pulse_scale(banner, 1.08)


func _create_report_detail_labels() -> void:
	var insert_index: int = _reputation_container.get_index()
	for i: int in range(10):
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.visible = false
		_vbox.add_child(label)
		_vbox.move_child(label, insert_index + i)
		_report_detail_labels.append(label)


func _populate_report_details(summary: Dictionary) -> void:
	var top_item_name: String = _get_top_item_name(summary)
	var top_item_quantity: int = _get_top_item_quantity(summary)
	var details: Array[String] = [
		"Items Sold: %d" % _get_summary_int(
			summary, ["items_sold", "total_items_sold"], 0
		),
		"Units Sold: %d" % _get_summary_int(
			summary, ["units_sold"], 0
		),
		"Customers Served: %d" % _get_summary_int(
			summary, ["customers_served"], 0
		),
		"Walkouts: %d" % _get_summary_int(summary, ["walkouts"], 0),
		"Satisfaction: %.0f%%" % (
			_get_summary_float(summary, ["satisfaction_rate"], 0.0)
			* 100.0
		),
		"Top Seller: %s" % (
			"%s (x%d)" % [top_item_name, top_item_quantity]
			if not top_item_name.is_empty()
			else "None"
		),
		"Haggling: %d won / %d lost" % [
			_get_summary_int(summary, ["haggle_wins"], 0),
			_get_summary_int(summary, ["haggle_losses"], 0),
		],
		"Late Fees: +$%.2f" % _get_summary_float(
			summary, ["late_fee_income"], 0.0
		),
		"Warranty: +$%.2f / -$%.2f" % [
			_get_summary_float(summary, ["warranty_revenue"], 0.0),
			_get_summary_float(summary, ["warranty_claim_costs"], 0.0),
		],
		"Records: %s" % _format_record_flags(
			_get_summary_dictionary(summary, "record_flags")
		),
	]
	for i: int in range(_report_detail_labels.size()):
		var label: Label = _report_detail_labels[i]
		label.text = details[i]
		label.visible = true


func _get_top_item_name(summary: Dictionary) -> String:
	var bestseller: Variant = summary.get("bestseller", {})
	if bestseller is Dictionary:
		var entry: Dictionary = bestseller as Dictionary
		return _get_summary_string(entry, ["item_name", "name", "item_id"], "")
	return _get_summary_string(
		summary, ["top_item_sold", "bestseller_name", "bestseller_item"], ""
	)


func _get_top_item_quantity(summary: Dictionary) -> int:
	var bestseller: Variant = summary.get("bestseller", {})
	if bestseller is Dictionary:
		var entry: Dictionary = bestseller as Dictionary
		return _get_summary_int(entry, ["quantity", "count"], 0)
	return _get_summary_int(
		summary, ["top_item_quantity", "bestseller_quantity"], 0
	)


func _format_record_flags(flags: Dictionary) -> String:
	var records: Array[String] = []
	if bool(flags.get("best_day_revenue", false)):
		records.append("Best Revenue")
	if bool(flags.get("worst_day_revenue", false)):
		records.append("Worst Revenue")
	if records.is_empty():
		return "None"
	return ", ".join(records)


func _capture_record_rows(flags: Dictionary) -> void:
	_clear_record_rows()
	if bool(flags.get("best_day_revenue", false)):
		_record_high_rows.append(_revenue_label)
	if bool(flags.get("worst_day_revenue", false)):
		_record_low_rows.append(_revenue_label)


func _clear_record_rows() -> void:
	_record_high_rows.clear()
	_record_low_rows.clear()


func _flash_record_rows() -> void:
	for row: Control in _record_high_rows:
		PanelAnimator.flash_color(row, RECORD_HIGH_FLASH_COLOR)
	for row: Control in _record_low_rows:
		PanelAnimator.flash_color(row, RECORD_LOW_FLASH_COLOR)


func _populate_milestones(summary: Dictionary) -> void:
	var milestones: Array = _get_summary_array(
		summary, ["milestones_unlocked", "milestones"]
	)
	if milestones.is_empty():
		_milestone_banner.visible = false
		return
	_milestone_banner.visible = true
	_milestone_banner.text = (
		"Milestone Unlocked: %s" % str(milestones[0])
	)
	_milestone_banner.add_theme_color_override(
		"font_color", MILESTONE_COLOR
	)
	PanelAnimator.pulse_scale(_milestone_banner, 1.08)


func _clear_reputation() -> void:
	for child: Node in _reputation_container.get_children():
		child.queue_free()


func _disable_acknowledge_temporarily() -> void:
	_acknowledge_button.disabled = true
	_acknowledge_button.text = "..."
	_delay_timer = get_tree().create_timer(ACKNOWLEDGE_DELAY)
	_delay_timer.timeout.connect(_enable_acknowledge)


func _enable_acknowledge() -> void:
	_acknowledge_button.disabled = false
	_acknowledge_button.text = (
		"Begin Day %d" % (_current_day + 1)
	)


func _on_acknowledge_pressed() -> void:
	_emit_day_acknowledged_on_close = true
	EventBus.next_day_confirmed.emit()
	_close()


func _on_review_inventory_pressed() -> void:
	_close()
	if inventory_panel:
		inventory_panel.open()
	review_inventory_requested.emit()


func _close() -> void:
	_kill_all_tweens()
	_anim_tween = PanelAnimator.modal_close(_panel)
	_overlay_tween = _panel.create_tween()
	_overlay_tween.tween_property(
		_overlay, "color:a", 0.0, PanelAnimator.MODAL_DURATION
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_overlay_tween.tween_callback(func() -> void:
		visible = false
		_overlay.visible = false
		_pending_report = null
		_pending_summary.clear()
		_wages_this_day = 0.0
		dismissed.emit()
		if _emit_day_acknowledged_on_close:
			_emit_day_acknowledged_on_close = false
			EventBus.day_acknowledged.emit()
	)


func _animate_open() -> void:
	_kill_all_tweens()
	visible = true

	_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_overlay.visible = true
	_overlay_tween = _overlay.create_tween()
	_overlay_tween.tween_property(
		_overlay, "color:a", OVERLAY_TARGET_ALPHA,
		OVERLAY_FADE_DURATION,
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	_anim_tween = PanelAnimator.modal_open(_panel)

	var stat_rows: Array[Control] = _get_visible_stat_rows()
	_stagger_tween = PanelAnimator.stagger_fade_in(
		stat_rows, STAT_STAGGER_DELAY
	)
	if _stagger_tween:
		_stagger_tween.tween_callback(_flash_record_rows)


func _get_visible_stat_rows() -> Array[Control]:
	var rows: Array[Control] = []
	var candidates: Array[Control] = [
		_title_label, _revenue_label, _expenses_label,
		_net_label, _wages_label,
	]
	for label: Label in _report_detail_labels:
		candidates.append(label)
	for control: Control in candidates:
		if control.visible:
			rows.append(control)
	for child: Node in _reputation_container.get_children():
		if child is Control and child.visible:
			rows.append(child as Control)
	if _milestone_banner.visible:
		rows.append(_milestone_banner)
	return rows


func _kill_all_tweens() -> void:
	PanelAnimator.kill_tween(_anim_tween)
	PanelAnimator.kill_tween(_overlay_tween)
	PanelAnimator.kill_tween(_stagger_tween)
