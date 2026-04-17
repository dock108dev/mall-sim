## Integration test: player interaction ray triggers interactable and store entry signals.
extends GutTest

const STORE_ID: StringName = &"test_store"

var _interaction_ray: Node
var _interacted_count: int = 0
var _store_entered_ids: Array[StringName] = []
var _bridge_connected: bool = false
var _unfocused_count: int = 0


func before_each() -> void:
	_interacted_count = 0
	_store_entered_ids.clear()
	_bridge_connected = false
	_unfocused_count = 0

	_interaction_ray = load(
		"res://game/scripts/player/interaction_ray.gd"
	).new()
	add_child_autofree(_interaction_ray)

	EventBus.store_entered.connect(_on_store_entered)
	EventBus.interactable_unfocused.connect(_on_interactable_unfocused)


func after_each() -> void:
	if EventBus.store_entered.is_connected(_on_store_entered):
		EventBus.store_entered.disconnect(_on_store_entered)
	if EventBus.interactable_unfocused.is_connected(
		_on_interactable_unfocused
	):
		EventBus.interactable_unfocused.disconnect(
			_on_interactable_unfocused
		)
	if _bridge_connected and EventBus.interactable_interacted.is_connected(
		_on_storefront_interacted_bridge
	):
		EventBus.interactable_interacted.disconnect(_on_storefront_interacted_bridge)


# ── Signal handlers ────────────────────────────────────────────────────────────

func _on_interacted() -> void:
	_interacted_count += 1


func _on_store_entered(store_id: StringName) -> void:
	_store_entered_ids.append(store_id)


func _on_interactable_unfocused() -> void:
	_unfocused_count += 1


## Bridges interactable_interacted(STOREFRONT) → store_entered to simulate
## the minimal wiring done by Storefront + MallHallway + StoreSelectorSystem
## without requiring those full scene nodes in the test.
func _on_storefront_interacted_bridge(
	_target: Interactable, interaction_type: int
) -> void:
	if interaction_type == Interactable.InteractionType.STOREFRONT:
		EventBus.store_entered.emit(STORE_ID)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_interact_event() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	return event


func _make_interactable(
	type: Interactable.InteractionType, label: String
) -> Interactable:
	var interactable := Interactable.new()
	interactable.interaction_type = type
	interactable.display_name = label
	add_child_autofree(interactable)
	return interactable


# ── Tests ─────────────────────────────────────────────────────────────────────

func test_interact_input_calls_interact_on_hovered_target() -> void:
	var interactable: Interactable = _make_interactable(
		Interactable.InteractionType.ITEM, "Test Item"
	)
	interactable.interacted.connect(_on_interacted)

	_interaction_ray._hovered_target = interactable
	_interaction_ray._unhandled_input(_make_interact_event())

	assert_eq(
		_interacted_count, 1,
		"interact() must be called on the hovered target when interact is pressed"
	)


func test_interact_input_out_of_range_does_not_call_interact() -> void:
	var interactable: Interactable = _make_interactable(
		Interactable.InteractionType.ITEM, "Out of Range Item"
	)
	interactable.interacted.connect(_on_interacted)

	# _hovered_target remains null — simulates interactable outside ray range
	_interaction_ray._unhandled_input(_make_interact_event())

	assert_eq(
		_interacted_count, 0,
		"interact() must NOT be called when no interactable is within ray range"
	)


func test_storefront_interaction_emits_store_entered() -> void:
	EventBus.interactable_interacted.connect(_on_storefront_interacted_bridge)
	_bridge_connected = true

	var storefront: Interactable = _make_interactable(
		Interactable.InteractionType.STOREFRONT, "Test Store"
	)

	_interaction_ray._hovered_target = storefront
	_interaction_ray._unhandled_input(_make_interact_event())

	assert_eq(
		_store_entered_ids.size(), 1,
		"store_entered must fire exactly once on storefront interaction"
	)
	assert_eq(
		_store_entered_ids[0], STORE_ID,
		"store_entered must carry the correct store_id"
	)


func test_resolve_interactable_from_child_area() -> void:
	var interactable: Interactable = _make_interactable(
		Interactable.InteractionType.ITEM, "Area Target"
	)

	var resolved: Interactable = _interaction_ray._resolve_interactable(
		interactable.get_interaction_area()
	)

	assert_same(
		resolved, interactable,
		"Ray hits on the child Area3D should resolve back to the Interactable"
	)


func test_hovered_target_clears_when_interactable_exits_tree() -> void:
	var interactable: Interactable = _make_interactable(
		Interactable.InteractionType.ITEM, "Transient Target"
	)

	_interaction_ray._set_hovered_target(interactable)
	interactable.queue_free()
	await get_tree().process_frame

	assert_null(
		_interaction_ray.get_hovered_target(),
		"Hovered target should clear when an interactable leaves the scene tree"
	)
	assert_eq(
		_unfocused_count, 1,
		"Store transitions should clear the prompt when the focused interactable exits"
	)
