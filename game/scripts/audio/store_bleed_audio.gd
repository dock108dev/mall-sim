## Spatial audio source that bleeds genre music from a store entrance into the hallway.
class_name StoreBleedAudio
extends Node3D

## Phase index matching TimeSystem.DayPhase.PRE_OPEN — store is closed during this phase.
const PRE_OPEN_PHASE: int = 0

## Peak volume in dB at the entrance (0 m from source).
@export var max_db: float = 75.0
## Reference distance (metres) for inverse-square attenuation; ~5 m gives -20 dB at 15 m.
@export var unit_size: float = 5.0
## Res-path to the WAV/OGG placeholder track for this store genre.
@export var music_path: String = ""

@onready var _player: AudioStreamPlayer3D = $AudioStreamPlayer3D

var _is_open: bool = false


func _ready() -> void:
	_configure_player()
	_load_stream()
	EventBus.day_phase_changed.connect(_on_day_phase_changed)
	EventBus.day_ended.connect(_on_day_ended)


## Applies export-var settings to the 3D player child at runtime.
func _configure_player() -> void:
	_player.bus = AudioManager.MUSIC_BUS
	_player.max_db = max_db
	_player.unit_size = unit_size
	_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE


## Loads the genre placeholder track; missing files emit a warning but do not crash.
func _load_stream() -> void:
	if music_path.is_empty():
		return
	if not ResourceLoader.exists(music_path):
		push_warning("StoreBleedAudio: music path not found: %s" % music_path)
		return
	_player.stream = load(music_path)


func _on_day_phase_changed(new_phase: int) -> void:
	_set_open(new_phase != PRE_OPEN_PHASE)


func _on_day_ended(_day: int) -> void:
	_set_open(false)


func _set_open(open: bool) -> void:
	if _is_open == open:
		return
	_is_open = open
	if open:
		if _player.stream != null and not _player.playing:
			_player.play()
	else:
		_player.stop()
