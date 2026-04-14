## Modal end-of-day summary panel showing revenue, expenses, wages, and net result.
class_name DaySummaryPanel
extends CanvasLayer


const ACKNOWLEDGE_DELAY: float = 1.0
const OVERLAY_FADE_DURATION: float = 0.2
const OVERLAY_TARGET_ALPHA: float = 0.6
const STAT_STAGGER_DELAY: float = 0.05
const NET_POSITIVE_COLOR := Color(0.2, 0.8, 0.2)
const NET_NEGATIVE_COLOR := Color(0.9, 0.2, 0.2)
const MILESTONE_COLOR := Color(1.0, 0.84, 0.0)
const REPUTATION_UP := "\u2191"
const REPUTATION_DOWN := "\u2193"
const REPUTATION_NEUTRAL := "\u2014"

var _anim_tween: Tween
var _overlay_tween: Tween
var _stagger_tween: Tween
var _delay_timer: SceneTreeTimer
var _current_day: int = 0
var _pending_report: PerformanceReport
var _wages_this_day: float = 0.0

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
@onready var _milestone_banner: Label = (
	$Panel/Margin/VBox/MilestoneBanner
)
@onready var _acknowledge_button: Button = (
	$Panel/Margin/VBox/AcknowledgeButton
)


func _ready() -> void:
	visible = false
	_overlay.visible = false
	_panel.visible = false
	_milestone_banner.visible = false
	_acknowledge_button.pressed.connect(_on_acknowledge_pressed)
	EventBus.day_ended.connect(_on_day_ended)
	EventBus.performance_report_ready.connect(
		_on_performance_report_ready
	)
	EventBus.staff_wages_paid.connect(_on_staff_wages_paid)


func _on_day_ended(day: int) -> void:
	_current_day = day
	_populate_and_show()


func _on_performance_report_ready(report: PerformanceReport) -> void:
	_pending_report = report
	if visible:
		_apply_report(report)


func _on_staff_wages_paid(total_amount: float) -> void:
	_wages_this_day = total_amount


func _populate_and_show() -> void:
	_title_label.text = "Day %d Summary" % _current_day

	if _pending_report:
		_apply_report(_pending_report)
	else:
		_revenue_label.text = "Revenue: $0.00"
		_expenses_label.text = "Expenses: $0.00"
		if _wages_this_day > 0.0:
			_wages_label.text = "Wages: -$%.2f" % _wages_this_day
			_wages_label.add_theme_color_override(
				"font_color", NET_NEGATIVE_COLOR
			)
		else:
			_wages_label.text = "Wages: $0.00"
		_net_label.text = "Net: $0.00"
		_set_net_color(0.0)
		_clear_reputation()
		_milestone_banner.visible = false

	_animate_open()
	_disable_acknowledge_temporarily()


func _apply_report(report: PerformanceReport) -> void:
	_revenue_label.text = "Revenue: $%.2f" % report.revenue
	_revenue_label.add_theme_color_override(
		"font_color", NET_POSITIVE_COLOR
	)
	_expenses_label.text = "Expenses: -$%.2f" % report.expenses
	_expenses_label.add_theme_color_override(
		"font_color", NET_NEGATIVE_COLOR
	)
	_wages_label.text = "Wages: -$%.2f" % _wages_this_day
	_wages_label.add_theme_color_override(
		"font_color", NET_NEGATIVE_COLOR
	)
	var net: float = report.profit
	if net > 0.0:
		_net_label.text = "Net: +$%.2f" % net
	elif net < 0.0:
		_net_label.text = "Net: -$%.2f" % absf(net)
	else:
		_net_label.text = "Net: $0.00"
	_set_net_color(net)
	_set_net_bold()
	_populate_reputation(report)
	_populate_milestone(report)


func _set_net_color(net: float) -> void:
	if net > 0.0:
		_net_label.add_theme_color_override(
			"font_color", NET_POSITIVE_COLOR
		)
	else:
		_net_label.add_theme_color_override(
			"font_color", NET_NEGATIVE_COLOR
		)


func _set_net_bold() -> void:
	_net_label.add_theme_font_size_override("font_size", 22)


func _populate_reputation(report: PerformanceReport) -> void:
	_clear_reputation()
	if not report.tier_changed:
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var sign_str: String = (
			REPUTATION_UP if report.reputation_delta > 0.0
			else REPUTATION_DOWN if report.reputation_delta < 0.0
			else REPUTATION_NEUTRAL
		)
		label.text = "Reputation: %s %.1f" % [
			sign_str, report.reputation_delta
		]
		_reputation_container.add_child(label)
		return
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var arrow: String = (
		REPUTATION_UP if report.reputation_delta >= 0.0
		else REPUTATION_DOWN
	)
	label.text = "Reputation: %s %s" % [arrow, report.new_tier_name]
	label.add_theme_color_override(
		"font_color", UIThemeConstants.get_positive_color()
		if report.reputation_delta >= 0.0
		else UIThemeConstants.get_negative_color()
	)
	_reputation_container.add_child(label)


func _populate_milestone(report: PerformanceReport) -> void:
	if report.milestones_unlocked.is_empty():
		_milestone_banner.visible = false
		return
	_milestone_banner.visible = true
	_milestone_banner.text = (
		"Milestone Unlocked: %s" % report.milestones_unlocked[0]
	)
	_milestone_banner.add_theme_color_override(
		"font_color", MILESTONE_COLOR
	)


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
	EventBus.day_acknowledged.emit()
	_close()


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
		_wages_this_day = 0.0
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


func _get_visible_stat_rows() -> Array[Control]:
	var rows: Array[Control] = []
	var candidates: Array[Control] = [
		_title_label, _revenue_label, _expenses_label,
		_wages_label, _net_label,
	]
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
