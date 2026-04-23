## Day-1 empty-inventory affordance cue. Shows a visible next-action prompt
## ("Stock shelves to open for business!") on first entry into a store whose
## inventory is empty, and auto-dismisses once the player stocks the store.
class_name FirstRunCueOverlay
extends PanelContainer


const _DEFAULT_MESSAGE: String = "Stock your shelves — open the Inventory panel (I) to fill them."
const _STORE_MESSAGES: Dictionary = {
	&"electronics": "Empty shelves! Open Inventory (I) and stock the Electronics store.",
	&"pocket_creatures": "Empty shelves! Open Inventory (I) and stock booster packs & cards.",
	&"rentals": "Empty shelves! Open Inventory (I) and stock the rental wall.",
	&"retro_games": "Empty shelves! Open Inventory (I) and stock the Retro Games store.",
	&"retro": "Empty shelves! Open Inventory (I) and stock the Retro Games store.",
	&"sneaker_citadel": "Empty shelves! Open Inventory (I) and stock sneakers.",
	&"sports": "Empty shelves! Open Inventory (I) and stock the Sports store.",
	&"video_rental": "Empty shelves! Open Inventory (I) and stock the rental wall.",
}

var inventory_system: Node = null
var time_system: Node = null

var _active_store_id: StringName = &""
var _dismissed_day_by_store: Dictionary = {}
var _is_showing: bool = false
var _current_day: int = 1

@onready var _message_label: Label = $Margin/VBox/MessageLabel
@onready var _pointer_label: Label = $Margin/VBox/PointerLabel


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EventBus.store_entered.connect(_on_store_entered)
	EventBus.inventory_updated.connect(_on_inventory_updated)
	EventBus.day_started.connect(_on_day_started)


func _on_day_started(day: int) -> void:
	_current_day = day
	if day > 1:
		_hide()
		_dismissed_day_by_store.clear()


func _on_store_entered(store_id: StringName) -> void:
	_active_store_id = store_id
	var day: int = _resolve_current_day()
	if day > 1:
		return
	if _already_dismissed(store_id, day):
		return
	if not _is_inventory_empty(store_id):
		return
	_show_for_store(store_id)


func _on_inventory_updated(store_id: StringName) -> void:
	if not _is_showing:
		return
	if store_id != _active_store_id:
		return
	if _is_inventory_empty(store_id):
		return
	_dismissed_day_by_store[store_id] = _resolve_current_day()
	_hide()


func _show_for_store(store_id: StringName) -> void:
	var message: String = _STORE_MESSAGES.get(store_id, _DEFAULT_MESSAGE)
	_message_label.text = message
	_pointer_label.text = "→ Inventory"
	_is_showing = true
	visible = true


func _hide() -> void:
	if not _is_showing and not visible:
		return
	_is_showing = false
	visible = false


func _already_dismissed(store_id: StringName, day: int) -> bool:
	var marker: Variant = _dismissed_day_by_store.get(store_id, -1)
	if marker is int:
		return int(marker) == day
	return false


func _resolve_current_day() -> int:
	if time_system != null and "current_day" in time_system:
		return int(time_system.current_day)
	return _current_day


func _is_inventory_empty(store_id: StringName) -> bool:
	if inventory_system == null:
		return true
	if not inventory_system.has_method("get_stock"):
		return true
	var stock: Array = inventory_system.call("get_stock", store_id)
	return stock.is_empty()
