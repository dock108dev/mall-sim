## Interactable that teleports the orbit camera pivot to this zone when clicked.
##
## Left-clicking or pressing the mapped keyboard shortcut (nav_zone_N) snaps
## the PlayerController pivot to this zone's world position. The collision
## shape remains active in all builds; any MeshInstance3D children (the
## DebugMesh placeholder) are hidden in release builds via
## `_apply_debug_visibility()`.
class_name NavZoneInteractable
extends Interactable

## Keyboard shortcut index (1–5). PlayerController maps nav_zone_N actions to
## nodes in the "nav_zone" group by matching this value.
@export var zone_index: int = 0


func _ready() -> void:
	super._ready()
	_apply_debug_visibility()


## Calls the base interact chain and emits nav_zone_selected so the
## PlayerController pivot teleports here regardless of how interact() was
## triggered (raycast click or keyboard shortcut).
func interact(by: Node = null) -> void:
	super.interact(by)
	EventBus.nav_zone_selected.emit(global_position)


func _apply_debug_visibility() -> void:
	var show_debug: bool = OS.is_debug_build()
	for child: Node in get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).visible = show_debug
