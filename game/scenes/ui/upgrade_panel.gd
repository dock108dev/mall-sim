## Slide-from-right panel for browsing and purchasing store upgrades.
class_name UpgradePanel
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
	_anim_tween = PanelAnimator.slide_open(
		_panel, _rest_x, false
	)
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
		_anim_tween = PanelAnimator.slide_close(
			_panel, _rest_x, false
		)
	EventBus.panel_closed.emit(PANEL_NAME)


func is_open() -> bool:
	return _is_open


func _refresh_catalog() -> void:
	_clear_grid(_universal_grid)
	_clear_grid(_specific_grid)

	if not data_loader:
		return

	var upgrades: Array[UpgradeDefinition] = (
		data_loader.get_upgrades_for_store(store_type)
	)
	for upgrade: UpgradeDefinition in upgrades:
		var target_grid: GridContainer = _universal_grid
		if not upgrade.is_universal():
			target_grid = _specific_grid
		_create_upgrade_button(upgrade, target_grid)

	_update_info_label()


func _clear_grid(grid: GridContainer) -> void:
	for child: Node in grid.get_children():
		child.queue_free()


func _create_upgrade_button(
	upgrade: UpgradeDefinition,
	grid: GridContainer
) -> void:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(200, 70)

	var is_installed: bool = _is_installed(upgrade.id)
	var is_locked: bool = _is_rep_locked(upgrade)
	var is_unaffordable: bool = _is_unaffordable(upgrade)

	var label_text: String = "%s  $%.0f\n%s" % [
		upgrade.display_name,
		upgrade.cost,
		upgrade.description,
	]

	if is_installed:
		label_text += "\n[Installed]"
		btn.disabled = true
		btn.modulate = Color(0.5, 0.8, 0.5, 0.8)
	elif is_locked:
		label_text += "\n[Rep %.0f needed]" % upgrade.rep_required
		btn.disabled = true
		btn.modulate = Color(0.5, 0.5, 0.5, 0.7)
	elif is_unaffordable:
		label_text += "\n[Insufficient funds]"
		btn.disabled = true
		btn.modulate = Color(0.8, 0.4, 0.4, 0.9)

	btn.text = label_text
	if not is_installed:
		btn.pressed.connect(
			_on_upgrade_pressed.bind(upgrade.id)
		)
	grid.add_child(btn)


func _is_installed(upgrade_id: String) -> bool:
	if not upgrade_system:
		return false
	return upgrade_system.is_purchased(store_type, upgrade_id)


func _is_rep_locked(upgrade: UpgradeDefinition) -> bool:
	if upgrade.rep_required <= 0.0:
		return false
	if not reputation_system:
		return true
	return (
		reputation_system.get_reputation(store_type)
		< upgrade.rep_required
	)


func _is_unaffordable(upgrade: UpgradeDefinition) -> bool:
	if not economy_system:
		return true
	return economy_system.get_cash() < upgrade.cost


func _on_upgrade_pressed(upgrade_id: String) -> void:
	if not upgrade_system:
		return
	var success: bool = upgrade_system.purchase_upgrade(
		store_type, upgrade_id
	)
	if success:
		_refresh_catalog()
		_update_info_label()


func _update_info_label() -> void:
	if not upgrade_system:
		_info_label.text = "Upgrades unavailable"
		return
	var purchased: Array = upgrade_system.get_purchased_ids(
		store_type
	)
	_info_label.text = "%d upgrade(s) installed" % purchased.size()


func _get_current_cash() -> float:
	if economy_system:
		return economy_system.get_cash()
	return 0.0


func _update_cash_display() -> void:
	_cash_label.text = "Cash: $%.0f" % _get_current_cash()


func _on_money_changed(
	_old_amount: float, new_amount: float
) -> void:
	if _is_open:
		_cash_label.text = "Cash: $%.0f" % new_amount
		_refresh_catalog()


func _on_panel_opened(panel_name: String) -> void:
	if panel_name != PANEL_NAME and _is_open:
		close(true)


func _on_active_store_changed(
	new_store_id: StringName
) -> void:
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
