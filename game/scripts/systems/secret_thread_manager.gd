## Manages the hidden secret narrative thread state.
class_name SecretThreadManager
extends Node


var _state: SecretThreadState = SecretThreadState.new()


## Registers that a clue was discovered, adding awareness points.
func register_clue_found(
	clue_id: String, awareness_points: int
) -> void:
	if clue_id.is_empty():
		push_warning(
			"SecretThreadManager: empty clue_id in register_clue_found"
		)
		return
	if awareness_points <= 0:
		push_warning(
			"SecretThreadManager: non-positive awareness_points for '%s'"
			% clue_id
		)
		return
	var old_phase: SecretThreadState.ThreadPhase = _state.thread_phase
	var new_phase: SecretThreadState.ThreadPhase = _state.add_awareness(
		clue_id, awareness_points
	)
	if new_phase != old_phase:
		push_warning(
			"SecretThreadManager: phase transition %d -> %d"
			% [old_phase, new_phase]
		)


## Records a player response to a clue, adding participation points.
func register_participation(
	clue_id: String,
	response_type: String,
	participation_points: int,
) -> void:
	if clue_id.is_empty():
		push_warning(
			"SecretThreadManager: empty clue_id in "
			+ "register_participation"
		)
		return
	if participation_points <= 0:
		push_warning(
			"SecretThreadManager: non-positive participation_points "
			+ "for '%s'" % clue_id
		)
		return
	_state.add_participation(
		clue_id, response_type, participation_points
	)


## Returns the current thread phase.
func get_thread_phase() -> SecretThreadState.ThreadPhase:
	return _state.thread_phase


## Returns the current awareness score.
func get_awareness_score() -> int:
	return _state.awareness_score


## Returns the current participation score.
func get_participation_score() -> int:
	return _state.participation_score


## Serializes state for saving. Returns empty dict if default.
func get_save_data() -> Dictionary:
	if not _state.is_non_default():
		return {}
	return _state.get_save_data()


## Restores state from saved data.
func load_save_data(data: Dictionary) -> void:
	_state = SecretThreadState.new()
	if not data.is_empty():
		_state.load_save_data(data)
