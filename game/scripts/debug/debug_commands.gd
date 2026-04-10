## Debug console commands for development. Attach to a debug node.
class_name DebugCommands
extends Node


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return


func add_cash(amount: float) -> void:
	push_warning("[Debug] add_cash(%s) — not yet wired" % amount)


func set_time(hour: int) -> void:
	push_warning("[Debug] set_time(%s) — not yet wired" % hour)


func list_items() -> void:
	if not GameManager.data_loader:
		push_warning("[Debug] DataLoader not available")
		return
	var items: Array[ItemDefinition] = GameManager.data_loader.get_all_items()
	for item: ItemDefinition in items:
		push_warning("  %s — $%s" % [item.name, item.base_price])
