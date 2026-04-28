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


# ── EventBus signal ───────────────────────────────────────────────────────────

func test_eventbus_has_nav_zone_selected_signal() -> void:
	var eb: Node = get_tree().root.get_node_or_null("EventBus")
	assert_not_null(eb, "EventBus autoload must be present")
	if eb:
		assert_true(
			eb.has_signal("nav_zone_selected"),
			"EventBus must declare nav_zone_selected signal"
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
