## Panel that displays all currently active market trends with category badges.
class_name TrendsPanel
extends PanelContainer

const PANEL_NAME: StringName = &"trends"

const _CATEGORY_COLORS: Dictionary = {
	"collectibles": Color("#D4A017"),
	"electronics": Color("#2E86C1"),
	"games": Color("#1E8449"),
	"apparel": Color("#7D3C98"),
}
const _DEFAULT_BADGE_COLOR: Color = Color("#7F8C8D")

## Assigned externally by the parent scene to provide trend data.
var trend_system: TrendSystem

var _is_open: bool = false
var _rest_x: float = 0.0
var _anim_tween: Tween
var _active_store_id: StringName = &""

@onready var _trend_list: VBoxContainer = $VBoxContainer/ScrollContainer/TrendList
@onready var _empty_state: Label = $VBoxContainer/EmptyState


func _ready() -> void:
	visible = false
	_rest_x = position.x
	_active_store_id = _get_active_store_id()
	EventBus.trend_changed.connect(_on_trend_changed)
	EventBus.active_store_changed.connect(_on_active_store_changed)


## Shows the panel and refreshes the trend list.
func open_panel() -> void:
	if _is_open:
		return
	_is_open = true
	visible = true
	_refresh_trend_list()
	EventBus.panel_opened.emit(PANEL_NAME)


## Hides the panel.
func close_panel() -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	EventBus.panel_closed.emit(PANEL_NAME)


func _refresh_trend_list() -> void:
	for child: Node in _trend_list.get_children():
		child.queue_free()
	if not trend_system or _active_store_id.is_empty():
		_empty_state.visible = true
		return
	var trends: Array[Dictionary] = _get_visible_trends()
	_empty_state.visible = trends.is_empty()
	for trend: Dictionary in trends:
		_trend_list.add_child(_create_trend_entry(trend))


func _create_trend_entry(trend: Dictionary) -> HBoxContainer:
	var target: String = trend.get("target", "unknown")
	var multiplier: float = trend.get("multiplier", 1.0) as float
	var end_day: int = trend.get("end_day", 0) as int
	var days_left: int = end_day - _get_current_day()

	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 32)
	row.add_theme_constant_override("separation", 8)

	row.add_child(_build_category_badge(target))

	var name_label := Label.new()
	name_label.text = target
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var mult_label := Label.new()
	mult_label.custom_minimum_size = Vector2(50, 0)
	mult_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mult_label.text = "%.1fx" % multiplier
	row.add_child(mult_label)

	var days_label := Label.new()
	days_label.custom_minimum_size = Vector2(60, 0)
	days_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	days_label.text = "%dd left" % maxi(0, days_left)
	row.add_child(days_label)

	return row


func _build_category_badge(category: String) -> PanelContainer:
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(90, 0)

	var style := StyleBoxFlat.new()
	style.bg_color = _CATEGORY_COLORS.get(category.to_lower(), _DEFAULT_BADGE_COLOR)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.content_margin_left = 4
	style.content_margin_right = 4
	badge.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = category
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(label)

	return badge


func _on_trend_changed(_trending: Array, _cold: Array) -> void:
	if _is_open:
		_refresh_trend_list()


func _on_active_store_changed(new_store_id: StringName) -> void:
	_active_store_id = new_store_id
	if _is_open:
		_refresh_trend_list()


func _get_current_day() -> int:
	var time_system: TimeSystem = GameManager.get_time_system()
	if time_system == null:
		return 1
	return time_system.current_day


func _get_visible_trends() -> Array[Dictionary]:
	var visible: Array[Dictionary] = []
	for trend: Dictionary in trend_system.get_active_trends():
		if _trend_matches_active_store(trend):
			visible.append(trend)
	return visible


func _trend_matches_active_store(trend: Dictionary) -> bool:
	if not GameManager.data_loader or _active_store_id.is_empty():
		return false
	var store_def: StoreDefinition = GameManager.data_loader.get_store(
		String(_active_store_id)
	)
	if store_def == null:
		return false
	var target_type: String = str(trend.get("target_type", ""))
	var target: String = str(trend.get("target", ""))
	if target_type == "category":
		return target in store_def.allowed_categories
	if target_type == "tag":
		for item_def: ItemDefinition in GameManager.data_loader.get_items_by_store(
			String(_active_store_id)
		):
			if target in item_def.tags:
				return true
	return false


func _get_active_store_id() -> StringName:
	return GameManager.current_store_id
