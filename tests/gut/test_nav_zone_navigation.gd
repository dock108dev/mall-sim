## Verifies nav zone navigation: EventBus signal, keyboard shortcut actions,
## and PlayerController response. Scene structural checks live in
## test_retro_games_scene_issue_006.gd (which already loads retro_games.tscn).
extends GutTest

const PlayerControllerScene: PackedScene = preload(
	"res://game/scenes/player/player_controller.tscn"
)

var _player: PlayerController = null


func before_all() -> void:
	_player = PlayerControllerScene.instantiate() as PlayerController
	add_child(_player)


func after_all() -> void:
	if is_instance_valid(_player):
		_player.free()
	_player = null


func before_each() -> void:
	# Reset session-wide static flag so each test starts with a clean slate.
	NavZoneInteractable._debug_always_on_session = false


# ── EventBus signal ───────────────────────────────────────────────────────────

func test_eventbus_has_nav_zone_selected_signal() -> void:
	var eb: Node = get_tree().root.get_node_or_null("EventBus")
	assert_not_null(eb, "EventBus autoload must be present")
	if eb:
		assert_true(
			eb.has_signal("nav_zone_selected"),
			"EventBus must declare nav_zone_selected signal"
		)


func test_eventbus_has_zone_labels_debug_toggled_signal() -> void:
	var eb: Node = get_tree().root.get_node_or_null("EventBus")
	assert_not_null(eb, "EventBus autoload must be present")
	if eb:
		assert_true(
			eb.has_signal("zone_labels_debug_toggled"),
			"EventBus must declare zone_labels_debug_toggled signal"
		)


# ── Keyboard input actions ────────────────────────────────────────────────────

func test_nav_zone_input_actions_registered() -> void:
	for i: int in range(1, 6):
		var action: String = "nav_zone_%d" % i
		assert_true(
			InputMap.has_action(action),
			"InputMap must have action '%s'" % action
		)


func test_nav_zone_actions_have_shift_modifier() -> void:
	for i: int in range(1, 6):
		var action: String = "nav_zone_%d" % i
		if not InputMap.has_action(action):
			continue
		var events: Array[InputEvent] = InputMap.action_get_events(action)
		var has_shift: bool = false
		for evt: InputEvent in events:
			if evt is InputEventKey and (evt as InputEventKey).shift_pressed:
				has_shift = true
				break
		assert_true(has_shift, "'%s' must bind a Shift+key combination" % action)


func test_zone_labels_debug_action_registered() -> void:
	assert_true(
		InputMap.has_action("zone_labels_debug"),
		"InputMap must have action 'zone_labels_debug' for F3 toggle"
	)


# ── PlayerController integration ──────────────────────────────────────────────

func test_player_controller_responds_to_nav_zone_selected() -> void:
	var eb: Node = get_tree().root.get_node_or_null("EventBus")
	if not eb or not is_instance_valid(_player):
		return
	var target: Vector3 = Vector3(1.0, 0.0, -1.0)
	eb.nav_zone_selected.emit(target)
	var pivot: Vector3 = _player.get_pivot()
	assert_almost_eq(pivot.x, target.x, 0.01, "Pivot x must match emitted zone x")
	assert_almost_eq(pivot.z, target.z, 0.01, "Pivot z must match emitted zone z")


func test_set_pivot_snap_is_immediate() -> void:
	if not is_instance_valid(_player):
		return
	var eb: Node = get_tree().root.get_node_or_null("EventBus")
	if not eb:
		return
	var before: Vector3 = _player.get_pivot()
	var target: Vector3 = Vector3(-1.5, 0.0, -1.0)
	eb.nav_zone_selected.emit(target)
	var after: Vector3 = _player.get_pivot()
	assert_ne(before, after, "Pivot must change immediately after nav_zone_selected")


# ── Label visibility behavior ─────────────────────────────────────────────────
# Tests use register_label() to set the label reference directly, bypassing
# NodePath resolution so the tests remain independent of scene tree layout.

func _make_zone_and_label() -> Array:
	var parent: Node3D = Node3D.new()
	var label: Label3D = Label3D.new()
	label.visible = true
	parent.add_child(label)
	var zone: NavZoneInteractable = NavZoneInteractable.new()
	zone.zone_index = 99
	parent.add_child(zone)
	return [parent, zone, label]


func test_nav_zone_label_hidden_by_default() -> void:
	var parts: Array = _make_zone_and_label()
	var parent: Node3D = parts[0]
	var zone: NavZoneInteractable = parts[1]
	var label: Label3D = parts[2]
	add_child_autofree(parent)
	zone.register_label(label)
	assert_false(label.visible, "Linked label must be hidden on register when no flag is set")


func test_nav_zone_label_shows_on_focused() -> void:
	var parts: Array = _make_zone_and_label()
	var parent: Node3D = parts[0]
	var zone: NavZoneInteractable = parts[1]
	var label: Label3D = parts[2]
	add_child_autofree(parent)
	zone.register_label(label)
	assert_false(label.visible, "Label must be hidden before focus")
	zone.focused.emit()
	assert_true(label.visible, "Label must show when zone is focused")


func test_nav_zone_label_hides_on_unfocused() -> void:
	var parts: Array = _make_zone_and_label()
	var parent: Node3D = parts[0]
	var zone: NavZoneInteractable = parts[1]
	var label: Label3D = parts[2]
	add_child_autofree(parent)
	zone.register_label(label)
	zone.focused.emit()
	assert_true(label.visible, "Label must show on focused")
	zone.unfocused.emit()
	assert_false(label.visible, "Label must hide on unfocused")


func test_nav_zone_label_shows_on_selection_match() -> void:
	var parts: Array = _make_zone_and_label()
	var parent: Node3D = parts[0]
	var zone: NavZoneInteractable = parts[1]
	var label: Label3D = parts[2]
	add_child_autofree(parent)
	zone.register_label(label)
	var eb: Node = get_tree().root.get_node_or_null("EventBus")
	if not eb:
		return
	eb.nav_zone_selected.emit(zone.global_position)
	assert_true(label.visible, "Label must show when this zone's position is selected")


func test_nav_zone_label_stays_hidden_on_selection_mismatch() -> void:
	var parts: Array = _make_zone_and_label()
	var parent: Node3D = parts[0]
	var zone: NavZoneInteractable = parts[1]
	var label: Label3D = parts[2]
	add_child_autofree(parent)
	zone.register_label(label)
	var eb: Node = get_tree().root.get_node_or_null("EventBus")
	if not eb:
		return
	eb.nav_zone_selected.emit(Vector3(999.0, 0.0, 999.0))
	assert_false(label.visible, "Label must stay hidden when a different zone is selected")


func test_nav_zone_label_shows_when_debug_always_on() -> void:
	var parts: Array = _make_zone_and_label()
	var parent: Node3D = parts[0]
	var zone: NavZoneInteractable = parts[1]
	var label: Label3D = parts[2]
	add_child_autofree(parent)
	zone.register_label(label)
	var eb: Node = get_tree().root.get_node_or_null("EventBus")
	if not eb:
		return
	eb.zone_labels_debug_toggled.emit(true)
	assert_true(label.visible, "Label must show when debug always-on is enabled")


func test_nav_zone_label_hides_when_debug_turned_off() -> void:
	var parts: Array = _make_zone_and_label()
	var parent: Node3D = parts[0]
	var zone: NavZoneInteractable = parts[1]
	var label: Label3D = parts[2]
	add_child_autofree(parent)
	zone.register_label(label)
	var eb: Node = get_tree().root.get_node_or_null("EventBus")
	if not eb:
		return
	eb.zone_labels_debug_toggled.emit(true)
	assert_true(label.visible, "Label visible with debug on")
	eb.zone_labels_debug_toggled.emit(false)
	assert_false(label.visible, "Label must hide when debug always-on is disabled")
