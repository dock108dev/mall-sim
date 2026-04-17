## Slide-from-right panel implementation for browsing and purchasing upgrades.
extends CanvasLayer

const PANEL_NAME: String = "store_upgrades"

var upgrade_system: StoreUpgradeSystem
var economy_system: EconomySystem
var reputation_system: ReputationSystem
var data_loader: DataLoader
var store_type: String = ""

var _is_open: bool = false
var _anim_tween: Tween
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
@onready var _specific_section: VBoxContainer = (
	$PanelRoot/Margin/VBox/SpecificSection
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
	EventBus.active_store_changed.connect(_on_active_store_changed)
	EventBus.toggle_upgrade_panel.connect(_on_toggle_requested)


func open() -> void:
	if _is_open:
		return
	if store_type.is_empty():
		push_warning("UpgradePanel: no store_type set")
		return
	_is_open = true
	_update_cash_display()
	_refresh_catalog()
	PanelAnimator.kill_tween(_anim_tween)
	_anim_tween = PanelAnimator.slide_open(_panel, _rest_x, false)
	EventBus.panel_opened.emit(PANEL_NAME)


func close(immediate: bool = false) -> void:
	if not _is_open:
		return
	_is_open = false
	PanelAnimator.kill_tween(_anim_tween)
	if immediate:
		_panel.visible = false
		_panel.position.x = _rest_x
	else:
		_anim_tween = PanelAnimator.slide_close(_panel, _rest_x, false)
	EventBus.panel_closed.emit(PANEL_NAME)


func is_open() -> bool:
	return _is_open


func _refresh_catalog() -> void:
	_clear_grid(_universal_grid)
	_clear_grid(_specific_grid)

	var upgrades: Array[UpgradeDefinition] = _get_upgrades_for_store()
	var specific_count: int = 0
	for upgrade: UpgradeDefinition in upgrades:
		if upgrade.is_universal():
			_universal_grid.add_child(_create_upgrade_row(upgrade))
		else:
			specific_count += 1
			_specific_grid.add_child(_create_upgrade_row(upgrade))

	_specific_section.visible = specific_count > 0
	_update_info_label()


func _get_upgrades_for_store() -> Array[UpgradeDefinition]:
	if upgrade_system:
		return upgrade_system.get_upgrades_for_store(store_type)
	if data_loader:
		return data_loader.get_upgrades_for_store(store_type)
	return []


func _clear_grid(grid: GridContainer) -> void:
	for child: Node in grid.get_children():
		child.queue_free()


func _create_upgrade_row(upgrade: UpgradeDefinition) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(260, 96)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)

	var title := Label.new()
	title.text = "%s  $%.0f" % [upgrade.display_name, upgrade.cost]
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(title)

	var requirement := Label.new()
	requirement.text = "Reputation %.0f / %.0f required" % [
		_get_current_reputation(),
		upgrade.rep_required,
	]
	requirement.modulate = Color(0.82, 0.82, 0.82)
	box.add_child(requirement)

	var description := Label.new()
	description.text = upgrade.description
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.modulate = Color(0.78, 0.78, 0.78)
	box.add_child(description)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	box.add_child(footer)

	var status := Label.new()
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.text = _get_upgrade_status(upgrade)
	footer.add_child(status)

	var button := Button.new()
	button.custom_minimum_size = Vector2(96, 32)
	button.text = "Installed" if _is_installed(upgrade.id) else "UPGRADE"
	button.disabled = not _can_purchase(upgrade)
	button.pressed.connect(_on_upgrade_pressed.bind(upgrade.id))
	footer.add_child(button)

	return card


func _get_upgrade_status(upgrade: UpgradeDefinition) -> String:
	if _is_installed(upgrade.id):
		return "Installed"
	if _is_rep_locked(upgrade):
		return "Reputation locked"
	if _is_unaffordable(upgrade):
		return "Need $%.0f" % (upgrade.cost - _get_current_cash())
	return "Available"


func _can_purchase(upgrade: UpgradeDefinition) -> bool:
	if not upgrade_system:
		return false
	return upgrade_system.can_purchase(store_type, upgrade.id)


func _is_installed(upgrade_id: String) -> bool:
	if not upgrade_system:
		return false
	return upgrade_system.is_purchased(store_type, upgrade_id)


func _is_rep_locked(upgrade: UpgradeDefinition) -> bool:
	if upgrade.rep_required <= 0.0:
		return false
	if not reputation_system:
		return true
	return _get_current_reputation() < upgrade.rep_required


func _is_unaffordable(upgrade: UpgradeDefinition) -> bool:
	return _get_current_cash() < upgrade.cost


func _on_upgrade_pressed(upgrade_id: String) -> void:
	if not upgrade_system:
		return
	if upgrade_system.purchase_upgrade(store_type, upgrade_id):
		_update_cash_display()
		_refresh_catalog()


func _update_info_label() -> void:
	if not upgrade_system:
		_info_label.text = "Upgrades unavailable"
		return
	var purchased: Array = upgrade_system.get_purchased_ids(store_type)
	_info_label.text = "%d upgrade(s) installed" % purchased.size()


func _get_current_cash() -> float:
	if economy_system:
		return economy_system.get_cash()
	return 0.0


func _get_current_reputation() -> float:
	if reputation_system:
		return reputation_system.get_reputation(store_type)
	return 0.0


func _update_cash_display() -> void:
	_cash_label.text = "Cash: $%.0f" % _get_current_cash()


func _on_money_changed(_old_amount: float, new_amount: float) -> void:
	if _is_open:
		_cash_label.text = "Cash: $%.0f" % new_amount
		_refresh_catalog()


func _on_panel_opened(panel_name: String) -> void:
	if panel_name != PANEL_NAME and _is_open:
		close(true)


func _on_active_store_changed(new_store_id: StringName) -> void:
	store_type = String(new_store_id)
	if _is_open:
		if new_store_id.is_empty():
			close(true)
		else:
			_refresh_catalog()


func _on_toggle_requested() -> void:
	if _is_open:
		close()
	else:
		open()
