## Tracks item stock across all player-owned stores.
class_name InventorySystem
extends Node

# store_id -> { item_id: quantity }
var _inventories: Dictionary = {}


func add_item(store_id: String, item_id: String, quantity: int = 1) -> void:
	if store_id not in _inventories:
		_inventories[store_id] = {}
	var inv: Dictionary = _inventories[store_id]
	inv[item_id] = inv.get(item_id, 0) + quantity


func remove_item(store_id: String, item_id: String, quantity: int = 1) -> bool:
	if store_id not in _inventories:
		return false
	var inv: Dictionary = _inventories[store_id]
	if inv.get(item_id, 0) < quantity:
		return false
	inv[item_id] -= quantity
	if inv[item_id] <= 0:
		inv.erase(item_id)
	return true


func get_stock(store_id: String, item_id: String) -> int:
	if store_id not in _inventories:
		return 0
	return _inventories[store_id].get(item_id, 0)
