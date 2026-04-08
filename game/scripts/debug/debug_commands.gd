## Debug console commands for development. Attach to a debug node.
class_name DebugCommands
extends Node


func add_cash(amount: float) -> void:
	# Requires EconomySystem to be accessible — wire during integration.
	print("[Debug] add_cash(%s) — not yet wired" % amount)


func set_time(hour: int) -> void:
	print("[Debug] set_time(%s) — not yet wired" % hour)


func list_items() -> void:
	var items := DataLoader.load_all_json_in(Constants.ITEMS_PATH)
	for item in items:
		print("  %s — $%s" % [item.get("name", "?"), item.get("base_price", "?")])
