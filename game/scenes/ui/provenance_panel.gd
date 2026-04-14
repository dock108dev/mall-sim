## Modal dialog for provenance verification when a customer offers to sell an item.
class_name ProvenancePanel
extends CanvasLayer

const PANEL_NAME: String = "provenance"
const SUSPICIOUS_PENALTY: float = 0.5

var _current_item: ItemInstance = null
var _current_customer: Node = null
var _is_open: bool = false
var _is_pending: bool = false
var _is_suspicious: bool = false
var _asking_price: float = 0.0
var _authenticated_value: float = 0.0
var _anim_tween: Tween

@onready var _panel: PanelContainer = $PanelRoot
@onready var _title_label: Label = (
	$PanelRoot/Margin/VBox/TitleLabel
)
@onready var _item_name_label: Label = (
	$PanelRoot/Margin/VBox/InfoVBox/ItemNameLabel
)
@onready var _asking_price_label: Label = (
	$PanelRoot/Margin/VBox/InfoVBox/AskingPriceLabel
)
@onready var _auth_value_label: Label = (
	$PanelRoot/Margin/VBox/InfoVBox/AuthValueLabel
)
@onready var _suspicious_label: Label = (
	$PanelRoot/Margin/VBox/InfoVBox/SuspiciousLabel
)
@onready var _error_label: Label = (
	$PanelRoot/Margin/VBox/InfoVBox/ErrorLabel
)
@onready var _accept_button: Button = (
	$PanelRoot/Margin/VBox/ButtonHBox/AcceptButton
)
@onready var _reject_button: Button = (
	$PanelRoot/Margin/VBox/ButtonHBox/RejectButton
)


func _ready() -> void:
	_panel.visible = false
	_error_label.visible = false
	_suspicious_label.visible = false
	_accept_button.pressed.connect(_on_accept)
	_reject_button.pressed.connect(_on_reject)
	EventBus.provenance_requested.connect(_on_provenance_requested)
	EventBus.provenance_completed.connect(_on_provenance_completed)


## Opens the panel for a customer offering an item for sale.
func open(
	item: ItemInstance, customer: Node, asking_price: float
) -> void:
	if _is_open:
		return
	if not item or not item.definition:
		push_error("ProvenancePanel: invalid item")
		return
	_current_item = item
	_current_customer = customer
	_asking_price = asking_price
	_is_pending = false
	_is_suspicious = _roll_suspicious(item)
	_authenticated_value = _calculate_authenticated_value(item)
	_error_label.visible = false
	_populate()
	_set_inputs_enabled(true)
	_is_open = true
	PanelAnimator.kill_tween(_anim_tween)
	_anim_tween = PanelAnimator.modal_open(_panel)
	EventBus.panel_opened.emit(PANEL_NAME)


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	_is_pending = false
	_current_item = null
	_current_customer = null
	PanelAnimator.kill_tween(_anim_tween)
	_anim_tween = PanelAnimator.modal_close(_panel)
	_anim_tween.finished.connect(
		func() -> void: EventBus.panel_closed.emit(PANEL_NAME),
		CONNECT_ONE_SHOT,
	)


func is_open() -> bool:
	return _is_open


func _populate() -> void:
	_title_label.text = "Provenance Verification"
	_item_name_label.text = _current_item.definition.item_name
	_asking_price_label.text = (
		"Asking Price: $%.2f" % _asking_price
	)
	var display_value: float = _authenticated_value
	if _is_suspicious:
		display_value = _authenticated_value * SUSPICIOUS_PENALTY
	_auth_value_label.text = (
		"Authenticated Value: $%.2f" % display_value
	)
	_suspicious_label.visible = _is_suspicious
	if _is_suspicious:
		_suspicious_label.text = "⚠ Suspicious Provenance"
	_accept_button.text = "Accept"


func _on_accept() -> void:
	if _is_pending or not _current_item:
		return
	_is_pending = true
	_error_label.visible = false
	_set_inputs_enabled(false)
	EventBus.provenance_accepted.emit(
		_current_item.instance_id
	)


func _on_reject() -> void:
	if _is_pending:
		return
	if _current_item and _current_customer:
		EventBus.provenance_rejected.emit(
			_current_item.instance_id
		)
		EventBus.customer_left_mall.emit(
			_current_customer, false
		)
	close()


func _on_provenance_requested(
	item_id: String, customer: Node
) -> void:
	if _is_open:
		return
	var item: ItemInstance = _create_offer_item(item_id)
	if not item:
		push_error(
			"ProvenancePanel: cannot resolve item '%s'" % item_id
		)
		return
	var price: float = item.get_current_value()
	open(item, customer, price)


func _on_provenance_completed(
	item_id: String, success: bool, message: String
) -> void:
	if not _is_open or not _current_item:
		return
	if item_id != _current_item.instance_id:
		return
	_is_pending = false
	if success:
		close()
	else:
		_error_label.text = message
		_error_label.visible = true
		_set_inputs_enabled(true)


func _set_inputs_enabled(enabled: bool) -> void:
	_accept_button.disabled = not enabled
	_reject_button.disabled = not enabled


func _roll_suspicious(item: ItemInstance) -> bool:
	var chance: float = item.definition.suspicious_chance
	if chance <= 0.0:
		return false
	return randf() < chance


func _calculate_authenticated_value(
	item: ItemInstance
) -> float:
	return item.get_current_value()


func _create_offer_item(item_id: String) -> ItemInstance:
	var canonical: StringName = ContentRegistry.resolve(item_id)
	if canonical.is_empty():
		canonical = StringName(item_id)
	var entry: Dictionary = ContentRegistry.get_entry(canonical)
	if entry.is_empty():
		return null
	var def: ItemDefinition = ItemDefinition.new()
	def.id = String(canonical)
	if entry.has("item_name"):
		def.item_name = str(entry["item_name"])
	if entry.has("base_price"):
		def.base_price = float(entry["base_price"])
	if entry.has("category"):
		def.category = str(entry["category"])
	if entry.has("rarity"):
		def.rarity = str(entry["rarity"])
	if entry.has("store_type"):
		def.store_type = str(entry["store_type"])
	if entry.has("suspicious_chance"):
		def.suspicious_chance = float(entry["suspicious_chance"])
	var item: ItemInstance = (
		ItemInstance.create_from_definition(def)
	)
	return item


## Returns whether the current item is flagged as suspicious.
func get_is_suspicious() -> bool:
	return _is_suspicious


## Returns the calculated authenticated value.
func get_authenticated_value() -> float:
	return _authenticated_value
