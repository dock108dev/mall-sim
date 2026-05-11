## Tests for the beta-suppression hook on `MomentsTray`.
##
## Covers `disable_for_beta()` — the disconnect+clear+hide path that
## prevents an ambient `EventBus.moment_displayed` from spawning a card
## in the bottom-right corner where the beta Today checklist now lives.
extends GutTest


func _make_tray() -> MomentsTray:
	var scene: PackedScene = load("res://game/scenes/ui/moments_tray.tscn")
	assert_not_null(scene, "moments_tray.tscn must be loadable")
	var tray: MomentsTray = scene.instantiate() as MomentsTray
	add_child_autofree(tray)
	return tray


func test_tray_registers_in_moments_tray_group_on_ready() -> void:
	# Group registration is what `BetaDayOneController._suppress_moments_tray`
	# uses to find the tray without a hard import dependency on game_world.
	var tray: MomentsTray = _make_tray()
	assert_true(
		tray.is_in_group("moments_tray"),
		"MomentsTray must register in the 'moments_tray' group on _ready"
	)


func test_disable_for_beta_disconnects_moment_displayed() -> void:
	var tray: MomentsTray = _make_tray()
	assert_true(
		EventBus.moment_displayed.is_connected(tray._on_moment_displayed),
		"Pre-condition: tray listens on moment_displayed at construction"
	)
	tray.disable_for_beta()
	assert_false(
		EventBus.moment_displayed.is_connected(tray._on_moment_displayed),
		"disable_for_beta() must disconnect the moment_displayed listener"
	)


func test_disable_for_beta_drops_subsequent_moment_emissions() -> void:
	var tray: MomentsTray = _make_tray()
	tray.disable_for_beta()
	EventBus.moment_displayed.emit(&"ambient_drop", "should be ignored", 5.0)
	await get_tree().process_frame
	assert_eq(
		tray.get_normal_queue_depth(), 0,
		"Tray must not enqueue cards from moment_displayed after suppression"
	)


func test_disable_for_beta_clears_pending_queue() -> void:
	var tray: MomentsTray = _make_tray()
	tray.suspend()
	for i: int in range(3):
		tray._normal_queue.append({
			"moment_id": "m%d" % i, "flavor_text": "t",
			"duration_seconds": 5.0, "character_name": "", "display_type": "toast",
		})
	tray.disable_for_beta()
	assert_eq(
		tray.get_queue_depth(), 0,
		"disable_for_beta() must clear any queued cards"
	)


func test_disable_for_beta_hides_tray() -> void:
	var tray: MomentsTray = _make_tray()
	tray.disable_for_beta()
	assert_false(
		tray.visible,
		"disable_for_beta() must hide the tray CanvasLayer"
	)


func test_disable_for_beta_is_idempotent() -> void:
	# Beta scene reloads (Day 1 → Day 2 → Day 1) might call this more than
	# once. The disconnect call must not raise on the second invocation.
	var tray: MomentsTray = _make_tray()
	tray.disable_for_beta()
	tray.disable_for_beta()
	assert_false(
		EventBus.moment_displayed.is_connected(tray._on_moment_displayed),
		"Second disable_for_beta() must remain a clean no-op"
	)
