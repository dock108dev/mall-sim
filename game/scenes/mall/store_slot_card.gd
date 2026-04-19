## Clickable store card for the mall overview hub.
## Shows store name, today's revenue, and an alert badge when stock is low
## or an event is pending. Emits store_selected on left-click.
class_name StoreSlotCard
extends PanelContainer

signal store_selected(store_id: StringName)

var _store_id: StringName = &""
var _low_stock: bool = false
var _event_pending: bool = false

@onready var _name_label: Label = $Margin/VBox/NameLabel
@onready var _revenue_label: Label = $Margin/VBox/RevenueLabel
@onready var _stock_label: Label = $Margin/VBox/StockLabel
@onready var _alert_badge: Label = $Margin/VBox/AlertBadge


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


## Populate the card with store identity; call once after instantiation.
func setup(store_id: StringName, display_name: String) -> void:
	_store_id = store_id
	_name_label.text = display_name
	_revenue_label.text = "$0"
	_stock_label.text = ""
	_alert_badge.visible = false


func update_revenue(amount: float) -> void:
	_revenue_label.text = "$%.0f" % amount


func update_stock(count: int) -> void:
	_stock_label.text = "%d items" % count
	_low_stock = count < 3
	_refresh_badge()


func set_event_pending(active: bool) -> void:
	_event_pending = active
	_refresh_badge()


func _refresh_badge() -> void:
	_alert_badge.visible = _low_stock or _event_pending


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			store_selected.emit(_store_id)
