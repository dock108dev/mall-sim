## Hidden state model for the secret narrative thread.
class_name SecretThreadState
extends RefCounted


enum ThreadPhase {
	DORMANT,
	SEEDED,
	ACTIVE,
	ESCALATED,
}

const SEEDED_THRESHOLD: int = 10
const ACTIVE_THRESHOLD: int = 30
const ESCALATED_THRESHOLD: int = 60
const MAX_SCORE: int = 100

var awareness_score: int = 0
var participation_score: int = 0
var thread_phase: ThreadPhase = ThreadPhase.DORMANT
var clues_found: Array[String] = []
var responses: Dictionary = {}


## Returns true if awareness or participation have been modified.
func is_non_default() -> bool:
	return (
		awareness_score > 0
		or participation_score > 0
		or not clues_found.is_empty()
		or not responses.is_empty()
	)


## Adds awareness points and records the clue. Returns the new phase.
func add_awareness(clue_id: String, points: int) -> ThreadPhase:
	if clue_id.is_empty() or points <= 0:
		return thread_phase
	if clue_id not in clues_found:
		clues_found.append(clue_id)
	awareness_score = mini(awareness_score + points, MAX_SCORE)
	_evaluate_phase()
	return thread_phase


## Records a participation response for a clue.
func add_participation(
	clue_id: String,
	response_type: String,
	points: int,
) -> void:
	if clue_id.is_empty() or points <= 0:
		return
	responses[clue_id] = response_type
	participation_score = mini(
		participation_score + points, MAX_SCORE
	)


## Serializes full state to a Dictionary for saving.
func get_save_data() -> Dictionary:
	return {
		"awareness_score": awareness_score,
		"participation_score": participation_score,
		"thread_phase": thread_phase,
		"clues_found": clues_found.duplicate(),
		"responses": responses.duplicate(),
	}


## Restores state from a saved Dictionary.
func load_save_data(data: Dictionary) -> void:
	awareness_score = clampi(
		int(data.get("awareness_score", 0)), 0, MAX_SCORE
	)
	participation_score = clampi(
		int(data.get("participation_score", 0)), 0, MAX_SCORE
	)
	var saved_phase: int = int(data.get("thread_phase", 0))
	if saved_phase >= 0 and saved_phase <= ThreadPhase.ESCALATED:
		thread_phase = saved_phase as ThreadPhase
	else:
		thread_phase = ThreadPhase.DORMANT

	clues_found = []
	var saved_clues: Variant = data.get("clues_found", [])
	if saved_clues is Array:
		for entry: Variant in saved_clues:
			clues_found.append(str(entry))

	responses = {}
	var saved_responses: Variant = data.get("responses", {})
	if saved_responses is Dictionary:
		var resp_dict: Dictionary = saved_responses as Dictionary
		for key: Variant in resp_dict:
			responses[str(key)] = str(resp_dict[key])


func _evaluate_phase() -> void:
	if awareness_score >= ESCALATED_THRESHOLD:
		thread_phase = ThreadPhase.ESCALATED
	elif awareness_score >= ACTIVE_THRESHOLD:
		thread_phase = ThreadPhase.ACTIVE
	elif awareness_score >= SEEDED_THRESHOLD:
		thread_phase = ThreadPhase.SEEDED
