## Floating tooltip panel that shows rich item data on hover.
class_name ItemTooltip
extends PanelContainer

const SHOW_DELAY: float = 0.3
const SCREEN_MARGIN: int = 12
const TOOLTIP_OFFSET := Vector2(16, 16)
const CONDITION_ORDER: Array[String] = [
	"poor", "fair", "good", "near_mint", "mint",
]

var economy_system: EconomySystem = null
var inventory_system: InventorySystem = null
var season_cycle_system: SeasonCycleSystem = null

var _current_item: ItemInstance = null
var _show_timer: float = -1.0
var _pending_item: ItemInstance = null
var _fade_tween: Tween

@onready var _name_label: Label = $Margin/VBox/NameLabel
@onready var _rarity_label: Label = $Margin/VBox/RarityLabel
@onready var _condition_label: Label = $Margin/VBox/ConditionRow/CondLabel
@onready var _condition_bar: ProgressBar = $Margin/VBox/ConditionRow/CondBar
@onready var _market_label: Label = $Margin/VBox/MarketLabel
@onready var _price_label: Label = $Margin/VBox/PriceLabel
@onready var _trend_label: Label = $Margin/VBox/TrendLabel
@onready var _auth_label: Label = $Margin/VBox/AuthLabel
@onready var _desc_label: Label = $Margin/VBox/DescLabel


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_children_mouse_filter(self)
	EventBus.item_tooltip_requested.connect(show_for_item)
	EventBus.item_tooltip_hidden.connect(hide_tooltip)
	EventBus.panel_opened.connect(_on_panel_opened)


func _process(delta: float) -> void:
	if _show_timer >= 0.0:
		_show_timer -= delta
		if _show_timer < 0.0 and _pending_item:
			_display_item(_pending_item)
			_pending_item = null
	if visible:
		_follow_mouse()


## Shows the tooltip for an item after a short delay.
func show_for_item(item: ItemInstance) -> void:
	if not item or not item.definition:
		hide_tooltip()
		return
	if item == _current_item and visible:
		return
	_pending_item = item
	_show_timer = SHOW_DELAY


## Hides the tooltip and clears state.
func hide_tooltip() -> void:
	PanelAnimator.kill_tween(_fade_tween)
	_pending_item = null
	_show_timer = -1.0
	_current_item = null
	modulate = Color.WHITE
	visible = false


func _display_item(item: ItemInstance) -> void:
	_current_item = item
	var def: ItemDefinition = item.definition

	_name_label.text = def.name
	var rarity_color: Color = UIThemeConstants.get_rarity_color(
		def.rarity
	)
	_name_label.add_theme_color_override("font_color", rarity_color)
	_rarity_label.text = UIThemeConstants.get_rarity_display(
		def.rarity
	)
	_rarity_label.add_theme_color_override("font_color", rarity_color)

	_update_condition(item.condition)
	_update_market_value(item)
	_update_set_price(item)
	_update_trend(item)
	_update_authentication(item)
	_update_description(def)

	PanelAnimator.kill_tween(_fade_tween)
	_fade_tween = PanelAnimator.fade_in(self)
	_follow_mouse()


func _update_condition(condition: String) -> void:
	_condition_label.text = condition.replace("_", " ").capitalize()
	var idx: int = CONDITION_ORDER.find(condition)
	if idx < 0:
		idx = 2
	_condition_bar.value = float(idx + 1) / float(CONDITION_ORDER.size())


func _update_market_value(item: ItemInstance) -> void:
	var value: float = 0.0
	if economy_system:
		value = economy_system.calculate_market_value(item)
	else:
		value = item.get_current_value()
	_market_label.text = "Market Value: $%.2f" % value


func _update_set_price(item: ItemInstance) -> void:
	if item.set_price > 0.0 and item.current_location.begins_with("shelf"):
		_price_label.text = "Your Price: $%.2f" % item.set_price
		_price_label.visible = true
	else:
		_price_label.visible = false


func _update_trend(item: ItemInstance) -> void:
	var trend_value: float = _calc_trend_direction(item)
	var season_hot: bool = _is_season_hot(item)
	if season_hot:
		_trend_label.text = "Trend: %s Trending (Season)" % char(9650)
		_trend_label.add_theme_color_override(
			"font_color", UIThemeConstants.get_positive_color()
		)
	elif trend_value > 1.05:
		_trend_label.text = "Trend: %s Up" % char(9650)
		_trend_label.add_theme_color_override(
			"font_color", UIThemeConstants.get_positive_color()
		)
	elif trend_value < 0.95:
		_trend_label.text = "Trend: %s Down" % char(9660)
		_trend_label.add_theme_color_override(
			"font_color", UIThemeConstants.get_negative_color()
		)
	else:
		_trend_label.text = "Trend: %s Stable" % char(9644)
		_trend_label.add_theme_color_override(
			"font_color", UIThemeConstants.BODY_FONT_COLOR
		)


func _calc_trend_direction(item: ItemInstance) -> float:
	if not economy_system or not item.definition:
		if item.definition and item.definition.appreciates:
			return 1.1
		if item.definition and item.definition.depreciates:
			return 0.9
		return 1.0
	var drift: float = economy_system.get_drift_factor(
		item.definition.id
	)
	var demand: float = economy_system.get_demand_modifier(
		item.definition.category
	)
	var combined: float = drift * demand
	if item.definition.appreciates:
		combined *= 1.05
	elif item.definition.depreciates:
		combined *= 0.95
	return combined


func _update_authentication(item: ItemInstance) -> void:
	match item.authentication_status:
		"authenticated":
			# Unicode shield U+1F6E1 may not render; use checkmark
			_auth_label.text = "%s Authenticated" % char(9989)
			_auth_label.add_theme_color_override(
				"font_color",
				UIThemeConstants.get_positive_color()
			)
			_auth_label.visible = true
		"fake":
			_auth_label.text = "%s Fake" % char(9888)
			_auth_label.add_theme_color_override(
				"font_color",
				UIThemeConstants.get_negative_color()
			)
			_auth_label.visible = true
		"authenticating":
			_auth_label.text = "%s Authenticating..." % char(8987)
			_auth_label.add_theme_color_override(
				"font_color", UIThemeConstants.BODY_FONT_COLOR
			)
			_auth_label.visible = true
		_:
			_auth_label.visible = false


func _update_description(def: ItemDefinition) -> void:
	if def.description.is_empty():
		_desc_label.visible = false
	else:
		_desc_label.text = def.description
		_desc_label.visible = true


func _follow_mouse() -> void:
	var viewport: Viewport = get_viewport()
	if not viewport:
		return
	var mouse_pos: Vector2 = viewport.get_mouse_position()
	var screen_size: Vector2 = viewport.get_visible_rect().size
	var tooltip_size: Vector2 = size

	var pos: Vector2 = mouse_pos + TOOLTIP_OFFSET

	if pos.x + tooltip_size.x > screen_size.x - SCREEN_MARGIN:
		pos.x = mouse_pos.x - tooltip_size.x - TOOLTIP_OFFSET.x
	if pos.y + tooltip_size.y > screen_size.y - SCREEN_MARGIN:
		pos.y = mouse_pos.y - tooltip_size.y - TOOLTIP_OFFSET.y

	pos.x = maxf(SCREEN_MARGIN, pos.x)
	pos.y = maxf(SCREEN_MARGIN, pos.y)
	global_position = pos


func _is_season_hot(item: ItemInstance) -> bool:
	if not season_cycle_system:
		return false
	return season_cycle_system.is_item_hot(item)


func _on_panel_opened(_panel_name: String) -> void:
	hide_tooltip()


func _set_children_mouse_filter(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children():
		_set_children_mouse_filter(child)
