## Fullscreen overlay that reveals booster pack cards one by one on click.
class_name PackOpeningPanel
extends CanvasLayer

# Localization marker for static validation: tr("PACK_OPENING_TITLE")

const PANEL_NAME: String = "pack_opening"
const CARDS_PER_PACK: int = 5
const FLIP_DURATION: float = 0.3
const RARE_HOLD_DURATION: float = 1.5
const GLOW_FLASH_DURATION: float = 0.4
const CARD_SIZE: Vector2 = Vector2(120, 170)
const RARE_RARITIES: Array[String] = [
	"rare", "ultra_rare",
]
const RARITY_COLORS: Dictionary = {
	"common": Color.WHITE,
	"uncommon": UIThemeConstants.RARITY_COLORS["uncommon"],
	"rare": UIThemeConstants.RARITY_COLORS["rare"],
	"ultra_rare": UIThemeConstants.RARITY_COLORS["very_rare"],
}
const RARITY_PIPS: Dictionary = {
	"common": "o",
	"uncommon": "<>",
	"rare": "*",
	"ultra_rare": "**",
}
const RARITY_LABELS: Dictionary = {
	"common": "Common",
	"uncommon": "Uncommon",
	"rare": "Rare",
	"ultra_rare": "Ultra Rare",
}

var _cards: Array[Dictionary] = []
var _revealed_count: int = 0
var _is_open: bool = false
var _is_flipping: bool = false
var _anim_tween: Tween
var _flip_tween: Tween
var _glow_tween: Tween
var pack_opening_system: PackOpeningSystem = null

@onready var _background: ColorRect = $Background
@onready var _panel: PanelContainer = $PanelRoot
@onready var _title_label: Label = (
	$PanelRoot/Margin/VBox/TitleLabel
)
@onready var _card_row: HBoxContainer = (
	$PanelRoot/Margin/VBox/CardRow
)
@onready var _add_button: Button = (
	$PanelRoot/Margin/VBox/ButtonHBox/AddToInventoryButton
)
@onready var _total_value_label: Label = (
	$PanelRoot/Margin/VBox/TotalValueLabel
)


func _ready() -> void:
	_panel.visible = false
	_background.visible = false
	_add_button.visible = false
	_add_button.disabled = false
	_add_button.pressed.connect(_on_add_to_inventory)
	EventBus.pack_opening_started.connect(_on_pack_opening_started)


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event:
		return
	if key_event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()


func _on_pack_opening_started(
	pack_id: String, card_results: Array[Dictionary],
) -> void:
	open(pack_id, card_results)


## Opens the panel with face-down cards for the player to flip.
func open(
	_pack_id: String, card_results: Array[Dictionary],
) -> void:
	if _is_open:
		return
	_cards = card_results
	_revealed_count = 0
	_is_open = true
	_is_flipping = false
	_add_button.disabled = false
	_title_label.text = "Click a card to reveal it!"
	_total_value_label.text = ""
	_add_button.visible = false
	_clear_card_row()
	_create_face_down_cards()
	_background.visible = true
	PanelAnimator.kill_tween(_anim_tween)
	_anim_tween = PanelAnimator.modal_open(_panel)
	EventBus.panel_opened.emit(PANEL_NAME)


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	_is_flipping = false
	_cards = []
	_kill_tweens()
	_background.visible = false
	PanelAnimator.kill_tween(_anim_tween)
	_anim_tween = PanelAnimator.modal_close(_panel)
	_anim_tween.finished.connect(
		func() -> void: EventBus.panel_closed.emit(PANEL_NAME),
		CONNECT_ONE_SHOT,
	)


func is_open() -> bool:
	return _is_open


func _kill_tweens() -> void:
	PanelAnimator.kill_tween(_flip_tween)
	PanelAnimator.kill_tween(_glow_tween)
	_flip_tween = null
	_glow_tween = null


func _clear_card_row() -> void:
	for child: Node in _card_row.get_children():
		child.queue_free()


func _create_face_down_cards() -> void:
	var count: int = mini(_cards.size(), CARDS_PER_PACK)
	for i: int in range(count):
		var card_button: Button = _build_card_back(i)
		_card_row.add_child(card_button)


func _build_card_back(index: int) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = CARD_SIZE
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.clip_text = true
	btn.rotation_degrees = lerpf(-8.0, 8.0, float(index) / maxf(CARDS_PER_PACK - 1.0, 1.0))
	btn.set_meta("card_index", index)
	btn.set_meta("revealed", false)

	var vbox := VBoxContainer.new()
	vbox.name = "CardContent"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)

	var art_rect := ColorRect.new()
	art_rect.name = "ArtPlaceholder"
	art_rect.custom_minimum_size = Vector2(80, 60)
	art_rect.color = Color(0.25, 0.25, 0.35, 1.0)
	art_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(art_rect)

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = "?"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(name_label)

	var rarity_row := HBoxContainer.new()
	rarity_row.name = "RarityRow"
	rarity_row.alignment = BoxContainer.ALIGNMENT_CENTER
	rarity_row.add_theme_constant_override("separation", 4)

	var rarity_pip := Label.new()
	rarity_pip.name = "RarityPip"
	rarity_pip.text = ""
	rarity_pip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_pip.add_theme_font_size_override("font_size", 12)
	rarity_row.add_child(rarity_pip)

	var rarity_label := Label.new()
	rarity_label.name = "RarityLabel"
	rarity_label.text = ""
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_label.add_theme_font_size_override("font_size", 11)
	rarity_row.add_child(rarity_label)
	vbox.add_child(rarity_row)

	var value_label := Label.new()
	value_label.name = "ValueLabel"
	value_label.text = ""
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(value_label)

	btn.add_child(vbox)
	btn.pressed.connect(_on_card_clicked.bind(btn))
	return btn


func _on_card_clicked(btn: Button) -> void:
	if _is_flipping:
		return
	if not _is_open:
		return
	var revealed: bool = btn.get_meta("revealed", false)
	if revealed:
		return
	var index: int = btn.get_meta("card_index", -1)
	if index < 0 or index >= _cards.size():
		return
	btn.set_meta("revealed", true)
	_is_flipping = true
	_flip_card(btn, index)


func _flip_card(btn: Button, index: int) -> void:
	var card_data: Dictionary = _cards[index]
	var half: float = FLIP_DURATION * 0.5

	btn.pivot_offset = btn.size / 2.0
	PanelAnimator.kill_tween(_flip_tween)
	_flip_tween = btn.create_tween()

	_flip_tween.tween_property(
		btn, "scale:x", 0.0, half
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)

	_flip_tween.tween_callback(
		_populate_card_face.bind(btn, card_data)
	)

	_flip_tween.tween_property(
		btn, "scale:x", 1.0, half
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	var rarity: String = _normalize_rarity(
		str(card_data.get("rarity", "common"))
	)
	if rarity in RARE_RARITIES:
		_flip_tween.tween_callback(
			_play_rare_fanfare.bind(btn, rarity)
		)
		_flip_tween.tween_interval(RARE_HOLD_DURATION)

	_flip_tween.tween_callback(_on_flip_complete)


func _populate_card_face(
	btn: Button, card_data: Dictionary,
) -> void:
	var vbox: VBoxContainer = (
		btn.get_node("CardContent") as VBoxContainer
	)
	if not vbox:
		return

	var art: ColorRect = (
		vbox.get_node("ArtPlaceholder") as ColorRect
	)
	var rarity: String = _normalize_rarity(
		str(card_data.get("rarity", "common"))
	)
	if art:
		art.color = _get_rarity_color(rarity)

	var name_label: Label = vbox.get_node("NameLabel") as Label
	if name_label:
		name_label.text = card_data.get("name", "Unknown")

	var rarity_pip: Label = vbox.get_node("RarityRow/RarityPip") as Label
	if rarity_pip:
		rarity_pip.text = _get_rarity_pip(rarity)
		rarity_pip.add_theme_color_override(
			"font_color",
			_get_rarity_color(rarity),
		)

	var rarity_label: Label = (
		vbox.get_node("RarityRow/RarityLabel") as Label
	)
	if rarity_label:
		rarity_label.text = _get_rarity_label(rarity)
		rarity_label.add_theme_color_override(
			"font_color",
			_get_rarity_color(rarity),
		)

	var value_label: Label = vbox.get_node("ValueLabel") as Label
	if value_label:
		var value: float = card_data.get("value", 0.0)
		value_label.text = "$%.2f" % value


func _play_rare_fanfare(btn: Button, rarity: String) -> void:
	var glow_color: Color = _get_rarity_color(rarity)
	var flash_color := Color(
		glow_color.r, glow_color.g, glow_color.b, 0.6
	)
	PanelAnimator.kill_tween(_glow_tween)
	_glow_tween = btn.create_tween()
	_glow_tween.tween_property(
		btn, "modulate", flash_color, GLOW_FLASH_DURATION * 0.3
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_glow_tween.tween_property(
		btn, "modulate", Color.WHITE, GLOW_FLASH_DURATION * 0.7
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	PanelAnimator.pulse_scale(btn, 1.2, GLOW_FLASH_DURATION)


func _on_flip_complete() -> void:
	_is_flipping = false
	_revealed_count += 1
	if _revealed_count >= mini(_cards.size(), CARDS_PER_PACK):
		_show_add_button()


func _show_add_button() -> void:
	_title_label.text = "All cards revealed!"
	_update_total_value()
	_add_button.visible = true
	_add_button.disabled = false
	PanelAnimator.pulse_scale(_add_button, 1.1, 0.25)


func _update_total_value() -> void:
	var total: float = 0.0
	for card: Dictionary in _get_revealed_cards():
		total += card.get("value", 0.0)
	_total_value_label.text = "Total Value: $%.2f" % total


func _on_add_to_inventory() -> void:
	if not _is_open:
		return
	if _revealed_count < _card_row.get_child_count():
		return
	if not pack_opening_system:
		push_error("PackOpeningPanel: pack_opening_system not set")
		return
	_add_button.disabled = true
	if not pack_opening_system.commit_pack_results(_get_revealed_cards()):
		_add_button.disabled = false
		return
	close()


func _get_revealed_cards() -> Array[Dictionary]:
	var revealed_cards: Array[Dictionary] = []
	for i: int in range(_card_row.get_child_count()):
		var button: Button = _card_row.get_child(i) as Button
		if not button or not button.get_meta("revealed", false):
			continue
		var card_index: int = int(button.get_meta("card_index", -1))
		if card_index < 0 or card_index >= _cards.size():
			continue
		revealed_cards.append(_cards[card_index])
	return revealed_cards


func _normalize_rarity(rarity: String) -> String:
	if rarity in RARITY_LABELS:
		return rarity
	match rarity:
		"rare_holo", "secret_rare", "very_rare", "legendary":
			return "ultra_rare"
		"rare":
			return "rare"
		"uncommon":
			return "uncommon"
		_:
			return "common"


func _get_rarity_color(rarity: String) -> Color:
	return RARITY_COLORS.get(_normalize_rarity(rarity), Color.WHITE)


func _get_rarity_pip(rarity: String) -> String:
	return RARITY_PIPS.get(_normalize_rarity(rarity), "o")


func _get_rarity_label(rarity: String) -> String:
	return RARITY_LABELS.get(_normalize_rarity(rarity), "Common")
