## Verifies the single-DrawerHost slide-out contract: tween-driven width,
## mouse_filter discipline, EventBus signal emission, and no-overlap switching.
extends GutTest

const DRAWER_HOST_SCENE: PackedScene = preload(
	"res://game/scenes/ui/drawer_host.tscn"
)
const MALL_HUB_SCENE: PackedScene = preload(
	"res://game/scenes/mall/mall_hub.tscn"
)


func _instance_host() -> Node:
	var host: Node = DRAWER_HOST_SCENE.instantiate()
	add_child_autofree(host)
	return host


func _get_panel(host: Node) -> PanelContainer:
	return host.get_node("HudRoot/DrawerPanel") as PanelContainer


func _get_hud_root(host: Node) -> Control:
	return host.get_node("HudRoot") as Control


func test_event_bus_declares_drawer_signals() -> void:
	assert_true(
		EventBus.has_signal("drawer_opened"),
		"EventBus must declare drawer_opened",
	)
	assert_true(
		EventBus.has_signal("drawer_closed"),
		"EventBus must declare drawer_closed",
	)


func test_mall_hub_instances_single_drawer_host() -> void:
	var state: SceneState = MALL_HUB_SCENE.get_state()
	var drawer_host_count: int = 0
	for i: int in range(state.get_node_count()):
		if state.get_node_name(i) == &"DrawerHost":
			drawer_host_count += 1
	assert_eq(
		drawer_host_count, 1,
		"mall_hub.tscn must contain exactly one DrawerHost node",
	)


func test_mall_hub_has_no_per_store_drawer_nodes() -> void:
	var state: SceneState = MALL_HUB_SCENE.get_state()
	var banned: Array[StringName] = [
		&"RetroGamesDrawer", &"PocketCreaturesDrawer", &"VideoRentalDrawer",
		&"ElectronicsDrawer", &"SportsCardsDrawer",
	]
	for i: int in range(state.get_node_count()):
		var name: StringName = state.get_node_name(i)
		assert_false(
			name in banned,
			"mall_hub.tscn must not host per-store drawer nodes (%s)" % name,
		)


func test_panel_uses_mouse_filter_stop() -> void:
	var host: Node = _instance_host()
	await wait_frames(1)
	var panel: PanelContainer = _get_panel(host)
	assert_eq(
		panel.mouse_filter, Control.MOUSE_FILTER_STOP,
		"Drawer panel must stop mouse events when visible",
	)


func test_hud_root_pass_through_when_closed() -> void:
	var host: Node = _instance_host()
	await wait_frames(1)
	var hud_root: Control = _get_hud_root(host)
	assert_eq(
		hud_root.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"HUD root must be IGNORE when drawer is closed",
	)


func test_open_drawer_emits_signal_and_tweens_width() -> void:
	var host: Node = _instance_host()
	await wait_frames(1)
	var panel: PanelContainer = _get_panel(host)
	watch_signals(EventBus)

	panel.open_drawer(&"retro_games")

	assert_signal_emitted_with_parameters(
		EventBus, "drawer_opened", [&"retro_games"],
	)
	assert_eq(
		panel.get_active_store_id(), &"retro_games",
		"Active store_id must match opened drawer",
	)

	# Tween runs ~0.25s; wait for completion.
	await get_tree().create_timer(0.35).timeout
	assert_almost_eq(
		panel.custom_minimum_size.x, 420.0, 0.5,
		"custom_minimum_size.x must tween to 420 px",
	)


func test_open_switches_hud_root_to_blocking() -> void:
	var host: Node = _instance_host()
	await wait_frames(1)
	var hud_root: Control = _get_hud_root(host)
	var panel: PanelContainer = _get_panel(host)
	panel.open_drawer(&"electronics")
	assert_eq(
		hud_root.mouse_filter, Control.MOUSE_FILTER_STOP,
		"HUD root must block pass-through while drawer is open",
	)


func test_close_drawer_emits_signal_and_tweens_width() -> void:
	var host: Node = _instance_host()
	await wait_frames(1)
	var panel: PanelContainer = _get_panel(host)
	panel.open_drawer(&"retro_games")
	watch_signals(EventBus)

	panel.close_drawer()

	assert_signal_emitted_with_parameters(
		EventBus, "drawer_closed", [&"retro_games"],
	)
	assert_eq(
		panel.get_active_store_id(), &"",
		"Active store_id must be empty after close",
	)

	await get_tree().create_timer(0.35).timeout
	assert_almost_eq(
		panel.custom_minimum_size.x, 0.0, 0.5,
		"custom_minimum_size.x must tween back to 0 px on close",
	)


func test_opening_another_drawer_closes_previous_first() -> void:
	var host: Node = _instance_host()
	await wait_frames(1)
	var panel: PanelContainer = _get_panel(host)
	panel.open_drawer(&"retro_games")
	watch_signals(EventBus)

	panel.open_drawer(&"pocket_creatures")

	assert_signal_emitted_with_parameters(
		EventBus, "drawer_closed", [&"retro_games"],
	)
	assert_signal_emitted_with_parameters(
		EventBus, "drawer_opened", [&"pocket_creatures"],
	)
	assert_eq(
		panel.get_active_store_id(), &"pocket_creatures",
		"Switching drawers must leave only the new store active",
	)


func test_no_animation_player_in_drawer_scene() -> void:
	var state: SceneState = DRAWER_HOST_SCENE.get_state()
	for i: int in range(state.get_node_count()):
		assert_ne(
			state.get_node_type(i), &"AnimationPlayer",
			"DrawerHost must not use AnimationPlayer; tween only",
		)


func test_storefront_clicked_opens_drawer() -> void:
	var host: Node = _instance_host()
	await wait_frames(1)
	var panel: PanelContainer = _get_panel(host)
	EventBus.storefront_clicked.emit(&"sports")
	assert_eq(
		panel.get_active_store_id(), &"sports",
		"DrawerHost must react to EventBus.storefront_clicked",
	)
