## Tracks milestone-reward unlocks and provides a gate API for other systems.
class_name UnlockSystem
extends Node


var _granted: Dictionary = {}
var _valid_ids: Dictionary = {}


func _ready() -> void:
	EventBus.content_loaded.connect(_on_content_loaded)
	EventBus.milestone_unlocked.connect(_on_milestone_unlocked)


func _on_content_loaded() -> void:
	initialize()


func initialize() -> void:
	_granted = {}
	_valid_ids = {}
	var unlock_ids: Array[StringName] = ContentRegistry.get_all_ids(
		"unlock"
	)
	for uid: StringName in unlock_ids:
		_valid_ids[uid] = true


func _on_milestone_unlocked(
	_milestone_id: StringName, reward: Dictionary
) -> void:
	var reward_type: String = str(reward.get("reward_type", ""))
	if reward_type != "unlock" and reward_type != "fixture_unlock":
		return
	var unlock_id: StringName = StringName(str(reward.get("unlock_id", "")))
	if unlock_id.is_empty():
		push_error("UnlockSystem: empty unlock_id in milestone reward")
		return
	grant_unlock(unlock_id)


func grant_unlock(unlock_id: StringName) -> void:
	if _granted.has(unlock_id):
		return
	if not _valid_ids.has(unlock_id):
		push_warning(
			"UnlockSystem: unknown unlock_id '%s' — discarding" % unlock_id
		)
		return
	_granted[unlock_id] = true
	EventBus.unlock_granted.emit(unlock_id)
	EventBus.toast_requested.emit(
		"Unlocked: %s" % _get_display_name(unlock_id), &"unlock", 5.0
	)


func _get_display_name(unlock_id: StringName) -> String:
	if not ContentRegistry.exists(String(unlock_id)):
		push_error(
			"UnlockSystem: ContentRegistry cannot resolve display name for '%s'" % unlock_id
		)
		return String(unlock_id)
	return ContentRegistry.get_display_name(unlock_id)


func is_unlocked(unlock_id: StringName) -> bool:
	return _granted.has(unlock_id)


func get_all_granted() -> Array[StringName]:
	var result: Array[StringName] = []
	for key: StringName in _granted:
		result.append(key)
	return result


func get_save_data() -> Dictionary:
	var granted_ids: Array = []
	for key: StringName in _granted:
		granted_ids.append(String(key))
	return {"granted": granted_ids}


func load_state(data: Dictionary) -> void:
	_granted = {}
	var granted_array: Variant = data.get("granted", [])
	if not granted_array is Array:
		return
	for raw_id: Variant in granted_array:
		var id: StringName = StringName(str(raw_id))
		if not _valid_ids.has(id) and not ContentRegistry.exists(str(id)):
			push_warning(
				"UnlockSystem: unknown unlock_id '%s' in save data — "
				% id + "discarding"
			)
			continue
		_granted[id] = true
