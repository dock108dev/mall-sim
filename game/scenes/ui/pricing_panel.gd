## Right-dock slide-in panel for setting per-item prices via markup slider.
class_name PricingPanel
extends CanvasLayer

# Localization marker for static validation: tr("PRICING_CONDITION")

const PANEL_NAME: String = "pricing"
const MIN_MARKUP: float = 0.5
const MAX_MARKUP: float = 3.0
const SLIDER_STEP: float = 0.01

const ZONE_GREEN_MAX: float = 0.9
const ZONE_BLUE_MAX: float = 1.1
const ZONE_YELLOW_MAX: float = 1.5

const FEEDBACK_BELOW_MARKET: String = (
	"Below market — sells fast, builds reputation"
)
const FEEDBACK_AT_MARKET: String = "At market — normal turnover"
const FEEDBACK_ABOVE_MARKET: String = "Above market — slower sales"
const FEEDBACK_PREMIUM: String = (
	"Premium pricing — only collectors will pay this"
)
const FEEDBACK_EXTREME: String = (
	"Extreme markup — may hurt reputation"
)

var inventory_system: InventorySystem
var economy_system: EconomySystem

var _is_open: bool = false
var _current_item: ItemInstance = null
var _market_value: float = 0.0
var _anim_tween: Tween
var _rest_x: float = 0.0
var _updating_from_slider: bool = false
var _updating_from_spin: bool = false
var _optimal_max: float = ZONE_YELLOW_MAX
var _max_viable: float = MAX_MARKUP

@onready var _panel: PanelContainer = $PanelRoot
@onready var _item_icon: TextureRect = (
	$PanelRoot/Margin/VBox/ItemHeader/ItemIcon
)
@onready var _item_name_label: Label = (
	$PanelRoot/Margin/VBox/ItemHeader/ItemInfo/ItemNameLabel
)
@onready var _condition_badge: Label = (
	$PanelRoot/Margin/VBox/ItemHeader/ItemInfo/ConditionBadge
)
@onready var _base_price_label: Label = (
	$PanelRoot/Margin/VBox/MarketSection/BasePriceLabel
)
@onready var _condition_mult_label: Label = (
	$PanelRoot/Margin/VBox/MarketSection/ConditionMultLabel
)
@onready var _effective_base_label: Label = (
	$PanelRoot/Margin/VBox/MarketSection/EffectiveBaseLabel
)
@onready var _markup_slider: HSlider = (
	$PanelRoot/Margin/VBox/SliderSection/MarkupSlider
)
@onready var _color_bar: ColorRect = (
	$PanelRoot/Margin/VBox/SliderSection/ColorBar
)
@onready var _price_spin: SpinBox = (
	$PanelRoot/Margin/VBox/PriceRow/PriceSpinBox
)
@onready var _markup_ratio_label: Label = (
	$PanelRoot/Margin/VBox/PriceRow/MarkupRatioLabel
)
@onready var _feedback_label: Label = (
	$PanelRoot/Margin/VBox/FeedbackLabel
)
@onready var _apply_button: Button = (
	$PanelRoot/Margin/VBox/ButtonRow/ApplyButton
)
@onready var _apply_all_button: Button = (
	$PanelRoot/Margin/VBox/ButtonRow/ApplyAllButton
)


func _ready() -> void:
	_panel.visible = false
	_rest_x = _panel.position.x
	_markup_slider.min_value = MIN_MARKUP
	_markup_slider.max_value = MAX_MARKUP
	_markup_slider.step = SLIDER_STEP
	_markup_slider.value = 1.0
	_markup_slider.value_changed.connect(_on_slider_changed)
	_price_spin.value_changed.connect(_on_spin_changed)
	_apply_button.pressed.connect(_on_apply)
	_apply_all_button.pressed.connect(_on_apply_all)
	EventBus.panel_opened.connect(_on_panel_opened)
	EventBus.interactable_interacted.connect(
		_on_interactable_interacted
	)
	EventBus.active_store_changed.connect(_on_active_store_changed)
	_load_store_markup_ranges()
	_set_disabled_state()


## Loads store-specific markup guidance thresholds from GameManager.data_loader.
## Replaces hardcoded constants with per-store recommended ranges.
func _load_store_markup_ranges() -> void:
	if GameManager.data_loader == null:
		return
	var store_id: String = String(GameManager.get_active_store_id())
	if store_id.is_empty():
		return
	var store_def: StoreDefinition = GameManager.data_loader.get_store(
		store_id
	)
	if store_def == null or not store_def.has_recommended_markup():
		return
	_optimal_max = store_def.recommended_markup_optimal_max
	_max_viable = store_def.recommended_markup_max_viable


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.is_action_pressed("toggle_pricing"):
		_toggle()
		get_viewport().set_input_as_handled()
		return
	if _is_open and key_event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open_for_item(item: ItemInstance) -> void:
	if not item or not item.definition:
		push_warning("PricingPanel: invalid item")
		return
	_current_item = item
	_populate_item_data(item)
	if not _is_open:
		_is_open = true
		PanelAnimator.kill_tween(_anim_tween)
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
	if immediate:
		_panel.visible = false
		_panel.position.x = _rest_x
	else:
		_anim_tween = PanelAnimator.slide_close(
			_panel, _rest_x, false
		)
	_set_disabled_state()
	EventBus.panel_closed.emit(PANEL_NAME)


func is_open() -> bool:
	return _is_open


func _toggle() -> void:
	if _is_open:
		close()
	else:
		if _current_item:
			open_for_item(_current_item)
		else:
			_open_empty()


func _open_empty() -> void:
	_current_item = null
	_set_disabled_state()
	if not _is_open:
		_is_open = true
		PanelAnimator.kill_tween(_anim_tween)
		_anim_tween = PanelAnimator.slide_open(
			_panel, _rest_x, false
		)
		EventBus.panel_opened.emit(PANEL_NAME)


func _populate_item_data(item: ItemInstance) -> void:
	var def: ItemDefinition = item.definition
	_item_name_label.text = def.name
	_condition_badge.text = item.condition.capitalize()
	_condition_badge.add_theme_color_override(
		"font_color", _get_condition_color(item.condition)
	)

	if def.icon_path and not def.icon_path.is_empty():
		var tex: Texture2D = load(def.icon_path) as Texture2D
		if tex:
			_item_icon.texture = tex
			_item_icon.visible = true
		else:
			_item_icon.visible = false
	else:
		_item_icon.visible = false

	var base: float = def.base_price
	var cond_mult: float = ItemInstance.CONDITION_MULTIPLIERS.get(
		item.condition, 1.0
	)
	var pr_multipliers: Array = []
	if economy_system:
		pr_multipliers = economy_system.get_item_multipliers(item)
	else:
		var rarity_mult: float = ItemInstance.calculate_effective_rarity(
			base, def.rarity
		)
		pr_multipliers = [
			{"slot": "rarity", "label": "Rarity", "factor": rarity_mult, "detail": def.rarity},
			{"slot": "condition", "label": "Condition", "factor": cond_mult, "detail": item.condition},
		]
	var pr_result: PriceResolver.Result = PriceResolver.resolve_for_item(
		StringName(item.instance_id), base, pr_multipliers, true
	)
	_market_value = pr_result.final_price

	_base_price_label.text = "Base Price: $%.2f" % base
	_condition_mult_label.text = (
		"Condition (%s): ×%.2f" % [item.condition.capitalize(), cond_mult]
	)
	_effective_base_label.text = (
		"Market Value: $%.2f" % _market_value
	)

	_apply_button.disabled = false
	_apply_all_button.disabled = false
	_markup_slider.editable = true
	_price_spin.editable = true

	var current_ratio: float = 1.0
	if _market_value > 0.0 and item.player_set_price > 0.0:
		current_ratio = clampf(
			item.player_set_price / _market_value, MIN_MARKUP, MAX_MARKUP
		)
	_set_slider_value(current_ratio)


func _set_disabled_state() -> void:
	_item_name_label.text = "No item selected"
	_condition_badge.text = ""
	_item_icon.visible = false
	_base_price_label.text = "Base Price: —"
	_condition_mult_label.text = "Condition: —"
	_effective_base_label.text = "Market Value: —"
	_markup_slider.editable = false
	_markup_slider.value = 1.0
	_price_spin.editable = false
	_price_spin.value = 0.0
	_markup_ratio_label.text = ""
	_feedback_label.text = ""
	_apply_button.disabled = true
	_apply_all_button.disabled = true


func _set_slider_value(ratio: float) -> void:
	_updating_from_slider = true
	_markup_slider.value = ratio
	_updating_from_slider = false
	_sync_price_from_ratio(ratio)
	_update_feedback(ratio)
	_update_color_bar(ratio)


func _on_slider_changed(value: float) -> void:
	if _updating_from_spin:
		return
	_updating_from_slider = true
	_sync_price_from_ratio(value)
	_update_feedback(value)
	_update_color_bar(value)
	_updating_from_slider = false


func _on_spin_changed(value: float) -> void:
	if _updating_from_slider:
		return
	if _market_value <= 0.0:
		return
	_updating_from_spin = true
	var ratio: float = clampf(
		value / _market_value, MIN_MARKUP, MAX_MARKUP
	)
	_markup_slider.value = ratio
	_update_feedback(ratio)
	_update_color_bar(ratio)
	_updating_from_spin = false


func _sync_price_from_ratio(ratio: float) -> void:
	if _market_value <= 0.0:
		return
	var price: float = snappedf(_market_value * ratio, 0.01)
	_updating_from_spin = true
	_price_spin.value = price
	_updating_from_spin = false
	var percent: int = roundi((ratio - 1.0) * 100.0)
	var sign_str: String = "+" if percent >= 0 else ""
	_markup_ratio_label.text = "%s%d%% (×%.2f)" % [
		sign_str, percent, ratio
	]
	_markup_ratio_label.add_theme_color_override(
		"font_color", _get_ratio_color(ratio)
	)


func _update_feedback(ratio: float) -> void:
	if ratio < ZONE_GREEN_MAX:
		_feedback_label.text = FEEDBACK_BELOW_MARKET
		_feedback_label.add_theme_color_override(
			"font_color", UIThemeConstants.get_positive_color()
		)
	elif ratio <= ZONE_BLUE_MAX:
		_feedback_label.text = FEEDBACK_AT_MARKET
		_feedback_label.add_theme_color_override(
			"font_color", UIThemeConstants.ACCENT_COLOR
		)
	elif ratio <= ZONE_YELLOW_MAX:
		_feedback_label.text = FEEDBACK_ABOVE_MARKET
		_feedback_label.add_theme_color_override(
			"font_color", UIThemeConstants.get_warning_color()
		)
	elif ratio <= 2.5:
		_feedback_label.text = FEEDBACK_PREMIUM
		_feedback_label.add_theme_color_override(
			"font_color", UIThemeConstants.get_negative_color()
		)
	else:
		_feedback_label.text = FEEDBACK_EXTREME
		_feedback_label.add_theme_color_override(
			"font_color", UIThemeConstants.get_negative_color()
		)


func _update_color_bar(ratio: float) -> void:
	if ratio < ZONE_GREEN_MAX:
		_color_bar.color = UIThemeConstants.get_positive_color()
	elif ratio <= ZONE_BLUE_MAX:
		_color_bar.color = Color(0.3, 0.5, 0.9, 1.0)
	elif ratio <= ZONE_YELLOW_MAX:
		_color_bar.color = UIThemeConstants.get_warning_color()
	else:
		_color_bar.color = UIThemeConstants.get_negative_color()


func _on_apply() -> void:
	if not _current_item:
		return
	var price: float = snappedf(_price_spin.value, 0.01)
	_current_item.player_set_price = price
	EventBus.price_set.emit(_current_item.instance_id, price)
	_emit_item_price_set(_current_item, price)
	PanelAnimator.pulse_scale(_apply_button)


func _on_apply_all() -> void:
	if not _current_item or not _current_item.definition:
		return
	if not inventory_system:
		push_warning("PricingPanel: no inventory_system for apply all")
		return
	var ratio: float = _markup_slider.value
	var def_id: String = _current_item.definition.id
	var store_id: String = _current_item.definition.store_type
	var items: Array[ItemInstance] = (
		inventory_system.get_items_for_store(store_id)
	)
	for item: ItemInstance in items:
		if not item.definition:
			continue
		if item.definition.id != def_id:
			continue
		var item_market: float = 0.0
		if economy_system:
			item_market = economy_system.calculate_market_value(item)
		else:
			item_market = item.get_current_value()
		if item_market <= 0.0:
			continue
		var new_price: float = snappedf(item_market * ratio, 0.01)
		item.player_set_price = new_price
		EventBus.price_set.emit(item.instance_id, new_price)
		_emit_item_price_set(item, new_price)
	PanelAnimator.pulse_scale(_apply_all_button)


func _on_active_store_changed(store_id: StringName) -> void:
	_apply_store_accent(store_id)


func _apply_store_accent(store_id_sn: StringName) -> void:
	var accent: Color = UIThemeConstants.get_store_accent(store_id_sn)
	var style := StyleBoxFlat.new()
	style.bg_color = UIThemeConstants.DARK_PANEL_FILL
	style.border_color = accent
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12.0
	style.content_margin_top = 10.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 10.0
	_panel.add_theme_stylebox_override(&"panel", style)


func _emit_item_price_set(item: ItemInstance, price: float) -> void:
	if not item or not item.definition:
		return
	var market_value: float = _market_value
	if economy_system:
		market_value = economy_system.calculate_market_value(item)
	elif item != _current_item:
		market_value = item.get_current_value()
	if market_value <= 0.0:
		return
	var ratio: float = price / market_value
	var store_id: StringName = StringName(item.definition.store_type)
	if ContentRegistry.exists(item.definition.store_type):
		store_id = ContentRegistry.resolve(item.definition.store_type)
	EventBus.item_price_set.emit(
		store_id,
		StringName(item.instance_id),
		price,
		ratio,
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
		return
	open_for_item(item)


func _on_panel_opened(panel_name: String) -> void:
	if panel_name != PANEL_NAME and _is_open:
		close(true)


func _get_condition_color(cond: String) -> Color:
	match cond:
		"mint":
			return UIThemeConstants.get_positive_color()
		"near_mint":
			return Color(0.5, 0.85, 0.45, 1.0)
		"good":
			return UIThemeConstants.BODY_FONT_COLOR
		"fair":
			return UIThemeConstants.get_warning_color()
		"poor":
			return UIThemeConstants.get_negative_color()
		_:
			return UIThemeConstants.BODY_FONT_COLOR


func _get_ratio_color(ratio: float) -> Color:
	if ratio < ZONE_GREEN_MAX:
		return UIThemeConstants.get_positive_color()
	if ratio <= ZONE_BLUE_MAX:
		return Color(0.3, 0.5, 0.9, 1.0)
	if ratio <= ZONE_YELLOW_MAX:
		return UIThemeConstants.get_warning_color()
	return UIThemeConstants.get_negative_color()
