## Tests for InteractionPrompt visibility, label text, fade behaviour, and
## the screen-state / modal-context visibility guards added for ISSUE-004.
extends GutTest


var _prompt: CanvasLayer
var _saved_state: GameManager.State


func before_each() -> void:
	_saved_state = GameManager.current_state
	# STORE_VIEW lets the focus → visible path run; the new guards block
	# MAIN_MENU and DAY_SUMMARY explicitly, which is what the new tests cover.
	GameManager.current_state = GameManager.State.STORE_VIEW
	_prompt = preload(
		"res://game/scenes/ui/interaction_prompt.tscn"
	).instantiate()
	add_child_autofree(_prompt)


func after_each() -> void:
	GameManager.current_state = _saved_state
	if InputFocus != null:
		InputFocus._reset_for_tests()


func _emit_state(new_state: GameManager.State) -> void:
	var old: GameManager.State = GameManager.current_state
	GameManager.current_state = new_state
	EventBus.game_state_changed.emit(int(old), int(new_state))


func test_hidden_by_default() -> void:
	var panel: PanelContainer = _prompt.get_node("PanelContainer")
	assert_false(
		panel.visible,
		"Panel should be hidden on ready"
	)
	assert_eq(
		panel.modulate.a, 0.0,
		"Panel alpha should be 0 on ready"
	)


func test_shows_on_interactable_focused() -> void:
	EventBus.interactable_focused.emit("Enter Store")
	var panel: PanelContainer = _prompt.get_node("PanelContainer")
	assert_true(
		panel.visible,
		"Panel should become visible after interactable_focused"
	)


func test_focus_fade_reaches_full_alpha() -> void:
	EventBus.interactable_focused.emit("Enter Store")
	var panel: PanelContainer = _prompt.get_node("PanelContainer")
	await get_tree().create_timer(0.2).timeout
	assert_almost_eq(
		panel.modulate.a,
		1.0,
		0.05,
		"Panel alpha should tween to fully visible on focus"
	)


func test_label_text_driven_by_action_label() -> void:
	EventBus.interactable_focused.emit("Examine Item")
	var label: Label = _prompt.get_node("PanelContainer/HBox/Label")
	assert_eq(
		label.text, "Examine Item",
		"Label should display the action_label verbatim (callers include key prefix)"
	)


func test_label_displays_click_prefix() -> void:
	EventBus.interactable_focused.emit("[Click] Enter Store")
	var label: Label = _prompt.get_node("PanelContainer/HBox/Label")
	assert_eq(
		label.text, "[Click] Enter Store",
		"Label must preserve caller-supplied key prefix"
	)


func test_label_updates_on_new_focus() -> void:
	EventBus.interactable_focused.emit("[E] Enter Store")
	EventBus.interactable_focused.emit("[E] Stock Shelf")
	var label: Label = _prompt.get_node("PanelContainer/HBox/Label")
	assert_eq(
		label.text, "[E] Stock Shelf",
		"Label should update when a new interactable is focused"
	)


func test_hides_after_unfocused_tween_completes() -> void:
	EventBus.interactable_focused.emit("Use Register")
	EventBus.interactable_unfocused.emit()
	var panel: PanelContainer = _prompt.get_node("PanelContainer")
	await get_tree().create_timer(0.2).timeout
	assert_almost_eq(
		panel.modulate.a,
		0.0,
		0.05,
		"Panel alpha should tween back to zero on unfocus"
	)
	assert_false(
		panel.visible,
		"Panel should be hidden after unfocused fade completes"
	)


func test_does_not_block_mouse_input() -> void:
	var panel: PanelContainer = _prompt.get_node("PanelContainer")
	assert_eq(
		panel.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"Panel should not intercept mouse events"
	)


# ── Screen-state guard ─────────────────────────────────────────────────────────

func test_does_not_show_in_main_menu_state() -> void:
	_emit_state(GameManager.State.MAIN_MENU)
	EventBus.interactable_focused.emit("Enter Store")
	var panel: PanelContainer = _prompt.get_node("PanelContainer")
	assert_false(
		panel.visible,
		"Prompt must not appear when state is MAIN_MENU"
	)


func test_does_not_show_in_day_summary_state() -> void:
	_emit_state(GameManager.State.DAY_SUMMARY)
	EventBus.interactable_focused.emit("Enter Store")
	var panel: PanelContainer = _prompt.get_node("PanelContainer")
	assert_false(
		panel.visible,
		"Prompt must not appear when state is DAY_SUMMARY"
	)


func test_hides_when_state_changes_to_main_menu_after_focus() -> void:
	EventBus.interactable_focused.emit("Enter Store")
	var panel: PanelContainer = _prompt.get_node("PanelContainer")
	assert_true(panel.visible, "Pre-condition: prompt visible in STORE_VIEW")
	_emit_state(GameManager.State.MAIN_MENU)
	await get_tree().create_timer(0.2).timeout
	assert_false(
		panel.visible,
		"Prompt must hide once state changes to MAIN_MENU"
	)


# ── Modal context guard ────────────────────────────────────────────────────────

func test_hides_when_modal_context_pushed() -> void:
	EventBus.interactable_focused.emit("Enter Store")
	var panel: PanelContainer = _prompt.get_node("PanelContainer")
	assert_true(panel.visible, "Pre-condition: prompt visible without modal")
	InputFocus.push_context(InputFocus.CTX_MODAL)
	await get_tree().create_timer(0.2).timeout
	assert_false(
		panel.visible,
		"Prompt must hide while modal context is on top of InputFocus stack"
	)


func test_reappears_when_modal_context_popped() -> void:
	EventBus.interactable_focused.emit("Enter Store")
	var panel: PanelContainer = _prompt.get_node("PanelContainer")
	InputFocus.push_context(InputFocus.CTX_MODAL)
	await get_tree().create_timer(0.2).timeout
	assert_false(panel.visible, "Pre-condition: hidden under modal")
	InputFocus.pop_context()
	assert_true(
		panel.visible,
		"Prompt must reappear when modal context is popped while focus target persists"
	)


func test_does_not_show_when_focus_arrives_during_modal() -> void:
	InputFocus.push_context(InputFocus.CTX_MODAL)
	EventBus.interactable_focused.emit("Enter Store")
	var panel: PanelContainer = _prompt.get_node("PanelContainer")
	assert_false(
		panel.visible,
		"Prompt must not become visible when focus arrives while modal is active"
	)


# ── Active vs. disabled prompt styling ─────────────────────────────────────

func test_active_focus_shows_e_key_badge() -> void:
	EventBus.interactable_focused.emit("Counter — Press E to use")
	var badge: PanelContainer = _prompt.get_node("PanelContainer/HBox/KeyBadge")
	assert_true(
		badge.visible,
		"E-key badge must be visible during active (can_interact=true) focus"
	)


func test_active_focus_label_uses_full_opacity() -> void:
	EventBus.interactable_focused.emit("Counter — Press E to use")
	var label: Label = _prompt.get_node("PanelContainer/HBox/Label")
	assert_almost_eq(
		label.modulate.a, 1.0, 0.001,
		"Active prompt's action label must render at full opacity"
	)


func test_disabled_focus_hides_e_key_badge() -> void:
	EventBus.interactable_focused_disabled.emit("No customer waiting")
	var badge: PanelContainer = _prompt.get_node("PanelContainer/HBox/KeyBadge")
	assert_false(
		badge.visible,
		"E-key badge must be hidden during disabled focus so the player can tell at a glance E will not act"
	)


func test_disabled_focus_label_uses_muted_modulate() -> void:
	EventBus.interactable_focused_disabled.emit("No customer waiting")
	var label: Label = _prompt.get_node("PanelContainer/HBox/Label")
	assert_lt(
		label.modulate.a, 0.85,
		"Disabled-reason text must render with reduced alpha so it does not compete with active prompts"
	)


func test_disabled_focus_label_text_matches_reason() -> void:
	EventBus.interactable_focused_disabled.emit("Shelf full")
	var label: Label = _prompt.get_node("PanelContainer/HBox/Label")
	assert_eq(
		label.text, "Shelf full",
		"Disabled-state label must display the get_disabled_reason() text verbatim"
	)


func test_disabled_focus_with_empty_reason_hides_panel() -> void:
	EventBus.interactable_focused_disabled.emit("")
	var panel: PanelContainer = _prompt.get_node("PanelContainer")
	await get_tree().create_timer(0.2).timeout
	assert_false(
		panel.visible,
		"An empty get_disabled_reason() must produce no visible prompt"
	)


func test_active_focus_after_disabled_restores_badge_and_full_opacity() -> void:
	EventBus.interactable_focused_disabled.emit("Shelf full")
	EventBus.interactable_focused.emit("Counter — Press E to use")
	var badge: PanelContainer = _prompt.get_node("PanelContainer/HBox/KeyBadge")
	var label: Label = _prompt.get_node("PanelContainer/HBox/Label")
	assert_true(
		badge.visible,
		"Switching back to an active focus must re-show the E-key badge"
	)
	assert_almost_eq(
		label.modulate.a, 1.0, 0.001,
		"Switching back to an active focus must restore full label opacity"
	)


# ── Defensive re-query when prompt re-shows after a hidden window ──────────

func test_modal_close_reapplies_disabled_styling_when_target_state_changed() -> void:
	# Hover starts active; modal pushes CTX_MODAL (without firing
	# panel_opened, so the ray's hover is not cleared). State of the hovered
	# target flips during the modal. When the modal closes and the prompt
	# re-shows via _refresh_visibility(), it must re-query the ray's current
	# hovered target and reflect can_interact()=false (badge hidden) rather
	# than restore the pre-modal active styling.
	var target: _StatefulTarget = _StatefulTarget.new()
	target.can = true
	add_child_autofree(target)
	var ray_stub: _RayStub = _RayStub.new()
	ray_stub.target = target
	add_child_autofree(ray_stub)

	EventBus.interactable_focused.emit("Counter — Press E to use")
	var badge: PanelContainer = _prompt.get_node("PanelContainer/HBox/KeyBadge")
	assert_true(badge.visible, "Pre-condition: active focus shows the E badge")

	InputFocus.push_context(InputFocus.CTX_MODAL)
	target.can = false
	InputFocus.pop_context()

	assert_false(
		badge.visible,
		"Modal close must re-evaluate can_interact() of the hovered target and hide the E badge when state flipped to false"
	)


func test_modal_close_reapplies_active_styling_when_target_state_changed() -> void:
	# Inverse: hover starts disabled, state flips to actionable during the
	# modal, modal closes — the badge must come back without the player
	# having to look away and back.
	var target: _StatefulTarget = _StatefulTarget.new()
	target.can = false
	target.disabled_reason = "No customer waiting"
	add_child_autofree(target)
	var ray_stub: _RayStub = _RayStub.new()
	ray_stub.target = target
	add_child_autofree(ray_stub)

	EventBus.interactable_focused_disabled.emit("No customer waiting")
	var badge: PanelContainer = _prompt.get_node("PanelContainer/HBox/KeyBadge")
	assert_false(badge.visible, "Pre-condition: disabled focus hides the E badge")

	InputFocus.push_context(InputFocus.CTX_MODAL)
	target.can = true
	InputFocus.pop_context()

	assert_true(
		badge.visible,
		"Modal close must re-evaluate can_interact() of the hovered target and re-show the E badge when state flipped to true"
	)


func test_modal_close_without_focus_target_does_not_query_ray() -> void:
	# Sanity: when no focus target is set, _refresh_visibility() returns
	# early before reaching the ray lookup. Asserts the early-return path
	# is preserved (no spurious styling changes when nothing is hovered).
	var target: _StatefulTarget = _StatefulTarget.new()
	target.can = false
	add_child_autofree(target)
	var ray_stub: _RayStub = _RayStub.new()
	ray_stub.target = target
	add_child_autofree(ray_stub)

	# No prior interactable_focused* event — _has_focus_target stays false.
	InputFocus.push_context(InputFocus.CTX_MODAL)
	InputFocus.pop_context()

	var panel: PanelContainer = _prompt.get_node("PanelContainer")
	assert_false(
		panel.visible,
		"Without a focus target, modal cycles must leave the prompt hidden"
	)


func test_panel_anchor_does_not_move_between_states() -> void:
	# Regression guard for the AC "active prompt and disabled reason render
	# at the same screen position." The panel itself is bottom-center
	# anchored; toggling KeyBadge.visible re-centres the HBox children
	# inside that panel, but the panel's anchor offsets must not shift.
	var panel: PanelContainer = _prompt.get_node("PanelContainer")
	var initial_offset_left: float = panel.offset_left
	var initial_offset_right: float = panel.offset_right
	var initial_offset_bottom: float = panel.offset_bottom

	EventBus.interactable_focused.emit("Counter — Press E to use")
	assert_eq(
		panel.offset_left, initial_offset_left,
		"Active focus must not shift the prompt panel's left anchor offset"
	)
	assert_eq(
		panel.offset_right, initial_offset_right,
		"Active focus must not shift the prompt panel's right anchor offset"
	)

	EventBus.interactable_focused_disabled.emit("Shelf full")
	assert_eq(
		panel.offset_left, initial_offset_left,
		"Disabled focus must not shift the prompt panel's left anchor offset"
	)
	assert_eq(
		panel.offset_right, initial_offset_right,
		"Disabled focus must not shift the prompt panel's right anchor offset"
	)
	assert_eq(
		panel.offset_bottom, initial_offset_bottom,
		"Disabled focus must not shift the prompt panel's bottom anchor offset"
	)


## Test stub registered in the `interaction_ray` lookup group so the prompt
## can resolve a hovered target during _refresh_visibility() without spinning
## up a real raycast pipeline.
class _RayStub extends Node:
	const _GROUP: StringName = &"interaction_ray"
	var target: Interactable = null

	func _ready() -> void:
		add_to_group(_GROUP)

	func get_hovered_target() -> Interactable:
		return target


## Stateful Interactable whose `can_interact()` is driven by a flag, used to
## simulate a state change during a modal-open window.
class _StatefulTarget extends Interactable:
	var can: bool = true
	var disabled_reason: String = ""

	func can_interact(_actor: Node = null) -> bool:
		return can

	func get_disabled_reason(_actor: Node = null) -> String:
		return disabled_reason
