## Bird's-eye store navigation hub.
## Renders all five stores with live revenue and alert badges.
## Signal-driven: no direct store controller node references.
## Call setup() once after instantiation to wire inventory and economy systems.
class_name MallOverview
extends Control

signal store_selected(store_id: StringName)

const _StoreSlotCardScene: PackedScene = preload(
	"res://game/scenes/mall/store_slot_card.tscn"
)

var _inventory_system: InventorySystem = null
var _economy_system: EconomySystem = null
## store_id (StringName) -> StoreSlotCard
var _cards: Dictionary = {}

@onready var _store_grid: HBoxContainer = $VBox/StoreGrid
@onready var _day_close_button: Button = $VBox/BottomRow/DayCloseButton


func _ready() -> void:
	_connect_signals()
	_day_close_button.pressed.connect(_on_day_close_pressed)
	EventBus.store_entered.connect(_on_store_entered)
	EventBus.store_exited.connect(_on_store_exited)


## Wire runtime systems and populate store cards.
## Must be called from GameWorld after systems are initialized.
func setup(
	inventory_system: InventorySystem,
	economy_system: EconomySystem,
) -> void:
	_inventory_system = inventory_system
	_economy_system = economy_system
	_populate_stores()


func _populate_stores() -> void:
	for child: Node in _store_grid.get_children():
		child.queue_free()
	_cards.clear()

	var store_ids: Array[StringName] = ContentRegistry.get_all_store_ids()
	for store_id: StringName in store_ids:
		var card: StoreSlotCard = _StoreSlotCardScene.instantiate() as StoreSlotCard
		_store_grid.add_child(card)
		var display_name: String = ContentRegistry.get_display_name(store_id)
		card.setup(store_id, display_name)
		card.store_selected.connect(_on_card_store_selected)
		_cards[store_id] = card
		_refresh_card(store_id)


func _refresh_card(store_id: StringName) -> void:
	if not _cards.has(store_id):
		return
	var card: StoreSlotCard = _cards[store_id] as StoreSlotCard
	if _economy_system:
		card.update_revenue(
			_economy_system.get_store_daily_revenue(String(store_id))
		)
	if _inventory_system:
		var stock: Array[ItemInstance] = _inventory_system.get_stock(store_id)
		card.update_stock(stock.size())


func _connect_signals() -> void:
	EventBus.inventory_updated.connect(_on_inventory_updated)
	EventBus.customer_purchased.connect(_on_customer_purchased)
	EventBus.day_started.connect(_on_day_started)
	EventBus.day_closed.connect(_on_day_closed)
	EventBus.market_event_triggered.connect(_on_market_event_triggered)
	EventBus.random_event_triggered.connect(_on_random_event_triggered)


func _on_inventory_updated(store_id: StringName) -> void:
	if not _inventory_system or not _cards.has(store_id):
		return
	var stock: Array[ItemInstance] = _inventory_system.get_stock(store_id)
	(_cards[store_id] as StoreSlotCard).update_stock(stock.size())


func _on_customer_purchased(
	store_id: StringName,
	_item_id: StringName,
	_price: float,
	_customer_id: StringName,
) -> void:
	if not _economy_system or not _cards.has(store_id):
		return
	(_cards[store_id] as StoreSlotCard).update_revenue(
		_economy_system.get_store_daily_revenue(String(store_id))
	)


func _on_day_started(_day: int) -> void:
	for store_id: StringName in _cards:
		var card: StoreSlotCard = _cards[store_id] as StoreSlotCard
		card.update_revenue(0.0)
		card.set_event_pending(false)
		if _inventory_system:
			var stock: Array[ItemInstance] = _inventory_system.get_stock(store_id)
			card.update_stock(stock.size())


func _on_day_closed(_day: int, summary: Dictionary) -> void:
	var store_revenues: Dictionary = summary.get("store_daily_revenue", {})
	for store_id: StringName in _cards:
		var rev: float = store_revenues.get(String(store_id), 0.0)
		(_cards[store_id] as StoreSlotCard).update_revenue(rev)


func _on_market_event_triggered(
	_event_id: StringName, store_id: StringName, _effect: Dictionary
) -> void:
	if _cards.has(store_id):
		(_cards[store_id] as StoreSlotCard).set_event_pending(true)


func _on_random_event_triggered(
	_event_id: StringName, store_id: StringName, _effect: Dictionary
) -> void:
	if _cards.has(store_id):
		(_cards[store_id] as StoreSlotCard).set_event_pending(true)


func _on_card_store_selected(store_id: StringName) -> void:
	store_selected.emit(store_id)
	EventBus.enter_store_requested.emit(store_id)


func _on_day_close_pressed() -> void:
	EventBus.day_close_requested.emit()


func _on_store_entered(_store_id: StringName) -> void:
	visible = false


func _on_store_exited(_store_id: StringName) -> void:
	visible = true
