# gdlint:disable=max-public-methods
## Base controller for all store types. Provides shared lifecycle, signal
## wiring, inventory interface, and slot/fixture management.
class_name StoreController
extends Node

## Emitted whenever current_objective_text changes. The HUD ObjectiveLabel
## binds to this (mirrored on EventBus.objective_text_changed for cross-scene
## wiring) so updates propagate within one frame.
signal objective_text_changed(text: String)

var store_type: String = ""

## HUD-driving objective text. Set via `set_objective_text()` so the binding
## signal fires; do not assign directly from outside.
var current_objective_text: String = ""

var _slots: Array[Node] = []
var _fixtures: Array[Node] = []
var _register_area: Area3D = null
var _entry_area: Area3D = null
var _is_active: bool = false
var _inventory_system: InventorySystem = null
var _customer_system: CustomerSystem = null
var _registered_interactables: Array[Interactable] = []
## Tracks whether this controller pushed CTX_STORE_GAMEPLAY so we never pop a
## context another owner placed (push/pop must stay balanced per InputFocus).
var _pushed_gameplay_context: bool = false


## Initializes shared store identity before ready-time lifecycle wiring.
func initialize_store(
	store_id: StringName, store_kind: StringName = &""
) -> void:
	var resolved_type: StringName = store_kind
	if resolved_type.is_empty():
		resolved_type = store_id
	store_type = String(resolved_type)


func _ready() -> void:
	_collect_fixtures()
	_collect_slots()
	_collect_areas()
	_register_interactables()
	_build_decorations()
	_connect_lifecycle_signals()


## Returns the canonical store id for this controller. Satisfies the
## StoreReadyContract / StorePlayerBody parent-chain check.
func get_store_id() -> StringName:
	return StringName(store_type)


## StoreReadyContract invariant 3. True once `initialize_store()` has set
## `store_type`. Subclasses may override to require stricter readiness (e.g.
## inventory wired) but must keep the base condition.
func is_controller_initialized() -> bool:
	return not store_type.is_empty()


## StoreReadyContract invariant 7. Returns the topmost InputFocus context so
## the contract verifies focus through the single owner instead of a parallel
## authority. Returns `&""` when the InputFocus autoload is absent (e.g. unit
## tests without the autoload tree).
func get_input_context() -> StringName:
	var focus: Node = _get_input_focus()
	if focus == null or not focus.has_method("current"):
		return &""
	return focus.call("current")


## StoreReadyContract invariant 8. True iff the topmost InputFocus context is
## CTX_MODAL — i.e. a modal panel has captured focus and gameplay input is
## suppressed. Same null-safe fallback as `get_input_context()`.
##
## §F-42 — `null` constant on `focus.get(&"CTX_MODAL")` is treated as "no
## blocking modal" (returns false). That branch fires only under unit-test
## isolation where InputFocus is partially stubbed (see §F-34); production
## boot always defines CTX_MODAL.
func has_blocking_modal() -> bool:
	var focus: Node = _get_input_focus()
	if focus == null:
		return false
	var modal_const: Variant = focus.get(&"CTX_MODAL")
	if modal_const == null:
		return false
	return get_input_context() == StringName(modal_const)


## Sets the InventorySystem reference for inventory queries.
func set_inventory_system(inv: InventorySystem) -> void:
	_inventory_system = inv


## Sets the CustomerSystem reference for active customer queries.
func set_customer_system(sys: CustomerSystem) -> void:
	_customer_system = sys


## Returns all items belonging to this store from InventorySystem.
func get_inventory() -> Array[Dictionary]:
	if not _inventory_system:
		return []
	var items: Array[ItemInstance] = (
		_inventory_system.get_items_for_store(store_type)
	)
	var result: Array[Dictionary] = []
	for item: ItemInstance in items:
		result.append({
			"instance_id": item.instance_id,
			"definition": item.definition,
			"condition": item.condition,
			"location": item.current_location,
		})
	return result


## Returns all active customers from CustomerSystem.
func get_active_customers() -> Array[Node]:
	if not _customer_system:
		return []
	var customers: Array[Customer] = (
		_customer_system.get_active_customers()
	)
	var result: Array[Node] = []
	for customer: Customer in customers:
		result.append(customer as Node)
	return result


## Validates store identity before emitting a signal on EventBus.
func emit_store_signal(
	signal_name: StringName, args: Array = []
) -> void:
	if store_type.is_empty():
		push_error(
			"StoreController: cannot emit signal without store_type"
		)
		return
	if not EventBus.has_signal(signal_name):
		push_warning(
			"StoreController: EventBus has no signal '%s'" % signal_name
		)
		return
	# Signal has no callv; route through Callable so callers can pass an
	# Array of args without manual splatting.
	Callable(EventBus, signal_name).callv(args)


## Returns all ShelfSlot children across all fixtures.
func get_all_slots() -> Array[Node]:
	return _slots


## Returns slots that currently hold an item.
func get_occupied_slots() -> Array[Node]:
	var occupied: Array[Node] = []
	for slot: Node in _slots:
		if slot.has_method("is_occupied") and slot.is_occupied():
			occupied.append(slot)
	return occupied


## Returns slots that are currently empty.
func get_empty_slots() -> Array[Node]:
	var empty: Array[Node] = []
	for slot: Node in _slots:
		if not slot.has_method("is_occupied") or not slot.is_occupied():
			empty.append(slot)
	return empty


## Finds a slot by its slot_id property, or null if not found.
func get_slot_by_id(slot_id: String) -> Node:
	for slot: Node in _slots:
		if slot.get("slot_id") == slot_id:
			return slot
	return null


## Returns the register interaction zone, or null if none found.
func get_register_area() -> Area3D:
	return _register_area


## Returns the store entrance zone, or null if none found.
func get_entry_area() -> Area3D:
	return _entry_area


## Returns null by default; subclasses override to provide management UI.
func get_management_ui() -> Control:
	return null


## Returns the number of fixture parent nodes in this store.
func get_fixture_count() -> int:
	return _fixtures.size()


## Returns true if this controller's store is currently active.
func is_active() -> bool:
	return _is_active


## Virtual method called when this store becomes the active store.
func _on_store_activated() -> void:
	pass


## Virtual method called when this store is no longer the active store.
func _on_store_deactivated() -> void:
	pass


## Virtual method called after GameWorld has wired dependencies for store entry.
func _on_store_entered(_store_id: StringName) -> void:
	pass


## Returns the descriptors the ActionDrawer should render for this store.
## Each entry is {id: StringName, label: String, icon: String}. Subclasses
## override to append store-specific actions — call `super()` to keep the
## shared stock/price/inspect set.
func get_store_actions() -> Array:
	return [
		{"id": &"stock", "label": "Stock", "icon": ""},
		{"id": &"price", "label": "Price", "icon": ""},
		{"id": &"inspect", "label": "Inspect", "icon": ""},
		{"id": &"haggle", "label": "Haggle", "icon": ""},
	]


## Emits EventBus.actions_registered so the ActionDrawer can render this
## store's buttons. Called from the deferred store-entered handler.
func emit_actions_registered() -> void:
	if store_type.is_empty():
		return
	EventBus.actions_registered.emit(
		StringName(store_type), get_store_actions()
	)


## Virtual method called when the player exits this store.
func _on_store_exited(_store_id: StringName) -> void:
	pass


## Virtual method called at the start of each day.
func _on_day_started(_day: int) -> void:
	pass


## Virtual method called when the day ends; override to add store-specific cleanup.
func _on_day_ended(_day: int) -> void:
	pass


## Virtual method called when a customer enters a store.
func _on_customer_entered(_customer_data: Dictionary) -> void:
	pass


func _on_active_store_changed(store_id: StringName) -> void:
	var my_id: StringName = StringName(store_type)
	if store_id == my_id:
		_is_active = true
		_on_store_activated()
	else:
		if _is_active:
			_is_active = false
			_on_store_deactivated()


func _collect_fixtures() -> void:
	_fixtures.clear()
	for child: Node in get_children():
		if child.is_in_group("fixture"):
			_fixtures.append(child)


func _collect_slots() -> void:
	_slots.clear()
	for fixture: Node in _fixtures:
		for child: Node in fixture.get_children():
			if child.is_in_group("shelf_slot") or child.get("slot_id") != null:
				_slots.append(child)


func _collect_areas() -> void:
	for child: Node in get_children():
		if child is Area3D:
			if child.is_in_group("register_area"):
				_register_area = child as Area3D
			elif child.is_in_group("entry_area"):
				_entry_area = child as Area3D


func _build_decorations() -> void:
	if store_type.is_empty():
		return
	var node_ref: Variant = self
	if node_ref is Node3D:
		StoreDecorationBuilder.build(node_ref as Node3D, store_type)


func _connect_lifecycle_signals() -> void:
	_connect_signal(EventBus.store_entered, _defer_store_entered)
	_connect_signal(EventBus.store_exited, _on_store_exited_notify)
	_connect_signal(EventBus.active_store_changed, _on_active_store_changed)
	_connect_signal(EventBus.day_started, _on_day_started)
	_connect_signal(EventBus.day_ended, _on_day_ended_notify)
	_connect_signal(EventBus.customer_entered, _on_customer_entered)
	_connect_signal(EventBus.item_stocked, _on_slot_stocked_visual)
	_connect_signal(EventBus.item_removed_from_shelf, _on_slot_cleared_visual)
	# `current_objective_text` mirrors ObjectiveDirector's day text so
	# StoreReadyContract invariant 10 (objective_matches_action) can validate
	# against the same text the player sees on the objective rail.
	_connect_signal(EventBus.objective_updated, _on_objective_updated)
	_connect_signal(EventBus.objective_changed, _on_objective_changed)


func _on_day_ended_notify(day: int) -> void:
	if store_type.is_empty():
		return
	_on_day_ended(day)
	_run_customer_simulation()
	EventBus.store_day_closed.emit(StringName(store_type), {"day": day})


## Runs the batch customer simulation for this store at end of day.
## Subclasses may override _get_event_traffic_multiplier() to provide
## store-specific event boosts.
func _run_customer_simulation() -> void:
	if not _inventory_system:
		return
	var rep_mult: float = ReputationSystemSingleton.get_customer_multiplier(store_type)
	var event_mult: float = _get_event_traffic_multiplier()
	var traffic: int = CustomerSimulator.calculate_traffic(
		CustomerSimulator.DEFAULT_BASE_TRAFFIC, rep_mult, event_mult
	)
	var snapshot: Array[ItemInstance] = _inventory_system.get_items_for_store(store_type)
	CustomerSimulator.simulate_day(StringName(store_type), traffic, snapshot)


## Override to return a store-specific event traffic multiplier.
func _get_event_traffic_multiplier() -> float:
	return 1.0


func _connect_signal(sig: Signal, callable: Callable) -> void:
	if not sig.is_connected(callable):
		sig.connect(callable)


func _defer_store_entered(store_id: StringName) -> void:
	call_deferred("_handle_store_entered", store_id)


func _handle_store_entered(store_id: StringName) -> void:
	if StringName(store_type) == store_id:
		_push_gameplay_input_context()
	_on_store_entered(store_id)
	if StringName(store_type) == store_id:
		emit_actions_registered()


## Listens to `EventBus.store_exited` so the base class can pop the gameplay
## input context before delegating to subclasses. Subclasses still receive the
## bare `_on_store_exited(store_id)` virtual.
func _on_store_exited_notify(store_id: StringName) -> void:
	if StringName(store_type) == store_id:
		_pop_gameplay_input_context()
	_on_store_exited(store_id)


## §F-35 — silent returns here are deliberate. Production builds always have
## the InputFocus autoload with CTX_STORE_GAMEPLAY defined, so these guards
## only fire under the unit-test seam (`get_input_context()` already documents
## the same contract). Repeat-entry idempotency (`_pushed_gameplay_context`)
## also short-circuits silently because pushing the same context twice would
## desync the stack the second time we pop.
func _push_gameplay_input_context() -> void:
	if _pushed_gameplay_context:
		return
	var focus: Node = _get_input_focus()
	if focus == null or not focus.has_method("push_context"):
		return
	var ctx: Variant = focus.get(&"CTX_STORE_GAMEPLAY")
	if ctx == null:
		return
	focus.call("push_context", StringName(ctx))
	_pushed_gameplay_context = true


func _pop_gameplay_input_context() -> void:
	if not _pushed_gameplay_context:
		return
	var focus: Node = _get_input_focus()
	if focus == null or not focus.has_method("pop_context"):
		_pushed_gameplay_context = false
		return
	var current_ctx: StringName = focus.call("current")
	var ctx_const: Variant = focus.get(&"CTX_STORE_GAMEPLAY")
	if ctx_const != null and current_ctx != StringName(ctx_const):
		# A modal pushed on top of us — leave it alone. The modal owner is
		# responsible for popping itself; once it does, the store_gameplay
		# context will be on top again. We mark our flag down so the next
		# store entry can re-push from a known state.
		_pushed_gameplay_context = false
		return
	focus.call("pop_context")
	_pushed_gameplay_context = false


func _get_input_focus() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("InputFocus")


## §F-43 — silent skip on `payload.hidden == true` is intentional: the
## ObjectiveDirector raises that flag when the rail is auto-hidden so
## subscribers (StoreController, HUD) keep their last visible text instead of
## flashing it to empty. Empty `text` is treated as "no payload to mirror"
## for the same reason. Both branches are stable-state mirrors, not failure
## paths.
func _on_objective_updated(payload: Dictionary) -> void:
	if payload.get("hidden", false):
		return
	var text: String = str(payload.get("current_objective", payload.get("text", "")))
	if text.is_empty():
		return
	set_objective_text(text)


func _on_objective_changed(payload: Dictionary) -> void:
	if payload.get("hidden", false):
		return
	var text: String = str(payload.get("text", payload.get("objective", "")))
	if text.is_empty():
		return
	set_objective_text(text)


## Registers an Interactable with this controller. Idempotent.
func register_interactable(node: Interactable) -> void:
	if node == null or not is_instance_valid(node):
		return
	if _registered_interactables.has(node):
		return
	_registered_interactables.append(node)


## Returns all Interactables registered with this controller (visible or not).
func get_registered_interactables() -> Array[Interactable]:
	return _registered_interactables.duplicate()


## Returns the count of Interactables currently visible in the scene tree.
func count_visible_interactables() -> int:
	var count: int = 0
	for node: Interactable in _registered_interactables:
		if not is_instance_valid(node):
			continue
		if not node.is_inside_tree():
			continue
		if not node.is_visible_in_tree():
			continue
		count += 1
	return count


## Sets current_objective_text and emits both the local signal and the
## EventBus mirror so HUDs not parented to this controller update within one frame.
func set_objective_text(text: String) -> void:
	if text == current_objective_text:
		return
	current_objective_text = text
	objective_text_changed.emit(text)
	if EventBus.has_signal(&"objective_text_changed"):
		EventBus.objective_text_changed.emit(text)


## StoreReadyContract invariant #10. The objective text references a real
## action when at least one registered, visible Interactable has an
## action_verb that appears as a token in the objective text AND a
## display_name token also appears in the text. Empty objective text is
## treated as a contract violation (no action to verify against).
func objective_matches_action() -> bool:
	if current_objective_text.strip_edges().is_empty():
		return false
	var lowered: String = current_objective_text.to_lower()
	for node: Interactable in _registered_interactables:
		if not is_instance_valid(node):
			continue
		if not node.is_visible_in_tree():
			continue
		var verb: String = node.action_verb.strip_edges().to_lower()
		var subject: String = node.display_name.strip_edges().to_lower()
		if verb.is_empty() or subject.is_empty():
			continue
		if lowered.contains(verb) and _objective_mentions_subject(lowered, subject):
			return true
	return false


func _objective_mentions_subject(lowered_text: String, subject: String) -> bool:
	if lowered_text.contains(subject):
		return true
	# Subject phrases like "interactable shelf" should still match an objective
	# that names only the head noun ("shelf").
	for token: String in subject.split(" ", false):
		if token.length() < 3:
			continue
		if lowered_text.contains(token):
			return true
	return false


func _register_interactables() -> void:
	_registered_interactables.clear()
	_collect_interactables_recursive(self)
	var owning_store_id: StringName = StringName(store_type)
	for node: Interactable in _registered_interactables:
		# Tag every interactable with the owning store so scoped
		# EventBus.interactable_clicked/_hovered events can identify source.
		node.store_id = owning_store_id
		if not node.interacted_by.is_connected(_on_interactable_interacted):
			node.interacted_by.connect(_on_interactable_interacted)


func _collect_interactables_recursive(node: Node) -> void:
	for child: Node in node.get_children():
		if child is Interactable:
			_registered_interactables.append(child as Interactable)
		_collect_interactables_recursive(child)


func _on_interactable_interacted(_by: Node) -> void:
	# Routed through EventBus.interactable_interacted by the Interactable
	# itself; this hook exists so subclasses can react via override without
	# wiring their own signal connections.
	pass


## Dev-only fallback that places one valid backroom item on the first empty
## ShelfSlot in this store. Routes through `assign_to_shelf()` so the normal
## item_stocked / inventory_changed signals fire and downstream listeners
## (HUD ItemsPlacedLabel, sale-eligibility, slot visuals) update exactly as
## they would for a real placement. Returns true on success.
##
## Guarded by `OS.is_debug_build()` — release builds short-circuit and return
## false. Intended to unblock the Day-1 placement loop when the inventory UI
## is broken; not a substitute for the real flow.
func dev_force_place_test_item() -> bool:
	if not OS.is_debug_build():
		return false
	if _inventory_system == null:
		push_warning(
			"StoreController: dev_force_place_test_item — no inventory_system"
		)
		return false
	var store_id: StringName = StringName(store_type)
	if store_id.is_empty():
		push_warning(
			"StoreController: dev_force_place_test_item — store_type unset"
		)
		return false
	var backroom: Array[ItemInstance] = (
		_inventory_system.get_backroom_items_for_store(String(store_id))
	)
	if backroom.is_empty():
		push_warning(
			(
				"StoreController: dev_force_place_test_item — backroom empty "
				+ "for '%s'; nothing to place"
			)
			% store_id
		)
		return false
	var target_slot: ShelfSlot = null
	for slot_node: Node in _slots:
		if not slot_node is ShelfSlot:
			continue
		var slot := slot_node as ShelfSlot
		if slot.is_occupied():
			continue
		if str(slot.slot_id).is_empty():
			continue
		target_slot = slot
		break
	if target_slot == null:
		push_warning(
			"StoreController: dev_force_place_test_item — no empty shelf slot"
		)
		return false
	var item: ItemInstance = backroom[0]
	var ok: bool = _inventory_system.assign_to_shelf(
		store_id,
		StringName(item.instance_id),
		StringName(target_slot.slot_id),
	)
	if ok:
		print(
			"[dev-fallback] dev_force_place_test_item placed '%s' on '%s' (store: %s)"
				% [item.instance_id, target_slot.slot_id, store_id]
		)
	return ok


## Shows a 3D mesh on the matching ShelfSlot when an item is stocked onto it.
## Idempotent: skipped when the slot is already visually occupied.
func _on_slot_stocked_visual(item_id: String, shelf_id: String) -> void:
	var slot_node: Node = get_slot_by_id(shelf_id)
	if not slot_node is ShelfSlot:
		return
	var slot := slot_node as ShelfSlot
	if slot.is_occupied():
		return
	var category: String = ""
	if _inventory_system:
		var item: ItemInstance = _inventory_system.get_item(item_id)
		if item and item.definition:
			category = item.definition.category
	slot.place_item(item_id, category)


## Clears the 3D mesh on the matching ShelfSlot when an item leaves it.
## Idempotent: no-op when the slot is already empty.
func _on_slot_cleared_visual(_item_id: String, shelf_id: String) -> void:
	var slot_node: Node = get_slot_by_id(shelf_id)
	if not slot_node is ShelfSlot:
		return
	(slot_node as ShelfSlot).remove_item()
