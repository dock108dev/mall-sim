## 2D storefront card for the mall hub.
## Displays name, accent color, live status string, urgency indicator, and a
## hover preview panel showing last-day revenue.
## Click emits EventBus.storefront_clicked.
## Highlights when EventBus.hub_store_highlighted fires for this store_id.
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
@onready var _status_label: Label = $StatusLabel
@onready var _urgency_dot: ColorRect = $UrgencyDot
@onready var _preview_panel: PanelContainer = $PreviewPanel
@onready var _preview_revenue_label: Label = $PreviewPanel/PreviewContent/RevenueLabel

var _day_closed: bool = false
var _last_day_revenue: float = 0.0
var _highlight_tween: Tween = null


func _ready() -> void:
	_click_area.input_event.connect(_on_click_area_input)
	_click_area.mouse_entered.connect(_on_mouse_entered)
	_click_area.mouse_exited.connect(_on_mouse_exited)

	if not display_name.is_empty():
		_name_label.text = display_name
	elif not String(store_id).is_empty():
		_name_label.text = ContentRegistry.get_display_name(store_id)

	_frame.color = accent_color
	_preview_panel.visible = false
	_refresh_diorama()
	_update_status()
	_update_urgency()

	EventBus.day_started.connect(_on_day_started)
	EventBus.day_closed.connect(_on_day_closed)
	EventBus.hub_store_highlighted.connect(_on_hub_store_highlighted)


## Re-populate diorama visuals. Safe no-op before _ready().
func refresh() -> void:
	if is_node_ready():
		_refresh_diorama()
		_update_status()
		_update_urgency()


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


func _update_status() -> void:
	if _day_closed:
		if _last_day_revenue > 0.0:
			_status_label.text = "Day closed · $%d" % int(_last_day_revenue)
		else:
			_status_label.text = "Day closed"
	else:
		_status_label.text = "Day active"


func _update_urgency() -> void:
	if _day_closed:
		_urgency_dot.color = UIThemeConstants.POSITIVE_COLOR
		return
	var rep_tier: int = 0
	if ReputationSystemSingleton != null:
		rep_tier = int(ReputationSystemSingleton.get_tier(String(store_id)))
	if rep_tier <= 1:
		_urgency_dot.color = UIThemeConstants.NEGATIVE_COLOR
	elif rep_tier == 2:
		_urgency_dot.color = UIThemeConstants.WARNING_COLOR
	else:
		_urgency_dot.color = UIThemeConstants.POSITIVE_COLOR


func _on_day_started(_day: int) -> void:
	_day_closed = false
	_update_status()
	_update_urgency()


func _on_day_closed(_day: int, summary: Dictionary) -> void:
	_day_closed = true
	var store_revenues: Variant = summary.get("store_revenue", {})
	if store_revenues is Dictionary:
		_last_day_revenue = float((store_revenues as Dictionary).get(String(store_id), 0.0))
	_preview_revenue_label.text = (
		"Last day: $%d" % int(_last_day_revenue)
		if _last_day_revenue > 0.0
		else "Last day: --"
	)
	_update_status()
	_update_urgency()


func _on_hub_store_highlighted(target_id: StringName) -> void:
	if target_id != store_id:
		return
	_pulse_highlight()


func _pulse_highlight() -> void:
	if _highlight_tween and _highlight_tween.is_valid():
		_highlight_tween.kill()
	_frame.color = UIThemeConstants.SEMANTIC_INFO
	_highlight_tween = create_tween()
	_highlight_tween.tween_interval(0.4)
	_highlight_tween.tween_property(_frame, "color", accent_color, 0.25)


func _on_click_area_input(
	_viewport: Node, event: InputEvent, _shape_idx: int
) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		EventBus.storefront_clicked.emit(store_id)


func _on_mouse_entered() -> void:
	_kill_highlight_tween()
	_frame.color = UIThemeConstants.SEMANTIC_INFO
	_preview_panel.visible = true
	EventBus.interactable_focused.emit("[Click] Enter Store")
	AuditOverlay.report_interactable(str(store_id))


func _on_mouse_exited() -> void:
	_kill_highlight_tween()
	_frame.color = accent_color
	_preview_panel.visible = false
	EventBus.interactable_unfocused.emit()


func _kill_highlight_tween() -> void:
	if _highlight_tween and _highlight_tween.is_valid():
		_highlight_tween.kill()
	_highlight_tween = null
