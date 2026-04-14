## Manages audio playback for music, SFX, and ambient sounds.
extends Node

const SFX_DIR: String = "res://game/assets/audio/sfx/"
const MUSIC_DIR: String = "res://game/assets/audio/music/"
const AMBIANCE_DIR: String = "res://game/assets/audio/ambiance/"
const SFX_POOL_SIZE: int = 8
const SFX_BUS: String = "SFX"
const MUSIC_BUS: String = "Music"
const AMBIENT_BUS: String = "Ambient"
const DEFAULT_CROSSFADE: float = 0.5
const AMBIENT_CROSSFADE_DURATION: float = 0.5
const MUSIC_VOLUME_DB: float = -6.0

var _sfx_streams: Dictionary = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_player_index: int = 0

var _music_player_a: AudioStreamPlayer = null
var _music_player_b: AudioStreamPlayer = null
var _active_music_player: AudioStreamPlayer = null
var _current_track_name: String = ""
var _crossfade_tween: Tween = null
var _music_streams: Dictionary = {}

var _ambient_player_a: AudioStreamPlayer = null
var _ambient_player_b: AudioStreamPlayer = null
var _active_ambient_player: AudioStreamPlayer = null
var _current_ambient_name: String = ""
var _ambient_crossfade_tween: Tween = null
var _ambient_streams: Dictionary = {}

var _zone_players: Dictionary = {}
var _zone_tweens: Dictionary = {}

var _event_handler: Node = null


func _ready() -> void:
	_create_players()
	_preload_sfx()
	_preload_music()
	_preload_ambient()
	_setup_event_handler()
	EventBus.preference_changed.connect(_on_preference_changed)


## Applies bus volumes from current Settings values. Called by boot sequence
## after Settings.load_settings() so volumes reflect saved preferences.
func initialize() -> void:
	_apply_settings_volumes()


## Plays a one-shot SFX by preloaded name key.
func play_sfx(sound_name: String) -> void:
	if not _sfx_streams.has(sound_name):
		push_warning("AudioManager: Unknown SFX '%s'" % sound_name)
		return

	var player: AudioStreamPlayer = _get_available_player()
	if player == null:
		return

	player.stream = _sfx_streams[sound_name]
	player.volume_db = 0.0
	player.play()


## Plays a one-shot SFX from an AudioStream on the SFX bus.
func play_sfx_stream(
	stream: AudioStream, volume_db: float = 0.0
) -> void:
	if stream == null:
		push_warning("AudioManager: null stream passed to play_sfx_stream")
		return

	var player: AudioStreamPlayer = _get_available_player()
	if player == null:
		return

	player.stream = stream
	player.volume_db = volume_db
	player.play()


## Crossfades from the current BGM to a new track.
func play_bgm(
	track_key: String, fade_duration: float = DEFAULT_CROSSFADE
) -> void:
	if track_key == _current_track_name:
		return

	var stream: AudioStream = _resolve_music_stream(track_key)
	if stream == null:
		push_warning(
			"AudioManager: Music track not found '%s'" % track_key
		)
		return

	_crossfade_to(stream, track_key, fade_duration)


## Fades out the current BGM without starting a new track.
func stop_bgm(fade_duration: float = DEFAULT_CROSSFADE) -> void:
	if _current_track_name.is_empty():
		return

	_current_track_name = ""
	_fade_out_active(fade_duration)


## Returns the currently playing music track ID, or empty string if none.
func get_current_music_id() -> String:
	return _current_track_name


## Returns the list of registered ambient zone IDs.
func get_active_zones() -> Array[String]:
	var zones: Array[String] = []
	for key: String in _zone_players:
		zones.append(key)
	return zones


## Unregisters an ambient zone by ID, stopping any active fade tween.
func unregister_zone(zone_id: String) -> void:
	if not _zone_players.has(zone_id):
		return
	_kill_zone_tween(zone_id)
	_zone_players.erase(zone_id)


## Returns the current Music bus volume in linear scale (0.0 to 1.0).
func get_music_volume() -> float:
	var idx: int = AudioServer.get_bus_index(MUSIC_BUS)
	if idx < 0:
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(idx))


## Returns the current SFX bus volume in linear scale (0.0 to 1.0).
func get_sfx_volume() -> float:
	var idx: int = AudioServer.get_bus_index(SFX_BUS)
	if idx < 0:
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(idx))


## Sets the Music bus volume in linear scale (0.0 to 1.0).
func set_music_volume(linear: float) -> void:
	var idx: int = AudioServer.get_bus_index(MUSIC_BUS)
	if idx < 0:
		push_error("AudioManager: Music bus not found")
		return
	AudioServer.set_bus_volume_db(
		idx, linear_to_db(clampf(linear, 0.0, 1.0))
	)


## Sets the Ambience bus volume in linear scale (0.0 to 1.0).
func set_ambience_volume(linear: float) -> void:
	var idx: int = AudioServer.get_bus_index(AMBIENT_BUS)
	if idx < 0:
		push_error("AudioManager: Ambient bus not found")
		return
	AudioServer.set_bus_volume_db(
		idx, linear_to_db(clampf(linear, 0.0, 1.0))
	)


## Sets volume for a named audio bus in linear scale (0.0 to 1.0).
func set_bus_volume(bus_name: StringName, linear_volume: float) -> void:
	var idx: int = AudioServer.get_bus_index(String(bus_name))
	if idx < 0:
		push_error("AudioManager: bus '%s' not found" % bus_name)
		return
	AudioServer.set_bus_volume_db(
		idx, linear_to_db(clampf(linear_volume, 0.0, 1.0))
	)


## Sets the SFX bus volume in linear scale (0.0 to 1.0).
func set_sfx_volume(linear: float) -> void:
	var idx: int = AudioServer.get_bus_index(SFX_BUS)
	if idx < 0:
		push_error("AudioManager: SFX bus not found")
		return
	AudioServer.set_bus_volume_db(
		idx, linear_to_db(clampf(linear, 0.0, 1.0))
	)


## Registers a zone's ambient AudioStreamPlayer for enter/exit control.
func register_zone(
	zone_id: String, player: AudioStreamPlayer
) -> void:
	if zone_id.is_empty():
		push_error("AudioManager: empty zone_id in register_zone")
		return
	if player == null:
		push_error(
			"AudioManager: null player for zone '%s'" % zone_id
		)
		return
	_zone_players[zone_id] = player


## Fades in the ambient player for a registered zone.
func enter_zone(zone_id: String) -> void:
	if not _zone_players.has(zone_id):
		push_warning(
			"AudioManager: unregistered zone '%s'" % zone_id
		)
		return

	var player: AudioStreamPlayer = _zone_players[zone_id]
	_kill_zone_tween(zone_id)

	if not player.playing:
		player.volume_db = linear_to_db(0.001)
		player.play()

	var tween: Tween = create_tween()
	tween.tween_method(
		_set_player_volume.bind(player),
		0.0, 1.0, AMBIENT_CROSSFADE_DURATION
	)
	_zone_tweens[zone_id] = tween


## Fades out the ambient player for a registered zone.
func exit_zone(zone_id: String) -> void:
	if not _zone_players.has(zone_id):
		push_warning(
			"AudioManager: unregistered zone '%s'" % zone_id
		)
		return

	var player: AudioStreamPlayer = _zone_players[zone_id]
	if not player.playing:
		return

	_kill_zone_tween(zone_id)

	var tween: Tween = create_tween()
	tween.tween_method(
		_set_player_volume.bind(player),
		db_to_linear(player.volume_db), 0.0,
		AMBIENT_CROSSFADE_DURATION
	)
	tween.tween_callback(player.stop)
	_zone_tweens[zone_id] = tween


func play_ambient(track_name: String) -> void:
	if track_name == _current_ambient_name:
		return

	var stream: AudioStream = _resolve_ambient_stream(track_name)
	if stream == null:
		push_warning(
			"AudioManager: Ambient track not found '%s'" % track_name
		)
		return

	_crossfade_ambient_to(stream, track_name)


func stop_ambient() -> void:
	if _current_ambient_name.is_empty():
		return

	_current_ambient_name = ""
	_fade_out_ambient()


func _apply_settings_volumes() -> void:
	set_music_volume(Settings.music_volume)
	set_ambience_volume(Settings.ambient_volume)
	set_sfx_volume(Settings.sfx_volume)


func _on_preference_changed(key: String, value: Variant) -> void:
	match StringName(key):
		&"master_volume":
			set_bus_volume(&"Master", value as float)
		&"music_volume":
			set_music_volume(value as float)
		&"sfx_volume":
			set_sfx_volume(value as float)
		&"ambient_volume":
			set_ambience_volume(value as float)


func _setup_event_handler() -> void:
	_event_handler = Node.new()
	_event_handler.set_script(
		preload("res://game/autoload/audio_event_handler.gd")
	)
	add_child(_event_handler)
	_event_handler.initialize(self)


func _kill_zone_tween(zone_id: String) -> void:
	if _zone_tweens.has(zone_id):
		var existing: Tween = _zone_tweens[zone_id]
		if existing != null and existing.is_valid():
			existing.kill()
		_zone_tweens.erase(zone_id)


func _create_players() -> void:
	for i: int in range(SFX_POOL_SIZE):
		_sfx_players.append(_make_stream_player(SFX_BUS, 0.0))
	_music_player_a = _make_stream_player(MUSIC_BUS, MUSIC_VOLUME_DB)
	_music_player_a.finished.connect(
		_on_music_finished.bind(_music_player_a)
	)
	_music_player_b = _make_stream_player(MUSIC_BUS, linear_to_db(0.0))
	_music_player_b.finished.connect(
		_on_music_finished.bind(_music_player_b)
	)
	_active_music_player = _music_player_a
	_ambient_player_a = _make_stream_player(AMBIENT_BUS, 0.0)
	_ambient_player_a.finished.connect(
		_on_ambient_finished.bind(_ambient_player_a)
	)
	_ambient_player_b = _make_stream_player(AMBIENT_BUS, linear_to_db(0.0))
	_ambient_player_b.finished.connect(
		_on_ambient_finished.bind(_ambient_player_b)
	)
	_active_ambient_player = _ambient_player_a


func _make_stream_player(
	bus: String, vol_db: float
) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.bus = bus
	player.volume_db = vol_db
	add_child(player)
	return player


func _preload_ambient() -> void:
	_load_audio_dir(
		{&"mall_hallway": "mall_hallway.wav"}, AMBIANCE_DIR, _ambient_streams
	)


func _preload_sfx() -> void:
	_load_audio_dir({
		&"purchase_chime": "purchase_chime.wav",
		&"purchase_ding": "purchase_ding.wav",
		&"door_bell": "door_bell.wav",
		&"cash_register": "cash_register.wav",
		&"item_placement": "item_placement.wav",
		&"ui_click": "ui_click.wav",
		&"day_end_chime": "day_end_chime.wav",
		&"notification_ping": "notification_ping.wav",
		&"haggle_accept": "haggle_accept.wav",
		&"haggle_reject": "haggle_reject.wav",
		&"build_place": "build_place.wav",
		&"build_error": "build_error.wav",
		&"build_mode_enter": "build_mode_enter.wav",
		&"pack_opening": "pack_opening.wav",
		&"refurbish_start": "refurbish_start.wav",
		&"refurbish_complete": "refurbish_complete.wav",
		&"tape_insert": "tape_insert.wav",
		&"auth_reveal": "auth_reveal.wav",
		&"demo_activate": "demo_activate.wav",
	}, SFX_DIR, _sfx_streams)


func _preload_music() -> void:
	_load_audio_dir({
		&"menu_music": "menu_music.wav",
		&"day_summary_music": "day_summary_music.wav",
		&"mall_hallway_music": "mall_hallway_music.wav",
		&"mall_open_music": "mall_open_music.wav",
		&"mall_close_music": "mall_close_music.wav",
		&"build_mode_music": "build_mode_music.wav",
	}, MUSIC_DIR, _music_streams)


func _load_audio_dir(
	files: Dictionary, base_dir: String, target: Dictionary
) -> void:
	for key: String in files:
		var path: String = base_dir + files[key]
		if ResourceLoader.exists(path):
			target[key] = load(path)
		else:
			push_warning("AudioManager: audio not found: %s" % path)


func _resolve_music_stream(track_name: String) -> AudioStream:
	return _resolve_stream(track_name, _music_streams)


func _crossfade_to(
	stream: AudioStream, track_name: String, duration: float
) -> void:
	if _crossfade_tween != null and _crossfade_tween.is_valid():
		_crossfade_tween.kill()

	var outgoing: AudioStreamPlayer = _active_music_player
	var incoming: AudioStreamPlayer = _get_inactive_player()
	var music_linear: float = db_to_linear(MUSIC_VOLUME_DB)

	incoming.stream = stream
	incoming.volume_db = linear_to_db(0.001)
	incoming.play()

	_crossfade_tween = create_tween()
	_crossfade_tween.set_parallel(true)

	_crossfade_tween.tween_method(
		_set_player_volume.bind(incoming),
		0.0, music_linear, duration
	)

	if outgoing.playing:
		_crossfade_tween.tween_method(
			_set_player_volume.bind(outgoing),
			music_linear, 0.0, duration
		)

	_crossfade_tween.chain().tween_callback(
		_on_crossfade_complete.bind(outgoing)
	)

	_active_music_player = incoming
	_current_track_name = track_name


func _fade_out_active(duration: float = DEFAULT_CROSSFADE) -> void:
	if _crossfade_tween != null and _crossfade_tween.is_valid():
		_crossfade_tween.kill()

	var outgoing: AudioStreamPlayer = _active_music_player
	if not outgoing.playing:
		return

	var music_linear: float = db_to_linear(MUSIC_VOLUME_DB)
	_crossfade_tween = create_tween()
	_crossfade_tween.tween_method(
		_set_player_volume.bind(outgoing),
		music_linear, 0.0, duration
	)
	_crossfade_tween.tween_callback(outgoing.stop)


func _set_player_volume(
	value: float, player: AudioStreamPlayer
) -> void:
	player.volume_db = linear_to_db(clampf(value, 0.001, 1.0))


func _on_crossfade_complete(old_player: AudioStreamPlayer) -> void:
	old_player.stop()


func _on_music_finished(player: AudioStreamPlayer) -> void:
	if player == _active_music_player and player.stream != null:
		player.play()


func _on_ambient_finished(player: AudioStreamPlayer) -> void:
	if player == _active_ambient_player and player.stream != null:
		player.play()


func _resolve_ambient_stream(track_name: String) -> AudioStream:
	return _resolve_stream(track_name, _ambient_streams)


func _resolve_stream(
	name: String, cache: Dictionary
) -> AudioStream:
	if cache.has(name):
		return cache[name] as AudioStream
	if ResourceLoader.exists(name):
		var stream: AudioStream = load(name) as AudioStream
		if stream != null:
			cache[name] = stream
			return stream
	return null


func _crossfade_ambient_to(
	stream: AudioStream, track_name: String
) -> void:
	if _ambient_crossfade_tween != null:
		if _ambient_crossfade_tween.is_valid():
			_ambient_crossfade_tween.kill()

	var outgoing: AudioStreamPlayer = _active_ambient_player
	var incoming: AudioStreamPlayer = _get_inactive_ambient_player()

	incoming.stream = stream
	incoming.volume_db = linear_to_db(0.001)
	incoming.play()

	_ambient_crossfade_tween = create_tween()
	_ambient_crossfade_tween.set_parallel(true)

	_ambient_crossfade_tween.tween_method(
		_set_player_volume.bind(incoming),
		0.0, 1.0, AMBIENT_CROSSFADE_DURATION
	)

	if outgoing.playing:
		_ambient_crossfade_tween.tween_method(
			_set_player_volume.bind(outgoing),
			1.0, 0.0, AMBIENT_CROSSFADE_DURATION
		)

	_ambient_crossfade_tween.chain().tween_callback(
		_on_crossfade_complete.bind(outgoing)
	)

	_active_ambient_player = incoming
	_current_ambient_name = track_name


func _fade_out_ambient() -> void:
	if _ambient_crossfade_tween != null:
		if _ambient_crossfade_tween.is_valid():
			_ambient_crossfade_tween.kill()

	var outgoing: AudioStreamPlayer = _active_ambient_player
	if not outgoing.playing:
		return

	_ambient_crossfade_tween = create_tween()
	_ambient_crossfade_tween.tween_method(
		_set_player_volume.bind(outgoing),
		1.0, 0.0, AMBIENT_CROSSFADE_DURATION
	)
	_ambient_crossfade_tween.tween_callback(outgoing.stop)


func _get_inactive_ambient_player() -> AudioStreamPlayer:
	return _ambient_player_b if _active_ambient_player == _ambient_player_a else _ambient_player_a


func _get_inactive_player() -> AudioStreamPlayer:
	return _music_player_b if _active_music_player == _music_player_a else _music_player_a


func _get_available_player() -> AudioStreamPlayer:
	for i: int in range(SFX_POOL_SIZE):
		var idx: int = (_next_player_index + i) % SFX_POOL_SIZE
		if not _sfx_players[idx].playing:
			_next_player_index = (idx + 1) % SFX_POOL_SIZE
			return _sfx_players[idx]

	var player: AudioStreamPlayer = _sfx_players[_next_player_index]
	_next_player_index = (_next_player_index + 1) % SFX_POOL_SIZE
	return player
