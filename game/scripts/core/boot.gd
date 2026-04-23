## Boot scene controller that runs synchronous startup checks before opening main menu.
extends Node

@onready var _title_label: Label = $TitleLabel
@onready var _error_panel: PanelContainer = $ErrorPanel
@onready var _error_label: RichTextLabel = $ErrorPanel/MarginContainer/ErrorLabel


func _ready() -> void:
	_error_panel.visible = false
	if GameManager.is_boot_completed():
		push_error("Boot: boot scene entered after boot already completed")
		_transition_to_main_menu()
		return
	call_deferred("initialize")


func initialize() -> void:
	DataLoaderSingleton.load_all()

	var load_errors: Array[String] = DataLoaderSingleton.get_load_errors()
	if not load_errors.is_empty():
		var msg: String = "Content loading failed:\n"
		for err: String in load_errors:
			msg += "  - %s\n" % err
		_show_error(msg)
		return

	var arc_errors: Array[String] = _validate_arc_unlocks()
	if not arc_errors.is_empty():
		var msg: String = "arc_unlocks.json schema errors:\n"
		for err: String in arc_errors:
			msg += "  - %s\n" % err
		_show_error(msg)
		return

	var obj_errors: Array[String] = _validate_objectives()
	if not obj_errors.is_empty():
		var msg: String = "objectives.json schema errors:\n"
		for err: String in obj_errors:
			msg += "  - %s\n" % err
		_show_error(msg)
		return

	if not ContentRegistry.is_ready():
		push_error(
			"Boot: ContentRegistry.is_ready() returned false after DataLoader load"
		)
		_show_error("ContentRegistry failed to initialize — no content loaded.")
		return

	var store_ids: Array[StringName] = ContentRegistry.get_all_store_ids()
	if store_ids.size() < 5:
		push_error("Boot: only %d store IDs registered" % store_ids.size())
		_show_error(
			"Expected at least 5 store IDs, found %d." % store_ids.size()
		)
		return

	Settings.load()
	AudioManager.initialize()
	GameManager.mark_boot_completed()
	EventBus.boot_completed.emit()
	if AuditLog != null:
		AuditLog.pass_check(&"boot_scene_ready", "from=boot.gd")
	_transition_to_main_menu()


func _validate_arc_unlocks() -> Array[String]:
	var errors: Array[String] = []
	var path := "res://game/content/progression/arc_unlocks.json"
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		errors.append("arc_unlocks.json not found at %s" % path)
		return errors
	var text: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		errors.append(
			"arc_unlocks.json parse error: %s" % json.get_error_message()
		)
		return errors
	var data: Variant = json.get_data()
	if not (data is Dictionary):
		errors.append("arc_unlocks.json root must be a Dictionary")
		return errors
	var d: Dictionary = data as Dictionary
	for key: String in ["arc_phases", "arc_unlocks"]:
		if not d.has(key):
			errors.append("arc_unlocks.json: missing required key '%s'" % key)
		elif not (d[key] is Array):
			errors.append("arc_unlocks.json: '%s' must be an Array" % key)
	if not d.has("win_condition"):
		errors.append("arc_unlocks.json: missing required key 'win_condition'")
	elif not (d["win_condition"] is Dictionary):
		errors.append("arc_unlocks.json: 'win_condition' must be a Dictionary")
	else:
		var wc: Dictionary = d["win_condition"] as Dictionary
		for wkey: String in ["target_day", "min_cash"]:
			if not wc.has(wkey):
				errors.append(
					"arc_unlocks.json: win_condition missing '%s'" % wkey
				)
	return errors


func _validate_objectives() -> Array[String]:
	var errors: Array[String] = []
	var path := "res://game/content/objectives.json"
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		errors.append("objectives.json not found at %s" % path)
		return errors
	var text: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		errors.append(
			"objectives.json parse error: %s" % json.get_error_message()
		)
		return errors
	var data: Variant = json.get_data()
	if not (data is Dictionary):
		errors.append("objectives.json root must be a Dictionary")
		return errors
	var d: Dictionary = data as Dictionary
	if not d.has("objectives"):
		errors.append("objectives.json: missing required key 'objectives'")
	elif not (d["objectives"] is Array):
		errors.append("objectives.json: 'objectives' must be an Array")
	else:
		var arr: Array = d["objectives"] as Array
		for i: int in arr.size():
			var entry: Variant = arr[i]
			if not (entry is Dictionary):
				errors.append("objectives.json: entry %d must be a Dictionary" % i)
				continue
			var e: Dictionary = entry as Dictionary
			if not e.has("day"):
				errors.append("objectives.json: entry %d missing 'day'" % i)
			if not e.has("text"):
				errors.append("objectives.json: entry %d missing 'text'" % i)
			if not e.has("action"):
				errors.append("objectives.json: entry %d missing 'action'" % i)
			if not e.has("key"):
				errors.append("objectives.json: entry %d missing 'key'" % i)
	if not d.has("default_text"):
		errors.append("objectives.json: missing required key 'default_text'")
	elif not (d["default_text"] is String):
		errors.append("objectives.json: 'default_text' must be a String")
	if not d.has("default_action"):
		errors.append("objectives.json: missing required key 'default_action'")
	elif not (d["default_action"] is String):
		errors.append("objectives.json: 'default_action' must be a String")
	return errors


func _show_error(message: String) -> void:
	_title_label.visible = false
	_error_panel.visible = true
	_error_label.text = "[b]Boot Error[/b]\n\n%s\n\nCheck the console for details." % message


func _transition_to_main_menu() -> void:
	GameManager.transition_to(GameManager.GameState.MAIN_MENU)
