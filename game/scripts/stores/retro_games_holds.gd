## Hold-list / reservation manager for RetroGames. Owns the per-store HoldList,
## the spawned paper-slip props on the hold shelf, and the Fulfillment Conflict
## resolution flow. Constructed by RetroGames at boot and addressed by callers
## via `controller.holds.X(...)` so the store controller's public surface stays
## focused on lifecycle / inventory wiring.
class_name RetroGamesHolds
extends RefCounted

const _HOLD_TERMINAL_UNLOCK_ID: StringName = &"employee_holdlist_access"
## Material colors for the spawned paper slip props. Flagged slips render
## with a red emissive tint so the player can pick them out at a glance on
## the hold shelf; unflagged slips use the default cream paper color.
const _HOLD_SLIP_MAT_COLOR_NORMAL: Color = Color(0.96, 0.92, 0.78)
const _HOLD_SLIP_MAT_COLOR_FLAGGED: Color = Color(0.95, 0.30, 0.25)
const _HOLD_SLIP_EMISSION_FLAGGED: Color = Color(0.85, 0.10, 0.10)
## Per-slip prop dimensions (paper-thin box on the hold shelf). The shelf
## surface is at Y≈1.6 in scene-local space; slips are stacked along the
## shelf's local +X axis with this spacing.
const _HOLD_SLIP_BOX_SIZE := Vector3(0.18, 0.02, 0.12)
const _HOLD_SLIP_X_SPACING: float = 0.22
## Trust deltas for the three Fulfillment Conflict resolution choices.
const _HOLD_CONFLICT_HONOR_MANAGER_TRUST_DELTA: float = 0.02
const _HOLD_CONFLICT_ESCALATE_MANAGER_TRUST_DELTA: float = 0.03
const _HOLD_CONFLICT_WALK_IN_MANAGER_TRUST_DELTA: float = -0.05
const _HOLD_CONFLICT_WALK_IN_EMPLOYEE_TRUST_DELTA: float = -3.0
const _HOLD_REASON_HONOR: String = "complaint_handled"
const _HOLD_REASON_ESCALATE: String = "manager_escalation"
const _HOLD_REASON_WALK_IN: String = "hold_conflict_bypass"
const _NEW_CONSOLE_PLATFORM_ID: StringName = &"vecforce_hd"

var _hold_list: HoldList = HoldList.new()
var _hold_slip_props: Dictionary = {}
var _controller: Node = null


func _init(controller: Node) -> void:
	_controller = controller
	_connect_hold_list_signals()


## Returns the store-local HoldList. Exposed for tests, terminal UI, and
## external systems that need to inspect slip state without going through the
## EventBus signal feed.
func get_hold_list() -> HoldList:
	return _hold_list


## Adds a hold slip on behalf of a customer interaction. Wraps HoldList.add_hold
## so callers don't need to compute creation_day or carry the StoreController
## reference. Returns the new slip; never null.
func add_customer_hold(
	customer_name: String,
	serial: String,
	item_id: StringName,
	item_label: String,
	tier: int,
	thread_id: String = "",
) -> HoldSlip:
	var day: int = GameManager.get_current_day()
	return _hold_list.add_hold(
		customer_name, serial, item_id, item_label, tier, day, thread_id
	)


## Returns true when the player has been granted the terminal access unlock.
## Before the unlock the manager handles allocation silently — the player
## cannot open the terminal panel, so the Fulfillment Conflict flow is not
## reachable.
func has_hold_terminal_access() -> bool:
	var tree: SceneTree = _controller.get_tree()
	if tree == null or tree.root == null:
		return false
	var unlocks: Node = tree.root.get_node_or_null("UnlockSystemSingleton")
	if unlocks == null or not unlocks.has_method("is_unlocked"):
		return false
	return bool(unlocks.call("is_unlocked", _HOLD_TERMINAL_UNLOCK_ID))


## Returns the count of in-stock units for a given item_id, regardless of
## location (shelf or backroom). Used by the conflict-detection rule
## `pending_holds_for(item_id).size() > units_in_stock(item_id)`.
func units_in_stock(item_id: StringName) -> int:
	var inv: Node = _controller.get("_inventory_system") as Node
	if inv == null:
		return 0
	var stock: Array[ItemInstance] = inv.get_items_for_store(
		String(_controller.STORE_ID)
	)
	var count: int = 0
	for item: ItemInstance in stock:
		if item == null or item.definition == null:
			continue
		if StringName(item.definition.id) == item_id:
			count += 1
	return count


## Returns true when the item's platform is supply-constrained (PlatformSystem
## reports a current shortage) OR when the ItemDefinition itself is flagged
## supply_constrained. The terminal only surfaces the Fulfillment Conflict
## panel for items where this is true.
func is_item_supply_constrained(item_id: StringName) -> bool:
	var inv: Node = _controller.get("_inventory_system") as Node
	if inv == null:
		return false
	var platform_id: StringName = &""
	var fallback_constrained: bool = false
	var stock: Array[ItemInstance] = inv.get_items_for_store(
		String(_controller.STORE_ID)
	)
	for item: ItemInstance in stock:
		if item == null or item.definition == null:
			continue
		if StringName(item.definition.id) != item_id:
			continue
		platform_id = item.definition.platform_id
		fallback_constrained = item.definition.supply_constrained
		break
	if platform_id != &"" and _has_platform_system():
		var ps: Node = _controller.get_tree().root.get_node("PlatformSystem")
		if ps.has_method("is_shortage"):
			return bool(ps.call("is_shortage", platform_id))
	return fallback_constrained


## Returns true when the terminal should render a CONFLICT badge on the row
## for `item_id`. Combines the supply-constrained check with the
## pending-holds vs units-in-stock comparison.
func has_fulfillment_conflict(item_id: StringName) -> bool:
	if not is_item_supply_constrained(item_id):
		return false
	return _hold_list.has_conflict(item_id, units_in_stock(item_id))


## Resolves a Fulfillment Conflict using the player's chosen action. choice
## is HoldList.ConflictChoice. Applies the documented manager_trust /
## employee_trust deltas and forwards the bypass case onto EventBus so
## hidden-thread listeners consume it as a Tier 2 trigger.
func resolve_fulfillment_conflict(
	item_id: StringName, choice: int
) -> Dictionary:
	var result: Dictionary = _hold_list.resolve_conflict(item_id, choice)
	match choice:
		HoldList.ConflictChoice.HONOR_EARLIEST:
			_apply_manager_trust_delta(
				_HOLD_CONFLICT_HONOR_MANAGER_TRUST_DELTA, _HOLD_REASON_HONOR
			)
		HoldList.ConflictChoice.ESCALATE_TO_MANAGER:
			_apply_manager_trust_delta(
				_HOLD_CONFLICT_ESCALATE_MANAGER_TRUST_DELTA,
				_HOLD_REASON_ESCALATE,
			)
		HoldList.ConflictChoice.GIVE_TO_WALK_IN:
			_apply_manager_trust_delta(
				_HOLD_CONFLICT_WALK_IN_MANAGER_TRUST_DELTA,
				_HOLD_REASON_WALK_IN,
			)
			_apply_employee_trust_delta(
				_HOLD_CONFLICT_WALK_IN_EMPLOYEE_TRUST_DELTA,
				_HOLD_REASON_WALK_IN,
			)
			EventBus.hold_conflict_bypassed.emit(
				_controller.STORE_ID, item_id, result.get("disputed_slip_ids", [])
			)
	return result


## Returns true when a non-terminal slip on the VecForce HD platform exists
## that is either flagged or carries a non-NORMAL requestor tier. Drives the
## new-console-hype "weird inventory" hidden-thread trigger.
func has_suspicious_vecforce_hd_hold() -> bool:
	var statuses: Array[int] = [
		HoldSlip.Status.ACTIVE, HoldSlip.Status.FLAGGED
	]
	for status: int in statuses:
		for slip: HoldSlip in _hold_list.get_slips_by_status(status):
			if not _slip_targets_vecforce_hd(slip):
				continue
			if status == HoldSlip.Status.FLAGGED:
				return true
			if slip.requestor_tier != HoldSlip.RequestorTier.NORMAL:
				return true
	return false


## Routes the hold-shelf E-press to the terminal opener.
func on_hold_shelf_interacted() -> void:
	open_hold_terminal()


## Opens the hold terminal panel when the player has the unlock; otherwise
## emits a notification explaining the manager handles allocation silently.
func open_hold_terminal() -> void:
	if not has_hold_terminal_access():
		EventBus.notification_requested.emit(
			"Vic handles the hold list — you'll get terminal access later."
		)
		return
	EventBus.notification_requested.emit(
		"Hold list — %d active." % _hold_list.get_slips_by_status(
			HoldSlip.Status.ACTIVE
		).size()
	)


## Saves the hold-list state for the per-store save_data payload.
func get_save_data() -> Dictionary:
	return _hold_list.get_save_data()


## Restores the hold-list state from saved data and rebuilds visible props.
func load_save_data(data: Dictionary) -> void:
	_hold_list.load_save_data(data)
	_resync_hold_slip_props()


# ── Internals ────────────────────────────────────────────────────────────────


func _connect_hold_list_signals() -> void:
	if not _hold_list.hold_added.is_connected(_on_hold_added):
		_hold_list.hold_added.connect(_on_hold_added)
	if not _hold_list.hold_fulfilled.is_connected(_on_hold_fulfilled):
		_hold_list.hold_fulfilled.connect(_on_hold_fulfilled)
	if not _hold_list.hold_expired.is_connected(_on_hold_expired):
		_hold_list.hold_expired.connect(_on_hold_expired)
	if not _hold_list.duplicate_detected.is_connected(_on_hold_duplicate_detected):
		_hold_list.duplicate_detected.connect(_on_hold_duplicate_detected)
	if not _hold_list.shady_request_received.is_connected(
		_on_hold_shady_request_received
	):
		_hold_list.shady_request_received.connect(
			_on_hold_shady_request_received
		)


func _on_hold_added(slip: HoldSlip) -> void:
	_spawn_hold_slip_prop(slip)
	EventBus.hold_added.emit(
		_controller.STORE_ID, slip.id, slip.item_id, slip.customer_name
	)


func _on_hold_fulfilled(slip: HoldSlip, reason: String) -> void:
	_remove_hold_slip_prop(slip.id)
	EventBus.hold_fulfilled.emit(
		_controller.STORE_ID, slip.id, slip.item_id, reason
	)


func _on_hold_expired(slip: HoldSlip) -> void:
	_apply_crumpled_visual(slip.id)
	EventBus.hold_expired.emit(_controller.STORE_ID, slip.id, slip.item_id)


func _on_hold_duplicate_detected(
	new_slip: HoldSlip, existing_slip: HoldSlip, conflict_field: StringName
) -> void:
	_refresh_hold_slip_prop_material(existing_slip)
	EventBus.hold_duplicate_detected.emit(
		_controller.STORE_ID, new_slip.id, existing_slip.id, conflict_field
	)


func _on_hold_shady_request_received(slip: HoldSlip) -> void:
	EventBus.hold_shady_request_received.emit(
		_controller.STORE_ID, slip.id, slip.item_id, slip.requestor_tier
	)


func _spawn_hold_slip_prop(slip: HoldSlip) -> void:
	var container: Node3D = _get_hold_slip_container()
	if container == null:
		return
	var node := MeshInstance3D.new()
	node.name = StringName(slip.id.replace("-", "_"))
	var mesh := BoxMesh.new()
	mesh.size = _HOLD_SLIP_BOX_SIZE
	node.mesh = mesh
	var x_offset: float = float(_hold_slip_props.size()) * _HOLD_SLIP_X_SPACING
	node.position = Vector3(x_offset - 0.4, 0.0, 0.0)
	node.set_meta("slip_id", slip.id)
	_apply_hold_slip_material(node, slip)
	container.add_child(node)
	_hold_slip_props[slip.id] = node


func _refresh_hold_slip_prop_material(slip: HoldSlip) -> void:
	var node: Variant = _hold_slip_props.get(slip.id, null)
	if node == null or not is_instance_valid(node):
		return
	_apply_hold_slip_material(node as MeshInstance3D, slip)


func _apply_hold_slip_material(
	node: MeshInstance3D, slip: HoldSlip
) -> void:
	if node == null:
		return
	var mat := StandardMaterial3D.new()
	if slip.is_flagged():
		mat.albedo_color = _HOLD_SLIP_MAT_COLOR_FLAGGED
		mat.emission_enabled = true
		mat.emission = _HOLD_SLIP_EMISSION_FLAGGED
		mat.emission_energy_multiplier = 0.7
	else:
		mat.albedo_color = _HOLD_SLIP_MAT_COLOR_NORMAL
	node.material_override = mat


func _apply_crumpled_visual(slip_id: String) -> void:
	var node: Variant = _hold_slip_props.get(slip_id, null)
	if node == null or not is_instance_valid(node):
		return
	var mesh_node := node as MeshInstance3D
	mesh_node.scale = Vector3(0.65, 0.65, 0.65)
	mesh_node.rotation = Vector3(0.0, 0.0, deg_to_rad(18.0))
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.52, 0.48)
	mesh_node.material_override = mat


func _remove_hold_slip_prop(slip_id: String) -> void:
	var node: Variant = _hold_slip_props.get(slip_id, null)
	if node != null and is_instance_valid(node):
		(node as Node).queue_free()
	_hold_slip_props.erase(slip_id)


func _resync_hold_slip_props() -> void:
	var container: Node3D = _get_hold_slip_container()
	if container == null:
		return
	for child: Node in container.get_children():
		if child.has_meta("slip_id"):
			child.queue_free()
	_hold_slip_props.clear()
	for slip: HoldSlip in _hold_list.get_all_slips():
		if slip.is_active() or slip.is_flagged():
			_spawn_hold_slip_prop(slip)
		elif slip.status == HoldSlip.Status.EXPIRED:
			_spawn_hold_slip_prop(slip)
			_apply_crumpled_visual(slip.id)


func _get_hold_slip_container() -> Node3D:
	return _controller.get_node_or_null(
		"hold_shelf/HoldSlipContainer"
	) as Node3D


func _slip_targets_vecforce_hd(slip: HoldSlip) -> bool:
	if slip == null or slip.item_id == &"":
		return false
	var item_def: ItemDefinition = ContentRegistry.get_item_definition(
		slip.item_id
	)
	if item_def == null:
		return false
	return item_def.platform_id == _NEW_CONSOLE_PLATFORM_ID


func _has_platform_system() -> bool:
	var tree: SceneTree = _controller.get_tree()
	return tree != null and tree.root != null and tree.root.has_node(
		"PlatformSystem"
	)


func _apply_manager_trust_delta(delta: float, reason: String) -> void:
	var tree: SceneTree = _controller.get_tree()
	if tree == null or tree.root == null:
		return
	var mrm: Node = tree.root.get_node_or_null(
		"ManagerRelationshipManager"
	)
	if mrm == null or not mrm.has_method("apply_trust_delta"):
		return
	mrm.call("apply_trust_delta", delta, reason)


func _apply_employee_trust_delta(delta: float, reason: String) -> void:
	var tree: SceneTree = _controller.get_tree()
	if tree == null or tree.root == null:
		return
	var emp: Node = tree.root.get_node_or_null("EmploymentSystem")
	if emp == null or not emp.has_method("apply_trust_delta"):
		return
	emp.call("apply_trust_delta", delta, reason)
