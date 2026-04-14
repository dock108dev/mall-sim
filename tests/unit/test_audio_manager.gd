## Unit tests for AudioManager — play_sfx, play_bgm crossfade, stop_bgm fade,
## zone enter/exit, volume passthrough, and missing-resource guard.
extends GutTest

const AudioManagerScript: GDScript = preload("res://game/autoload/audio_manager.gd")

var _audio: Node


func before_each() -> void:
	_audio = AudioManagerScript.new()
	add_child_autofree(_audio)


func _inject_sfx_stream(key: String) -> AudioStreamWAV:
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	_audio._sfx_streams[key] = stream
	return stream


func _inject_music_stream(key: String) -> AudioStreamWAV:
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	_audio._music_streams[key] = stream
	return stream


# --- play_sfx: known resource ---

func test_play_sfx_known_resource_completes_without_error() -> void:
	_inject_sfx_stream("purchase_ding")
	_audio.play_sfx("purchase_ding")
	assert_true(true, "play_sfx with a known resource should complete without error")


func test_play_sfx_known_resource_assigns_stream_to_pool_player() -> void:
	var stream: AudioStreamWAV = _inject_sfx_stream("purchase_ding")
	_audio.play_sfx("purchase_ding")
	var found: Array = [false]
	for player: AudioStreamPlayer in _audio._sfx_players:
		if player.stream == stream:
			found[0] = true
			break
	assert_true(found[0], "A pool player should have the injected stream assigned after play_sfx")


# --- play_sfx: missing resource ---

func test_play_sfx_missing_resource_does_not_crash() -> void:
	_audio.play_sfx("nonexistent_sfx")
	assert_true(
		true,
		"play_sfx with an unknown key should emit push_warning and not crash"
	)


func test_play_sfx_missing_resource_starts_no_pool_player() -> void:
	_audio.play_sfx("nonexistent_sfx")
	var any_assigned: Array = [false]
	for player: AudioStreamPlayer in _audio._sfx_players:
		if player.stream != null:
			any_assigned[0] = true
			break
	assert_false(
		any_assigned[0],
		"No SFX pool player should have a stream assigned after a missing-resource call"
	)


# --- play_bgm: starts looping track ---

func test_play_bgm_sets_current_track_name() -> void:
	_inject_music_stream("ambient_mall_music")
	_audio.play_bgm("ambient_mall_music", 0.0)
	assert_eq(
		_audio.get_current_music_id(),
		"ambient_mall_music",
		"get_current_music_id should return the started track key"
	)


func test_play_bgm_assigns_stream_to_active_player() -> void:
	var stream: AudioStreamWAV = _inject_music_stream("ambient_mall_music")
	_audio.play_bgm("ambient_mall_music", 0.0)
	assert_eq(
		_audio._active_music_player.stream,
		stream,
		"Active music player should have the injected stream assigned"
	)


func test_play_bgm_missing_track_does_not_change_current_id() -> void:
	_audio.play_bgm("nonexistent_music_track", 0.0)
	assert_eq(
		_audio.get_current_music_id(),
		"",
		"play_bgm with a missing track should not update current track name"
	)


# --- play_bgm: replaces existing BGM ---

func test_play_bgm_replaces_existing_track() -> void:
	_inject_music_stream("track_a")
	_inject_music_stream("track_b")
	_audio.play_bgm("track_a", 0.0)
	_audio.play_bgm("track_b", 0.0)
	assert_eq(
		_audio.get_current_music_id(),
		"track_b",
		"Current track should be track_b after replacing track_a"
	)


func test_play_bgm_replaces_without_two_simultaneous_active_players() -> void:
	_inject_music_stream("track_a")
	_inject_music_stream("track_b")
	_audio.play_bgm("track_a", 0.0)
	_audio.play_bgm("track_b", 0.0)
	# _active_music_player must point to exactly one player; the other is outgoing
	assert_ne(
		_audio._active_music_player,
		null,
		"Active music player reference must not be null after replacement"
	)
	assert_eq(
		_audio.get_current_music_id(),
		"track_b",
		"Only the new track should be current after BGM replacement"
	)


# --- stop_bgm: immediate cut ---

func test_stop_bgm_immediate_clears_track_name() -> void:
	_inject_music_stream("ambient_mall_music")
	_audio.play_bgm("ambient_mall_music", 0.0)
	_audio.stop_bgm(0.0)
	assert_eq(
		_audio.get_current_music_id(),
		"",
		"stop_bgm(0.0) should clear the current track name in the same call frame"
	)


# --- stop_bgm: fade-out ---

func test_stop_bgm_fade_clears_track_name_when_fade_begins() -> void:
	_inject_music_stream("ambient_mall_music")
	_audio.play_bgm("ambient_mall_music", 0.0)
	_audio.stop_bgm(1.5)
	assert_eq(
		_audio.get_current_music_id(),
		"",
		"stop_bgm with fade_duration=1.5 should clear the track name when the fade begins"
	)


func test_stop_bgm_fade_creates_crossfade_tween() -> void:
	_inject_music_stream("ambient_mall_music")
	_audio.play_bgm("ambient_mall_music", 0.0)
	_audio.stop_bgm(1.5)
	assert_ne(
		_audio._crossfade_tween,
		null,
		"A crossfade tween should be active during a fade-out"
	)


# --- stop_bgm: no-op when silent ---

func test_stop_bgm_when_no_bgm_is_playing_is_noop() -> void:
	assert_eq(_audio.get_current_music_id(), "", "No BGM should be playing initially")
	_audio.stop_bgm(0.0)
	assert_eq(
		_audio.get_current_music_id(),
		"",
		"stop_bgm on a silent AudioManager should be a no-op"
	)


func test_stop_bgm_twice_is_noop_without_error() -> void:
	_inject_music_stream("ambient_mall_music")
	_audio.play_bgm("ambient_mall_music", 0.0)
	_audio.stop_bgm(0.0)
	_audio.stop_bgm(0.0)
	assert_eq(
		_audio.get_current_music_id(),
		"",
		"A second stop_bgm call when no BGM is playing should be a no-op and not crash"
	)


# --- enter_zone / exit_zone ---

func test_register_zone_appears_in_active_zones() -> void:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	add_child_autofree(player)
	_audio.register_zone("store_sports", player)
	assert_true(
		_audio.get_active_zones().has("store_sports"),
		"Registered zone should appear in get_active_zones()"
	)


func test_enter_zone_completes_without_error() -> void:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	add_child_autofree(player)
	_audio.register_zone("store_sports", player)
	_audio.enter_zone("store_sports")
	assert_true(true, "enter_zone on a registered zone should complete without error")


func test_exit_zone_completes_without_error() -> void:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	add_child_autofree(player)
	_audio.register_zone("store_sports", player)
	_audio.exit_zone("store_sports")
	assert_true(true, "exit_zone on a registered zone should complete without error")


func test_enter_zone_switch_leaves_no_orphaned_registrations() -> void:
	var player_a: AudioStreamPlayer = AudioStreamPlayer.new()
	var player_b: AudioStreamPlayer = AudioStreamPlayer.new()
	add_child_autofree(player_a)
	add_child_autofree(player_b)
	_audio.register_zone("store_sports", player_a)
	_audio.register_zone("store_retro", player_b)
	_audio.enter_zone("store_sports")
	_audio.enter_zone("store_retro")
	assert_true(
		_audio.get_active_zones().has("store_sports"),
		"store_sports zone should still be registered after switching"
	)
	assert_true(
		_audio.get_active_zones().has("store_retro"),
		"store_retro zone should be registered after the switch"
	)
	assert_eq(
		_audio.get_active_zones().size(),
		2,
		"Exactly two zones should be registered with no orphaned extras"
	)


func test_enter_unregistered_zone_is_noop_no_crash() -> void:
	_audio.enter_zone("not_registered_zone")
	assert_true(
		true,
		"enter_zone on an unregistered zone should emit push_warning and not crash"
	)


func test_exit_unregistered_zone_is_noop_no_crash() -> void:
	_audio.exit_zone("not_registered_zone")
	assert_true(
		true,
		"exit_zone on an unregistered zone should emit push_warning and not crash"
	)


# --- volume passthrough from Settings ---

func test_set_and_get_music_volume_roundtrip() -> void:
	_audio.set_music_volume(0.5)
	assert_almost_eq(
		_audio.get_music_volume(),
		0.5,
		0.01,
		"get_music_volume should reflect the value set via set_music_volume"
	)


func test_volume_passthrough_reflects_settings_music_volume() -> void:
	# Simulate the Settings -> AudioManager passthrough (ISSUE-296 linkage)
	var original_volume: float = Settings.music_volume
	Settings.music_volume = 0.3
	_audio.set_music_volume(Settings.music_volume)
	assert_almost_eq(
		_audio.get_music_volume(),
		0.3,
		0.01,
		"AudioManager.get_music_volume should reflect Settings.music_volume after passthrough"
	)
	Settings.music_volume = original_volume


# --- concurrent SFX ---

func test_concurrent_sfx_both_complete_without_error() -> void:
	_inject_sfx_stream("purchase_ding")
	_inject_sfx_stream("ui_click")
	_audio.play_sfx("purchase_ding")
	_audio.play_sfx("ui_click")
	assert_true(
		true,
		"Two rapid play_sfx calls with different ids should both complete without error"
	)


func test_concurrent_sfx_assign_to_separate_pool_players() -> void:
	var stream_a: AudioStreamWAV = _inject_sfx_stream("purchase_ding")
	var stream_b: AudioStreamWAV = _inject_sfx_stream("ui_click")
	_audio.play_sfx("purchase_ding")
	_audio.play_sfx("ui_click")
	var has_a: Array = [false]
	var has_b: Array = [false]
	for player: AudioStreamPlayer in _audio._sfx_players:
		if player.stream == stream_a:
			has_a[0] = true
		if player.stream == stream_b:
			has_b[0] = true
	assert_true(has_a[0], "A pool player should have stream_a assigned (purchase_ding)")
	assert_true(has_b[0], "A different pool player should have stream_b assigned (ui_click)")


# --- EventBus.preference_changed → bus volume (ISSUE-428) ---

func test_preference_changed_music_volume_updates_bus() -> void:
	_audio._on_preference_changed("music_volume", 0.25)
	assert_almost_eq(
		_audio.get_music_volume(), 0.25, 0.01,
		"Music bus should reflect volume set via _on_preference_changed"
	)


func test_preference_changed_sfx_volume_updates_bus() -> void:
	_audio._on_preference_changed("sfx_volume", 0.6)
	assert_almost_eq(
		_audio.get_sfx_volume(), 0.6, 0.01,
		"SFX bus should reflect volume set via _on_preference_changed"
	)


func test_preference_changed_unknown_key_does_not_crash() -> void:
	_audio._on_preference_changed("display_mode", 1)
	assert_true(true, "Unknown preference key in _on_preference_changed should be a no-op")
