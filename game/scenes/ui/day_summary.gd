## Full-screen day summary overlay shown at end of each day.
class_name DaySummary
extends PanelContainer


signal continue_pressed

var _anim_tween: Tween
var _current_day: int = 0
var _discrepancy_label: Label

@onready var _day_label: Label = $Margin/VBox/DayLabel
@onready var _revenue_label: Label = $Margin/VBox/RevenueLabel
@onready var _rent_label: Label = $Margin/VBox/RentLabel
@onready var _expenses_label: Label = $Margin/VBox/ExpensesLabel
@onready var _profit_label: Label = $Margin/VBox/ProfitLabel
@onready var _items_sold_label: Label = $Margin/VBox/ItemsSoldLabel
@onready var _warranty_revenue_label: Label = (
	$Margin/VBox/WarrantyRevenueLabel
)
@onready var _warranty_claims_label: Label = (
	$Margin/VBox/WarrantyClaimsLabel
)
@onready var _seasonal_event_label: Label = (
	$Margin/VBox/SeasonalEventLabel
)
@onready var _continue_button: Button = $Margin/VBox/ContinueButton


func _ready() -> void:
	visible = false
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
	_day_label.text = "Day %d Summary" % day
	_revenue_label.text = "Revenue: $%.2f" % revenue
	_rent_label.text = "Rent: -$%.2f" % rent
	_expenses_label.text = "Total Expenses: $%.2f" % expenses
	_profit_label.text = "Net Profit: $%.2f" % net_profit
	_items_sold_label.text = "Items Sold: %d" % items_sold
	_set_warranty_display(warranty_revenue, warranty_claims)
	_set_seasonal_display(seasonal_impact)
	_set_discrepancy_display(discrepancy)
	PanelAnimator.kill_tween(_anim_tween)
	_anim_tween = PanelAnimator.modal_open(self)


## Hides the summary panel.
func hide_summary() -> void:
	PanelAnimator.kill_tween(_anim_tween)
	_anim_tween = PanelAnimator.modal_close(self)


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
			"Warranty Revenue: $%.2f" % warranty_revenue
		)
		_warranty_claims_label.text = (
			"Warranty Claims: -$%.2f" % warranty_claims
		)


func _set_seasonal_display(seasonal_impact: String) -> void:
	var has_seasonal: bool = not seasonal_impact.is_empty()
	_seasonal_event_label.visible = has_seasonal
	if has_seasonal:
		_seasonal_event_label.text = (
			"Seasonal Events:\n%s" % seasonal_impact
		)


func _create_discrepancy_label() -> void:
	_discrepancy_label = Label.new()
	_discrepancy_label.name = "DiscrepancyLabel"
	_discrepancy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_discrepancy_label.visible = false
	_discrepancy_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_discrepancy_label.tooltip_text = "Click to report"
	_discrepancy_label.gui_input.connect(_on_discrepancy_input)
	var vbox: VBoxContainer = $Margin/VBox
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
			"Unaccounted: %s$%.2f" % [sign_str, discrepancy]
		)
		_discrepancy_label.add_theme_color_override(
			"font_color", Color(0.9, 0.7, 0.3)
		)


func _on_discrepancy_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			EventBus.discrepancy_noticed.emit(_current_day)
			_discrepancy_label.text += " [noted]"
			_discrepancy_label.mouse_filter = (
				Control.MOUSE_FILTER_IGNORE
			)


func _on_continue_pressed() -> void:
	hide_summary()
	continue_pressed.emit()
