## Interactable that teleports the orbit camera pivot to this zone when clicked.
##
## Left-clicking or pressing the mapped keyboard shortcut (nav_zone_N) snaps
## the PlayerController pivot to this zone's world position. The collision
## shape remains active in all builds; any MeshInstance3D children are hidden
## in release builds (OS.is_debug_build() == false).
##
## When linked_label is set (via export NodePath or register_label()), the
## Label3D is shown only when the zone is hovered, selected, or within
## proximity_radius of the camera pivot — unless the session-wide debug
## override (F3 / zone_labels_debug) is active.
## NodePath resolution is lazy (first _process frame) so sibling nodes are
## guaranteed to be in the tree. Use register_label() to set the reference
## directly when constructing zones without a scene file.
class_name NavZoneInteractable
extends Interactable

## Session-wide debug toggle: all instances share this flag so it survives
## store scene changes within a single play session.
static var _debug_always_on_session: bool = false

## Keyboard shortcut index (1–5). PlayerController maps nav_zone_N actions to
## nodes in the "nav_zone" group by matching this value.
@export var zone_index: int = 0
## NodePath to a Label3D that tracks this zone's hover/selected/proximity state.
## Leave empty to disable label management for this zone.
@export var linked_label: NodePath = NodePath("")
## Distance (world units) from the camera pivot within which the label is shown.
@export var proximity_radius: float = 2.5

var _label_node: Label3D = null
var _is_hovered: bool = false
var _is_selected: bool = false
var _is_in_proximity: bool = false
var _cached_player: PlayerController = null


func _ready() -> void:
	super._ready()
	_apply_debug_visibility()
	focused.connect(_on_focused)
	unfocused.connect(_on_unfocused)
	var eb: Node = _get_event_bus()
	if eb != null:
		if eb.has_signal("nav_zone_selected"):
			eb.nav_zone_selected.connect(_on_nav_zone_selected)
		if eb.has_signal("zone_labels_debug_toggled"):
			eb.zone_labels_debug_toggled.connect(_on_debug_always_on_toggled)
	# Enable processing when there is a label path to manage.
	# Actual NodePath resolution is deferred to _process() so sibling nodes
	# are guaranteed present in the tree.
	set_process(not linked_label.is_empty())


func _process(_delta: float) -> void:
	# Lazy label resolution: resolve NodePath on first process frame.
	if _label_node == null and not linked_label.is_empty():
		_resolve_linked_label()
		if is_instance_valid(_label_node):
			_label_node.visible = (
				NavZoneInteractable._debug_always_on_session
				or _is_hovered
				or _is_selected
			)

	var old_proximity: bool = _is_in_proximity
	_check_proximity()
	if old_proximity != _is_in_proximity:
		_refresh_label_visibility()


## Calls the base interact chain and emits nav_zone_selected so the
## PlayerController pivot teleports here regardless of how interact() was
## triggered (raycast click or keyboard shortcut).
func interact(by: Node = null) -> void:
	super.interact(by)
	EventBus.nav_zone_selected.emit(global_position)


## Directly register a Label3D without NodePath resolution. Hides the label
## immediately according to current state. Use when constructing zones
## programmatically rather than from a scene file.
func register_label(label: Label3D) -> void:
	_label_node = label
	_refresh_label_visibility()
	set_process(is_instance_valid(_label_node))


func _apply_debug_visibility() -> void:
	var show_debug: bool = OS.is_debug_build()
	for child: Node in get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).visible = show_debug


func _resolve_linked_label() -> void:
	if linked_label.is_empty():
		return
	var node: Node = get_node_or_null(linked_label)
	if node is Label3D:
		_label_node = node as Label3D
	elif node != null:
		# §F-28: linked_label path resolves to a non-Label3D node — likely a
		# scene-authoring error; label management is disabled for this zone.
		push_warning(
			"NavZoneInteractable '%s': linked_label '%s' resolves to %s, not Label3D"
			% [name, linked_label, node.get_class()]
		)


func _on_focused() -> void:
	_is_hovered = true
	_refresh_label_visibility()


func _on_unfocused() -> void:
	_is_hovered = false
	_refresh_label_visibility()


func _on_nav_zone_selected(zone_position: Vector3) -> void:
	_is_selected = global_position.is_equal_approx(zone_position)
	_refresh_label_visibility()


func _on_debug_always_on_toggled(always_on: bool) -> void:
	NavZoneInteractable._debug_always_on_session = always_on
	_refresh_label_visibility()


func _check_proximity() -> void:
	if not is_instance_valid(_cached_player):
		_cached_player = _find_player_controller()
	if not is_instance_valid(_cached_player):
		_is_in_proximity = false
		return
	var pivot: Vector3 = _cached_player.get_pivot()
	_is_in_proximity = global_position.distance_to(pivot) <= proximity_radius


func _refresh_label_visibility() -> void:
	if not is_instance_valid(_label_node):
		return
	_label_node.visible = (
		NavZoneInteractable._debug_always_on_session
		or _is_hovered
		or _is_selected
		or _is_in_proximity
	)


func _find_player_controller() -> PlayerController:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var nodes: Array[Node] = tree.get_nodes_in_group(&"player_controller")
	if nodes.is_empty():
		return null
	var node: Node = nodes[0]
	if node is PlayerController:
		return node as PlayerController
	return null


func _get_event_bus() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("EventBus")
