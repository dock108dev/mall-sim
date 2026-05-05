## Inventory-variance / discrepancy tracker for RetroGames. Owns the per-day
## flagged-SKU set and the back-room inventory panel lifecycle. Constructed by
## RetroGames and addressed by callers via `controller.audit.X(...)` so the
## store controller's public surface stays focused on lifecycle / inventory.
class_name RetroGamesAudit
extends RefCounted

const _BACK_ROOM_INVENTORY_PANEL_SCENE: PackedScene = preload(
	"res://game/scenes/ui/back_room_inventory_panel.tscn"
)

var _flagged_skus_today: Dictionary = {}
var _discrepancies_flagged_count: int = 0
var _delivery_manifest_examined_today: bool = false
var _back_room_inventory_panel: Control = null
var _controller: Node = null


func _init(controller: Node) -> void:
	_controller = controller


## Resets per-day tracking state. Called by RetroGames on the day_started hook.
func reset_for_new_day() -> void:
	_flagged_skus_today.clear()
	_discrepancies_flagged_count = 0
	_delivery_manifest_examined_today = false


## True the first call per day; false after that — used to gate the
## delivery_manifest_examined signal so it fires at most once per day.
func consume_delivery_manifest_examined() -> bool:
	if _delivery_manifest_examined_today:
		return false
	_delivery_manifest_examined_today = true
	return true


## Builds the audit rows the back-room inventory panel renders. Each row keys
## an item_id to the expected count (from the last delivery manifest snapshot)
## and the actual count (from InventorySystem). Until the delivery-manifest
## persistence layer lands (ISSUE-014/015), expected mirrors actual so a fresh
## floor reads zero discrepancies; downstream systems can override
## `_inventory_audit_expected` via tests or future hooks to inject mismatches.
func get_inventory_audit_rows() -> Array:
	var rows: Array = []
	var inv: Node = _controller.get("_inventory_system") as Node
	if inv == null:
		return rows
	var expected_map: Dictionary = _resolve_expected_inventory(inv)
	var actual_map: Dictionary = _resolve_actual_inventory(inv)
	var seen_ids: Dictionary = {}
	for raw_key: Variant in expected_map:
		var item_id: StringName = StringName(str(raw_key))
		seen_ids[item_id] = true
	for raw_key: Variant in actual_map:
		var item_id: StringName = StringName(str(raw_key))
		seen_ids[item_id] = true
	for item_id: StringName in seen_ids:
		var expected: int = int(expected_map.get(item_id, 0))
		var actual: int = int(actual_map.get(item_id, 0))
		var name_for_row: String = _resolve_item_display_name(item_id)
		rows.append({
			"item_id": item_id,
			"item_name": name_for_row,
			"expected": expected,
			"actual": actual,
			"flagged": _flagged_skus_today.has(item_id),
			"mismatched": expected != actual,
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("item_name", "")) < String(b.get("item_name", ""))
	)
	return rows


## Per-day-flagged SKU set, exposed for tests and future closing-summary
## consumers (ISSUE-007 closing summary card).
func get_flagged_skus_today() -> Array:
	var keys: Array = []
	for raw_key: Variant in _flagged_skus_today:
		keys.append(StringName(str(raw_key)))
	return keys


## Total distinct SKUs flagged today; mirrors the closing-summary key.
func get_discrepancies_flagged_today() -> int:
	return _discrepancies_flagged_count


## Records a player-flagged inventory variance. Idempotent per item per day:
## flagging the same SKU twice on the same day is a no-op (no double-emit, no
## counter increment). Returns true when the flag was newly recorded.
func flag_discrepancy(
	item_id: StringName, expected: int, actual: int
) -> bool:
	if item_id == &"":
		push_warning("RetroGamesAudit.flag_discrepancy: empty item_id")
		return false
	if _flagged_skus_today.has(item_id):
		return false
	_flagged_skus_today[item_id] = true
	_discrepancies_flagged_count += 1
	EventBus.inventory_variance_noted.emit(
		_controller.STORE_ID, item_id, expected, actual
	)
	return true


## Returns true when `flag_discrepancy(item_id, …)` would be a fresh flag.
## Mirrors the panel's per-row Flag-button enabled state.
func can_flag_discrepancy(item_id: StringName) -> bool:
	if item_id == &"":
		return false
	return not _flagged_skus_today.has(item_id)


## Opens the back-room inventory panel. Creates a fresh panel each call,
## queue_freeing any previous instance so re-entries don't leak.
func open_back_room_inventory_panel() -> void:
	if _BACK_ROOM_INVENTORY_PANEL_SCENE == null:
		return
	if is_instance_valid(_back_room_inventory_panel):
		_back_room_inventory_panel.queue_free()
		_back_room_inventory_panel = null
	var panel_root: Node = _BACK_ROOM_INVENTORY_PANEL_SCENE.instantiate()
	if panel_root == null:
		return
	if panel_root.has_method("set_controller"):
		panel_root.call("set_controller", _controller)
	var ui_host: Node = _resolve_panel_host()
	if ui_host == null:
		return
	ui_host.add_child(panel_root)
	_back_room_inventory_panel = panel_root as Control


# ── Internals ────────────────────────────────────────────────────────────────


func _resolve_expected_inventory(_inv: Node) -> Dictionary:
	# Until the delivery manifest persistence lands the expected counts mirror
	# the actual current inventory. Future ISSUE-014/015 work will inject the
	# manifest snapshot taken at start-of-day and inflate variance.
	return _resolve_actual_inventory(_inv)


func _resolve_actual_inventory(inv: Node) -> Dictionary:
	var counts: Dictionary = {}
	var items: Array[ItemInstance] = inv.get_items_for_store(
		String(_controller.STORE_ID)
	)
	for item: ItemInstance in items:
		if item == null or item.definition == null:
			continue
		var key: StringName = StringName(item.definition.id)
		counts[key] = int(counts.get(key, 0)) + 1
	return counts


func _resolve_item_display_name(item_id: StringName) -> String:
	var entry: Dictionary = ContentRegistry.get_entry(item_id)
	if entry.has("item_name"):
		return str(entry["item_name"])
	return String(item_id)


func _resolve_panel_host() -> Node:
	var tree: SceneTree = _controller.get_tree()
	if tree == null:
		return null
	var current_scene: Node = tree.current_scene
	if current_scene == null:
		return tree.root
	return current_scene
