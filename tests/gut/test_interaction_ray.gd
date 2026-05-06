## Tests interaction ray focus/unfocus signal emission for hover state changes.
extends GutTest


const _InteractionRayScript: GDScript = preload(
	"res://game/scripts/player/interaction_ray.gd"
)

var _ray: Node
var _focused_labels: Array[String] = []
var _disabled_reasons: Array[String] = []
var _unfocused_count: int = 0
var _notifications: Array[String] = []


func before_each() -> void:
	_focused_labels.clear()
	_disabled_reasons.clear()
	_unfocused_count = 0
	_notifications.clear()
	_ray = Node.new()
	_ray.set_script(_InteractionRayScript)
	add_child_autofree(_ray)
	EventBus.interactable_focused.connect(_on_interactable_focused)
	EventBus.interactable_focused_disabled.connect(_on_interactable_focused_disabled)
	EventBus.interactable_unfocused.connect(_on_interactable_unfocused)
	EventBus.notification_requested.connect(_on_notification_requested)


func after_each() -> void:
	if EventBus.interactable_focused.is_connected(_on_interactable_focused):
		EventBus.interactable_focused.disconnect(_on_interactable_focused)
	if EventBus.interactable_focused_disabled.is_connected(_on_interactable_focused_disabled):
		EventBus.interactable_focused_disabled.disconnect(_on_interactable_focused_disabled)
	if EventBus.interactable_unfocused.is_connected(_on_interactable_unfocused):
		EventBus.interactable_unfocused.disconnect(_on_interactable_unfocused)
	if EventBus.notification_requested.is_connected(_on_notification_requested):
		EventBus.notification_requested.disconnect(_on_notification_requested)


func test_focus_emits_action_label_when_target_changes() -> void:
	var target: Interactable = _create_target("Enter", "Store")

	_ray._set_hovered_target(target)

	assert_eq(
		_focused_labels,
		["Store — Press E to enter"],
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
		"GlassCase — Press E to inspect",
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


func test_default_ray_distance_capped_for_first_person() -> void:
	# FP gameplay must require walking up to a fixture; a long default would
	# let the player interact across the 16x20m store from the entrance.
	assert_lt(
		_ray.ray_distance, 2.51,
		"Default ray_distance must be <= 2.5m to preserve gaze-based FP interaction"
	)
	assert_gt(
		_ray.ray_distance, 0.0,
		"Default ray_distance must be positive"
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


func test_disabled_focus_emits_disabled_signal_with_reason() -> void:
	var target: _DisabledTarget = _DisabledTarget.new()
	target.prompt_text = "Use"
	target.display_name = "Counter"
	target.disabled_reason = "No customer waiting"
	add_child_autofree(target)

	_ray._set_hovered_target(target)

	assert_true(
		_focused_labels.is_empty(),
		"Disabled targets must not emit interactable_focused — that path is reserved for actionable focus"
	)
	assert_eq(
		_disabled_reasons,
		["No customer waiting"],
		"Disabled focus must route through interactable_focused_disabled with the reason text"
	)


func test_disabled_focus_caches_can_interact_for_e_press_guard() -> void:
	var target: _DisabledTarget = _DisabledTarget.new()
	target.disabled_reason = "Shelf full"
	add_child_autofree(target)

	_ray._set_hovered_target(target)

	assert_false(
		_ray._hovered_can_interact,
		"InteractionRay must cache can_interact()=false so E-press dispatch can short-circuit"
	)


func test_active_focus_caches_can_interact_true() -> void:
	var target: Interactable = _create_target("Use", "Register")

	_ray._set_hovered_target(target)

	assert_true(
		_ray._hovered_can_interact,
		"InteractionRay must cache can_interact()=true for actionable targets"
	)


func test_clearing_target_resets_can_interact_cache() -> void:
	var target: _DisabledTarget = _DisabledTarget.new()
	target.disabled_reason = "Shelf full"
	add_child_autofree(target)

	_ray._set_hovered_target(target)
	_ray._set_hovered_target(null)

	assert_false(
		_ray._hovered_can_interact,
		"Clearing the hovered target must reset the can_interact cache"
	)


func test_hovered_action_label_returns_disabled_reason() -> void:
	var target: _DisabledTarget = _DisabledTarget.new()
	target.disabled_reason = "Shelf full"
	add_child_autofree(target)

	_ray._set_hovered_target(target)

	assert_eq(
		_ray.get_hovered_action_label(),
		"Shelf full",
		"Disabled-state focus should still expose the reason via get_hovered_action_label() so AuditOverlay reflects it"
	)


func test_poll_emits_disabled_when_can_interact_flips_to_false_mid_hover() -> void:
	# Trigger sequence: the player aims at an active target, runtime state
	# flips can_interact() to false mid-hover (shelf fills, customer leaves,
	# register disables). The same-target short-circuit in `_update_raycast`
	# must still re-query and re-emit so the prompt does not lie.
	var target: _StatefulTarget = _StatefulTarget.new()
	target.prompt_text = "Stock"
	target.display_name = "Shelf"
	target.disabled_reason = "Shelf full"
	target.can = true
	add_child_autofree(target)
	_ray._set_hovered_target(target)
	_focused_labels.clear()
	_disabled_reasons.clear()

	target.can = false
	_ray._poll_hovered_can_interact()

	assert_false(
		_ray._hovered_can_interact,
		"Per-frame poll must update _hovered_can_interact when state flips to false"
	)
	assert_eq(
		_disabled_reasons,
		["Shelf full"],
		"State flip to can_interact()=false must re-emit interactable_focused_disabled"
	)
	assert_true(
		_focused_labels.is_empty(),
		"State flip must not emit a fresh interactable_focused alongside the disabled signal"
	)


func test_poll_emits_focused_when_can_interact_flips_to_true_mid_hover() -> void:
	# Inverse case: the player is aiming at a disabled register; a customer
	# arrives and can_interact() flips to true. Without the poll, the player
	# has to look away and back to see the E badge.
	var target: _StatefulTarget = _StatefulTarget.new()
	target.prompt_text = "Use"
	target.display_name = "Register"
	target.disabled_reason = "No customer"
	target.can = false
	add_child_autofree(target)
	_ray._set_hovered_target(target)
	_focused_labels.clear()
	_disabled_reasons.clear()

	target.can = true
	_ray._poll_hovered_can_interact()

	assert_true(
		_ray._hovered_can_interact,
		"Per-frame poll must update _hovered_can_interact when state flips to true"
	)
	assert_eq(
		_focused_labels,
		["Register — Press E to use"],
		"State flip to can_interact()=true must re-emit interactable_focused with the action label"
	)
	assert_true(
		_disabled_reasons.is_empty(),
		"State flip must not emit a stale interactable_focused_disabled alongside the active signal"
	)


func test_poll_is_no_op_when_can_interact_unchanged() -> void:
	# can_interact() implementations are expected to be cheap, but they are
	# called every frame while hovered. Guard against spurious signal
	# emission when the cached value still matches the live result.
	var target: Interactable = _create_target("Use", "Register")
	_ray._set_hovered_target(target)
	_focused_labels.clear()
	_disabled_reasons.clear()

	_ray._poll_hovered_can_interact()
	_ray._poll_hovered_can_interact()
	_ray._poll_hovered_can_interact()

	assert_true(
		_focused_labels.is_empty(),
		"Repeated polls with unchanged can_interact() must not re-emit interactable_focused"
	)
	assert_true(
		_disabled_reasons.is_empty(),
		"Repeated polls with unchanged can_interact() must not emit interactable_focused_disabled"
	)


func test_poll_updates_hovered_action_label_on_state_change() -> void:
	# get_hovered_action_label() backs the AuditOverlay; when state flips it
	# should reflect the new disabled-reason text rather than the stale
	# "Press E" label captured at hover-entry.
	var target: _StatefulTarget = _StatefulTarget.new()
	target.prompt_text = "Use"
	target.display_name = "Register"
	target.disabled_reason = "Closed"
	target.can = true
	add_child_autofree(target)
	_ray._set_hovered_target(target)
	assert_eq(
		_ray.get_hovered_action_label(),
		"Register — Press E to use",
		"Pre-condition: active label captured at hover-entry"
	)

	target.can = false
	_ray._poll_hovered_can_interact()

	assert_eq(
		_ray.get_hovered_action_label(),
		"Closed",
		"Hovered action label must follow the disabled reason after state flip"
	)


func test_poll_no_op_when_no_target_hovered() -> void:
	# Defensive: the poll is invoked from `_update_raycast` only when the
	# raycast result equals the current hover, but the helper must also
	# tolerate a null hover (e.g. test seam, future call sites).
	_focused_labels.clear()
	_disabled_reasons.clear()

	_ray._poll_hovered_can_interact()

	assert_true(
		_focused_labels.is_empty() and _disabled_reasons.is_empty(),
		"Poll with no hovered target must emit nothing"
	)


func test_get_open_panel_count_starts_at_zero() -> void:
	assert_eq(
		_ray.get_open_panel_count(),
		0,
		"InteractionRay.get_open_panel_count() should start at zero"
	)


func test_get_open_panel_count_tracks_panel_signals() -> void:
	# Public accessor must mirror the private counter so debug overlays and
	# audit tooling can read modal-lock depth without poking internals.
	EventBus.panel_opened.emit("debug_panel_one")
	assert_eq(
		_ray.get_open_panel_count(),
		1,
		"panel_opened should increment the open panel count"
	)
	EventBus.panel_opened.emit("debug_panel_two")
	assert_eq(
		_ray.get_open_panel_count(),
		2,
		"Concurrent open panels should accumulate in the count"
	)
	EventBus.panel_closed.emit("debug_panel_one")
	assert_eq(
		_ray.get_open_panel_count(),
		1,
		"panel_closed should decrement the open panel count"
	)
	EventBus.panel_closed.emit("debug_panel_two")
	assert_eq(
		_ray.get_open_panel_count(),
		0,
		"Closing all panels should return the count to zero"
	)


func test_debug_overlay_node_present_in_debug_build() -> void:
	# Headless GUT runs in a debug build, so the debug overlay CanvasLayer
	# should have been spawned by `_ready`. In a release export build the
	# `OS.is_debug_build()` gate keeps the node from ever being instantiated.
	if not OS.is_debug_build():
		pending("Debug overlay only exists in debug builds")
		return
	var overlay: Node = _ray.get_node_or_null("DebugInteractionOverlay")
	assert_not_null(
		overlay,
		"InteractionRay should attach a DebugInteractionOverlay child in debug builds"
	)
	assert_true(
		overlay is CanvasLayer,
		"DebugInteractionOverlay should be a CanvasLayer so it draws above the HUD"
	)


func _create_target(prompt_text: String, display_name: String) -> Interactable:
	var target := Interactable.new()
	target.prompt_text = prompt_text
	target.display_name = display_name
	add_child_autofree(target)
	return target


func _on_interactable_focused(action_label: String) -> void:
	_focused_labels.append(action_label)


func _on_interactable_focused_disabled(reason: String) -> void:
	_disabled_reasons.append(reason)


func _on_interactable_unfocused() -> void:
	_unfocused_count += 1


func _on_notification_requested(message: String) -> void:
	_notifications.append(message)


## Test stub that returns false from `can_interact()` and exposes a settable
## `disabled_reason` field. Mirrors the production override pattern used by
## the retro-games checkout counter and ShelfSlot empty-state migrations.
class _DisabledTarget extends Interactable:
	var disabled_reason: String = ""

	func can_interact(_actor: Node = null) -> bool:
		return false

	func get_disabled_reason(_actor: Node = null) -> String:
		return disabled_reason


## Test stub whose `can_interact()` result is driven by a public flag, so a
## test can flip the value mid-hover and assert the per-frame poll re-emits
## the correct focus/disabled signal pair.
class _StatefulTarget extends Interactable:
	var can: bool = true
	var disabled_reason: String = ""

	func can_interact(_actor: Node = null) -> bool:
		return can

	func get_disabled_reason(_actor: Node = null) -> String:
		return disabled_reason
