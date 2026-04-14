## Manages layered ambient audio zones for the mall hallway.
class_name HallwayAmbientZones
extends Node


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

const AMBIANCE_DIR: String = "res://game/assets/audio/ambiance/"
const SFX_DIR: String = "res://game/assets/audio/sfx/"

const _MUZAK_PATH: String = AMBIANCE_DIR + "hallway_muzak.wav"
const _MUZAK_CHRISTMAS_PATH: String = (
	AMBIANCE_DIR + "hallway_muzak_christmas.wav"
)
const _MECHANICAL_PATH: String = AMBIANCE_DIR + "hallway_mechanical.wav"
const _CROWD_PATH: String = AMBIANCE_DIR + "hallway_crowd.wav"
const _FOOD_COURT_PATH: String = AMBIANCE_DIR + "food_court_ambience.wav"
const _TRAY_CLATTER_PATH: String = SFX_DIR + "tray_clatter.wav"
const _FRYER_SFX_PATH: String = SFX_DIR + "fryer_sizzle.wav"

var _muzak_player: AudioStreamPlayer = null
var _mechanical_player: AudioStreamPlayer = null
var _crowd_player: AudioStreamPlayer = null
var _food_court_player: AudioStreamPlayer = null
var _food_court_sfx_timer: Timer = null
var _food_court_active: bool = false
var _customer_system: CustomerSystem = null
var _time_system: TimeSystem = null

var _muzak_stream: AudioStream = null
var _muzak_christmas_stream: AudioStream = null
var _mechanical_stream: AudioStream = null
var _crowd_stream: AudioStream = null
var _food_court_stream: AudioStream = null
var _tray_clatter_stream: AudioStream = null
var _fryer_stream: AudioStream = null
var _food_court_sfx_streams: Array[AudioStream] = []
var _using_christmas_muzak: bool = false


func initialize(
	customer_system: CustomerSystem,
	time_system: TimeSystem
) -> void:
	_customer_system = customer_system
	_time_system = time_system
	_load_streams()
	_create_players()
	_register_zones()
	_connect_signals()
	_start_persistent_zones()
	_check_food_court_phase()


func _exit_tree() -> void:
	_unregister_zones()


func _load_streams() -> void:
	_muzak_stream = _try_load_stream(_MUZAK_PATH)
	_muzak_christmas_stream = _try_load_stream(_MUZAK_CHRISTMAS_PATH)
	_mechanical_stream = _try_load_stream(_MECHANICAL_PATH)
	_crowd_stream = _try_load_stream(_CROWD_PATH)
	_food_court_stream = _try_load_stream(_FOOD_COURT_PATH)
	_tray_clatter_stream = _try_load_stream(_TRAY_CLATTER_PATH)
	_fryer_stream = _try_load_stream(_FRYER_SFX_PATH)

	if _tray_clatter_stream:
		_food_court_sfx_streams.append(_tray_clatter_stream)
	if _fryer_stream:
		_food_court_sfx_streams.append(_fryer_stream)


func _try_load_stream(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		push_warning(
			"HallwayAmbientZones: audio not found: %s" % path
		)
		return null
	return load(path) as AudioStream


func _create_players() -> void:
	_muzak_player = _make_ambient_player(
		"MuzakPlayer", MUZAK_VOLUME_DB
	)
	_mechanical_player = _make_ambient_player(
		"MechanicalPlayer", MECHANICAL_VOLUME_DB
	)
	_crowd_player = _make_ambient_player(
		"CrowdPlayer", CROWD_MIN_DB
	)
	_food_court_player = _make_ambient_player(
		"FoodCourtPlayer", FOOD_COURT_VOLUME_DB
	)

	_food_court_sfx_timer = Timer.new()
	_food_court_sfx_timer.name = "FoodCourtSFXTimer"
	_food_court_sfx_timer.one_shot = true
	_food_court_sfx_timer.timeout.connect(_on_food_court_sfx_timeout)
	add_child(_food_court_sfx_timer)


func _make_ambient_player(
	player_name: String, volume_db: float
) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = player_name
	player.bus = AudioManager.AMBIENT_BUS
	player.volume_db = volume_db
	add_child(player)
	return player


func _register_zones() -> void:
	AudioManager.register_zone(ZONE_MUZAK, _muzak_player)
	AudioManager.register_zone(ZONE_MECHANICAL, _mechanical_player)
	AudioManager.register_zone(ZONE_CROWD, _crowd_player)
	AudioManager.register_zone(ZONE_FOOD_COURT, _food_court_player)


func _unregister_zones() -> void:
	for zone_id: String in [
		ZONE_MUZAK, ZONE_MECHANICAL, ZONE_CROWD, ZONE_FOOD_COURT
	]:
		AudioManager.exit_zone(zone_id)


func _connect_signals() -> void:
	EventBus.customer_spawned.connect(_on_shopper_count_changed)
	EventBus.customer_left_mall.connect(_on_customer_left_mall)
	EventBus.day_phase_changed.connect(_on_day_phase_changed)
	EventBus.day_started.connect(_on_day_started)
	EventBus.hour_changed.connect(_on_hour_changed)


func _start_persistent_zones() -> void:
	_update_muzak_track()
	_assign_and_loop(_muzak_player, _get_active_muzak_stream())
	_assign_and_loop(_mechanical_player, _mechanical_stream)
	_assign_and_loop(_crowd_player, _crowd_stream)
	_update_crowd_volume()


func _assign_and_loop(
	player: AudioStreamPlayer, stream: AudioStream
) -> void:
	if stream == null:
		return
	player.stream = stream
	player.play()


func _get_active_muzak_stream() -> AudioStream:
	if _using_christmas_muzak and _muzak_christmas_stream:
		return _muzak_christmas_stream
	return _muzak_stream


func _update_muzak_track() -> void:
	if not _time_system:
		return
	var month: int = _time_system.get_current_month()
	var should_be_christmas: bool = month == 11 or month == 12
	if should_be_christmas == _using_christmas_muzak:
		return
	_using_christmas_muzak = should_be_christmas
	var new_stream: AudioStream = _get_active_muzak_stream()
	if new_stream == null:
		return
	_muzak_player.stream = new_stream
	_muzak_player.play()


func _update_crowd_volume() -> void:
	var shopper_count: int = 0
	if _customer_system:
		shopper_count = _customer_system.get_active_mall_shopper_count()
	var t: float = clampf(
		float(shopper_count) / float(CROWD_MAX_SHOPPERS), 0.0, 1.0
	)
	_crowd_player.volume_db = lerpf(CROWD_MIN_DB, CROWD_MAX_DB, t)


func _activate_food_court() -> void:
	if _food_court_active:
		return
	_food_court_active = true
	_assign_and_loop(_food_court_player, _food_court_stream)
	_schedule_next_food_court_sfx()


func _deactivate_food_court() -> void:
	if not _food_court_active:
		return
	_food_court_active = false
	_food_court_player.stop()
	_food_court_sfx_timer.stop()


func _schedule_next_food_court_sfx() -> void:
	if not _food_court_active:
		return
	var delay: float = randf_range(
		FOOD_COURT_SFX_MIN_INTERVAL, FOOD_COURT_SFX_MAX_INTERVAL
	)
	_food_court_sfx_timer.start(delay)


func _check_food_court_phase() -> void:
	if not _time_system:
		return
	var phase: TimeSystem.DayPhase = _time_system.get_current_phase()
	if phase == TimeSystem.DayPhase.MIDDAY_RUSH:
		_activate_food_court()
	else:
		_deactivate_food_court()


func _on_shopper_count_changed(_customer: Node) -> void:
	_update_crowd_volume()


func _on_customer_left_mall(
	_customer: Node, _satisfied: bool
) -> void:
	_update_crowd_volume()


func _on_day_phase_changed(new_phase: int) -> void:
	if new_phase == TimeSystem.DayPhase.MIDDAY_RUSH:
		_activate_food_court()
	else:
		_deactivate_food_court()


func _on_day_started(_day: int) -> void:
	_update_muzak_track()
	_update_crowd_volume()


func _on_hour_changed(_hour: int) -> void:
	_update_crowd_volume()


func _on_food_court_sfx_timeout() -> void:
	if not _food_court_active:
		return
	if not _food_court_sfx_streams.is_empty():
		var stream: AudioStream = _food_court_sfx_streams.pick_random()
		AudioManager.play_sfx_stream(stream, FOOD_COURT_VOLUME_DB)
	_schedule_next_food_court_sfx()
