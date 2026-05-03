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
	&"sports": "Empty shelves! Open Inventory (I) and stock the Sports store.",
	&"video_rental": "Empty shelves! Open Inventory (I) and stock the rental wall.",
}

# Tutorial steps whose on-screen prompt duplicates this overlay's "open inventory
# and stock shelves" message. While any of these is the active tutorial step, the
# overlay stays hidden and re-evaluates eligibility on tutorial_completed /
# tutorial_skipped. Step IDs come from TutorialSystem.STEP_IDS.
const _TUTORIAL_SUPPRESSING_STEPS: Array[String] = [
	"welcome", "move_to_shelf", "open_inventory", "place_item",
]

var inventory_system: Node = null
var time_system: Node = null

var _active_store_id: StringName = &""
var _dismissed_day_by_store: Dictionary = {}
var _is_showing: bool = false
var _current_day: int = 1
var _tutorial_suppressing: bool = false

@onready var _message_label: Label = $Margin/VBox/MessageLabel
@onready var _pointer_label: Label = $Margin/VBox/PointerLabel


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tutorial_suppressing = _is_tutorial_active_at_boot()
	EventBus.store_entered.connect(_on_store_entered)
	EventBus.inventory_updated.connect(_on_inventory_updated)
	EventBus.day_started.connect(_on_day_started)
	EventBus.tutorial_step_changed.connect(_on_tutorial_step_changed)
	EventBus.tutorial_completed.connect(_on_tutorial_finished)
	EventBus.tutorial_skipped.connect(_on_tutorial_finished)


func _on_day_started(day: int) -> void:
	_current_day = day
	if day > 1:
		_hide()
		_dismissed_day_by_store.clear()


func _on_store_entered(store_id: StringName) -> void:
	_active_store_id = store_id
	if _tutorial_suppressing:
		return
	var day: int = _resolve_current_day()
	if day > 1:
		return
	if _already_dismissed(store_id, day):
		return
	if not _is_inventory_empty(store_id):
		return
	_show_for_store(store_id)


func _on_tutorial_step_changed(step_id: String) -> void:
	var was_suppressing: bool = _tutorial_suppressing
	_tutorial_suppressing = _TUTORIAL_SUPPRESSING_STEPS.has(step_id)
	if _tutorial_suppressing:
		if _is_showing:
			_hide()
	elif was_suppressing:
		_maybe_reshow_for_active_store()


func _on_tutorial_finished() -> void:
	if not _tutorial_suppressing:
		return
	_tutorial_suppressing = false
	_maybe_reshow_for_active_store()


func _maybe_reshow_for_active_store() -> void:
	if _active_store_id == &"":
		return
	if _is_showing:
		return
	var day: int = _resolve_current_day()
	if day > 1:
		return
	if _already_dismissed(_active_store_id, day):
		return
	if not _is_inventory_empty(_active_store_id):
		return
	_show_for_store(_active_store_id)


func _is_tutorial_active_at_boot() -> bool:
	# GameManager.is_tutorial_active mirrors TutorialSystem.tutorial_active and
	# is reachable as an autoload before the per-step signal has fired.
	return GameManager.is_tutorial_active


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
	if _tutorial_suppressing:
		return
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
	# Null inventory_system is the legitimate test/early-boot path: treat as
	# empty so the cue still fires when the eligibility timing window opens.
	# A bound system that lacks `get_stock`, however, is a programming error
	# (interface drift). Surface it once via push_warning rather than
	# silently lying about emptiness. See docs/audits/error-handling-report.md
	# finding F2.
	if inventory_system == null:
		return true
	if not inventory_system.has_method("get_stock"):
		push_warning(
			"FirstRunCueOverlay: bound inventory_system lacks get_stock() — "
			+ "treating store '%s' as empty"
			% String(store_id)
		)
		return true
	var stock: Array = inventory_system.call("get_stock", store_id)
	return stock.is_empty()
