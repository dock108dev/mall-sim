## 2D storefront card for the mall hub. Click emits EventBus.storefront_clicked.
## Hosts a SubViewport diorama (stock bar, reputation pips, idle customer sprite)
## and an Area2D for click detection.
class_name StorefrontCard
extends Node2D

@export var store_id: StringName = &""
@export var display_name: String = ""
@export var accent_color: Color = Color(0.7, 0.7, 0.8, 1.0)

@onready var _click_area: Area2D = $ClickArea
@onready var _frame: ColorRect = $Frame
@onready var _name_label: Label = $NameLabel
@onready var _diorama_viewport: SubViewport = $DioramaContainer/Diorama
@onready var _stock_bar: ColorRect = $DioramaContainer/Diorama/StockBar
@onready var _reputation_pips: HBoxContainer = $DioramaContainer/Diorama/ReputationPips
@onready var _idle_customer: Sprite2D = $DioramaContainer/Diorama/IdleCustomer


func _ready() -> void:
	_click_area.input_event.connect(_on_click_area_input)
	_click_area.mouse_entered.connect(_on_mouse_entered)
	_click_area.mouse_exited.connect(_on_mouse_exited)
	if not display_name.is_empty():
		_name_label.text = display_name
	elif not String(store_id).is_empty():
		_name_label.text = ContentRegistry.get_display_name(store_id)
	_frame.color = accent_color
	_refresh_diorama()


## Re-populate diorama visuals. Safe no-op before _ready().
func refresh() -> void:
	if is_node_ready():
		_refresh_diorama()


func _refresh_diorama() -> void:
	var stock_ratio: float = 0.6
	_stock_bar.size.x = clampf(stock_ratio, 0.0, 1.0) * 160.0

	var reputation: int = 3
	if ReputationSystemSingleton != null:
		reputation = int(ReputationSystemSingleton.get_tier(String(store_id)))
	for i: int in _reputation_pips.get_child_count():
		var pip: ColorRect = _reputation_pips.get_child(i) as ColorRect
		if pip != null:
			pip.modulate = Color(1, 1, 1, 1) if i < reputation else Color(1, 1, 1, 0.25)


func _on_click_area_input(
	_viewport: Node, event: InputEvent, _shape_idx: int
) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		EventBus.storefront_clicked.emit(store_id)


func _on_mouse_entered() -> void:
	_frame.modulate = Color(1.15, 1.15, 1.15, 1.0)


func _on_mouse_exited() -> void:
	_frame.modulate = Color(1, 1, 1, 1)
