## Modal preview shown when the player clicks "Close Day".
## Runs a dry-run customer simulation and reveals each customer event one at a time
## so the player can see browsing activity before committing to close.
extends CanvasLayer

signal confirmed
signal cancelled

const REVEAL_DELAY: float = 0.28
const MAX_FEED_LINES: int = 12

const _WALK_REASON_LABELS: Dictionary = {
	"price_too_high": "price way too high",
	"over_budget": "over budget",
	"not_interested": "nothing appealing",
	"no_item": "no item",
	"no_archetype": "no customer",
	"no_price": "unpriced",
}

var _get_snapshot: Callable = Callable()
var _reveal_timer: Timer
var _pending_events: Array[Dictionary] = []
var _reveal_index: int = 0
var _sold_count: int = 0
var _walked_count: int = 0

@onready var _overlay: ColorRect = $Control/Overlay
@onready var _panel: PanelContainer = $Control/Panel
@onready var _title_label: Label = $Control/Panel/Margin/VBox/TitleLabel
@onready var _stats_label: Label = $Control/Panel/Margin/VBox/StatsLabel
@onready var _feed_container: VBoxContainer = (
	$Control/Panel/Margin/VBox/FeedScroll/FeedContainer
)
@onready var _summary_label: Label = $Control/Panel/Margin/VBox/SummaryLabel
@onready var _cancel_button: Button = (
	$Control/Panel/Margin/VBox/ButtonRow/CancelButton
)
@onready var _confirm_button: Button = (
	$Control/Panel/Margin/VBox/ButtonRow/ConfirmButton
)


func _ready() -> void:
	visible = false
	_cancel_button.pressed.connect(_on_cancel_pressed)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_reveal_timer = Timer.new()
	_reveal_timer.wait_time = REVEAL_DELAY
	_reveal_timer.one_shot = false
	_reveal_timer.timeout.connect(_reveal_next_event)
	add_child(_reveal_timer)


## Sets the callable that returns Array[ItemInstance] for the active store.
func set_snapshot_callback(callback: Callable) -> void:
	_get_snapshot = callback


## Opens the preview, runs dry-run simulation, and starts the staggered reveal.
func show_preview() -> void:
	_reset_state()
	visible = true
	var store_id: StringName = GameManager.get_active_store_id()
	var day: int = GameManager.get_current_day()
	_title_label.text = "End of Day — Day %d" % day
	_stats_label.text = ""
	_summary_label.text = ""
	_summary_label.visible = false
	_confirm_button.disabled = true

	var snapshot: Array = []
	if _get_snapshot.is_valid():
		snapshot = _get_snapshot.call()
	else:
		# Reaching `show_preview` without a wired snapshot callback is a
		# wiring error — the HUD calls `set_snapshot_callback` from
		# `_wire_close_day_preview` in `_ready`. Without the callback the
		# dry-run sees zero shelf inventory and falsely reports "no
		# customers", which would let the player close a day looking
		# empty when their shelves are full. Surface the misconfiguration
		# rather than silently degrading. See
		# docs/audits/error-handling-report.md EH-05.
		push_warning(
			"CloseDayPreview.show_preview: snapshot callback not wired; "
			+ "dry-run will run against an empty shelf snapshot."
		)

	var shelf_count: int = 0
	for item: Variant in snapshot:
		if item is ItemInstance:
			var inst: ItemInstance = item as ItemInstance
			if not (inst.current_location in CustomerSimulator.UNAVAILABLE_LOCATIONS):
				shelf_count += 1

	_stats_label.text = "%d item%s on the shelf" % [
		shelf_count,
		"s" if shelf_count != 1 else "",
	]

	var rep_mult: float = ReputationSystemSingleton.get_customer_multiplier(store_id)
	var traffic: int = CustomerSimulator.calculate_traffic(
		CustomerSimulator.DEFAULT_BASE_TRAFFIC, rep_mult, 1.0
	)

	_pending_events = CustomerSimulator.simulate_day_dry_run(traffic, snapshot)

	if _pending_events.is_empty():
		_summary_label.text = "No customers today — stock up and try tomorrow."
		_summary_label.visible = true
		_confirm_button.disabled = false
		return

	_reveal_timer.start()


func _reset_state() -> void:
	_reveal_index = 0
	_sold_count = 0
	_walked_count = 0
	_pending_events.clear()
	for child: Node in _feed_container.get_children():
		child.queue_free()


func _reveal_next_event() -> void:
	if _reveal_index >= _pending_events.size():
		_reveal_timer.stop()
		_finish_reveal()
		return

	var event: Dictionary = _pending_events[_reveal_index]
	_reveal_index += 1

	var line := Label.new()
	line.autowrap_mode = TextServer.AUTOWRAP_OFF
	if event.get("accepted", false):
		_sold_count += 1
		var price: float = event.get("price", 0.0)
		var name_str: String = event.get("item_name", "Item")
		line.text = "  Sold  %s — $%.2f" % [name_str, price]
		line.add_theme_color_override("font_color", Color(0.3, 0.85, 0.45))
	else:
		_walked_count += 1
		var reason_key: String = event.get("walk_reason", "not_interested")
		var reason_label: String = _WALK_REASON_LABELS.get(
			reason_key, reason_key
		)
		var name_str: String = event.get("item_name", "Item")
		line.text = "  Passed  %s (%s)" % [name_str, reason_label]
		line.add_theme_color_override("font_color", Color(0.8, 0.55, 0.3))

	_feed_container.add_child(line)

	if _feed_container.get_child_count() > MAX_FEED_LINES:
		_feed_container.get_child(0).queue_free()


func _finish_reveal() -> void:
	var total: int = _sold_count + _walked_count
	_summary_label.text = (
		"%d sold, %d passed — out of %d customers" % [_sold_count, _walked_count, total]
	)
	_summary_label.visible = true
	_confirm_button.disabled = false


func _on_cancel_pressed() -> void:
	visible = false
	cancelled.emit()


func _on_confirm_pressed() -> void:
	visible = false
	EventBus.day_close_requested.emit()
	confirmed.emit()
