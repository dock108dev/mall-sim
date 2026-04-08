## Manages money, pricing, supply/demand, and transactions.
class_name EconomySystem
extends Node

var player_cash: float = Constants.STARTING_CASH


func process_sale(item_id: String, price: float) -> void:
	player_cash += price
	EventBus.item_sold.emit(item_id, price)


func process_purchase(item_id: String, cost: float) -> bool:
	if player_cash < cost:
		return false
	player_cash -= cost
	EventBus.item_purchased.emit(item_id, cost)
	return true
