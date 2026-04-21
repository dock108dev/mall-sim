## Difficulty selection panel shown during new-game setup and optionally from the pause menu.
class_name DifficultySelectionPanel
extends CanvasLayer

## Emitted when the player confirms a difficulty tier selection.
signal difficulty_confirmed(tier_id: StringName)

const _STAT_KEYS: Array[StringName] = [
	&"starting_cash_multiplier",
	&"daily_rent_multiplier",
	&"foot_traffic_multiplier",
]
const _STAT_LABELS: Array[String] = ["Starting Cash", "Daily Rent", "Customer Traffic"]
const _BAR_MAX: float = 2.0
const _SELECTED_MODULATE: Color = Color(1.0, 1.0, 1.0, 1.0)
const _DESELECTED_MODULATE: Color = Color(0.65, 0.65, 0.65, 1.0)

@onready var _cards_row: HBoxContainer = $Panel/Margin/VBox/CardsRow
@onready var _assisted_dialog: ConfirmationDialog = $AssistedWarningDialog

var _tiers: Array[Dictionary] = []
var _tier_ids: Array[StringName] = []
var _selected_tier_id: StringName = &""
var _from_pause: bool = false
var _pending_tier_id: StringName = &""


func _ready() -> void:
	_load_tiers()
	_build_cards()
	_assisted_dialog.confirmed.connect(_on_assisted_confirmed)
	_assisted_dialog.canceled.connect(_on_assisted_canceled)


## Opens the panel. Pass from_pause=true when invoked from the pause menu.
func open(from_pause: bool = false) -> void:
	_from_pause = from_pause
	_selected_tier_id = DifficultySystemSingleton.get_current_tier_id()
	_highlight_card(_selected_tier_id)
	show()


func _load_tiers() -> void:
	var config: Dictionary = DataLoaderSingleton.get_difficulty_config()
	if config.is_empty():
		var loaded: Variant = DataLoader.load_json(
			"res://game/content/economy/difficulty_config.json"
		)
		if loaded is Dictionary:
			config = loaded as Dictionary
	var tiers_array: Array = config.get("tiers", [])
	for tier_data: Variant in tiers_array:
		var tier: Dictionary = tier_data as Dictionary
		var id: StringName = StringName(tier.get("id", ""))
		if id.is_empty():
			continue
		_tiers.append(tier)
		_tier_ids.append(id)


func _build_cards() -> void:
	for i: int in range(_tiers.size()):
		var card: PanelContainer = _build_card(_tiers[i], _tier_ids[i])
		_cards_row.add_child(card)


func _build_card(tier: Dictionary, tier_id: StringName) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.name = "Card_" + String(tier_id)
	card.custom_minimum_size = Vector2(200, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	card.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	_add_name_label(vbox, tier, tier_id)
	_add_tagline_label(vbox, tier)
	vbox.add_child(HSeparator.new())
	_build_stat_bars(vbox, tier)
	_add_spacer(vbox)
	_add_select_button(vbox, tier_id)

	return card


func _add_name_label(parent: VBoxContainer, tier: Dictionary, tier_id: StringName) -> void:
	var label: Label = Label.new()
	label.text = tier.get("display_name", String(tier_id)) as String
	label.theme_type_variation = &"HeaderLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)


func _add_tagline_label(parent: VBoxContainer, tier: Dictionary) -> void:
	var label: Label = Label.new()
	label.text = tier.get("tagline", "") as String
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
	parent.add_child(label)


func _build_stat_bars(parent: VBoxContainer, tier: Dictionary) -> void:
	var modifiers: Dictionary = tier.get("modifiers", {})
	var stats_box: VBoxContainer = VBoxContainer.new()
	stats_box.add_theme_constant_override("separation", 4)
	parent.add_child(stats_box)

	for i: int in range(_STAT_KEYS.size()):
		var key: String = String(_STAT_KEYS[i])
		var value: float = float(modifiers.get(key, 1.0))
		_add_stat_row(stats_box, _STAT_LABELS[i], value)


func _add_stat_row(parent: VBoxContainer, stat_label: String, value: float) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	var label: Label = Label.new()
	label.text = stat_label
	label.custom_minimum_size = Vector2(110, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	var bar: ProgressBar = ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = _BAR_MAX
	bar.value = value
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.show_percentage = false
	row.add_child(bar)


func _add_spacer(parent: VBoxContainer) -> void:
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.custom_minimum_size = Vector2(0, 8)
	parent.add_child(spacer)


func _add_select_button(parent: VBoxContainer, tier_id: StringName) -> void:
	var btn: Button = Button.new()
	btn.text = "Select"
	btn.custom_minimum_size = Vector2(0, 36)
	btn.pressed.connect(_on_select_pressed.bind(tier_id))
	parent.add_child(btn)


func _highlight_card(tier_id: StringName) -> void:
	for child: Node in _cards_row.get_children():
		var card: PanelContainer = child as PanelContainer
		if card == null:
			continue
		if card.name == "Card_" + String(tier_id):
			card.modulate = _SELECTED_MODULATE
		else:
			card.modulate = _DESELECTED_MODULATE


func _on_select_pressed(tier_id: StringName) -> void:
	_selected_tier_id = tier_id
	_highlight_card(tier_id)

	if _from_pause and _get_current_day() > 1 and _is_lower_tier(tier_id):
		_pending_tier_id = tier_id
		_assisted_dialog.popup_centered()
		return

	_confirm_selection(tier_id)


func _on_assisted_confirmed() -> void:
	_confirm_selection(_pending_tier_id)
	_pending_tier_id = &""


func _on_assisted_canceled() -> void:
	_selected_tier_id = DifficultySystemSingleton.get_current_tier_id()
	_highlight_card(_selected_tier_id)
	_pending_tier_id = &""


func _confirm_selection(tier_id: StringName) -> void:
	DifficultySystemSingleton.set_tier(tier_id)
	difficulty_confirmed.emit(tier_id)
	hide()


func _is_lower_tier(new_id: StringName) -> bool:
	var current_idx: int = _tier_ids.find(DifficultySystemSingleton.get_current_tier_id())
	var new_idx: int = _tier_ids.find(new_id)
	if current_idx < 0 or new_idx < 0:
		return false
	return new_idx < current_idx


func _get_current_day() -> int:
	var time_system: TimeSystem = GameManager.get_time_system()
	if time_system == null:
		return 1
	return time_system.current_day
