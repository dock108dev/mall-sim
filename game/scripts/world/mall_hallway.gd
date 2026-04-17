## Manages the mall hallway environment with storefronts and common area.
class_name MallHallway
extends Node3D

const STOREFRONT_COUNT: int = 5
const STOREFRONT_SPACING: float = 8.0
const DEFAULT_RENT: float = 60.0

var SLOT_STORE_IDS: Array[StringName] = []

const _StoreLeaseDialogScene: PackedScene = preload(
	"res://game/scenes/ui/store_lease_dialog.tscn"
)
const _PlayerControllerScene: PackedScene = preload(
	"res://game/scenes/player/player_controller.tscn"
)
const _StorefrontScene: PackedScene = preload(
	"res://game/scenes/world/storefront.tscn"
)

var _storefronts: Array[Storefront] = []
var _camera_controller: PlayerController
var _interaction_ray: Node
var _lease_dialog: StoreLeaseDialog
var _store_container: Node3D
var _economy_system: EconomySystem
var _reputation_system: ReputationSystem
var _inventory_system: InventorySystem
var _progression_system: ProgressionSystem
var _store_state_manager: StoreStateManager
var _pending_starter_inventory: Array[ItemInstance] = []
var _ambient_zones: HallwayAmbientZones = null

@onready var _hallway_geometry: Node3D = $HallwayGeometry
@onready var _storefront_slots: Node3D = $StorefrontSlots
@onready var _player_spawn: Marker3D = $PlayerSpawn
@onready var _navigation_region: NavigationRegion3D = (
	$NavigationRegion3D
)
@onready var _waypoint_graph: Node3D = $WaypointGraph
@onready var _ui_layer: CanvasLayer = $UILayer


func _ready() -> void:
	SLOT_STORE_IDS = ContentRegistry.get_all_ids("store")

	_store_container = Node3D.new()
	_store_container.name = "ActiveStoreContainer"
	add_child(_store_container)

	MallHallwayGeometry.build_all(_hallway_geometry)
	_initialize_storefronts()
	_setup_camera()
	_setup_lease_dialog()
	_apply_owned_stores()
	_spawn_renovation_storefront()
	_setup_navigation()
	_initialize_waypoint_graph()

	EventBus.store_leased.connect(_on_store_leased)
	EventBus.owned_slots_restored.connect(_on_owned_slots_restored)
	EventBus.store_slot_unlocked.connect(_on_store_slot_unlocked)
	EventBus.day_started.connect(_on_day_started_deliver_inventory)


## Injects runtime system references needed for the lease flow.
func set_systems(
	economy: EconomySystem,
	reputation: ReputationSystem,
	inventory: InventorySystem,
	progression: ProgressionSystem = null,
	store_state_manager: StoreStateManager = null
) -> void:
	_economy_system = economy
	_reputation_system = reputation
	_inventory_system = inventory
	_progression_system = progression
	_store_state_manager = store_state_manager
	if _interaction_ray and _interaction_ray.has_method("set_inventory_system"):
		_interaction_ray.call("set_inventory_system", _inventory_system)


## Injects customer and time systems to initialize ambient audio zones.
func set_ambient_systems(
	customer_system: CustomerSystem,
	time_system: TimeSystem
) -> void:
	if _ambient_zones != null:
		_ambient_zones.configure_runtime_dependencies(
			customer_system, time_system
		)
		return
	_ambient_zones = HallwayAmbientZones.new()
	_ambient_zones.name = "AmbientZones"
	_ambient_zones.configure_runtime_dependencies(
		customer_system, time_system
	)
	add_child(_ambient_zones)


## Returns the mall camera controller.
func get_camera_controller() -> PlayerController:
	return _camera_controller


## Returns the storefront at the given slot index, or null.
func get_storefront(slot_index: int) -> Storefront:
	if slot_index < 0 or slot_index >= _storefronts.size():
		return null
	return _storefronts[slot_index]


func _initialize_storefronts() -> void:
	for i: int in range(STOREFRONT_COUNT):
		var slot: Storefront = _storefront_slots.get_node(
			"Slot_%d" % i
		) as Storefront
		if not slot:
			push_error("MallHallway: missing Slot_%d in scene" % i)
			continue
		_storefronts.append(slot)
		if i == 0:
			slot.set_available(_get_rent_for_slot(i))
		else:
			slot.set_locked()
		slot.door_interacted.connect(
			_on_storefront_door_interacted
		)
		_add_storefront_accent_light(slot.position)


func _add_storefront_accent_light(at_pos: Vector3) -> void:
	var accent_light := SpotLight3D.new()
	accent_light.name = "StorefrontAccent_%d" % int(
		round(at_pos.x * 10.0)
	)
	accent_light.position = at_pos + Vector3(0.0, 3.25, 2.8)
	accent_light.rotation_degrees = Vector3(-88.0, 0.0, 0.0)
	accent_light.light_color = Color(1.0, 0.9, 0.75, 1.0)
	# Keep storefront pools readable without overpowering the hallway key/fill rig.
	accent_light.light_energy = 0.14
	accent_light.spot_range = 4.2
	accent_light.spot_angle = 28.0
	accent_light.spot_attenuation = 1.0
	accent_light.shadow_enabled = false
	_hallway_geometry.add_child(accent_light)


func _setup_camera() -> void:
	_camera_controller = (
		_PlayerControllerScene.instantiate() as PlayerController
	)
	_camera_controller.name = "MallCameraController"
	_camera_controller.store_bounds_min = Vector3(-20.0, 0.0, -2.0)
	_camera_controller.store_bounds_max = Vector3(20.0, 0.0, 8.0)
	_camera_controller.move_speed = 8.0
	_camera_controller.set_pivot(_player_spawn.position)
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


func _setup_lease_dialog() -> void:
	_lease_dialog = (
		_StoreLeaseDialogScene.instantiate() as StoreLeaseDialog
	)
	_ui_layer.add_child(_lease_dialog)
	_lease_dialog.hide()


func _setup_navigation() -> void:
	var nav_mesh: NavigationMesh = _navigation_region.navigation_mesh
	if not nav_mesh:
		nav_mesh = NavigationMesh.new()
		nav_mesh.agent_radius = 0.4
		nav_mesh.agent_height = 1.8
		nav_mesh.agent_max_climb = 0.25
		nav_mesh.agent_max_slope = 45.0

	var half_len: float = MallHallwayGeometry.HALLWAY_LENGTH * 0.5
	var inset: float = nav_mesh.agent_radius
	var width: float = MallHallwayGeometry.HALLWAY_WIDTH
	nav_mesh.vertices = PackedVector3Array([
		Vector3(-half_len + inset, 0.0, inset),
		Vector3(half_len - inset, 0.0, inset),
		Vector3(half_len - inset, 0.0, width - inset),
		Vector3(-half_len + inset, 0.0, width - inset),
	])
	nav_mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	_navigation_region.navigation_mesh = nav_mesh


func _initialize_waypoint_graph() -> void:
	if _waypoint_graph.get_child_count() == 0:
		MallWaypointGraphBuilder.build(_waypoint_graph, SLOT_STORE_IDS)
	for i: int in range(SLOT_STORE_IDS.size()):
		var store_id: StringName = SLOT_STORE_IDS[i]
		_assign_waypoint_store_id("StoreEntrance_%d" % i, store_id)
		_assign_waypoint_store_id("Register_%d" % i, store_id)


func _assign_waypoint_store_id(
	node_name: String, store_id: StringName
) -> void:
	var waypoint: MallWaypoint = _waypoint_graph.get_node_or_null(
		node_name
	) as MallWaypoint
	if waypoint == null:
		push_error(
			"MallHallway: missing %s in WaypointGraph" % node_name
		)
		return
	waypoint.associated_store_id = store_id


## Marks storefronts as owned based on GameManager.owned_stores.
func _apply_owned_stores() -> void:
	var owned_slots: Dictionary = {}
	for i: int in range(_storefronts.size()):
		if i >= SLOT_STORE_IDS.size():
			break
		var store_id: StringName = SLOT_STORE_IDS[i]
		if not GameManager.is_store_owned(String(store_id)):
			continue
		owned_slots[i] = store_id
	_apply_owned_slot_visuals(owned_slots)


## Applies unlock state from the progression system to storefronts.
func apply_unlock_state(progression: ProgressionSystem) -> void:
	for i: int in range(1, _storefronts.size()):
		if _storefronts[i].is_owned:
			continue
		if progression.is_slot_unlocked(i):
			_storefronts[i].set_available(_get_rent_for_slot(i))
		else:
			_storefronts[i].set_locked()


## Restores storefront visuals from the saved slot -> store_id mapping.
func _on_owned_slots_restored(slots: Dictionary) -> void:
	_apply_owned_slot_visuals(slots)


func _apply_owned_slot_visuals(slots: Dictionary) -> void:
	for i: int in range(_storefronts.size()):
		if slots.has(i):
			var store_id: StringName = slots[i]
			var store_name: String = ContentRegistry.get_display_name(
				store_id
			)
			if _store_state_manager:
				store_name = _store_state_manager.get_store_name(store_id)
			_storefronts[i].set_owned(String(store_id), store_name)
		elif _progression_system and _progression_system.is_slot_unlocked(i):
			_storefronts[i].set_available(_get_rent_for_slot(i))
		elif i > 0:
			_storefronts[i].set_locked()
		else:
			_storefronts[i].set_available(_get_rent_for_slot(i))


## Creates a permanently "under renovation" storefront at the end.
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
	var canonical: StringName = ContentRegistry.resolve(store_type)
	if not canonical.is_empty():
		return ContentRegistry.get_display_name(canonical)
	return store_type


func _get_rent_for_slot(slot_index: int) -> float:
	if slot_index < 0 or slot_index >= SLOT_STORE_IDS.size():
		return DEFAULT_RENT
	var entry: Dictionary = ContentRegistry.get_entry(
		SLOT_STORE_IDS[slot_index]
	)
	if entry.has("daily_rent"):
		return float(entry["daily_rent"])
	return DEFAULT_RENT


func _on_store_slot_unlocked(slot_index: int) -> void:
	var storefront: Storefront = get_storefront(slot_index)
	if not storefront:
		return
	if storefront.is_owned:
		return
	storefront.set_available(_get_rent_for_slot(slot_index))
	EventBus.notification_requested.emit(
		"A new storefront is available for lease!"
	)


func _on_storefront_door_interacted(
	storefront: Storefront
) -> void:
	if storefront.is_owned:
		EventBus.enter_store_requested.emit(
			StringName(storefront.store_id)
		)
	elif storefront.is_locked:
		return
	else:
		_show_lease_dialog(storefront)


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


## Backward-compatible bridge for tests and older callers.
func _on_lease_requested(
	store_id: StringName,
	slot_index: int,
	store_name: String
) -> void:
	if (
		_progression_system != null
		and slot_index > 0
		and not _progression_system.is_slot_unlocked(slot_index)
	):
		EventBus.lease_completed.emit(
			store_id, false, "This storefront is not yet available."
		)
		return
	if _store_state_manager == null:
		push_error("MallHallway: missing StoreStateManager for lease flow")
		EventBus.lease_completed.emit(
			store_id, false, "Lease system unavailable."
		)
		return
	EventBus.lease_requested.emit(store_id, slot_index, store_name)


## Returns the hallway geometry node for show/hide during transitions.
func get_hallway_geometry() -> Node3D:
	return _hallway_geometry


## Returns the container node where store scenes are instantiated.
func get_store_container() -> Node3D:
	return _store_container


func _on_store_leased(slot_index: int, store_type: String) -> void:
	var storefront: Storefront = get_storefront(slot_index)
	if not storefront:
		return
	var canonical: StringName = ContentRegistry.resolve(store_type)
	if canonical.is_empty():
		canonical = StringName(store_type)
	var display_name: String = ContentRegistry.get_display_name(canonical)
	if _store_state_manager:
		display_name = _store_state_manager.get_store_name(canonical)
	storefront.set_owned(String(canonical), display_name)
	_queue_starter_inventory(String(canonical))


## Generates starter inventory and queues it for next day_started.
func _queue_starter_inventory(store_type: String) -> void:
	var canonical: StringName = ContentRegistry.resolve(store_type)
	if canonical.is_empty():
		push_warning(
			"MallHallway: cannot create inventory for unknown store '%s'"
			% store_type
		)
		return
	var items: Array[ItemInstance] = _generate_starter_inventory(canonical)
	_pending_starter_inventory.append_array(items)


func _generate_starter_inventory(
	store_type: StringName
) -> Array[ItemInstance]:
	if not GameManager.data_loader:
		push_warning(
			"MallHallway: cannot create inventory, "
			+ "missing data loader"
		)
		return []
	return (
		GameManager.data_loader.generate_starter_inventory(
			String(store_type)
		)
	)


## Delivers any pending starter inventory on the next morning.
func _on_day_started_deliver_inventory(_day: int) -> void:
	if _pending_starter_inventory.is_empty():
		return
	if not _inventory_system:
		push_warning(
			"MallHallway: cannot deliver inventory, "
			+ "missing inventory system"
		)
		return
	for item: ItemInstance in _pending_starter_inventory:
		_inventory_system.register_item(item)
	_pending_starter_inventory.clear()
