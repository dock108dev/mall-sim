## Manages audio playback for music, SFX, and ambient sounds.
extends Node

## Emitted on every key-based play call (play_sfx or play_bgm/play_music).
## Allows external systems to monitor or test audio dispatch without AudioServer.
signal audio_played(key: String)

const SFX_DIR: String = "res://game/assets/audio/sfx/"
const MUSIC_DIR: String = "res://game/assets/audio/music/"
const AMBIANCE_DIR: String = "res://game/assets/audio/ambiance/"
const AUDIO_REGISTRY_PATH: String = "res://game/content/audio_registry.json"
const SFX_POOL_SIZE: int = 8
const SFX_BUS: String = "SFX"
const MUSIC_BUS: String = "Music"
const AMBIENCE_BUS: String = "Ambience"
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
var _zone_target_linear: Dictionary = {}
var _zone_tweens: Dictionary = {}
var _warned_messages: Dictionary = {}

var _event_handler: Node = null

## Cached music_stems section from audio registry; keyed by store_id string.
var _music_stems: Dictionary = {}

## Ambience bus duck state: volume_db before ducking.
var _ambience_pre_duck_db: float = 0.0
var _duck_tween: Tween = null

const DUCK_DURATION: float = 0.3
const DUCK_TARGET_DB: float = -12.0


func _ready() -> void:
	_create_players()
	_load_from_registry()
	_setup_event_handler()
	if not EventBus.preference_changed.is_connected(_on_preference_changed):
		EventBus.preference_changed.connect(_on_preference_changed)
	_apply_settings_volumes()


## Applies bus volumes from current Settings values. Called by boot sequence
## after Settings.load_settings() so volumes reflect saved preferences.
func initialize() -> void:
	if _is_headless():
		return
	_apply_settings_volumes()


## Crossfades BGM to the music stem registered for the given store_id.
## Falls back to mall_hallway_music when no stem is configured.
func crossfade(store_id: StringName) -> void:
	if _is_headless():
		return
	var key: String = _music_stems.get(String(store_id), "")
	if key.is_empty():
		play_bgm("mall_hallway_music", DEFAULT_CROSSFADE)
		return
	play_bgm(key, DEFAULT_CROSSFADE)


## Ducks the Ambience bus to DUCK_TARGET_DB over DUCK_DURATION seconds.
func duck_hub_ambience() -> void:
	if _is_headless():
		return
	var idx: int = _get_ambience_bus_index()
	if idx < 0:
		return
	_ambience_pre_duck_db = AudioServer.get_bus_volume_db(idx)
	_kill_duck_tween()
	_duck_tween = create_tween()
	_duck_tween.tween_method(
		func(db: float) -> void: AudioServer.set_bus_volume_db(idx, db),
		_ambience_pre_duck_db, DUCK_TARGET_DB, DUCK_DURATION
	)


## Restores the Ambience bus to its pre-duck volume over DUCK_DURATION seconds.
func unduck_hub_ambience() -> void:
	if _is_headless():
		return
	var idx: int = _get_ambience_bus_index()
	if idx < 0:
		return
	var current_db: float = AudioServer.get_bus_volume_db(idx)
	_kill_duck_tween()
	_duck_tween = create_tween()
	_duck_tween.tween_method(
		func(db: float) -> void: AudioServer.set_bus_volume_db(idx, db),
		current_db, _ambience_pre_duck_db, DUCK_DURATION
	)


## Returns a cached ambient stream by registry key, or null if not found.
func get_ambient_stream(key: String) -> AudioStream:
	return _ambient_streams.get(key, null) as AudioStream


## Returns true when running without a display (CI headless mode).
func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


func _kill_duck_tween() -> void:
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	_duck_tween = null


## Plays a one-shot SFX from either a preloaded name key or an AudioStream.
func play_sfx(sound: Variant, volume_db: float = 0.0) -> void:
	if sound is AudioStream:
		_play_sfx_stream(sound as AudioStream, volume_db)
		return
	if not (sound is String or sound is StringName):
		push_warning("AudioManager: unsupported SFX value '%s'" % str(sound))
		return

	var sound_name: String = String(sound)
	audio_played.emit(sound_name)
	if not _sfx_streams.has(sound_name):
		push_warning("AudioManager: Unknown SFX '%s'" % sound_name)
		return

	var player: AudioStreamPlayer = _get_available_player()
	player.stream = _sfx_streams[sound_name]
	player.volume_db = volume_db
	player.play()


func _play_sfx_stream(
	stream: AudioStream, volume_db: float = 0.0
) -> void:
	if stream == null:
		push_warning("AudioManager: null stream passed to play_sfx_stream")
		return

	var player: AudioStreamPlayer = _get_available_player()
	player.stream = stream
	player.volume_db = volume_db
	player.play()


## Crossfades from the current BGM to a new track.
func play_bgm(
	track_key: String, fade_duration: float = DEFAULT_CROSSFADE
) -> void:
	if track_key == _current_track_name:
		return

	audio_played.emit(track_key)
	var stream: AudioStream = _resolve_music_stream(track_key)
	if stream == null:
		_warn_once(
			"music_track:%s" % track_key,
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
	_zone_target_linear.erase(zone_id)


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
	var idx: int = _get_bus_index(MUSIC_BUS)
	if idx < 0:
		push_error("AudioManager: Music bus not found")
		return
	AudioServer.set_bus_volume_db(
		idx, linear_to_db(clampf(linear, 0.0, 1.0))
	)


## Sets the Ambience bus volume in linear scale (0.0 to 1.0).
func set_ambience_volume(linear: float) -> void:
	var idx: int = _get_ambience_bus_index()
	if idx < 0:
		push_error("AudioManager: Ambience bus not found")
		return
	AudioServer.set_bus_volume_db(
		idx, linear_to_db(clampf(linear, 0.0, 1.0))
	)


## Sets volume for a named audio bus in linear scale (0.0 to 1.0).
func set_bus_volume(bus_name: StringName, linear_volume: float) -> void:
	var idx: int = _get_bus_index(String(bus_name))
	if idx < 0:
		push_error("AudioManager: bus '%s' not found" % bus_name)
		return
	AudioServer.set_bus_volume_db(
		idx, linear_to_db(clampf(linear_volume, 0.0, 1.0))
	)


## Sets the SFX bus volume in linear scale (0.0 to 1.0).
func set_sfx_volume(linear: float) -> void:
	var idx: int = _get_bus_index(SFX_BUS)
	if idx < 0:
		push_error("AudioManager: SFX bus not found")
		return
	AudioServer.set_bus_volume_db(
		idx, linear_to_db(clampf(linear, 0.0, 1.0))
	)


## Registers a zone player for enter/exit control.
func register_zone(
	zone_id: String, player: Node
) -> void:
	if zone_id.is_empty():
		push_error("AudioManager: empty zone_id in register_zone")
		return
	if player == null:
		push_error(
			"AudioManager: null player for zone '%s'" % zone_id
		)
		return
	if not _is_zone_audio_player(player):
		push_error(
			"AudioManager: unsupported zone player for '%s'" % zone_id
		)
		return
	_zone_players[zone_id] = player
	_zone_target_linear[zone_id] = _get_zone_linear_volume(player)


## Updates the target dB level for a registered zone.
func set_zone_volume_db(zone_id: String, volume_db: float) -> void:
	if not _zone_players.has(zone_id):
		push_warning("AudioManager: unregistered zone '%s'" % zone_id)
		return
	var player: Node = _zone_players[zone_id] as Node
	_zone_target_linear[zone_id] = db_to_linear(volume_db)
	_set_zone_player_volume_db(player, volume_db)


## Fades in the ambient player for a registered zone.
func enter_zone(zone_id: String) -> void:
	if not _zone_players.has(zone_id):
		push_warning(
			"AudioManager: unregistered zone '%s'" % zone_id
		)
		return

	var player: Node = _zone_players[zone_id] as Node
	_kill_zone_tween(zone_id)
	var target_linear: float = _zone_target_linear.get(
		zone_id, _get_zone_linear_volume(player)
	)

	if not _is_zone_player_playing(player):
		_set_zone_player_volume_db(player, linear_to_db(0.001))
		_play_zone_player(player)

	var tween: Tween = create_tween()
	tween.tween_method(
		_set_player_volume.bind(player),
		0.0, target_linear, AMBIENT_CROSSFADE_DURATION
	)
	_zone_tweens[zone_id] = tween


## Fades out the ambient player for a registered zone.
func exit_zone(zone_id: String) -> void:
	if not _zone_players.has(zone_id):
		push_warning(
			"AudioManager: unregistered zone '%s'" % zone_id
		)
		return

	var player: Node = _zone_players[zone_id] as Node
	if not _is_zone_player_playing(player):
		return

	_kill_zone_tween(zone_id)

	var tween: Tween = create_tween()
	tween.tween_method(
		_set_player_volume.bind(player),
		_get_zone_linear_volume(player), 0.0,
		AMBIENT_CROSSFADE_DURATION
	)
	tween.tween_callback(_stop_zone_player.bind(player))
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


func _get_bus_index(bus_name: String) -> int:
	if bus_name == AMBIENCE_BUS:
		return _get_ambience_bus_index()
	return AudioServer.get_bus_index(bus_name)


func _get_ambience_bus_index() -> int:
	return AudioServer.get_bus_index(AMBIENCE_BUS)


func _setup_event_handler() -> void:
	_event_handler = Node.new()
	_event_handler.set_script(
		preload("res://game/autoload/audio_event_handler.gd")
	)
	add_child(_event_handler)
	_event_handler.initialize(self)
	# Keep signal wiring in AudioEventHandler so this autoload only owns
	# playback state, player pools, and bus volume control.


## Alias for play_bgm — plays a background music track by name.
func play_music(track_key: String) -> void:
	play_bgm(track_key)


## Sets volume for a named audio bus in linear scale (0.0–1.0).
## Convenience wrapper over set_bus_volume for String bus names.
func set_volume(bus: String, value: float) -> void:
	set_bus_volume(StringName(bus), value)


func _kill_zone_tween(zone_id: String) -> void:
	if _zone_tweens.has(zone_id):
		var existing: Tween = _zone_tweens[zone_id]
		if existing != null and existing.is_valid():
			existing.kill()
		_zone_tweens.erase(zone_id)


func _is_zone_audio_player(player: Node) -> bool:
	return player is AudioStreamPlayer or player is AudioStreamPlayer3D


func _play_zone_player(player: Node) -> void:
	if player is AudioStreamPlayer:
		(player as AudioStreamPlayer).play()
	elif player is AudioStreamPlayer3D:
		(player as AudioStreamPlayer3D).play()


func _stop_zone_player(player: Node) -> void:
	if player is AudioStreamPlayer:
		(player as AudioStreamPlayer).stop()
	elif player is AudioStreamPlayer3D:
		(player as AudioStreamPlayer3D).stop()


func _is_zone_player_playing(player: Node) -> bool:
	if player is AudioStreamPlayer:
		return (player as AudioStreamPlayer).playing
	if player is AudioStreamPlayer3D:
		return (player as AudioStreamPlayer3D).playing
	return false


func _get_zone_linear_volume(player: Node) -> float:
	if player is AudioStreamPlayer:
		return db_to_linear((player as AudioStreamPlayer).volume_db)
	if player is AudioStreamPlayer3D:
		return db_to_linear((player as AudioStreamPlayer3D).volume_db)
	return 0.001


func _set_zone_player_volume_db(player: Node, volume_db: float) -> void:
	if player is AudioStreamPlayer:
		(player as AudioStreamPlayer).volume_db = volume_db
	elif player is AudioStreamPlayer3D:
		(player as AudioStreamPlayer3D).volume_db = volume_db


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
	_ambient_player_a = _make_stream_player(AMBIENCE_BUS, 0.0)
	_ambient_player_a.finished.connect(
		_on_ambient_finished.bind(_ambient_player_a)
	)
	_ambient_player_b = _make_stream_player(AMBIENCE_BUS, linear_to_db(0.0))
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


func _load_from_registry() -> void:
	if not FileAccess.file_exists(AUDIO_REGISTRY_PATH):
		push_error(
			"AudioManager: audio registry not found: %s" % AUDIO_REGISTRY_PATH
		)
		return
	var file := FileAccess.open(AUDIO_REGISTRY_PATH, FileAccess.READ)
	if file == null:
		push_error("AudioManager: cannot open audio registry")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("AudioManager: audio registry parse error")
		return
	var reg: Dictionary = parsed as Dictionary
	_load_audio_dir(reg.get("sfx", {}), SFX_DIR, _sfx_streams)
	_load_audio_dir(reg.get("music", {}), MUSIC_DIR, _music_streams)
	_load_audio_dir(reg.get("ambient", {}), AMBIANCE_DIR, _ambient_streams)
	var stems: Variant = reg.get("music_stems", {})
	if stems is Dictionary:
		_music_stems = stems as Dictionary


func _load_audio_dir(
	files: Dictionary, base_dir: String, target: Dictionary
) -> void:
	for key: String in files:
		var path: String = base_dir + files[key]
		if ".." in path:
			push_warning("AudioManager: rejecting path with traversal segment: %s" % path)
			continue
		if ResourceLoader.exists(path):
			target[key] = load(path)
		else:
			_warn_once(
				"audio_path:%s" % path,
				"AudioManager: audio not found: %s" % path
			)


func _warn_once(key: String, message: String) -> void:
	if _warned_messages.has(key):
		return
	_warned_messages[key] = true
	push_warning(message)


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
	value: float, player: Node
) -> void:
	_set_zone_player_volume_db(
		player, linear_to_db(clampf(value, 0.001, 1.0))
	)


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
	stream_key: String, cache: Dictionary
) -> AudioStream:
	if cache.has(stream_key):
		return cache[stream_key] as AudioStream
	if ResourceLoader.exists(stream_key):
		var stream: AudioStream = load(stream_key) as AudioStream
		if stream != null:
			cache[stream_key] = stream
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

	_warn_once("sfx_pool_full", "AudioManager: SFX pool saturated — stealing a playing channel")
	var player: AudioStreamPlayer = _sfx_players[_next_player_index]
	_next_player_index = (_next_player_index + 1) % SFX_POOL_SIZE
	return player
