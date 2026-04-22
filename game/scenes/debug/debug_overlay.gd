## Debug overlay — shows game state info and provides cheat commands.
## Toggle with F1 (toggle_debug input action). Only available in debug builds.
extends CanvasLayer


const DEBUG_CASH_AMOUNT: float = 100.0

var time_system: TimeSystem
var economy_system: EconomySystem
var inventory_system: InventorySystem
var customer_system: CustomerSystem
var mall_customer_spawner: MallCustomerSpawner

var _overlay_visible: bool = false

@onready var _label: Label = $Label


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	visible = false


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		_overlay_visible = not _overlay_visible
		visible = _overlay_visible
		return

	if not _overlay_visible:
		return

	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if not key_event.ctrl_pressed:
		return

	match key_event.keycode:
		KEY_M:
			_debug_add_cash()
			get_viewport().set_input_as_handled()
		KEY_C:
			_debug_spawn_customer()
			get_viewport().set_input_as_handled()
		KEY_H:
			_debug_advance_hour()
			get_viewport().set_input_as_handled()
		KEY_D:
			_debug_end_day()
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not _overlay_visible:
		return
	_label.text = _build_display_text()


func _build_display_text() -> String:
	var fps: int = Engine.get_frames_per_second()
	var state_name: String = GameManager.GameState.keys()[
		int(GameManager.current_state)
	]

	var cash_text: String = "N/A"
	if economy_system:
		cash_text = "$%.2f" % economy_system.get_cash()

	var customer_text: String = "N/A"
	if customer_system:
		customer_text = str(customer_system.get_active_customer_count())

	var inv_backroom: String = "N/A"
	var inv_shelf: String = "N/A"
	if inventory_system:
		inv_backroom = str(inventory_system.get_backroom_items().size())
		inv_shelf = str(inventory_system.get_shelf_items().size())

	var phase_text: String = "N/A"
	var speed_text: String = "N/A"
	var day_text: String = "N/A"
	var hour_text: String = "N/A"
	if time_system:
		phase_text = TimeSystem.DayPhase.keys()[int(time_system.current_phase)]
		speed_text = "%.0fx" % time_system.speed_multiplier
		day_text = str(time_system.current_day)
		hour_text = str(time_system.current_hour) + ":00"

	var lines: PackedStringArray = PackedStringArray([
		"=== DEBUG ===",
		"FPS: %d | State: %s" % [fps, state_name],
		"Day: %s | Hour: %s | Phase: %s | Speed: %s" % [
			day_text, hour_text, phase_text, speed_text
		],
		"Cash: %s" % cash_text,
		"Customers: %s" % customer_text,
		"Inventory — Backroom: %s | Shelf: %s" % [
			inv_backroom, inv_shelf
		],
		"",
		"Ctrl+M: +$100 | Ctrl+C: Spawn customer",
		"Ctrl+H: +1 hour | Ctrl+D: End day",
	])
	return "\n".join(lines)


func _debug_add_cash() -> void:
	if not economy_system:
		push_warning("DebugOverlay: EconomySystem not available")
		return
	economy_system.add_cash(DEBUG_CASH_AMOUNT, "debug_cheat")


func _debug_spawn_customer() -> void:
	if not mall_customer_spawner:
		push_warning("DebugOverlay: MallCustomerSpawner not available")
		return
	mall_customer_spawner.debug_spawn_customer()


func _debug_advance_hour() -> void:
	if not time_system:
		push_warning("DebugOverlay: TimeSystem not available")
		return
	if time_system.current_hour >= Constants.STORE_CLOSE_HOUR - 1:
		push_warning("DebugOverlay: Already at closing hour")
		return
	time_system._advance_hour()


func _debug_end_day() -> void:
	if not time_system:
		push_warning("DebugOverlay: TimeSystem not available")
		return
	time_system._end_day()
