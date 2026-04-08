## Central signal bus for decoupled communication between systems.
extends Node

# Player
signal player_interacted(target: Node)

# Economy
signal item_sold(item_id: String, price: float)
signal item_purchased(item_id: String, cost: float)

# Store
signal store_opened(store_id: String)
signal store_closed(store_id: String)
signal customer_entered(customer_data: Dictionary)
signal customer_left(customer_data: Dictionary)

# Time
signal day_started(day: int)
signal day_ended(day: int)
signal hour_changed(hour: int)

# UI
signal notification_requested(message: String)
