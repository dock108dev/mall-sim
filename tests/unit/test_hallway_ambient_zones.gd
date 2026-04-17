## Unit tests for HallwayAmbientZones zone setup, playback, and phase behavior.
extends GutTest


var _zones: HallwayAmbientZones
var _time_system: TimeSystem
var _customer_system: CustomerSystem


func before_each() -> void:
	_time_system = TimeSystem.new()
	add_child_autofree(_time_system)
	_time_system.initialize()

	_customer_system = CustomerSystem.new()
	add_child_autofree(_customer_system)

	_zones = HallwayAmbientZones.new()
	_zones.configure_runtime_dependencies(_customer_system, _time_system)
	add_child_autofree(_zones)


func test_all_zones_register_with_audio_manager_on_ready() -> void:
	assert_true(
		AudioManager._zone_players.has(HallwayAmbientZones.ZONE_MUZAK),
		"Muzak zone should register in _ready"
	)
	assert_true(
		AudioManager._zone_players.has(HallwayAmbientZones.ZONE_MECHANICAL),
		"Mechanical zone should register in _ready"
	)
	assert_true(
		AudioManager._zone_players.has(HallwayAmbientZones.ZONE_CROWD),
		"Crowd zone should register in _ready"
	)
	assert_true(
		AudioManager._zone_players.has(HallwayAmbientZones.ZONE_FOOD_COURT),
		"Food court zone should register in _ready"
	)


func test_registered_zone_players_are_audio_stream_player_3d() -> void:
	assert_typeof(
		AudioManager._zone_players[HallwayAmbientZones.ZONE_MUZAK],
		TYPE_OBJECT,
		"Registered muzak zone should store an object"
	)
	assert_true(
		AudioManager._zone_players[HallwayAmbientZones.ZONE_MUZAK]
		is AudioStreamPlayer3D,
		"Muzak zone should use AudioStreamPlayer3D"
	)
	assert_true(
		AudioManager._zone_players[HallwayAmbientZones.ZONE_MECHANICAL]
		is AudioStreamPlayer3D,
		"Mechanical zone should use AudioStreamPlayer3D"
	)
	assert_true(
		AudioManager._zone_players[HallwayAmbientZones.ZONE_CROWD]
		is AudioStreamPlayer3D,
		"Crowd zone should use AudioStreamPlayer3D"
	)


func test_persistent_hallway_zones_play_on_load() -> void:
	assert_true(
		_zones._muzak_player.playing,
		"Hallway muzak should start looping when the hallway loads"
	)
	assert_true(
		_zones._mechanical_player.playing,
		"Mechanical ambience should start looping when the hallway loads"
	)
	assert_true(
		_zones._crowd_player.playing,
		"Crowd ambience should start looping when the hallway loads"
	)


func test_mechanical_zone_uses_ambience_bus_and_negative_18_db() -> void:
	assert_eq(
		_zones._mechanical_player.bus,
		AudioManager.AMBIENCE_BUS,
		"Mechanical ambience should route to the Ambience bus"
	)
	assert_almost_eq(
		_zones._mechanical_player.volume_db,
		-18.0,
		0.1,
		"Mechanical ambience should play at -18 dB"
	)


func test_crowd_volume_at_zero_shoppers() -> void:
	_customer_system._active_mall_shopper_count = 0
	_zones._update_crowd_volume()
	assert_almost_eq(
		_zones._crowd_player.volume_db,
		-20.0,
		0.1,
		"Crowd volume at 0 shoppers should be -20 dB"
	)


func test_crowd_volume_at_max_shoppers() -> void:
	_customer_system._active_mall_shopper_count = 15
	_zones._update_crowd_volume()
	assert_almost_eq(
		_zones._crowd_player.volume_db,
		-8.0,
		0.1,
		"Crowd volume at 15+ shoppers should be -8 dB"
	)


func test_crowd_volume_scales_linearly() -> void:
	_customer_system._active_mall_shopper_count = 8
	_zones._update_crowd_volume()
	var expected_db: float = lerpf(-20.0, -8.0, 8.0 / 15.0)
	assert_almost_eq(
		_zones._crowd_player.volume_db,
		expected_db,
		0.1,
		"Crowd volume should scale linearly with shopper count"
	)


func test_customer_left_signal_refreshes_crowd_volume() -> void:
	_customer_system._active_mall_shopper_count = 12
	_zones._update_crowd_volume()
	_customer_system._active_mall_shopper_count = 4
	EventBus.customer_left.emit({})
	await get_tree().process_frame
	var expected_db: float = lerpf(-20.0, -8.0, 4.0 / 15.0)
	assert_almost_eq(
		_zones._crowd_player.volume_db,
		expected_db,
		0.1,
		"customer_left should refresh crowd ambience from the current shopper count"
	)


func test_food_court_activates_during_midday_rush() -> void:
	_zones._on_day_phase_changed(TimeSystem.DayPhase.MIDDAY_RUSH)
	assert_true(
		_zones._food_court_active,
		"Food court should activate during lunch rush"
	)
	assert_true(
		_zones._food_court_player.playing,
		"Food court ambience should play during lunch rush"
	)


func test_food_court_deactivates_outside_midday_rush() -> void:
	_zones._on_day_phase_changed(TimeSystem.DayPhase.MIDDAY_RUSH)
	assert_true(_zones._food_court_active)
	_zones._on_day_phase_changed(TimeSystem.DayPhase.AFTERNOON)
	assert_false(
		_zones._food_court_active,
		"Food court should deactivate when the day phase changes away from lunch rush"
	)


func test_muzak_switches_to_christmas_in_november() -> void:
	_time_system.current_day = 301
	_zones._update_muzak_track()
	assert_true(
		_zones._using_christmas_muzak,
		"November should enable Christmas hallway muzak"
	)
	assert_eq(
		_zones._muzak_player.stream,
		_zones._muzak_christmas_stream,
		"Christmas muzak stream should be active in November"
	)


func test_muzak_uses_regular_track_outside_holidays() -> void:
	_time_system.current_day = 271
	_zones._update_muzak_track()
	assert_false(
		_zones._using_christmas_muzak,
		"October should keep the standard hallway muzak"
	)
	assert_eq(
		_zones._muzak_player.stream,
		_zones._muzak_stream,
		"Standard muzak stream should stay active outside November and December"
	)


func test_zones_unregister_on_exit_tree() -> void:
	var zones_node: HallwayAmbientZones = HallwayAmbientZones.new()
	var time_system: TimeSystem = TimeSystem.new()
	var customer_system: CustomerSystem = CustomerSystem.new()
	add_child(time_system)
	add_child(customer_system)
	zones_node.configure_runtime_dependencies(customer_system, time_system)
	add_child(zones_node)
	assert_true(
		AudioManager._zone_players.has(HallwayAmbientZones.ZONE_MUZAK),
		"Muzak zone should be registered before free()"
	)
	zones_node.free()
	time_system.free()
	customer_system.free()
	assert_false(
		AudioManager._zone_players.has(HallwayAmbientZones.ZONE_MUZAK),
		"Muzak zone should unregister in _exit_tree"
	)
