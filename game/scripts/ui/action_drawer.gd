## Unified in-store action panel. Renders action buttons dynamically based on
## the descriptors each store controller publishes via
## EventBus.actions_registered. Press routes through
## EventBus.action_requested(action_id, store_id) — this drawer holds no
## store-specific logic.
class_name ActionDrawer
extends PanelContainer


const ACTION_ID_KEY: String = "id"
const ACTION_LABEL_KEY: String = "label"
const ACTION_ICON_KEY: String = "icon"

var _current_store_id: StringName = &""
var _action_ids: Array[StringName] = []

@onready var _button_container: BoxContainer = $Margin/Buttons


func _ready() -> void:
	EventBus.actions_registered.connect(_on_actions_registered)
	EventBus.store_exited.connect(_on_store_exited)


## Returns the action ids currently rendered (used by tests).
func get_action_ids() -> Array[StringName]:
	return _action_ids.duplicate()


## Returns the store id whose actions are currently shown.
func get_current_store_id() -> StringName:
	return _current_store_id


func _on_actions_registered(store_id: StringName, actions: Array) -> void:
	_current_store_id = store_id
	_rebuild(actions)


func _on_store_exited(_store_id: StringName) -> void:
	_current_store_id = &""
	_rebuild([])


func _rebuild(actions: Array) -> void:
	_action_ids.clear()
	if _button_container == null:
		return
	for child: Node in _button_container.get_children():
		child.queue_free()
	for entry: Variant in actions:
		if typeof(entry) != TYPE_DICTIONARY:
			push_warning("ActionDrawer: non-dict action descriptor skipped")
			continue
		var descriptor: Dictionary = entry
		if not descriptor.has(ACTION_ID_KEY):
			push_warning("ActionDrawer: action descriptor missing 'id'")
			continue
		var action_id: StringName = StringName(descriptor[ACTION_ID_KEY])
		var label: String = String(
			descriptor.get(ACTION_LABEL_KEY, String(action_id))
		)
		var icon_path: String = String(descriptor.get(ACTION_ICON_KEY, ""))
		var button := Button.new()
		button.text = label
		button.name = "Action_%s" % String(action_id)
		if icon_path != "" and ResourceLoader.exists(icon_path):
			var tex: Resource = load(icon_path)
			if tex is Texture2D:
				button.icon = tex
		button.pressed.connect(_on_action_pressed.bind(action_id))
		_button_container.add_child(button)
		_action_ids.append(action_id)


func _on_action_pressed(action_id: StringName) -> void:
	EventBus.action_requested.emit(action_id, _current_store_id)
