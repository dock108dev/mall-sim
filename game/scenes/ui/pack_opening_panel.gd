## UI panel that reveals cards from an opened booster pack one by one.
class_name PackOpeningPanel
extends CanvasLayer

const PANEL_NAME: String = "pack_opening"
const REVEAL_DELAY: float = 0.35
var _cards: Array[ItemInstance] = []
var _reveal_index: int = 0
var _is_open: bool = false
var _anim_tween: Tween
var _reveal_timer: float = 0.0
var _revealing: bool = false

@onready var _panel: PanelContainer = $PanelRoot
@onready var _title_label: Label = (
	$PanelRoot/Margin/VBox/TitleLabel
)
@onready var _card_grid: GridContainer = (
	$PanelRoot/Margin/VBox/ScrollContainer/CardGrid
)
@onready var _close_button: Button = (
	$PanelRoot/Margin/VBox/ButtonHBox/CloseButton
)
@onready var _total_value_label: Label = (
	$PanelRoot/Margin/VBox/TotalValueLabel
)


func _ready() -> void:
	_panel.visible = false
	_close_button.pressed.connect(close)
	_close_button.disabled = true


func _process(delta: float) -> void:
	if not _revealing:
		return
	_reveal_timer -= delta
	if _reveal_timer > 0.0:
		return
	if _reveal_index >= _cards.size():
		_revealing = false
		_close_button.disabled = false
		_update_total_value()
		return
	_show_card_at_index(_reveal_index)
	_reveal_index += 1
	_reveal_timer = REVEAL_DELAY


## Opens the panel and begins card reveal sequence.
func open(cards: Array[ItemInstance], pack_name: String) -> void:
	if _is_open:
		return
	_cards = cards
	_reveal_index = 0
	_revealing = true
	_reveal_timer = 0.0
	_is_open = true
	_title_label.text = tr("PACK_OPENING_TITLE") % pack_name
	_total_value_label.text = ""
	_close_button.disabled = true
	_clear_grid()
	_create_card_placeholders()
	PanelAnimator.kill_tween(_anim_tween)
	_anim_tween = PanelAnimator.modal_open(_panel)
	EventBus.panel_opened.emit(PANEL_NAME)


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	_revealing = false
	_cards = []
	PanelAnimator.kill_tween(_anim_tween)
	_anim_tween = PanelAnimator.modal_close(_panel)
	_anim_tween.finished.connect(
		func() -> void: EventBus.panel_closed.emit(PANEL_NAME),
		CONNECT_ONE_SHOT,
	)


func is_open() -> bool:
	return _is_open


func _clear_grid() -> void:
	for child: Node in _card_grid.get_children():
		child.queue_free()


func _create_card_placeholders() -> void:
	for i: int in range(_cards.size()):
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(140, 80)
		cell.modulate = Color(0.3, 0.3, 0.3, 0.5)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 2)

		var name_label := Label.new()
		name_label.name = "NameLabel"
		name_label.text = "???"
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 12)
		vbox.add_child(name_label)

		var rarity_label := Label.new()
		rarity_label.name = "RarityLabel"
		rarity_label.text = ""
		rarity_label.horizontal_alignment = (
			HORIZONTAL_ALIGNMENT_CENTER
		)
		rarity_label.add_theme_font_size_override("font_size", 10)
		vbox.add_child(rarity_label)

		var value_label := Label.new()
		value_label.name = "ValueLabel"
		value_label.text = ""
		value_label.horizontal_alignment = (
			HORIZONTAL_ALIGNMENT_CENTER
		)
		value_label.add_theme_font_size_override("font_size", 10)
		vbox.add_child(value_label)

		cell.add_child(vbox)
		_card_grid.add_child(cell)


func _show_card_at_index(index: int) -> void:
	if index < 0 or index >= _cards.size():
		return
	var card: ItemInstance = _cards[index]
	var cell: PanelContainer = (
		_card_grid.get_child(index) as PanelContainer
	)
	if not cell:
		return

	cell.modulate = Color.WHITE
	var vbox: VBoxContainer = cell.get_child(0) as VBoxContainer
	if not vbox:
		return

	var name_label: Label = vbox.get_node("NameLabel") as Label
	var rarity_label: Label = (
		vbox.get_node("RarityLabel") as Label
	)
	var value_label: Label = (
		vbox.get_node("ValueLabel") as Label
	)

	if name_label and card.definition:
		name_label.text = card.definition.name
	if rarity_label and card.definition:
		var rarity_display: String = UIThemeConstants.get_rarity_display(
			card.definition.rarity
		)
		rarity_label.text = "[%s]" % rarity_display
		var color: Color = UIThemeConstants.get_rarity_color(
			card.definition.rarity
		)
		rarity_label.add_theme_color_override("font_color", color)
	if value_label:
		value_label.text = "$%.2f" % card.get_current_value()


func _update_total_value() -> void:
	var total: float = 0.0
	for card: ItemInstance in _cards:
		total += card.get_current_value()
	_total_value_label.text = tr("PACK_TOTAL_VALUE") % total
