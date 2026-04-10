## Manages audio playback for music, SFX, and ambient sounds.
extends Node

const SFX_DIR: String = "res://game/assets/audio/sfx/"
const MUSIC_DIR: String = "res://game/assets/audio/music/"
const AMBIANCE_DIR: String = "res://game/assets/audio/ambiance/"
const SFX_POOL_SIZE: int = 8
const SFX_BUS: String = "SFX"
const MUSIC_BUS: String = "Music"
const AMBIENT_BUS: String = "Ambient"
const CROSSFADE_DURATION: float = 1.5
const AMBIENT_CROSSFADE_DURATION: float = 0.5
const MALL_AMBIENT_PATH: String = (
	"res://game/assets/audio/ambiance/mall_hallway.wav"
)

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


func _ready() -> void:
	_create_sfx_pool()
	_create_music_players()
	_create_ambient_players()
	_preload_sfx()
	_preload_music()
	_preload_ambient()
	_connect_event_signals()


func play_sfx(sound_name: String) -> void:
	if not _sfx_streams.has(sound_name):
		push_warning("AudioManager: Unknown SFX '%s'" % sound_name)
		return

	var player: AudioStreamPlayer = _get_available_player()
	if player == null:
		return

	player.stream = _sfx_streams[sound_name]
	player.play()


func play_music(track_name: String) -> void:
	if track_name == _current_track_name:
		return

	var stream: AudioStream = _resolve_music_stream(track_name)
	if stream == null:
		push_warning("AudioManager: Music track not found '%s'" % track_name)
		return

	_crossfade_to(stream, track_name)


func stop_music() -> void:
	if _current_track_name.is_empty():
		return

	_current_track_name = ""
	_fade_out_active()


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


func _create_sfx_pool() -> void:
	for i: int in range(SFX_POOL_SIZE):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = SFX_BUS
		add_child(player)
		_sfx_players.append(player)


func _create_music_players() -> void:
	_music_player_a = AudioStreamPlayer.new()
	_music_player_a.bus = MUSIC_BUS
	_music_player_a.volume_db = 0.0
	_music_player_a.finished.connect(_on_music_finished.bind(_music_player_a))
	add_child(_music_player_a)

	_music_player_b = AudioStreamPlayer.new()
	_music_player_b.bus = MUSIC_BUS
	_music_player_b.volume_db = linear_to_db(0.0)
	_music_player_b.finished.connect(_on_music_finished.bind(_music_player_b))
	add_child(_music_player_b)

	_active_music_player = _music_player_a


func _create_ambient_players() -> void:
	_ambient_player_a = AudioStreamPlayer.new()
	_ambient_player_a.bus = AMBIENT_BUS
	_ambient_player_a.volume_db = 0.0
	_ambient_player_a.finished.connect(
		_on_ambient_finished.bind(_ambient_player_a)
	)
	add_child(_ambient_player_a)

	_ambient_player_b = AudioStreamPlayer.new()
	_ambient_player_b.bus = AMBIENT_BUS
	_ambient_player_b.volume_db = linear_to_db(0.0)
	_ambient_player_b.finished.connect(
		_on_ambient_finished.bind(_ambient_player_b)
	)
	add_child(_ambient_player_b)

	_active_ambient_player = _ambient_player_a


func _preload_ambient() -> void:
	if ResourceLoader.exists(MALL_AMBIENT_PATH):
		_ambient_streams["mall_hallway"] = load(MALL_AMBIENT_PATH)
	else:
		push_warning(
			"AudioManager: Mall ambient not found: %s"
			% MALL_AMBIENT_PATH
		)


func _preload_sfx() -> void:
	var sfx_files: Dictionary = {
		"purchase_chime": "purchase_chime.wav",
		"door_bell": "door_bell.wav",
		"cash_register": "cash_register.wav",
		"item_placement": "item_placement.wav",
		"ui_click": "ui_click.wav",
		"day_end_chime": "day_end_chime.wav",
		"notification_ping": "notification_ping.wav",
	}

	for key: String in sfx_files:
		var path: String = SFX_DIR + sfx_files[key]
		if ResourceLoader.exists(path):
			_sfx_streams[key] = load(path)
		else:
			push_warning("AudioManager: SFX file not found: %s" % path)


func _preload_music() -> void:
	var music_files: Dictionary = {
		"menu_music": "menu_music.wav",
		"day_summary_music": "day_summary_music.wav",
	}

	for key: String in music_files:
		var path: String = MUSIC_DIR + music_files[key]
		if ResourceLoader.exists(path):
			_music_streams[key] = load(path)
		else:
			push_warning("AudioManager: Music file not found: %s" % path)


## Resolves a track name to an AudioStream. Checks preloaded music
## first, then attempts to load from an absolute resource path.
func _resolve_music_stream(track_name: String) -> AudioStream:
	if _music_streams.has(track_name):
		return _music_streams[track_name] as AudioStream

	# Treat as a resource path (for store ambient_sound fields)
	if ResourceLoader.exists(track_name):
		var stream: AudioStream = load(track_name) as AudioStream
		if stream != null:
			_music_streams[track_name] = stream
			return stream

	return null


func _crossfade_to(stream: AudioStream, track_name: String) -> void:
	if _crossfade_tween != null and _crossfade_tween.is_valid():
		_crossfade_tween.kill()

	var outgoing: AudioStreamPlayer = _active_music_player
	var incoming: AudioStreamPlayer = _get_inactive_player()

	incoming.stream = stream
	incoming.volume_db = linear_to_db(0.0)
	incoming.play()

	_crossfade_tween = create_tween()
	_crossfade_tween.set_parallel(true)

	# Fade in the incoming player
	_crossfade_tween.tween_method(
		_set_player_volume.bind(incoming),
		0.0, 1.0, CROSSFADE_DURATION
	)

	# Fade out the outgoing player (only if it's playing)
	if outgoing.playing:
		_crossfade_tween.tween_method(
			_set_player_volume.bind(outgoing),
			1.0, 0.0, CROSSFADE_DURATION
		)

	_crossfade_tween.chain().tween_callback(_on_crossfade_complete.bind(
		outgoing
	))

	_active_music_player = incoming
	_current_track_name = track_name


func _fade_out_active() -> void:
	if _crossfade_tween != null and _crossfade_tween.is_valid():
		_crossfade_tween.kill()

	var outgoing: AudioStreamPlayer = _active_music_player
	if not outgoing.playing:
		return

	_crossfade_tween = create_tween()
	_crossfade_tween.tween_method(
		_set_player_volume.bind(outgoing),
		1.0, 0.0, CROSSFADE_DURATION
	)
	_crossfade_tween.tween_callback(outgoing.stop)


func _set_player_volume(value: float, player: AudioStreamPlayer) -> void:
	player.volume_db = linear_to_db(clampf(value, 0.001, 1.0))


func _on_crossfade_complete(old_player: AudioStreamPlayer) -> void:
	old_player.stop()


func _on_music_finished(player: AudioStreamPlayer) -> void:
	# Restart the active player for seamless looping
	if player == _active_music_player and player.stream != null:
		player.play()


func _resolve_ambient_stream(track_name: String) -> AudioStream:
	if _ambient_streams.has(track_name):
		return _ambient_streams[track_name] as AudioStream

	if ResourceLoader.exists(track_name):
		var stream: AudioStream = load(track_name) as AudioStream
		if stream != null:
			_ambient_streams[track_name] = stream
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
		_on_ambient_crossfade_complete.bind(outgoing)
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


func _on_ambient_crossfade_complete(
	old_player: AudioStreamPlayer,
) -> void:
	old_player.stop()


func _on_ambient_finished(player: AudioStreamPlayer) -> void:
	if player == _active_ambient_player and player.stream != null:
		player.play()


func _get_inactive_ambient_player() -> AudioStreamPlayer:
	if _active_ambient_player == _ambient_player_a:
		return _ambient_player_b
	return _ambient_player_a


func _get_inactive_player() -> AudioStreamPlayer:
	if _active_music_player == _music_player_a:
		return _music_player_b
	return _music_player_a


func _get_available_player() -> AudioStreamPlayer:
	for i: int in range(SFX_POOL_SIZE):
		var idx: int = (_next_player_index + i) % SFX_POOL_SIZE
		if not _sfx_players[idx].playing:
			_next_player_index = (idx + 1) % SFX_POOL_SIZE
			return _sfx_players[idx]

	# All players busy — reuse the next in rotation
	var player: AudioStreamPlayer = _sfx_players[_next_player_index]
	_next_player_index = (_next_player_index + 1) % SFX_POOL_SIZE
	return player


func _connect_event_signals() -> void:
	EventBus.item_sold.connect(_on_item_sold)
	EventBus.customer_entered.connect(_on_customer_entered)
	EventBus.customer_ready_to_purchase.connect(
		_on_customer_ready_to_purchase
	)
	EventBus.item_stocked.connect(_on_item_stocked)
	EventBus.day_ended.connect(_on_day_ended)
	EventBus.reputation_changed.connect(_on_reputation_changed)
	EventBus.game_state_changed.connect(_on_game_state_changed)
	EventBus.storefront_entered.connect(_on_storefront_entered)
	EventBus.storefront_exited.connect(_on_storefront_exited)


func _on_item_sold(_id: String, _p: float, _c: String) -> void:
	play_sfx("purchase_chime")

func _on_customer_ready_to_purchase(_d: Dictionary) -> void:
	play_sfx("cash_register")

func _on_customer_entered(_d: Dictionary) -> void:
	play_sfx("door_bell")

func _on_item_stocked(_id: String, _shelf: String) -> void:
	play_sfx("item_placement")

func _on_day_ended(_day: int) -> void:
	play_sfx("day_end_chime")

func _on_reputation_changed(_old: float, _new: float) -> void:
	play_sfx("notification_ping")


func _on_game_state_changed(_old: int, new_state: int) -> void:
	match new_state:
		GameManager.GameState.MENU:
			play_music("menu_music")
			stop_ambient()
		GameManager.GameState.DAY_SUMMARY:
			play_music("day_summary_music")
		GameManager.GameState.PLAYING:
			_play_store_music()
			_play_store_ambient()


func _on_storefront_entered(_slot: int, store_id: String) -> void:
	_play_store_music_for(store_id)
	_play_store_ambient_for(store_id)


func _on_storefront_exited() -> void:
	play_music("menu_music")
	play_ambient("mall_hallway")


func _play_store_music() -> void:
	var store_id: String = GameManager.current_store_id
	if store_id.is_empty():
		return
	_play_store_music_for(store_id)


func _play_store_music_for(store_id: String) -> void:
	if GameManager.data_loader == null:
		return

	var store_def: StoreDefinition = GameManager.data_loader.get_store(
		store_id
	)
	if store_def == null:
		return

	var ambient_path: String = store_def.ambient_sound
	if ambient_path.is_empty():
		return

	play_music(ambient_path)


func _play_store_ambient() -> void:
	var store_id: String = GameManager.current_store_id
	if store_id.is_empty():
		play_ambient("mall_hallway")
		return
	_play_store_ambient_for(store_id)


func _play_store_ambient_for(store_id: String) -> void:
	if GameManager.data_loader == null:
		return

	var store_def: StoreDefinition = GameManager.data_loader.get_store(
		store_id
	)
	if store_def == null:
		play_ambient("mall_hallway")
		return

	var ambient_path: String = store_def.ambient_sound
	if ambient_path.is_empty():
		play_ambient("mall_hallway")
		return

	play_ambient(ambient_path)
