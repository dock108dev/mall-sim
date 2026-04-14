## Panel displaying the current refurbishment queue for the retro games store.
class_name RefurbQueuePanel
extends CanvasLayer

const PANEL_NAME: String = "refurb_queue"

var refurbishment_system: RefurbishmentSystem
var inventory_system: InventorySystem
var _is_open: bool = false
var _anim_tween: Tween
var _rest_x: float = 0.0

@onready var _panel: PanelContainer = $PanelRoot
@onready var _grid: VBoxContainer = (
	$PanelRoot/Margin/VBox/Scroll/Grid
)
@onready var _empty_label: Label = (
	$PanelRoot/Margin/VBox/EmptyLabel
)
@onready var _close_button: Button = (
	$PanelRoot/Margin/VBox/Header/CloseButton
)
@onready var _scroll: ScrollContainer = (
	$PanelRoot/Margin/VBox/Scroll
)


func _ready() -> void:
	_panel.visible = false
	_rest_x = _panel.position.x
	_close_button.pressed.connect(close)
	EventBus.panel_opened.connect(_on_panel_opened)
	EventBus.refurbishment_started.connect(_on_refurbishment_changed)
	EventBus.refurbishment_completed.connect(_on_refurbishment_done)
	EventBus.day_started.connect(_on_day_started)
	EventBus.toggle_refurb_queue_panel.connect(_toggle)


func open() -> void:
	if _is_open:
		return
	_is_open = true
	_refresh_list()
	PanelAnimator.kill_tween(_anim_tween)
	_anim_tween = PanelAnimator.slide_open(_panel, _rest_x, false)
	EventBus.panel_opened.emit(PANEL_NAME)


func close(immediate: bool = false) -> void:
	if not _is_open:
		return
	_is_open = false
	PanelAnimator.kill_tween(_anim_tween)
	if immediate:
		_panel.visible = false
		_panel.position.x = _rest_x
	else:
		_anim_tween = PanelAnimator.slide_close(
			_panel, _rest_x, false
		)
	EventBus.panel_closed.emit(PANEL_NAME)


func is_open() -> bool:
	return _is_open


func _toggle() -> void:
	if _is_open:
		close()
	else:
		open()


func _refresh_list() -> void:
	_clear_list()
	if not refurbishment_system:
		_empty_label.visible = true
		_scroll.visible = false
		return
	var queue: Array[Dictionary] = refurbishment_system.get_queue()
	_empty_label.visible = queue.is_empty()
	_scroll.visible = not queue.is_empty()
	for entry: Dictionary in queue:
		_create_queue_row(entry)


func _clear_list() -> void:
	for child: Node in _grid.get_children():
		child.queue_free()


func _create_queue_row(entry: Dictionary) -> void:
	var instance_id: String = entry.get("instance_id", "")
	var cost: float = entry.get("parts_cost", 0.0)
	var days_left: int = entry.get("days_remaining", 0)
	var item_name: String = _resolve_item_name(instance_id)

	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 40)

	var name_label := Label.new()
	name_label.text = item_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(name_label)

	var days_label := Label.new()
	days_label.custom_minimum_size = Vector2(80, 0)
	days_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var day_text: String = (
		"%d day%s left" % [days_left, "" if days_left == 1 else "s"]
	)
	days_label.text = day_text
	row.add_child(days_label)

	var cost_label := Label.new()
	cost_label.custom_minimum_size = Vector2(70, 0)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost_label.text = "$%.2f" % cost
	row.add_child(cost_label)

	_grid.add_child(row)

	var sep := HSeparator.new()
	_grid.add_child(sep)


func _resolve_item_name(instance_id: String) -> String:
	if not inventory_system:
		return instance_id
	var item: ItemInstance = inventory_system.get_item(instance_id)
	if not item or not item.definition:
		return instance_id
	return item.definition.item_name


func _on_panel_opened(panel_name: String) -> void:
	if panel_name != PANEL_NAME and _is_open:
		close(true)


func _on_refurbishment_changed(
	_item_id: String, _cost: float, _duration: int
) -> void:
	if _is_open:
		_refresh_list()


func _on_refurbishment_done(
	_item_id: String, _success: bool, _new_condition: String
) -> void:
	if _is_open:
		_refresh_list()


func _on_day_started(_day: int) -> void:
	if _is_open:
		_refresh_list()
