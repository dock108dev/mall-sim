## Clickable store card for the mall overview hub.
## Shows store name, reputation tier, today's cash, inventory count, and
## today's sold count. AlertBadge fires only for actionable conditions
## (depleted stock after operating, or pending event). Locked cards collapse
## detail rows and surface a single "Requires: Rep N · $M" line. Emits
## store_selected on left-click when unlocked.
class_name StoreSlotCard
extends PanelContainer

signal store_selected(store_id: StringName)

var _store_id: StringName = &""
var _stock_count: int = 0
var _has_been_operating: bool = false
var _event_pending: bool = false
var _is_locked: bool = false

@onready var _name_label: Label = $Margin/VBox/NameLabel
@onready var _rep_badge: Label = $Margin/VBox/RepBadge
@onready var _revenue_label: Label = $Margin/VBox/RevenueLabel
@onready var _stock_label: Label = $Margin/VBox/StockLabel
@onready var _sold_label: Label = $Margin/VBox/SoldLabel
@onready var _alert_badge: Label = $Margin/VBox/AlertBadge
@onready var _locked_overlay: Label = $Margin/VBox/LockedOverlay


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


## Populate the card with store identity; call once after instantiation.
func setup(store_id: StringName, display_name: String) -> void:
	_store_id = store_id
	_name_label.text = display_name
	_rep_badge.text = ""
	_revenue_label.text = "Cash: $0"
	_stock_label.text = "Inventory: 0 items"
	_sold_label.text = "Today: 0 sold"
	_alert_badge.visible = false
	_locked_overlay.visible = false


func update_revenue(amount: float) -> void:
	_revenue_label.text = "Cash: $%s" % UIThemeConstants.format_thousands(
		int(round(amount))
	)


func update_stock(count: int) -> void:
	_stock_count = count
	_stock_label.text = "Inventory: %d items" % count
	if count > 0:
		_has_been_operating = true
	_refresh_badge()


## Update today's sold count for this store.
func update_today_sold(count: int) -> void:
	_sold_label.text = "Today: %d sold" % count
	if count > 0:
		_has_been_operating = true
	_refresh_badge()


func set_event_pending(active: bool) -> void:
	_event_pending = active
	_refresh_badge()


## Update the reputation tier badge label.
func set_reputation_tier(tier_name: String) -> void:
	_rep_badge.text = tier_name


## Toggle locked state; requirements_text is shown below the LOCKED label.
func set_locked(locked: bool, requirements_text: String) -> void:
	_is_locked = locked
	mouse_default_cursor_shape = (
		Control.CURSOR_ARROW if locked else Control.CURSOR_POINTING_HAND
	)
	if locked:
		_locked_overlay.text = "LOCKED" if requirements_text.is_empty() else (
			"LOCKED\nRequires: " + requirements_text
		)
	_locked_overlay.visible = locked
	# Locked cards hide the live-state detail rows; the LOCKED + Requires
	# overlay is the only content. Otherwise show the operational detail rows.
	_rep_badge.visible = not locked
	_revenue_label.visible = not locked
	_stock_label.visible = not locked
	_sold_label.visible = not locked
	_refresh_badge()


func _refresh_badge() -> void:
	if _is_locked:
		_alert_badge.visible = false
		return
	var depleted_after_operating: bool = (
		_stock_count == 0 and _has_been_operating
	)
	_alert_badge.visible = depleted_after_operating or _event_pending


func _gui_input(event: InputEvent) -> void:
	if _is_locked:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			store_selected.emit(_store_id)
