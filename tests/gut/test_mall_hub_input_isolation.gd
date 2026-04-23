## ISSUE-002: a click in an active store scene must never route to another
## store. The mall hub shares the viewport with the active store scene, so on
## store_entered the hub Controls and card Area2D pickers must stop accepting
## input. Verifies acceptance criteria #3 (mouse_filter=IGNORE + process_mode=
## DISABLED) and #4 (corner-click simulation emits no store-nav signals).
##
## Builds a minimal mall_hub structure programmatically to avoid booting the
## heavy GameWorld child from mall_hub.tscn.
extends GutTest

const MallHubScript: GDScript = preload("res://game/scenes/mall/mall_hub.gd")
const CardScene: PackedScene = preload(
	"res://game/scenes/mall/storefront_card.tscn"
)

var _hub: Node
var _requested_ids: Array[StringName] = []
var _clicked_ids: Array[StringName] = []


func before_each() -> void:
	_requested_ids.clear()
	_clicked_ids.clear()
	EventBus.enter_store_requested.connect(_on_enter_store_requested)
	EventBus.storefront_clicked.connect(_on_storefront_clicked)
	_hub = _build_hub()
	add_child_autofree(_hub)
	await wait_frames(1)


func after_each() -> void:
	if EventBus.enter_store_requested.is_connected(_on_enter_store_requested):
		EventBus.enter_store_requested.disconnect(_on_enter_store_requested)
	if EventBus.storefront_clicked.is_connected(_on_storefront_clicked):
		EventBus.storefront_clicked.disconnect(_on_storefront_clicked)


## Programmatically assembles the subset of mall_hub.tscn that mall_hub.gd's
## _ready requires. Deliberately skips the GameWorld child so test runs stay
## fast and isolated from runtime-systems boot.
func _build_hub() -> Node:
	var hub: Node = Node.new()
	hub.set_script(MallHubScript)

	var hub_layer: CanvasLayer = CanvasLayer.new()
	hub_layer.name = "HubLayer"
	hub.add_child(hub_layer)

	var concourse: Node2D = Node2D.new()
	concourse.name = "ConcourseRoot"
	hub_layer.add_child(concourse)

	var row: Node2D = Node2D.new()
	row.name = "StorefrontRow"
	concourse.add_child(row)

	var card: StorefrontCard = CardScene.instantiate() as StorefrontCard
	card.store_id = &"retro_games"
	row.add_child(card)

	var ambient: Node2D = Node2D.new()
	ambient.name = "AmbientCustomers"
	concourse.add_child(ambient)

	var overlay: Control = Control.new()
	overlay.name = "HubUIOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hub_layer.add_child(overlay)

	var sneaker_tile: Button = Button.new()
	sneaker_tile.name = "SneakerCitadelTile"
	sneaker_tile.unique_name_in_owner = true
	overlay.add_child(sneaker_tile)
	# %SneakerCitadelTile lookup requires owner to be the scene root.
	sneaker_tile.owner = hub
	overlay.owner = hub
	hub_layer.owner = hub

	var ambience: AudioStreamPlayer = AudioStreamPlayer.new()
	ambience.name = "HubAmbiencePlayer"
	hub.add_child(ambience)
	return hub


## Acceptance #3: hub Controls transition to IGNORE + DISABLED when a store
## becomes active.
func test_store_entered_disables_hub_ui_overlay() -> void:
	var overlay: Control = _hub.get_node("HubLayer/HubUIOverlay") as Control
	assert_eq(overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"baseline: overlay ignores mouse input")

	EventBus.store_entered.emit(&"sports")
	await wait_frames(1)

	assert_false(overlay.visible,
		"HubUIOverlay must be hidden while a store is active")
	assert_eq(overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"HubUIOverlay must keep MOUSE_FILTER_IGNORE while a store is active")
	assert_eq(overlay.process_mode, Node.PROCESS_MODE_DISABLED,
		"HubUIOverlay must be PROCESS_MODE_DISABLED while a store is active")


func test_store_entered_disables_storefront_card_picking() -> void:
	var row: Node2D = _hub.get_node("HubLayer/ConcourseRoot/StorefrontRow") as Node2D
	var card: StorefrontCard = row.get_child(0) as StorefrontCard
	var click_area: Area2D = card.get_node("ClickArea") as Area2D
	assert_true(click_area.input_pickable,
		"baseline: card ClickArea picks input in hub mode")

	EventBus.store_entered.emit(&"sports")
	await wait_frames(1)

	assert_eq(row.process_mode, Node.PROCESS_MODE_DISABLED,
		"StorefrontRow must disable processing during store gameplay")
	assert_false(click_area.input_pickable,
		"card ClickArea must stop picking input during store gameplay")


func test_store_exited_restores_hub_input() -> void:
	var overlay: Control = _hub.get_node("HubLayer/HubUIOverlay") as Control
	var row: Node2D = _hub.get_node("HubLayer/ConcourseRoot/StorefrontRow") as Node2D
	var card: StorefrontCard = row.get_child(0) as StorefrontCard
	var click_area: Area2D = card.get_node("ClickArea") as Area2D

	EventBus.store_entered.emit(&"sports")
	await wait_frames(1)
	EventBus.store_exited.emit(&"sports")
	await wait_frames(1)

	assert_true(overlay.visible, "overlay must be re-shown on store_exited")
	assert_eq(overlay.process_mode, Node.PROCESS_MODE_INHERIT,
		"overlay process_mode must restore to INHERIT on store_exited")
	assert_eq(row.process_mode, Node.PROCESS_MODE_INHERIT,
		"storefront row process_mode must restore on store_exited")
	assert_true(click_area.input_pickable,
		"card ClickArea must resume picking input on store_exited")


## Acceptance #4: dispatch real mouse button events at each screen corner
## while a store is active; no storefront_clicked or enter_store_requested
## signal must fire. Relies on the hub Controls + Area2D pickers being
## disabled on store_entered (the fix under test).
func test_corner_clicks_in_active_store_never_navigate() -> void:
	EventBus.store_entered.emit(&"sports")
	await wait_frames(2)

	var corners: Array[Vector2] = [
		Vector2(2, 2),
		Vector2(2, 1078),
		Vector2(1918, 2),
		Vector2(1918, 1078),
	]
	for pos: Vector2 in corners:
		var down: InputEventMouseButton = InputEventMouseButton.new()
		down.button_index = MOUSE_BUTTON_LEFT
		down.pressed = true
		down.position = pos
		down.global_position = pos
		Input.parse_input_event(down)
		var up: InputEventMouseButton = InputEventMouseButton.new()
		up.button_index = MOUSE_BUTTON_LEFT
		up.pressed = false
		up.position = pos
		up.global_position = pos
		Input.parse_input_event(up)
	Input.flush_buffered_events()
	await wait_frames(2)

	assert_eq(_clicked_ids.size(), 0,
		"no storefront_clicked may fire from screen-corner clicks")
	assert_eq(_requested_ids.size(), 0,
		"no enter_store_requested may fire from screen-corner clicks")


func _on_enter_store_requested(store_id: StringName) -> void:
	_requested_ids.append(store_id)


func _on_storefront_clicked(store_id: StringName) -> void:
	_clicked_ids.append(store_id)
