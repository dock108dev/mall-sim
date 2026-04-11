## Full-screen day summary overlay shown at end of each day.
class_name DaySummary
extends Control


signal continue_pressed

const OVERLAY_FADE_DURATION: float = 0.2
const OVERLAY_TARGET_ALPHA: float = 0.6
const PANEL_DELAY: float = 0.05
const STAT_STAGGER_DELAY: float = 0.05
const CONTINUE_FADE_DELAY: float = 0.2
const RECORD_PULSE_SCALE: float = 1.05

var _anim_tween: Tween
var _overlay_tween: Tween
var _stagger_tween: Tween
var _current_day: int = 0
var _discrepancy_label: Label
var _record_high_revenue: float = 0.0
var _record_high_profit: float = 0.0
var _record_high_items: int = 0

@onready var _overlay: ColorRect = $Overlay
@onready var _panel: PanelContainer = $Panel
@onready var _day_label: Label = $Panel/Margin/VBox/DayLabel
@onready var _revenue_label: Label = $Panel/Margin/VBox/RevenueLabel
@onready var _rent_label: Label = $Panel/Margin/VBox/RentLabel
@onready var _expenses_label: Label = $Panel/Margin/VBox/ExpensesLabel
@onready var _profit_label: Label = $Panel/Margin/VBox/ProfitLabel
@onready var _items_sold_label: Label = $Panel/Margin/VBox/ItemsSoldLabel
@onready var _warranty_revenue_label: Label = (
	$Panel/Margin/VBox/WarrantyRevenueLabel
)
@onready var _warranty_claims_label: Label = (
	$Panel/Margin/VBox/WarrantyClaimsLabel
)
@onready var _seasonal_event_label: Label = (
	$Panel/Margin/VBox/SeasonalEventLabel
)
@onready var _continue_button: Button = $Panel/Margin/VBox/ContinueButton


func _ready() -> void:
	visible = false
	_overlay.visible = false
	_panel.visible = false
	_continue_button.pressed.connect(_on_continue_pressed)
	_create_discrepancy_label()


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
) -> void:
	_current_day = day
	_day_label.text = tr("DAY_SUMMARY_TITLE") % day
	_revenue_label.text = tr("DAY_SUMMARY_REVENUE") % revenue
	_rent_label.text = tr("DAY_SUMMARY_RENT") % rent
	_expenses_label.text = tr("DAY_SUMMARY_EXPENSES") % expenses
	_profit_label.text = tr("DAY_SUMMARY_PROFIT") % net_profit
	_items_sold_label.text = tr("DAY_SUMMARY_ITEMS_SOLD") % items_sold
	_set_warranty_display(warranty_revenue, warranty_claims)
	_set_seasonal_display(seasonal_impact)
	_set_discrepancy_display(discrepancy)
	_apply_record_highlights(revenue, net_profit, items_sold)
	_animate_open()


## Hides the summary panel with close animation.
func hide_summary() -> void:
	_kill_all_tweens()
	_anim_tween = PanelAnimator.modal_close(_panel)
	_overlay_tween = _panel.create_tween()
	_overlay_tween.tween_property(
		_overlay, "color:a", 0.0, PanelAnimator.MODAL_DURATION
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_overlay_tween.tween_callback(func() -> void:
		visible = false
		_overlay.visible = false
	)


func _animate_open() -> void:
	_kill_all_tweens()
	visible = true

	# Step 1: Fade in overlay
	_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_overlay.visible = true
	_overlay_tween = _overlay.create_tween()
	_overlay_tween.tween_property(
		_overlay, "color:a", OVERLAY_TARGET_ALPHA, OVERLAY_FADE_DURATION
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# Step 2: Panel modal open after short delay
	_panel.pivot_offset = _panel.size / 2.0
	_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_panel.scale = Vector2(
		PanelAnimator.MODAL_SCALE_START,
		PanelAnimator.MODAL_SCALE_START,
	)
	_panel.visible = true

	_anim_tween = _panel.create_tween()
	_anim_tween.tween_interval(PANEL_DELAY)
	_anim_tween.tween_property(
		_panel, "modulate", Color.WHITE, PanelAnimator.MODAL_DURATION
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_anim_tween.parallel().tween_property(
		_panel, "scale", Vector2.ONE, PanelAnimator.MODAL_DURATION
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# Step 3: Stagger stat rows after panel opens
	var stat_rows: Array[Control] = _get_visible_stat_rows()
	_continue_button.modulate = Color.TRANSPARENT
	_stagger_tween = PanelAnimator.stagger_fade_in(
		stat_rows, STAT_STAGGER_DELAY
	)

	# Step 4: Fade in continue button after stats
	if _stagger_tween:
		_stagger_tween.tween_interval(CONTINUE_FADE_DELAY)
		_stagger_tween.tween_property(
			_continue_button, "modulate", Color.WHITE, 0.15
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _get_visible_stat_rows() -> Array[Control]:
	var rows: Array[Control] = []
	var stat_labels: Array[Label] = [
		_day_label, _revenue_label, _rent_label,
		_expenses_label, _profit_label, _items_sold_label,
		_warranty_revenue_label, _warranty_claims_label,
		_seasonal_event_label,
	]
	if _discrepancy_label:
		stat_labels.append(_discrepancy_label)
	for label: Label in stat_labels:
		if label.visible:
			rows.append(label)
	return rows


func _apply_record_highlights(
	revenue: float, net_profit: float, items_sold: int
) -> void:
	_reset_stat_colors()
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
	PanelAnimator.pulse_scale(label, RECORD_PULSE_SCALE)


func _highlight_record_low(label: Label) -> void:
	label.add_theme_color_override(
		"font_color", UIThemeConstants.get_negative_color()
	)


func _reset_stat_colors() -> void:
	var labels: Array[Label] = [
		_revenue_label, _profit_label, _items_sold_label,
	]
	for label: Label in labels:
		label.remove_theme_color_override("font_color")


func _kill_all_tweens() -> void:
	PanelAnimator.kill_tween(_anim_tween)
	PanelAnimator.kill_tween(_overlay_tween)
	PanelAnimator.kill_tween(_stagger_tween)


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


func _on_continue_pressed() -> void:
	hide_summary()
	continue_pressed.emit()
