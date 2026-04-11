## Manages the mall hallway environment with storefronts and common area.
class_name MallHallway
extends Node3D

const STOREFRONT_COUNT: int = 5
const STOREFRONT_SPACING: float = 7.0
const DEFAULT_RENT: float = 60.0
const FADE_DURATION: float = 0.3

const STORE_SCENES: Dictionary = {
	"sports_memorabilia":
		"res://game/scenes/stores/sports_memorabilia.tscn",
	"retro_games":
		"res://game/scenes/stores/retro_games.tscn",
	"video_rental":
		"res://game/scenes/stores/video_rental.tscn",
	"pocket_creatures":
		"res://game/scenes/stores/pocket_creatures.tscn",
	"consumer_electronics":
		"res://game/scenes/stores/consumer_electronics.tscn",
}

const SLOT_STORE_TYPES: Array[String] = [
	"sports_memorabilia", "retro_games", "video_rental",
	"pocket_creatures", "consumer_electronics",
]

const _StorefrontScene: PackedScene = preload(
	"res://game/scenes/world/storefront.tscn"
)
const _StoreLeaseDialogScene: PackedScene = preload(
	"res://game/scenes/ui/store_lease_dialog.tscn"
)
const _PlayerControllerScene: PackedScene = preload(
	"res://game/scenes/player/player_controller.tscn"
)

var _storefronts: Array[Storefront] = []
var _camera_controller: PlayerController
var _interaction_ray: Node
var _lease_dialog: StoreLeaseDialog
var _hallway_geometry: Node3D
var _store_container: Node3D
var _active_store_scene: Node3D
var _store_camera: PlayerController
var _inside_store: bool = false
var _fade_rect: ColorRect
var _is_transitioning: bool = false
var _economy_system: EconomySystem
var _reputation_system: ReputationSystem
var _inventory_system: InventorySystem

## Preloaded store scenes for fast transitions.
var _preloaded_scenes: Dictionary = {}

@onready var _ui_layer: CanvasLayer = $UILayer


func _ready() -> void:
	_hallway_geometry = Node3D.new()
	_hallway_geometry.name = "HallwayGeometry"
	add_child(_hallway_geometry)

	_store_container = Node3D.new()
	_store_container.name = "ActiveStoreContainer"
	add_child(_store_container)

	MallHallwayGeometry.build_all(_hallway_geometry)
	_preload_store_scenes()
	_spawn_storefronts()
	_setup_camera()
	_setup_lease_dialog()
	_setup_fade_rect()
	_apply_owned_stores()

	_spawn_renovation_storefront()

	EventBus.store_leased.connect(_on_store_leased)
	EventBus.storefront_exited.connect(_on_storefront_exited)


## Injects runtime system references needed for the lease flow.
func set_systems(
	economy: EconomySystem,
	reputation: ReputationSystem,
	inventory: InventorySystem
) -> void:
	_economy_system = economy
	_reputation_system = reputation
	_inventory_system = inventory
	if _interaction_ray and _interaction_ray.has_method("set_inventory_system"):
		_interaction_ray.call("set_inventory_system", _inventory_system)


## Returns the mall camera controller.
func get_camera_controller() -> PlayerController:
	return _camera_controller


## Returns the storefront at the given slot index, or null.
func get_storefront(slot_index: int) -> Storefront:
	if slot_index < 0 or slot_index >= _storefronts.size():
		return null
	return _storefronts[slot_index]


func _spawn_storefronts() -> void:
	var start_x: float = (
		-float(STOREFRONT_COUNT - 1) * 0.5 * STOREFRONT_SPACING
	)
	for i: int in range(STOREFRONT_COUNT):
		var storefront: Storefront = _StorefrontScene.instantiate()
		storefront.name = "Storefront_%d" % i
		storefront.slot_index = i
		storefront.position = Vector3(
			start_x + float(i) * STOREFRONT_SPACING,
			0.0,
			0.1
		)
		_hallway_geometry.add_child(storefront)
		storefront.set_available(_get_rent_for_slot(i))
		storefront.door_interacted.connect(
			_on_storefront_door_interacted
		)
		_storefronts.append(storefront)


func _setup_camera() -> void:
	_camera_controller = (
		_PlayerControllerScene.instantiate() as PlayerController
	)
	_camera_controller.name = "MallCameraController"
	_camera_controller.store_bounds_min = Vector3(-18.0, 0.0, -2.0)
	_camera_controller.store_bounds_max = Vector3(18.0, 0.0, 8.0)
	_camera_controller.move_speed = 8.0
	_camera_controller.set_pivot(Vector3(0.0, 0.0, 0.0))
	_camera_controller.set_camera_angles(0.0, 24.0)
	_camera_controller.set_zoom_distance(8.0)
	add_child(_camera_controller)

	var InteractionRayScript: GDScript = preload(
		"res://game/scripts/player/interaction_ray.gd"
	)
	_interaction_ray = Node.new()
	_interaction_ray.name = "InteractionRay"
	_interaction_ray.set_script(InteractionRayScript)
	add_child(_interaction_ray)
	_interaction_ray.call(
		"initialize",
		_camera_controller.get_camera()
	)


func _setup_lease_dialog() -> void:
	_lease_dialog = (
		_StoreLeaseDialogScene.instantiate() as StoreLeaseDialog
	)
	_ui_layer.add_child(_lease_dialog)
	_lease_dialog.hide()


func _setup_fade_rect() -> void:
	_fade_rect = ColorRect.new()
	_fade_rect.name = "FadeRect"
	_fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade_rect.anchors_preset = Control.PRESET_FULL_RECT
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_layer.add_child(_fade_rect)


## Marks storefronts as owned based on GameManager.owned_stores.
func _apply_owned_stores() -> void:
	for i: int in range(_storefronts.size()):
		if i >= SLOT_STORE_TYPES.size():
			break
		var store_type: String = SLOT_STORE_TYPES[i]
		if not GameManager.is_store_owned(store_type):
			continue
		var store_name: String = _get_store_display_name(store_type)
		_storefronts[i].set_owned(store_type, store_name)


## Creates a permanently "under renovation" storefront at the end of the hall.
func _spawn_renovation_storefront() -> void:
	var start_x: float = (
		-float(STOREFRONT_COUNT - 1) * 0.5 * STOREFRONT_SPACING
	)
	var reno_x: float = (
		start_x + float(STOREFRONT_COUNT) * STOREFRONT_SPACING
	)
	var reno: Storefront = _StorefrontScene.instantiate()
	reno.name = "Storefront_Renovation"
	reno.slot_index = -1
	reno.position = Vector3(reno_x, 0.0, 0.1)
	_hallway_geometry.add_child(reno)
	reno.set_renovation()


func _get_store_display_name(store_type: String) -> String:
	if GameManager.data_loader:
		var store_def: StoreDefinition = (
			GameManager.data_loader.get_store(store_type)
		)
		if store_def:
			return store_def.name
	return store_type


func _get_rent_for_slot(slot_index: int) -> float:
	if not GameManager.data_loader:
		return DEFAULT_RENT
	if slot_index < 0 or slot_index >= SLOT_STORE_TYPES.size():
		return DEFAULT_RENT
	var store_def: StoreDefinition = GameManager.data_loader.get_store(
		SLOT_STORE_TYPES[slot_index]
	)
	if store_def:
		return store_def.daily_rent
	return DEFAULT_RENT


func _unhandled_input(event: InputEvent) -> void:
	if not _inside_store:
		return
	if event.is_action_pressed("ui_cancel"):
		EventBus.storefront_exited.emit()
		get_viewport().set_input_as_handled()


func _on_storefront_door_interacted(
	storefront: Storefront
) -> void:
	if storefront.is_owned:
		_enter_store(storefront)
	else:
		_show_lease_dialog(storefront)


func _enter_store(storefront: Storefront) -> void:
	if _is_transitioning:
		return
	var store_scene: PackedScene = _get_store_scene(
		storefront.store_id
	)
	if not store_scene:
		push_warning(
			"MallHallway: no scene for store '%s'"
			% storefront.store_id
		)
		return

	_is_transitioning = true
	var old_store: String = GameManager.current_store_id
	await _fade_in()

	_active_store_scene = store_scene.instantiate()
	_store_container.add_child(_active_store_scene)

	_hallway_geometry.visible = false
	_camera_controller.set_process(false)
	_camera_controller.set_process_unhandled_input(false)

	_store_camera = (
		_PlayerControllerScene.instantiate() as PlayerController
	)
	_store_camera.name = "StoreCamera"
	_store_container.add_child(_store_camera)
	if _interaction_ray and _interaction_ray.has_method("set_camera"):
		_interaction_ray.call(
			"set_camera",
			_store_camera.get_camera()
		)

	_inside_store = true
	EventBus.storefront_entered.emit(
		storefront.slot_index, storefront.store_id
	)
	if not old_store.is_empty():
		EventBus.store_switched.emit(
			old_store, storefront.store_id
		)

	await _fade_out()
	_is_transitioning = false


func _show_lease_dialog(storefront: Storefront) -> void:
	var store_defs: Array[StoreDefinition] = []
	if GameManager.data_loader:
		store_defs = GameManager.data_loader.get_all_stores()

	var cash: float = 0.0
	if _economy_system:
		cash = _economy_system.get_cash()

	var reputation: float = 0.0
	if _reputation_system:
		reputation = _reputation_system.get_reputation()

	_lease_dialog.show_for_slot(
		storefront.slot_index,
		store_defs,
		GameManager.owned_stores,
		cash,
		reputation
	)


## Preloads all store scenes at startup for instant transitions.
func _preload_store_scenes() -> void:
	for store_id: String in STORE_SCENES:
		var path: String = STORE_SCENES[store_id]
		var scene: PackedScene = load(path) as PackedScene
		if scene:
			_preloaded_scenes[store_id] = scene
		else:
			push_warning(
				"MallHallway: failed to preload '%s'" % path
			)


## Returns a preloaded store scene, falling back to runtime load.
func _get_store_scene(store_id: String) -> PackedScene:
	if _preloaded_scenes.has(store_id):
		return _preloaded_scenes[store_id]
	var path: String = STORE_SCENES.get(store_id, "")
	if path.is_empty():
		return null
	return load(path) as PackedScene


func _on_store_leased(
	slot_index: int, store_type: String
) -> void:
	var storefront: Storefront = get_storefront(slot_index)
	if not storefront:
		push_warning(
			"MallHallway: invalid slot index %d for lease"
			% slot_index
		)
		return

	var lease_cost: float = _get_lease_cost_for_next_store()
	if _economy_system and lease_cost > 0.0:
		var success: bool = _economy_system.deduct_cash(
			lease_cost, "Store lease: %s" % store_type
		)
		if not success:
			push_warning(
				"MallHallway: insufficient funds for lease"
			)
			return

	GameManager.own_store(store_type)
	_create_starting_inventory(store_type)

	var store_name: String = _get_store_display_name(store_type)
	storefront.set_owned(store_type, store_name)
	EventBus.store_unlocked.emit(store_type, lease_cost)


func _get_lease_cost_for_next_store() -> float:
	var index: int = GameManager.owned_stores.size()
	if index <= 0:
		return 0.0
	if index >= StoreLeaseDialog.UNLOCK_REQUIREMENTS.size():
		return 0.0
	var req: Dictionary = (
		StoreLeaseDialog.UNLOCK_REQUIREMENTS[index]
	)
	return float(req.get("cost", 0))


func _create_starting_inventory(store_type: String) -> void:
	if not GameManager.data_loader or not _inventory_system:
		push_warning(
			"MallHallway: cannot create inventory, "
			+ "missing loader or inventory system"
		)
		return
	var items: Array[ItemInstance] = (
		GameManager.data_loader.create_starting_inventory(
			store_type
		)
	)
	for item: ItemInstance in items:
		_inventory_system.register_item(item)


func _on_storefront_exited() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	_exit_store_with_fade()


func _exit_store_with_fade() -> void:
	await _fade_in()

	if _store_camera:
		_store_container.remove_child(_store_camera)
		_store_camera.queue_free()
		_store_camera = null

	if _active_store_scene:
		_store_container.remove_child(_active_store_scene)
		_active_store_scene.queue_free()
		_active_store_scene = null

	_hallway_geometry.visible = true
	_camera_controller.set_process(true)
	_camera_controller.set_process_unhandled_input(true)
	if _interaction_ray and _interaction_ray.has_method("set_camera"):
		_interaction_ray.call(
			"set_camera",
			_camera_controller.get_camera()
		)
	_inside_store = false

	await _fade_out()
	_is_transitioning = false


## Tweens fade rect to opaque black over FADE_DURATION.
func _fade_in() -> void:
	if not _fade_rect:
		return
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween: Tween = create_tween()
	tween.tween_property(
		_fade_rect, "color:a", 1.0, FADE_DURATION
	)
	await tween.finished


## Tweens fade rect to transparent over FADE_DURATION.
func _fade_out() -> void:
	if not _fade_rect:
		return
	var tween: Tween = create_tween()
	tween.tween_property(
		_fade_rect, "color:a", 0.0, FADE_DURATION
	)
	await tween.finished
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
