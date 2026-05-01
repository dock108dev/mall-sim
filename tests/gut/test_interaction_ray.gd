## Tests interaction ray focus/unfocus signal emission for hover state changes.
extends GutTest


const _InteractionRayScript: GDScript = preload(
	"res://game/scripts/player/interaction_ray.gd"
)

var _ray: Node
var _focused_labels: Array[String] = []
var _unfocused_count: int = 0
var _notifications: Array[String] = []


func before_each() -> void:
	_focused_labels.clear()
	_unfocused_count = 0
	_notifications.clear()
	_ray = Node.new()
	_ray.set_script(_InteractionRayScript)
	add_child_autofree(_ray)
	EventBus.interactable_focused.connect(_on_interactable_focused)
	EventBus.interactable_unfocused.connect(_on_interactable_unfocused)
	EventBus.notification_requested.connect(_on_notification_requested)


func after_each() -> void:
	if EventBus.interactable_focused.is_connected(_on_interactable_focused):
		EventBus.interactable_focused.disconnect(_on_interactable_focused)
	if EventBus.interactable_unfocused.is_connected(_on_interactable_unfocused):
		EventBus.interactable_unfocused.disconnect(_on_interactable_unfocused)
	if EventBus.notification_requested.is_connected(_on_notification_requested):
		EventBus.notification_requested.disconnect(_on_notification_requested)


func test_focus_emits_action_label_when_target_changes() -> void:
	var target: Interactable = _create_target("Enter", "Store")

	_ray._set_hovered_target(target)

	assert_eq(
		_focused_labels,
		["Store / Press E to enter"],
		"Focusing a target should emit interactable_focused with the built action label"
	)
	assert_eq(_unfocused_count, 0, "Focusing should not emit unfocus")


func test_hovered_action_label_getter_reflects_focus_state() -> void:
	var target: Interactable = _create_target("Inspect", "GlassCase")

	assert_eq(
		_ray.get_hovered_action_label(),
		"",
		"With no hovered target, action label getter should return empty string"
	)

	_ray._set_hovered_target(target)
	assert_eq(
		_ray.get_hovered_action_label(),
		"GlassCase / Press E to inspect",
		"Hovered action label should match the built action label"
	)

	_ray._set_hovered_target(null)
	assert_eq(
		_ray.get_hovered_action_label(),
		"",
		"After unfocus, action label getter should reset to empty string"
	)


func test_interaction_ray_registers_in_lookup_group() -> void:
	assert_true(
		_ray.is_in_group(&"interaction_ray"),
		"InteractionRay should self-register in the 'interaction_ray' group for AuditOverlay lookup"
	)


func test_unfocus_emits_when_target_cleared() -> void:
	var target: Interactable = _create_target("Inspect", "Item")
	_ray._set_hovered_target(target)

	_ray._set_hovered_target(null)

	assert_eq(_unfocused_count, 1, "Clearing the target should emit interactable_unfocused once")


func test_target_loss_emits_unfocus_when_hovered_node_exits_tree() -> void:
	var target: Interactable = _create_target("Use", "Register")
	_ray._set_hovered_target(target)

	target.queue_free()
	await get_tree().process_frame

	assert_eq(
		_unfocused_count,
		1,
		"Hovered target exiting the tree should emit interactable_unfocused"
	)
	assert_null(_ray.get_hovered_target(), "Hovered target should be cleared after tree exit")


func test_hover_changes_do_not_emit_legacy_notifications() -> void:
	var target: Interactable = _create_target("Enter", "Store")

	_ray._set_hovered_target(target)
	_ray._set_hovered_target(null)

	assert_true(
		_notifications.is_empty(),
		"Interaction hover should use interactable_focused/unfocused instead of notification_requested"
	)


func _create_target(prompt_text: String, display_name: String) -> Interactable:
	var target := Interactable.new()
	target.prompt_text = prompt_text
	target.display_name = display_name
	add_child_autofree(target)
	return target


func _on_interactable_focused(action_label: String) -> void:
	_focused_labels.append(action_label)


func _on_interactable_unfocused() -> void:
	_unfocused_count += 1


func _on_notification_requested(message: String) -> void:
	_notifications.append(message)
