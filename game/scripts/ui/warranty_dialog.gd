## Modal dialog offering extended warranty add-on after a qualifying electronics sale.
class_name WarrantyDialog
extends CanvasLayer

const PANEL_NAME: String = "warranty"
const DEFAULT_WARRANTY_PERCENT: float = 0.20

signal warranty_accepted(item_id: String, warranty_fee: float)
signal warranty_declined

var _is_open: bool = false
var _item_id: String = ""
var _sale_price: float = 0.0
var _warranty_fee: float = 0.0
var _wholesale_cost: float = 0.0
var _anim_tween: Tween

@onready var _panel: PanelContainer = $PanelRoot
@onready var _title_label: Label = (
	$PanelRoot/Margin/VBox/TitleLabel
)
@onready var _item_name_label: Label = (
	$PanelRoot/Margin/VBox/InfoVBox/ItemNameLabel
)
@onready var _sale_price_label: Label = (
	$PanelRoot/Margin/VBox/InfoVBox/SalePriceLabel
)
@onready var _warranty_cost_label: Label = (
	$PanelRoot/Margin/VBox/InfoVBox/WarrantyCostLabel
)
@onready var _duration_label: Label = (
	$PanelRoot/Margin/VBox/InfoVBox/DurationLabel
)
@onready var _add_button: Button = (
	$PanelRoot/Margin/VBox/ButtonHBox/AddButton
)
@onready var _decline_button: Button = (
	$PanelRoot/Margin/VBox/ButtonHBox/DeclineButton
)


func _ready() -> void:
	_panel.visible = false
	_add_button.pressed.connect(_on_add_pressed)
	_decline_button.pressed.connect(_on_decline_pressed)


## Opens the warranty offer dialog for a sold item.
func open(
	item_id: String,
	item_name: String,
	sale_price: float,
	wholesale_cost: float,
	warranty_percent: float = DEFAULT_WARRANTY_PERCENT,
) -> void:
	if _is_open:
		return
	_item_id = item_id
	_sale_price = sale_price
	_wholesale_cost = wholesale_cost
	_warranty_fee = WarrantyManager.calculate_fee(
		sale_price, warranty_percent
	)
	_populate(item_name, sale_price)
	_is_open = true
	PanelAnimator.kill_tween(_anim_tween)
	_anim_tween = PanelAnimator.modal_open(_panel)
	EventBus.panel_opened.emit(PANEL_NAME)


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	_item_id = ""
	_sale_price = 0.0
	_warranty_fee = 0.0
	_wholesale_cost = 0.0
	PanelAnimator.kill_tween(_anim_tween)
	_anim_tween = PanelAnimator.modal_close(_panel)
	_anim_tween.finished.connect(
		func() -> void: EventBus.panel_closed.emit(PANEL_NAME),
		CONNECT_ONE_SHOT,
	)


func is_open() -> bool:
	return _is_open


func _populate(item_name: String, sale_price: float) -> void:
	_title_label.text = "Extended Warranty"
	_item_name_label.text = item_name
	_sale_price_label.text = "Sale Price: $%.2f" % sale_price
	_warranty_cost_label.text = (
		"Warranty Cost: $%.2f" % _warranty_fee
	)
	_duration_label.text = "Duration: %d days" % (
		WarrantyManager.WARRANTY_DURATION_DAYS
	)
	_add_button.text = "Add Warranty ($%.2f)" % _warranty_fee


func _on_add_pressed() -> void:
	if not _is_open:
		return
	var item_id: String = _item_id
	var fee: float = _warranty_fee
	close()
	warranty_accepted.emit(item_id, fee)


func _on_decline_pressed() -> void:
	if not _is_open:
		return
	close()
	warranty_declined.emit()
