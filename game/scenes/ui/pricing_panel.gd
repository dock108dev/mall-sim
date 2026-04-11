## Panel for setting or adjusting the sale price of an item on a shelf.
class_name PricingPanel
extends CanvasLayer

const PANEL_NAME: String = "pricing"

var inventory_system: InventorySystem
var economy_system: EconomySystem

var _is_open: bool = false
var _current_item: ItemInstance = null
var _current_slot: ShelfSlot = null
var _market_value: float = 0.0
var _default_markup: float = 1.35
var _min_markup: float = 1.05
var _max_markup: float = 5.0
var _optimal_min: float = 0.0
var _optimal_max: float = 0.0
var _max_viable: float = 0.0
var _anim_tween: Tween
var _rest_x: float = 0.0

@onready var _panel: PanelContainer = $PanelRoot
@onready var _item_name_label: Label = (
	$PanelRoot/Margin/VBox/ItemNameLabel
)
@onready var _condition_label: Label = (
	$PanelRoot/Margin/VBox/ConditionLabel
)
@onready var _market_value_label: Label = (
	$PanelRoot/Margin/VBox/MarketValueLabel
)
@onready var _suggested_label: Label = (
	$PanelRoot/Margin/VBox/SuggestedLabel
)
@onready var _price_spin: SpinBox = (
	$PanelRoot/Margin/VBox/PriceRow/PriceSpinBox
)
@onready var _markup_indicator: Label = (
	$PanelRoot/Margin/VBox/PriceRow/MarkupIndicator
)
@onready var _confirm_button: Button = (
	$PanelRoot/Margin/VBox/ButtonRow/ConfirmButton
)
@onready var _cancel_button: Button = (
	$PanelRoot/Margin/VBox/ButtonRow/CancelButton
)


func _ready() -> void:
	_panel.visible = false
	_rest_x = _panel.position.x
	_confirm_button.pressed.connect(_on_confirm)
	_cancel_button.pressed.connect(_on_cancel)
	_price_spin.value_changed.connect(_on_price_changed)
	EventBus.interactable_interacted.connect(
		_on_interactable_interacted
	)
	EventBus.panel_opened.connect(_on_panel_opened)
	_load_pricing_config()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.is_action_pressed("ui_cancel"):
		close(true)
		get_viewport().set_input_as_handled()


func open(item: ItemInstance, slot: ShelfSlot) -> void:
	if _is_open:
		close(true)
	if not item or not item.definition:
		push_warning("PricingPanel: invalid item")
		return
	PanelAnimator.kill_tween(_anim_tween)
	_current_item = item
	_current_slot = slot
	_load_store_markup_ranges()
	if economy_system:
		_market_value = economy_system.calculate_market_value(item)
	else:
		_market_value = item.get_current_value()
	var suggested: float = _market_value * _default_markup
	var min_price: float = _market_value * _min_markup
	var max_price: float = _market_value * _max_markup

	_item_name_label.text = item.definition.name
	_condition_label.text = (
		tr("PRICING_CONDITION") % item.condition.capitalize()
	)
	_market_value_label.text = (
		tr("PRICING_MARKET_VALUE") % _market_value
	)
	_suggested_label.text = (
		tr("PRICING_SUGGESTED") % suggested
	)

	_price_spin.min_value = snappedf(min_price, 0.01)
	_price_spin.max_value = snappedf(max_price, 0.01)
	_price_spin.step = 0.25

	var initial_price: float = item.set_price
	if initial_price < min_price or initial_price > max_price:
		initial_price = suggested
	_price_spin.value = snappedf(initial_price, 0.01)
	_update_markup_indicator(initial_price)

	_is_open = true
	_anim_tween = PanelAnimator.slide_open(
		_panel, _rest_x, false
	)
	EventBus.panel_opened.emit(PANEL_NAME)


func close(immediate: bool = false) -> void:
	if not _is_open:
		return
	PanelAnimator.kill_tween(_anim_tween)
	_is_open = false
	_current_item = null
	_current_slot = null
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


func _on_confirm() -> void:
	if not _current_item:
		close()
		return
	var price: float = snappedf(_price_spin.value, 0.01)
	_current_item.set_price = price
	EventBus.price_set.emit(
		_current_item.instance_id, price
	)
	close()


func _on_cancel() -> void:
	close()


func _on_price_changed(value: float) -> void:
	_update_markup_indicator(value)


func _update_markup_indicator(price: float) -> void:
	if _market_value <= 0.0:
		_markup_indicator.text = ""
		return
	var ratio: float = price / _market_value
	var percent: int = roundi((ratio - 1.0) * 100.0)
	var label: String = _get_store_markup_label(ratio)
	_markup_indicator.text = tr("PRICING_MARKUP") % [percent, label]
	_markup_indicator.add_theme_color_override(
		"font_color", _get_store_markup_color(ratio)
	)


func _on_interactable_interacted(
	target: Interactable, type: int
) -> void:
	if type != Interactable.InteractionType.SHELF_SLOT:
		return
	if not target is ShelfSlot:
		return
	var slot := target as ShelfSlot
	if not slot.is_occupied():
		return
	if not inventory_system:
		push_warning("PricingPanel: no inventory_system assigned")
		return
	var item: ItemInstance = inventory_system.get_item(
		slot.get_item_instance_id()
	)
	if not item:
		push_warning(
			"PricingPanel: item not found for slot %s"
			% slot.slot_id
		)
		return
	open(item, slot)


func _on_panel_opened(panel_name: String) -> void:
	if panel_name != PANEL_NAME and _is_open:
		close(true)


func _load_store_markup_ranges() -> void:
	_optimal_min = 0.0
	_optimal_max = 0.0
	_max_viable = 0.0
	var store_id: String = GameManager.current_store_id
	if store_id.is_empty() or not GameManager.data_loader:
		return
	var store_def: StoreDefinition = (
		GameManager.data_loader.get_store(store_id)
	)
	if not store_def or not store_def.has_recommended_markup():
		return
	_optimal_min = store_def.recommended_markup_optimal_min
	_optimal_max = store_def.recommended_markup_optimal_max
	_max_viable = store_def.recommended_markup_max_viable


func _get_store_markup_label(ratio: float) -> String:
	if _max_viable <= 0.0:
		return UIThemeConstants.get_markup_label(ratio)
	if ratio <= _optimal_max:
		return "Fair"
	if ratio <= _max_viable:
		return "High"
	return "Very High"


func _get_store_markup_color(ratio: float) -> Color:
	if _max_viable <= 0.0:
		return UIThemeConstants.get_markup_color(ratio)
	if ratio <= _optimal_max:
		return UIThemeConstants.get_positive_color()
	if ratio <= _max_viable:
		return UIThemeConstants.get_warning_color()
	return UIThemeConstants.get_negative_color()


func _load_pricing_config() -> void:
	var file := FileAccess.open(
		"res://game/content/economy/pricing_config.json",
		FileAccess.READ
	)
	if not file:
		push_warning(
			"PricingPanel: could not load pricing_config.json"
		)
		return
	var json := JSON.new()
	var err: Error = json.parse(file.get_as_text())
	if err != OK:
		push_warning(
			"PricingPanel: failed to parse pricing_config.json"
		)
		return
	var data: Dictionary = json.data
	if data.has("markup_ranges"):
		var ranges: Dictionary = data["markup_ranges"]
		_default_markup = ranges.get("default", 1.35)
		_min_markup = ranges.get("minimum", 1.05)
		_max_markup = ranges.get("maximum", 5.0)
