## Build mode fixture catalog panel for browsing and selecting fixtures.
class_name FixtureCatalog
extends CanvasLayer

const PANEL_NAME: String = "fixture_catalog"
const PLACEMENT_PUNCH_SCALE: float = 1.08
const PLACEMENT_PUNCH_DURATION: float = 0.2

var data_loader: DataLoader
var economy_system: EconomySystem
var placement_system: FixturePlacementSystem
var store_type: String = "sports_memorabilia"
var current_reputation: float = 0.0
var current_day: int = 1

var _is_open: bool = false
var _selected_fixture_id: String = ""
var _anim_tween: Tween
var _feedback_tween: Tween
var _rest_x: float = 0.0

@onready var _panel: PanelContainer = $PanelRoot
@onready var _close_button: Button = (
	$PanelRoot/Margin/VBox/Header/CloseButton
)
@onready var _cash_label: Label = (
	$PanelRoot/Margin/VBox/Header/CashLabel
)
@onready var _universal_grid: GridContainer = (
	$PanelRoot/Margin/VBox/UniversalSection/UniversalScroll/UniversalGrid
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
	EventBus.fixture_placement_invalid.connect(
		_on_fixture_placement_invalid
	)


func open() -> void:
	if _is_open:
		return
	if not data_loader:
		push_warning("FixtureCatalog: no data_loader assigned")
		return
	_is_open = true
	_selected_fixture_id = ""
	_update_cash_display()
	_refresh_catalog()
	_update_info_label()
	PanelAnimator.kill_tween(_anim_tween)
	_anim_tween = PanelAnimator.slide_open(
		_panel, _rest_x, false
	)
	EventBus.panel_opened.emit(PANEL_NAME)


func close(immediate: bool = false) -> void:
	if not _is_open:
		return
	_is_open = false
	_selected_fixture_id = ""
	PanelAnimator.kill_tween(_anim_tween)
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


func _refresh_catalog() -> void:
	_clear_grid(_universal_grid)
	_clear_grid(_specific_grid)

	var fixtures: Array[FixtureDefinition] = (
		data_loader.get_fixtures_for_store(store_type)
	)
	for fixture: FixtureDefinition in fixtures:
		var target_grid: GridContainer = _universal_grid
		if fixture.category == "store_specific":
			target_grid = _specific_grid
		_create_fixture_button(fixture, target_grid)


func _clear_grid(grid: GridContainer) -> void:
	for child: Node in grid.get_children():
		child.queue_free()


func _create_fixture_button(
	fixture: FixtureDefinition,
	grid: GridContainer
) -> void:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(200, 70)

	var is_locked: bool = _is_fixture_locked(fixture)
	var cash: float = _get_current_cash()
	var is_unaffordable: bool = fixture.price > cash

	var label_text: String = tr("FIXTURE_INFO") % [
		fixture.name,
		fixture.price,
		fixture.grid_size.x,
		fixture.grid_size.y,
		fixture.slot_count,
	]

	if is_locked:
		label_text += "\n%s" % _get_unlock_text(fixture)
		btn.disabled = true
		btn.modulate = Color(0.5, 0.5, 0.5, 0.7)
	elif is_unaffordable:
		label_text += "\n" + tr("FIXTURE_INSUFFICIENT_FUNDS")
		btn.disabled = true
		btn.modulate = Color(0.8, 0.4, 0.4, 0.9)

	btn.text = label_text
	btn.pressed.connect(
		_on_fixture_selected.bind(fixture.id, btn)
	)
	grid.add_child(btn)


func _is_fixture_locked(fixture: FixtureDefinition) -> bool:
	if fixture.unlock_condition.is_empty():
		return false
	if fixture.unlock_condition.has("reputation"):
		var req: float = float(fixture.unlock_condition["reputation"])
		if current_reputation < req:
			return true
	if fixture.unlock_condition.has("day"):
		var req_day: int = int(fixture.unlock_condition["day"])
		if current_day < req_day:
			return true
	return false


func _get_unlock_text(fixture: FixtureDefinition) -> String:
	var parts: PackedStringArray = []
	if fixture.unlock_condition.has("reputation"):
		parts.append(
			tr("FIXTURE_UNLOCK_REP") % int(
				fixture.unlock_condition["reputation"]
			)
		)
	if fixture.unlock_condition.has("day"):
		parts.append(
			tr("FIXTURE_UNLOCK_DAY") % int(
				fixture.unlock_condition["day"]
			)
		)
	if parts.is_empty():
		return tr("FIXTURE_LOCKED")
	return "[%s]" % ", ".join(parts)


func _on_fixture_selected(
	fixture_id: String, btn: Button
) -> void:
	_selected_fixture_id = fixture_id
	_highlight_selected(btn)

	if placement_system:
		placement_system.select_fixture(fixture_id)
	EventBus.fixture_selected.emit(fixture_id)
	_update_info_label()


func _highlight_selected(active_btn: Button) -> void:
	for child: Node in _universal_grid.get_children():
		if child is Button and not (child as Button).disabled:
			(child as Button).modulate = Color.WHITE
	for child: Node in _specific_grid.get_children():
		if child is Button and not (child as Button).disabled:
			(child as Button).modulate = Color.WHITE
	active_btn.modulate = Color(0.7, 1.0, 0.7)


func _update_info_label() -> void:
	if _selected_fixture_id.is_empty():
		_info_label.text = tr("FIXTURE_SELECT_HINT")
		return
	var def: FixtureDefinition = data_loader.get_fixture(
		_selected_fixture_id
	)
	if def:
		_info_label.text = tr("FIXTURE_PLACING") % def.name
	else:
		_info_label.text = tr("FIXTURE_SELECT_FALLBACK")


func _get_current_cash() -> float:
	if economy_system:
		return economy_system.get_cash()
	return 0.0


func _update_cash_display() -> void:
	_cash_label.text = tr("ORDER_CASH") % _get_current_cash()


func _on_money_changed(
	_old_amount: float, new_amount: float
) -> void:
	if _is_open:
		_cash_label.text = tr("ORDER_CASH") % new_amount
		_refresh_catalog()


func _on_panel_opened(panel_name: String) -> void:
	if panel_name != PANEL_NAME and _is_open:
		close(true)


func _on_build_mode_entered() -> void:
	current_day = GameManager.current_day
	PanelAnimator.kill_tween(_anim_tween)
	_anim_tween = create_tween()
	_anim_tween.tween_interval(0.1)
	_anim_tween.tween_callback(open)


func _on_build_mode_exited() -> void:
	PanelAnimator.kill_tween(_anim_tween)
	close()


func _on_fixture_placed(
	_fixture_id: String, _grid_pos: Vector2i
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
		_panel, UIThemeConstants.get_negative_color(),
		PanelAnimator.FEEDBACK_SHAKE_DURATION
	)
