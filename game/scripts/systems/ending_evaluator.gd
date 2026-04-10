## Evaluates ending variant based on milestone completion and secret thread state.
class_name EndingEvaluator
extends Node


const CONFIG_PATH := "res://game/content/endings/ending_config.json"

const ENDING_NORMAL := "normal"
const ENDING_QUESTIONED := "questioned"
const ENDING_TAKEDOWN := "takedown"

var _config: Dictionary = {}
var _thresholds: Dictionary = {}
var _endings: Dictionary = {}
var _progression_system: ProgressionSystem
var _secret_thread_manager: SecretThreadManager
var _ending_shown: bool = false
var _recorded_ending: String = ""


func initialize(
	progression: ProgressionSystem,
	secret_thread: SecretThreadManager,
) -> void:
	_progression_system = progression
	_secret_thread_manager = secret_thread
	_load_config()
	EventBus.milestone_completed.connect(_on_milestone_completed)


## Returns the ending type based on current secret thread scores.
func evaluate_ending() -> String:
	if not _secret_thread_manager:
		return ENDING_NORMAL

	var awareness: int = _secret_thread_manager.get_awareness_score()
	var participation: int = (
		_secret_thread_manager.get_participation_score()
	)

	var takedown_cfg: Dictionary = _thresholds.get(
		ENDING_TAKEDOWN, {}
	)
	var takedown_awareness: int = int(
		takedown_cfg.get("min_awareness", 40)
	)
	var takedown_participation: int = int(
		takedown_cfg.get("min_participation", 30)
	)

	if (
		awareness >= takedown_awareness
		and participation >= takedown_participation
	):
		return ENDING_TAKEDOWN

	var questioned_cfg: Dictionary = _thresholds.get(
		ENDING_QUESTIONED, {}
	)
	var questioned_awareness: int = int(
		questioned_cfg.get("min_awareness", 20)
	)
	var questioned_participation: int = int(
		questioned_cfg.get("min_participation", 0)
	)

	if (
		awareness >= questioned_awareness
		and participation >= questioned_participation
	):
		return ENDING_QUESTIONED

	return ENDING_NORMAL


## Returns the full ending data dict for the given ending type.
func get_ending_data(ending_type: String) -> Dictionary:
	return _endings.get(ending_type, {})


## Returns whether an ending has already been shown this session.
func has_ending_been_shown() -> bool:
	return _ending_shown


## Marks the ending as shown and records the type.
func record_ending(ending_type: String) -> void:
	_ending_shown = true
	_recorded_ending = ending_type
	EventBus.ending_triggered.emit(ending_type)


## Returns the recorded ending type, or empty if none.
func get_recorded_ending() -> String:
	return _recorded_ending


func get_save_data() -> Dictionary:
	if _recorded_ending.is_empty():
		return {}
	return {
		"ending_type": _recorded_ending,
		"ending_shown": _ending_shown,
	}


func load_save_data(data: Dictionary) -> void:
	_recorded_ending = str(data.get("ending_type", ""))
	_ending_shown = bool(data.get("ending_shown", false))


func _check_all_milestones_completed() -> bool:
	if not _progression_system:
		return false
	var milestones: Array[Dictionary] = (
		_progression_system.get_milestones()
	)
	if milestones.is_empty():
		return false
	for milestone: Dictionary in milestones:
		var mid: String = milestone.get("id", "")
		if not _progression_system.is_milestone_completed(mid):
			return false
	return true


func _on_milestone_completed(
	_milestone_id: String,
	_milestone_name: String,
	_reward_description: String,
) -> void:
	if _ending_shown:
		return
	if _check_all_milestones_completed():
		EventBus.all_milestones_completed.emit()


func _load_config() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		push_warning(
			"EndingEvaluator: config not found at %s"
			% CONFIG_PATH
		)
		return

	var file: FileAccess = FileAccess.open(
		CONFIG_PATH, FileAccess.READ
	)
	if not file:
		push_warning(
			"EndingEvaluator: failed to open %s" % CONFIG_PATH
		)
		return

	var json := JSON.new()
	var err: Error = json.parse(file.get_as_text())
	file.close()

	if err != OK:
		push_warning(
			"EndingEvaluator: JSON parse error — %s"
			% json.get_error_message()
		)
		return

	var root: Variant = json.data
	if root is not Dictionary:
		push_warning("EndingEvaluator: root is not a Dictionary")
		return

	_config = root as Dictionary
	var endings_raw: Variant = _config.get("endings", {})
	if endings_raw is Dictionary:
		_endings = endings_raw as Dictionary

	var thresholds_raw: Variant = _config.get("thresholds", {})
	if thresholds_raw is Dictionary:
		_thresholds = thresholds_raw as Dictionary
