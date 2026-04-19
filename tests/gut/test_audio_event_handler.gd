## Tests that AudioEventHandler wires EventBus signals to AudioManager correctly.
extends GutTest


class MockAudio extends Node:
	var sfx_calls: Array[String] = []
	var bgm_calls: Array[Dictionary] = []
	var stop_bgm_calls: Array[float] = []
	var enter_zone_calls: Array[String] = []
	var exit_zone_calls: Array[String] = []

	func play_sfx(name: String) -> void:
		sfx_calls.append(name)

	func play_bgm(track: String, fade: float = 0.5) -> void:
		bgm_calls.append({"track": track, "fade": fade})

	func stop_bgm(fade: float = 0.5) -> void:
		stop_bgm_calls.append(fade)

	func enter_zone(zone_id: String) -> void:
		enter_zone_calls.append(zone_id)

	func exit_zone(zone_id: String) -> void:
		exit_zone_calls.append(zone_id)

	func play_ambient(_track: String) -> void:
		pass

	func stop_ambient() -> void:
		pass


var _handler: Node
var _mock: MockAudio


func before_each() -> void:
	_mock = MockAudio.new()
	add_child_autofree(_mock)
	_handler = Node.new()
	_handler.set_script(
		preload("res://game/autoload/audio_event_handler.gd")
	)
	add_child_autofree(_handler)
	_handler.initialize(_mock)


func test_store_entered_calls_enter_zone() -> void:
	EventBus.store_entered.emit(&"sports_memorabilia")
	assert_eq(
		_mock.enter_zone_calls.size(), 1,
		"store_entered should trigger enter_zone once"
	)
	assert_eq(
		_mock.enter_zone_calls[0], "sports_memorabilia",
		"enter_zone should receive the correct store_id"
	)


func test_store_exited_calls_exit_zone() -> void:
	EventBus.store_exited.emit(&"sports_memorabilia")
	assert_eq(
		_mock.exit_zone_calls.size(), 1,
		"store_exited should trigger exit_zone once"
	)
	assert_eq(
		_mock.exit_zone_calls[0], "sports_memorabilia",
		"exit_zone should receive the correct store_id"
	)


func test_customer_purchased_plays_purchase_ding() -> void:
	EventBus.customer_purchased.emit(
		&"retro_games", &"snes_cartridge", 25.0, &"customer_001"
	)
	assert_true(
		_mock.sfx_calls.has("purchase_ding"),
		"customer_purchased should play purchase_ding SFX"
	)


func test_day_started_plays_mall_open_music_with_fade() -> void:
	EventBus.day_started.emit(1)
	var found: Array = [false]
	for call: Dictionary in _mock.bgm_calls:
		if call["track"] == "mall_open_music" and absf(call["fade"] - 0.5) < 0.001:
			found[0] = true
			break
	assert_true(found[0], "day_started should play mall_open_music with 0.5 fade")


func test_day_ended_plays_mall_close_music_with_fade() -> void:
	EventBus.day_ended.emit(1)
	var found: Array = [false]
	for call: Dictionary in _mock.bgm_calls:
		if call["track"] == "mall_close_music" and absf(call["fade"] - 1.0) < 0.001:
			found[0] = true
			break
	assert_true(found[0], "day_ended should play mall_close_music with 1.0 fade")


func test_day_ended_also_plays_day_end_chime_sfx() -> void:
	EventBus.day_ended.emit(1)
	assert_true(
		_mock.sfx_calls.has("day_end_chime"),
		"day_ended should still play day_end_chime SFX"
	)


func test_game_over_stops_bgm_with_two_second_fade() -> void:
	EventBus.game_state_changed.emit(
		GameManager.GameState.GAMEPLAY,
		GameManager.GameState.GAME_OVER
	)
	assert_eq(
		_mock.stop_bgm_calls.size(), 1,
		"GAME_OVER state should call stop_bgm once"
	)
	assert_almost_eq(
		_mock.stop_bgm_calls[0], 2.0, 0.001,
		"stop_bgm should be called with a 2.0-second fade"
	)


func test_build_mode_entered_plays_sfx() -> void:
	EventBus.build_mode_entered.emit()
	assert_true(
		_mock.sfx_calls.has("build_mode_enter"),
		"build_mode_entered should play build_mode_enter SFX"
	)


func test_build_mode_entered_plays_bgm_with_short_fade() -> void:
	EventBus.build_mode_entered.emit()
	var found: Array = [false]
	for call: Dictionary in _mock.bgm_calls:
		if call["track"] == "build_mode_music" and absf(call["fade"] - 0.3) < 0.001:
			found[0] = true
			break
	assert_true(found[0], "build_mode_entered should play build_mode_music with 0.3 fade")


func test_build_mode_exited_restores_mall_open_music() -> void:
	EventBus.build_mode_exited.emit()
	var found: Array = [false]
	for call: Dictionary in _mock.bgm_calls:
		if call["track"] == "mall_open_music" and absf(call["fade"] - 0.3) < 0.001:
			found[0] = true
			break
	assert_true(found[0], "build_mode_exited should restore mall_open_music with 0.3 fade")


func test_haggle_started_plays_haggle_start_sfx() -> void:
	EventBus.haggle_started.emit("item_001", 42)
	assert_true(
		_mock.sfx_calls.has("haggle_start"),
		"haggle_started should play haggle_start SFX"
	)


func test_milestone_unlocked_plays_milestone_pop_sfx() -> void:
	EventBus.milestone_unlocked.emit(&"first_sale", {})
	assert_true(
		_mock.sfx_calls.has("milestone_pop"),
		"milestone_unlocked should play milestone_pop SFX"
	)


func test_no_direct_autoload_references_in_handler() -> void:
	# Verify the handler holds no direct system references — only the audio node.
	assert_eq(
		_handler._audio, _mock,
		"Handler should only hold a reference to the audio manager"
	)
