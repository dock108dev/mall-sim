## Manages layered ambient audio zones for the mall hallway.
class_name HallwayAmbientZones
extends Node3D


const ZONE_MUZAK: String = "hallway_muzak"
const ZONE_MECHANICAL: String = "hallway_mechanical"
const ZONE_CROWD: String = "hallway_crowd"
const ZONE_FOOD_COURT: String = "food_court"

const MUZAK_VOLUME_DB: float = -8.0
const MECHANICAL_VOLUME_DB: float = -18.0
const CROWD_MIN_DB: float = -20.0
const CROWD_MAX_DB: float = -8.0
const CROWD_MAX_SHOPPERS: int = 15
const FOOD_COURT_VOLUME_DB: float = -4.0
const FOOD_COURT_SFX_MIN_INTERVAL: float = 3.0
const FOOD_COURT_SFX_MAX_INTERVAL: float = 8.0
const PLAYER_UNIT_SIZE: float = 24.0
const PLAYER_MAX_DISTANCE: float = 60.0
const SAMPLE_RATE: int = 11025
const FOOD_COURT_ACTIVE_PHASE: int = TimeSystem.DayPhase.MIDDAY_RUSH

const AMBIANCE_DIR: String = "res://game/assets/audio/ambiance/"
const MUSIC_DIR: String = "res://game/assets/audio/music/"
const SFX_DIR: String = "res://game/assets/audio/sfx/"

const _MUZAK_PATH: String = AMBIANCE_DIR + "hallway_muzak.wav"
const _MUZAK_FALLBACK_PATH: String = MUSIC_DIR + "mall_hallway_music.wav"
const _MUZAK_CHRISTMAS_PATH: String = (
	AMBIANCE_DIR + "hallway_muzak_christmas.wav"
)
const _MECHANICAL_PATH: String = AMBIANCE_DIR + "hallway_mechanical.wav"
const _MECHANICAL_FALLBACK_PATH: String = AMBIANCE_DIR + "mall_hallway.wav"
const _CROWD_PATH: String = AMBIANCE_DIR + "hallway_crowd.wav"
const _CROWD_FALLBACK_PATH: String = AMBIANCE_DIR + "mall_hallway.wav"
const _FOOD_COURT_PATH: String = AMBIANCE_DIR + "food_court_ambience.wav"
const _FOOD_COURT_FALLBACK_PATH: String = AMBIANCE_DIR + "mall_hallway.wav"
const _TRAY_CLATTER_PATH: String = SFX_DIR + "tray_clatter.wav"
const _TRAY_CLATTER_FALLBACK_PATH: String = SFX_DIR + "item_placement.wav"
const _FRYER_SFX_PATH: String = SFX_DIR + "fryer_sizzle.wav"
const _FRYER_SFX_FALLBACK_PATH: String = SFX_DIR + "refurbish_start.wav"

var _muzak_player: AudioStreamPlayer3D = null
var _mechanical_player: AudioStreamPlayer3D = null
var _crowd_player: AudioStreamPlayer3D = null
var _food_court_player: AudioStreamPlayer3D = null
var _food_court_sfx_timer: Timer = null

var _food_court_active: bool = false
var _is_initialized: bool = false
var _using_christmas_muzak: bool = false

var _customer_system: CustomerSystem = null
var _time_system: TimeSystem = null

var _muzak_stream: AudioStream = null
var _muzak_christmas_stream: AudioStream = null
var _mechanical_stream: AudioStream = null
var _crowd_stream: AudioStream = null
var _food_court_stream: AudioStream = null
var _food_court_sfx_streams: Array[AudioStream] = []


## Injects the runtime systems used by crowd and time-aware ambience.
func configure_runtime_dependencies(
	customer_system: CustomerSystem,
	time_system: TimeSystem
) -> void:
	_customer_system = customer_system
	_time_system = time_system
	_try_initialize_runtime()


func _ready() -> void:
	_try_initialize_runtime()


func _exit_tree() -> void:
	_disconnect_signals()
	_deactivate_food_court()
	_unregister_zones()


func _try_initialize_runtime() -> void:
	if _is_initialized or not is_inside_tree():
		return
	if _customer_system == null:
		push_warning(
			"HallwayAmbientZones: missing CustomerSystem; crowd ambience stays at minimum volume"
		)
	if _time_system == null:
		push_error(
			"HallwayAmbientZones: missing TimeSystem; seasonal and food court ambience disabled"
		)

	_load_streams()
	_create_players()
	_register_zones()
	_connect_signals()
	_start_persistent_zones()
	_refresh_food_court_state()
	_is_initialized = true


func _load_streams() -> void:
	_muzak_stream = _load_stream_with_fallback(
		_MUZAK_PATH, _MUZAK_FALLBACK_PATH, "hallway muzak"
	)
	_muzak_christmas_stream = _load_stream_or_default(
		_MUZAK_CHRISTMAS_PATH,
		_build_christmas_muzak_stream(),
		"hallway Christmas muzak"
	)
	_mechanical_stream = _load_stream_with_fallback(
		_MECHANICAL_PATH, _MECHANICAL_FALLBACK_PATH, "hallway mechanical"
	)
	_crowd_stream = _load_stream_with_fallback(
		_CROWD_PATH, _CROWD_FALLBACK_PATH, "hallway crowd"
	)
	_food_court_stream = _load_stream_with_fallback(
		_FOOD_COURT_PATH, _FOOD_COURT_FALLBACK_PATH, "food court ambience"
	)
	_food_court_sfx_streams.clear()

	var tray_stream: AudioStream = _load_stream_with_fallback(
		_TRAY_CLATTER_PATH, _TRAY_CLATTER_FALLBACK_PATH, "food court tray clatter"
	)
	if tray_stream != null:
		_food_court_sfx_streams.append(tray_stream)

	var fryer_stream: AudioStream = _load_stream_with_fallback(
		_FRYER_SFX_PATH, _FRYER_SFX_FALLBACK_PATH, "food court fryer"
	)
	if fryer_stream != null:
		_food_court_sfx_streams.append(fryer_stream)


func _create_players() -> void:
	_muzak_player = _make_zone_player(
		"MuzakPlayer", Vector3(0.0, 2.6, 4.0), MUZAK_VOLUME_DB
	)
	_mechanical_player = _make_zone_player(
		"MechanicalPlayer", Vector3(0.0, 3.6, 0.5), MECHANICAL_VOLUME_DB
	)
	_crowd_player = _make_zone_player(
		"CrowdPlayer", Vector3(0.0, 2.8, 4.8), CROWD_MIN_DB
	)
	_food_court_player = _make_zone_player(
		"FoodCourtPlayer", Vector3(0.0, 2.4, 6.6), FOOD_COURT_VOLUME_DB
	)

	_food_court_sfx_timer = Timer.new()
	_food_court_sfx_timer.name = "FoodCourtSFXTimer"
	_food_court_sfx_timer.one_shot = true
	_food_court_sfx_timer.timeout.connect(_on_food_court_sfx_timeout)
	add_child(_food_court_sfx_timer)


func _make_zone_player(
	player_name: String,
	player_position: Vector3,
	volume_db: float
) -> AudioStreamPlayer3D:
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.name = player_name
	player.position = player_position
	player.bus = AudioManager.AMBIENCE_BUS
	player.volume_db = volume_db
	player.unit_size = PLAYER_UNIT_SIZE
	player.max_distance = PLAYER_MAX_DISTANCE
	player.attenuation_model = (
		AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
	)
	player.finished.connect(_on_zone_player_finished.bind(player))
	add_child(player)
	return player


func _register_zones() -> void:
	AudioManager.register_zone(ZONE_MUZAK, _muzak_player)
	AudioManager.register_zone(ZONE_MECHANICAL, _mechanical_player)
	AudioManager.register_zone(ZONE_CROWD, _crowd_player)
	AudioManager.register_zone(ZONE_FOOD_COURT, _food_court_player)


func _unregister_zones() -> void:
	var zone_map: Dictionary = {
		ZONE_MUZAK: _muzak_player,
		ZONE_MECHANICAL: _mechanical_player,
		ZONE_CROWD: _crowd_player,
		ZONE_FOOD_COURT: _food_court_player,
	}
	for zone_id: String in zone_map:
		AudioManager.exit_zone(zone_id)
		var player: AudioStreamPlayer3D = zone_map[zone_id] as AudioStreamPlayer3D
		if player != null:
			player.stop()
		AudioManager.unregister_zone(zone_id)


func _connect_signals() -> void:
	if not EventBus.customer_spawned.is_connected(_on_customer_spawned):
		EventBus.customer_spawned.connect(_on_customer_spawned)
	if not EventBus.customer_left.is_connected(_on_customer_left):
		EventBus.customer_left.connect(_on_customer_left)
	if not EventBus.day_phase_changed.is_connected(_on_day_phase_changed):
		EventBus.day_phase_changed.connect(_on_day_phase_changed)
	if not EventBus.day_started.is_connected(_on_day_started):
		EventBus.day_started.connect(_on_day_started)


func _disconnect_signals() -> void:
	if EventBus.customer_spawned.is_connected(_on_customer_spawned):
		EventBus.customer_spawned.disconnect(_on_customer_spawned)
	if EventBus.customer_left.is_connected(_on_customer_left):
		EventBus.customer_left.disconnect(_on_customer_left)
	if EventBus.day_phase_changed.is_connected(_on_day_phase_changed):
		EventBus.day_phase_changed.disconnect(_on_day_phase_changed)
	if EventBus.day_started.is_connected(_on_day_started):
		EventBus.day_started.disconnect(_on_day_started)


func _start_persistent_zones() -> void:
	_update_muzak_track()
	_assign_looping_stream(_muzak_player, _get_active_muzak_stream())
	_assign_looping_stream(_mechanical_player, _mechanical_stream)
	_assign_looping_stream(_crowd_player, _crowd_stream)
	_play_registered_zone(ZONE_MUZAK, _muzak_player)
	_play_registered_zone(ZONE_MECHANICAL, _mechanical_player)
	_play_registered_zone(ZONE_CROWD, _crowd_player)
	_update_crowd_volume()


func _assign_looping_stream(
	player: AudioStreamPlayer3D,
	stream: AudioStream
) -> void:
	if player == null or stream == null:
		return
	player.stream = stream


func _play_registered_zone(
	zone_id: String,
	player: AudioStreamPlayer3D
) -> void:
	if player == null or player.stream == null:
		return
	AudioManager.set_zone_volume_db(zone_id, player.volume_db)
	player.play()


func _get_active_muzak_stream() -> AudioStream:
	if _using_christmas_muzak and _muzak_christmas_stream != null:
		return _muzak_christmas_stream
	return _muzak_stream


func _update_muzak_track() -> void:
	var should_be_christmas: bool = false
	if _time_system != null:
		var month: int = _time_system.get_current_month()
		should_be_christmas = month == 11 or month == 12
	if should_be_christmas == _using_christmas_muzak:
		return
	_using_christmas_muzak = should_be_christmas
	var new_stream: AudioStream = _get_active_muzak_stream()
	if new_stream == null:
		return
	_muzak_player.stream = new_stream
	if _muzak_player.playing:
		_muzak_player.play()


func _update_crowd_volume() -> void:
	var shopper_count: int = 0
	if _customer_system != null:
		shopper_count = _customer_system.get_active_mall_shopper_count()
	var t: float = clampf(
		float(shopper_count) / float(CROWD_MAX_SHOPPERS), 0.0, 1.0
	)
	var volume_db: float = lerpf(CROWD_MIN_DB, CROWD_MAX_DB, t)
	_crowd_player.volume_db = volume_db
	AudioManager.set_zone_volume_db(ZONE_CROWD, volume_db)


func _refresh_food_court_state() -> void:
	if _time_system == null:
		_deactivate_food_court()
		return
	if _time_system.get_current_phase() == FOOD_COURT_ACTIVE_PHASE:
		_activate_food_court()
	else:
		_deactivate_food_court()


func _activate_food_court() -> void:
	if _food_court_active:
		return
	_food_court_active = true
	_assign_looping_stream(_food_court_player, _food_court_stream)
	AudioManager.enter_zone(ZONE_FOOD_COURT)
	_schedule_next_food_court_sfx()


func _deactivate_food_court() -> void:
	if not _food_court_active:
		return
	_food_court_active = false
	if _food_court_sfx_timer != null:
		_food_court_sfx_timer.stop()
	AudioManager.exit_zone(ZONE_FOOD_COURT)
	if _food_court_player != null:
		_food_court_player.stop()


func _schedule_next_food_court_sfx() -> void:
	if not _food_court_active or _food_court_sfx_timer == null:
		return
	var delay: float = randf_range(
		FOOD_COURT_SFX_MIN_INTERVAL, FOOD_COURT_SFX_MAX_INTERVAL
	)
	_food_court_sfx_timer.start(delay)


func _on_customer_spawned(_customer: Node) -> void:
	_update_crowd_volume()


func _on_customer_left(_customer_data: Dictionary) -> void:
	call_deferred("_update_crowd_volume")


func _on_day_phase_changed(new_phase: int) -> void:
	if new_phase == FOOD_COURT_ACTIVE_PHASE:
		_activate_food_court()
	else:
		_deactivate_food_court()


func _on_day_started(_day: int) -> void:
	_update_muzak_track()
	_update_crowd_volume()
	_refresh_food_court_state()


func _on_food_court_sfx_timeout() -> void:
	if not _food_court_active or _food_court_sfx_streams.is_empty():
		return
	var stream: AudioStream = _food_court_sfx_streams.pick_random()
	AudioManager.play_sfx_stream(stream, FOOD_COURT_VOLUME_DB)
	_schedule_next_food_court_sfx()


func _on_zone_player_finished(player: AudioStreamPlayer3D) -> void:
	if player == null or player.stream == null:
		return
	if player == _food_court_player and not _food_court_active:
		return
	player.play()


func _load_stream_with_fallback(
	primary_path: String,
	fallback_path: String,
	label: String
) -> AudioStream:
	var primary_stream: AudioStream = _load_stream_or_null(primary_path)
	if primary_stream != null:
		return primary_stream
	var fallback_stream: AudioStream = _load_stream_or_null(fallback_path)
	if fallback_stream != null:
		push_warning(
			"HallwayAmbientZones: using fallback audio for %s" % label
		)
		return fallback_stream
	push_warning(
		"HallwayAmbientZones: missing audio for %s" % label
	)
	return null


func _load_stream_or_default(
	path: String,
	default_stream: AudioStream,
	label: String
) -> AudioStream:
	var stream: AudioStream = _load_stream_or_null(path)
	if stream != null:
		return stream
	push_warning(
		"HallwayAmbientZones: using procedural fallback for %s" % label
	)
	return default_stream


func _load_stream_or_null(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream


func _build_christmas_muzak_stream() -> AudioStreamWAV:
	var frame_count: int = SAMPLE_RATE * 2
	var data: PackedByteArray = PackedByteArray()
	data.resize(frame_count)
	for i: int in range(frame_count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var chord: float = sin(TAU * 261.63 * t) * 0.32
		chord += sin(TAU * 329.63 * t) * 0.24
		chord += sin(TAU * 392.00 * t) * 0.18
		var bell_gate: float = maxf(sin(TAU * 1.1 * t), 0.0)
		var bells: float = sin(TAU * 784.0 * t) * 0.12 * bell_gate
		data[i] = _linear_to_pcm8(chord + bells)

	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = frame_count
	stream.data = data
	return stream


func _linear_to_pcm8(value: float) -> int:
	var clamped: float = clampf(value, -1.0, 1.0)
	return int(round((clamped * 0.5 + 0.5) * 255.0))
