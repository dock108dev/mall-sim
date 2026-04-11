## Panel shown in build mode when selecting a placed fixture, with upgrade options.
class_name FixtureUpgradePanel
extends CanvasLayer

const PANEL_NAME: String = "fixture_upgrade"

var placement_system: FixturePlacementSystem
var data_loader: DataLoader
var economy_system: EconomySystem

var _is_open: bool = false
var _anim_tween: Tween
var _rest_x: float = 0.0
var _selected_fixture_id: String = ""

var _panel: PanelContainer
var _title_label: Label
var _tier_label: Label
var _slots_label: Label
var _bonus_label: Label
var _cost_label: Label
var _requirement_label: Label
var _upgrade_button: Button
var _close_button: Button


func _ready() -> void:
	_build_ui()
	_panel.visible = false
	_rest_x = _panel.position.x
	EventBus.fixture_selected.connect(_on_fixture_selected)
	EventBus.build_mode_exited.connect(close)
	EventBus.panel_opened.connect(_on_panel_opened)
	EventBus.fixture_upgraded.connect(_on_fixture_upgraded)


func open(fixture_id: String) -> void:
	if not placement_system or not data_loader:
		push_warning("FixtureUpgradePanel: missing system references")
		return
	var data: Dictionary = placement_system.get_fixture_data(
		fixture_id
	)
	if data.is_empty():
		return
	_selected_fixture_id = fixture_id
	_is_open = true
	_refresh_display()
	PanelAnimator.kill_tween(_anim_tween)
	_anim_tween = PanelAnimator.slide_open(_panel, _rest_x, false)
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


func _refresh_display() -> void:
	var data: Dictionary = placement_system.get_fixture_data(
		_selected_fixture_id
	)
	if data.is_empty():
		close()
		return

	var fixture_type: String = data.get("fixture_type", "") as String
	var tier: int = int(
		data.get("tier", FixtureDefinition.TierLevel.BASIC)
	)
	var def: FixtureDefinition = data_loader.get_fixture(fixture_type)
	if not def:
		close()
		return

	var tier_name: String = FixtureDefinition.get_tier_name(tier)
	_title_label.text = def.name
	_tier_label.text = tr("UPGRADE_CURRENT_TIER") % tier_name

	var current_slots: int = def.get_slots_for_tier(tier)
	var current_bonus: float = def.get_purchase_prob_bonus(tier)
	_slots_label.text = tr("UPGRADE_SLOTS") % current_slots
	_bonus_label.text = tr("UPGRADE_BONUS") % roundi(
		current_bonus * 100.0
	)

	if tier >= FixtureDefinition.TierLevel.PREMIUM:
		_cost_label.text = tr("UPGRADE_MAX_TIER")
		_requirement_label.text = ""
		_upgrade_button.visible = false
		return

	_upgrade_button.visible = true
	var next_tier: int = tier + 1
	var next_name: String = FixtureDefinition.get_tier_name(next_tier)
	var cost: float = placement_system.get_upgrade_cost(
		_selected_fixture_id
	)
	var next_slots: int = def.get_slots_for_tier(next_tier)
	var next_bonus: float = def.get_purchase_prob_bonus(next_tier)

	_cost_label.text = (
		tr("UPGRADE_COST")
		% [
			next_name,
			cost,
			next_slots - current_slots,
			roundi((next_bonus - current_bonus) * 100.0),
		]
	)

	var block_reason: String = (
		placement_system.get_upgrade_block_reason(
			_selected_fixture_id
		)
	)
	if block_reason.is_empty():
		_upgrade_button.disabled = false
		_requirement_label.text = ""
	else:
		_upgrade_button.disabled = true
		_requirement_label.text = block_reason


func _on_upgrade_pressed() -> void:
	if _selected_fixture_id.is_empty():
		return
	placement_system.try_upgrade(_selected_fixture_id)


func _on_fixture_selected(fixture_id: String) -> void:
	var data: Dictionary = placement_system.get_fixture_data(
		fixture_id
	)
	if data.is_empty():
		return
	open(fixture_id)


func _on_fixture_upgraded(
	fixture_id: String, _new_tier: int
) -> void:
	if _is_open and fixture_id == _selected_fixture_id:
		_refresh_display()


func _on_panel_opened(panel_name: String) -> void:
	if panel_name != PANEL_NAME and _is_open:
		close(true)


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "UpgradePanelRoot"
	_panel.anchors_preset = Control.PRESET_CENTER_RIGHT
	_panel.custom_minimum_size = Vector2(280, 0)
	_panel.position = Vector2(-300, -150)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)

	_title_label = Label.new()
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)

	_close_button = Button.new()
	_close_button.text = "X"
	_close_button.pressed.connect(close)
	header.add_child(_close_button)

	_tier_label = Label.new()
	vbox.add_child(_tier_label)

	_slots_label = Label.new()
	vbox.add_child(_slots_label)

	_bonus_label = Label.new()
	vbox.add_child(_bonus_label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	_cost_label = Label.new()
	_cost_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_cost_label)

	_requirement_label = Label.new()
	_requirement_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_requirement_label.modulate = Color(1.0, 0.5, 0.5)
	vbox.add_child(_requirement_label)

	_upgrade_button = Button.new()
	_upgrade_button.text = tr("UPGRADE_BUTTON")
	_upgrade_button.custom_minimum_size = Vector2(0, 36)
	_upgrade_button.pressed.connect(_on_upgrade_pressed)
	vbox.add_child(_upgrade_button)
