## Slide-in fixture catalog panel for build mode placement selection.
class_name FixtureCatalogPanel
extends CanvasLayer

const PANEL_NAME: StringName = &"fixture_catalog"
const PLACE_BUTTON_TEXT: String = "Place"
const SELECTED_BUTTON_TEXT: String = "Selected"
const LOCKED_COLOR: Color = Color(0.5, 0.5, 0.5, 0.7)
const UNAFFORDABLE_COLOR: Color = Color(0.75, 0.55, 0.55, 0.9)
const SELECTED_COLOR: Color = Color(0.74, 0.95, 0.78, 1.0)
const PLACEABLE_COLOR: Color = Color.WHITE
const PLACEMENT_PUNCH_SCALE: float = 1.08
const PLACEMENT_PUNCH_DURATION: float = 0.2

var data_loader: DataLoader
var economy_system: EconomySystem
var store_type: StringName = &""

var _is_open: bool = false
var _selected_fixture_id: StringName = &""
var _anim_tween: Tween
var _feedback_tween: Tween
var _rest_x: float = 0.0
var _current_day_snapshot: int = 1
var _card_buttons: Dictionary = {}
var _card_panels: Dictionary = {}

@onready var _panel: PanelContainer = $PanelRoot
@onready var _close_button: Button = (
	$PanelRoot/Margin/VBox/Header/CloseButton
)
@onready var _cash_label: Label = (
	$PanelRoot/Margin/VBox/Header/CashLabel
)
@onready var _universal_section: VBoxContainer = (
	$PanelRoot/Margin/VBox/UniversalSection
)
@onready var _universal_grid: GridContainer = (
	$PanelRoot/Margin/VBox/UniversalSection/UniversalScroll/UniversalGrid
)
@onready var _specific_section: VBoxContainer = (
	$PanelRoot/Margin/VBox/SpecificSection
)
@onready var _specific_grid: GridContainer = (
	$PanelRoot/Margin/VBox/SpecificSection/SpecificScroll/SpecificGrid
)
@onready var _info_label: Label = (
	$PanelRoot/Margin/VBox/InfoLabel
)


func _ready() -> void:
	_panel.visible = false
	_rest_x = _panel.position.x
	_close_button.pressed.connect(close)
	EventBus.panel_opened.connect(_on_panel_opened)
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.build_mode_entered.connect(_on_build_mode_entered)
	EventBus.build_mode_exited.connect(_on_build_mode_exited)
	EventBus.fixture_placed.connect(_on_fixture_placed)
	EventBus.fixture_placement_invalid.connect(_on_fixture_placement_invalid)
	EventBus.active_store_changed.connect(_on_active_store_changed)
	EventBus.reputation_changed.connect(_on_reputation_changed)


## Opens the fixture catalog and refreshes available fixtures.
func open() -> void:
	if _is_open:
		return
	if data_loader == null:
		push_warning("FixtureCatalogPanel: missing data_loader")
		return
	var active_store_id: StringName = _get_active_store_id()
	if active_store_id.is_empty():
		push_warning("FixtureCatalogPanel: missing active store")
		return
	_is_open = true
	_selected_fixture_id = &""
	_sync_runtime_state()
	_update_cash_display()
	_refresh_catalog()
	_update_info_label()
	PanelAnimator.kill_tween(_anim_tween)
	_anim_tween = PanelAnimator.slide_open(_panel, _rest_x, false)
	EventBus.panel_opened.emit(PANEL_NAME)


## Closes the fixture catalog.
func close(immediate: bool = false) -> void:
	if not _is_open:
		return
	_is_open = false
	_selected_fixture_id = &""
	PanelAnimator.kill_tween(_anim_tween)
	if immediate:
		_panel.visible = false
		_panel.position.x = _rest_x
	else:
		_anim_tween = PanelAnimator.slide_close(_panel, _rest_x, false)
	EventBus.panel_closed.emit(PANEL_NAME)
	_update_info_label()


## Returns true when the panel is currently open.
func is_open() -> bool:
	return _is_open


func _refresh_catalog() -> void:
	_clear_grid(_universal_grid)
	_clear_grid(_specific_grid)
	_card_buttons.clear()
	_card_panels.clear()
	var fixtures: Array[FixtureDefinition] = data_loader.get_fixtures_for_store(
		String(_get_active_store_id())
	)
	fixtures.sort_custom(_sort_fixture_definitions)
	var universal_count: int = 0
	var specific_count: int = 0
	for fixture: FixtureDefinition in fixtures:
		if fixture.category == "store_specific":
			specific_count += 1
			_specific_grid.add_child(_create_fixture_card(fixture))
		else:
			universal_count += 1
			_universal_grid.add_child(_create_fixture_card(fixture))
	_universal_section.visible = universal_count > 0
	_specific_section.visible = specific_count > 0
	_update_selection_state()


func _clear_grid(grid: GridContainer) -> void:
	for child: Node in grid.get_children():
		child.queue_free()


func _create_fixture_card(fixture: FixtureDefinition) -> Control:
	var card := PanelContainer.new()
	card.name = "%sCard" % fixture.id
	card.custom_minimum_size = Vector2(260.0, 120.0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	margin.add_child(content)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	content.add_child(header)

	header.add_child(_build_icon_placeholder())
	header.add_child(_build_title_block(fixture))
	content.add_child(_build_meta_label(fixture))

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	content.add_child(footer)

	var status_label := Label.new()
	status_label.name = "StatusLabel"
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var status_text: String = _get_fixture_status_text(fixture)
	status_label.text = status_text
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.add_child(status_label)

	var button := Button.new()
	button.name = "SelectButton"
	button.custom_minimum_size = Vector2(92.0, 32.0)
	button.text = PLACE_BUTTON_TEXT
	var locked: bool = _is_fixture_locked(fixture)
	var affordable: bool = fixture.cost <= _get_current_cash()
	button.disabled = locked or not affordable
	button.pressed.connect(_on_fixture_requested.bind(fixture.id))
	footer.add_child(button)

	if locked:
		card.modulate = LOCKED_COLOR
		var tooltip: String = _get_unlock_tooltip(fixture)
		card.tooltip_text = tooltip
		button.tooltip_text = tooltip
	elif not affordable:
		card.modulate = UNAFFORDABLE_COLOR
		var shortfall: float = fixture.cost - _get_current_cash()
		var tooltip: String = "Need $%.0f more cash" % shortfall
		card.tooltip_text = tooltip
		button.tooltip_text = tooltip
	else:
		card.modulate = PLACEABLE_COLOR

	_card_buttons[fixture.id] = button
	_card_panels[fixture.id] = card
	return card


func _build_icon_placeholder() -> Control:
	var icon_shell := PanelContainer.new()
	icon_shell.custom_minimum_size = Vector2(44.0, 44.0)
	icon_shell.name = "IconPlaceholder"
	var label := Label.new()
	label.text = "ICON"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon_shell.add_child(label)
	return icon_shell


func _build_title_block(fixture: FixtureDefinition) -> Control:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 2)

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = fixture.display_name
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(name_label)

	var cost_label := Label.new()
	cost_label.name = "CostLabel"
	cost_label.text = "Cost: $%.0f" % fixture.cost
	cost_label.modulate = Color(0.82, 0.82, 0.82)
	column.add_child(cost_label)
	return column


func _build_meta_label(fixture: FixtureDefinition) -> Label:
	var sellback: float = fixture.get_sellback_price()
	var meta_label := Label.new()
	meta_label.name = "MetaLabel"
	meta_label.text = "Slots: %d   Sell-back: $%.0f" % [
		fixture.slot_count,
		sellback,
	]
	meta_label.modulate = Color(0.76, 0.76, 0.76)
	return meta_label


func _get_fixture_status_text(fixture: FixtureDefinition) -> String:
	if _is_fixture_locked(fixture):
		return _get_unlock_tooltip(fixture)
	if fixture.cost > _get_current_cash():
		return "Unavailable until you have $%.0f" % fixture.cost
	return "Ready to place"


func _get_unlock_tooltip(fixture: FixtureDefinition) -> String:
	var conditions: PackedStringArray = []
	if fixture.unlock_rep > 0.0:
		conditions.append("Reputation %.0f required" % fixture.unlock_rep)
	if fixture.unlock_day > 0:
		conditions.append("Day %d required" % fixture.unlock_day)
	if conditions.is_empty():
		return "Locked"
	return ", ".join(conditions)


func _is_fixture_locked(fixture: FixtureDefinition) -> bool:
	if fixture.unlock_rep > 0.0 and _get_current_reputation() < fixture.unlock_rep:
		return true
	if fixture.unlock_day > 0 and _current_day_snapshot < fixture.unlock_day:
		return true
	return false


func _on_fixture_requested(fixture_id: String) -> void:
	_selected_fixture_id = StringName(fixture_id)
	_update_selection_state()
	_update_info_label()
	EventBus.fixture_catalog_requested.emit(fixture_id)


func _update_selection_state() -> void:
	for fixture_id: Variant in _card_buttons.keys():
		var id: String = str(fixture_id)
		var button: Button = _card_buttons[id] as Button
		var card: PanelContainer = _card_panels[id] as PanelContainer
		if button == null or card == null or button.disabled:
			continue
		if id == String(_selected_fixture_id):
			button.text = SELECTED_BUTTON_TEXT
			card.modulate = SELECTED_COLOR
		else:
			button.text = PLACE_BUTTON_TEXT
			card.modulate = PLACEABLE_COLOR


func _update_info_label() -> void:
	if _selected_fixture_id.is_empty():
		_info_label.text = "Select a fixture, then click the grid to place it"
		return
	var fixture: FixtureDefinition = data_loader.get_fixture(String(_selected_fixture_id))
	if fixture == null:
		_info_label.text = "Select a fixture, then click the grid to place it"
		return
	_info_label.text = "Placing: %s" % fixture.display_name


func _get_current_cash() -> float:
	if economy_system == null:
		return 0.0
	return economy_system.get_cash()


func _get_current_reputation() -> float:
	if not is_instance_valid(ReputationSystemSingleton):
		return ReputationSystem.DEFAULT_REPUTATION
	return ReputationSystemSingleton.get_reputation(String(_get_active_store_id()))


func _get_active_store_id() -> StringName:
	var candidate: String = String(store_type)
	if candidate.is_empty():
		candidate = String(GameManager.get_active_store_id())
	if candidate.is_empty():
		return &""
	var resolved: StringName = ContentRegistry.resolve(candidate)
	if not resolved.is_empty():
		return resolved
	return StringName(candidate)


func _sync_runtime_state() -> void:
	var time_system: TimeSystem = GameManager.get_time_system()
	if time_system != null:
		_current_day_snapshot = time_system.current_day
	else:
		_current_day_snapshot = 1


func _sort_fixture_definitions(
	left: FixtureDefinition,
	right: FixtureDefinition
) -> bool:
	return left.display_name.naturalnocasecmp_to(right.display_name) < 0


func _update_cash_display() -> void:
	_cash_label.text = "Cash: $%.0f" % _get_current_cash()


func _on_panel_opened(panel_name: String) -> void:
	if panel_name != PANEL_NAME and _is_open:
		close(true)


func _on_money_changed(_old_amount: float, _new_amount: float) -> void:
	if not _is_open:
		return
	_update_cash_display()
	_refresh_catalog()


func _on_reputation_changed(
	store_id: String, _old_score: float, _new_score: float
) -> void:
	if not _is_open:
		return
	if ContentRegistry.resolve(store_id) != _get_active_store_id():
		return
	_refresh_catalog()


func _on_active_store_changed(new_store_id: StringName) -> void:
	store_type = new_store_id
	if not _is_open:
		return
	if new_store_id.is_empty():
		close(true)
		return
	_refresh_catalog()
	_update_info_label()


func _on_build_mode_entered() -> void:
	_sync_runtime_state()
	open()


func _on_build_mode_exited() -> void:
	PanelAnimator.kill_tween(_anim_tween)
	if _is_open:
		close()
		return
	_panel.visible = false
	_panel.position.x = _rest_x
	_selected_fixture_id = &""
	_update_info_label()


func _on_fixture_placed(
	_fixture_id: String, _grid_pos: Vector2i, _rotation: int
) -> void:
	if not _is_open:
		return
	PanelAnimator.kill_tween(_feedback_tween)
	_feedback_tween = PanelAnimator.pulse_scale(
		_panel, PLACEMENT_PUNCH_SCALE, PLACEMENT_PUNCH_DURATION
	)


func _on_fixture_placement_invalid(_reason: String) -> void:
	if not _is_open:
		return
	PanelAnimator.kill_tween(_feedback_tween)
	PanelAnimator.shake(_panel)
	_feedback_tween = PanelAnimator.flash_color(
		_panel,
		UIThemeConstants.get_negative_color(),
		PanelAnimator.FEEDBACK_SHAKE_DURATION
	)
