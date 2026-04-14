## Unit tests for HallwayAmbientZones zone setup, volume scaling, and phase activation.
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
	add_child_autofree(_zones)
	_zones.initialize(_customer_system, _time_system)


func test_all_zones_registered_with_audio_manager() -> void:
	var muzak: String = HallwayAmbientZones.ZONE_MUZAK
	var mech: String = HallwayAmbientZones.ZONE_MECHANICAL
	var crowd: String = HallwayAmbientZones.ZONE_CROWD
	var food: String = HallwayAmbientZones.ZONE_FOOD_COURT
	assert_true(
		AudioManager._zone_players.has(muzak),
		"Muzak zone should be registered"
	)
	assert_true(
		AudioManager._zone_players.has(mech),
		"Mechanical zone should be registered"
	)
	assert_true(
		AudioManager._zone_players.has(crowd),
		"Crowd zone should be registered"
	)
	assert_true(
		AudioManager._zone_players.has(food),
		"Food court zone should be registered"
	)


func test_mechanical_volume_is_negative_18_db() -> void:
	var player: AudioStreamPlayer = AudioManager._zone_players.get(
		HallwayAmbientZones.ZONE_MECHANICAL
	)
	assert_not_null(player, "Mechanical player should exist")
	assert_almost_eq(
		player.volume_db, -18.0, 0.1,
		"Mechanical volume should be -18 dB"
	)


func test_crowd_volume_at_zero_shoppers() -> void:
	_customer_system._active_mall_shopper_count = 0
	_zones._update_crowd_volume()
	var player: AudioStreamPlayer = AudioManager._zone_players.get(
		HallwayAmbientZones.ZONE_CROWD
	)
	assert_not_null(player, "Crowd player should exist")
	assert_almost_eq(
		player.volume_db, -20.0, 0.1,
		"Crowd volume at 0 shoppers should be -20 dB"
	)


func test_crowd_volume_at_max_shoppers() -> void:
	_customer_system._active_mall_shopper_count = 15
	_zones._update_crowd_volume()
	var player: AudioStreamPlayer = AudioManager._zone_players.get(
		HallwayAmbientZones.ZONE_CROWD
	)
	assert_not_null(player, "Crowd player should exist")
	assert_almost_eq(
		player.volume_db, -8.0, 0.1,
		"Crowd volume at 15+ shoppers should be -8 dB"
	)


func test_crowd_volume_scales_linearly() -> void:
	_customer_system._active_mall_shopper_count = 8
	_zones._update_crowd_volume()
	var player: AudioStreamPlayer = AudioManager._zone_players.get(
		HallwayAmbientZones.ZONE_CROWD
	)
	var expected_db: float = lerpf(-20.0, -8.0, 8.0 / 15.0)
	assert_almost_eq(
		player.volume_db, expected_db, 0.1,
		"Crowd volume should scale linearly with shopper count"
	)


func test_crowd_volume_clamps_above_max() -> void:
	_customer_system._active_mall_shopper_count = 30
	_zones._update_crowd_volume()
	var player: AudioStreamPlayer = AudioManager._zone_players.get(
		HallwayAmbientZones.ZONE_CROWD
	)
	assert_almost_eq(
		player.volume_db, -8.0, 0.1,
		"Crowd volume should clamp at -8 dB for counts above 15"
	)


func test_food_court_activates_during_midday_rush() -> void:
	_zones._on_day_phase_changed(TimeSystem.DayPhase.MIDDAY_RUSH)
	assert_true(
		_zones._food_court_active,
		"Food court should be active during MIDDAY_RUSH"
	)


func test_food_court_deactivates_outside_midday_rush() -> void:
	_zones._on_day_phase_changed(TimeSystem.DayPhase.MIDDAY_RUSH)
	assert_true(_zones._food_court_active)
	_zones._on_day_phase_changed(TimeSystem.DayPhase.AFTERNOON)
	assert_false(
		_zones._food_court_active,
		"Food court should deactivate when phase changes away"
	)


func test_food_court_inactive_during_morning() -> void:
	_zones._on_day_phase_changed(TimeSystem.DayPhase.MORNING_RAMP)
	assert_false(
		_zones._food_court_active,
		"Food court should not be active during MORNING_RAMP"
	)


func test_muzak_uses_christmas_in_november() -> void:
	_time_system.current_day = 301
	var month: int = _time_system.get_current_month()
	assert_eq(month, 11, "Day 301 should be November")
	_zones._update_muzak_track()
	assert_true(
		_zones._using_christmas_muzak,
		"Should use Christmas muzak in November"
	)


func test_muzak_uses_christmas_in_december() -> void:
	_time_system.current_day = 331
	var month: int = _time_system.get_current_month()
	assert_eq(month, 12, "Day 331 should be December")
	_zones._update_muzak_track()
	assert_true(
		_zones._using_christmas_muzak,
		"Should use Christmas muzak in December"
	)


func test_muzak_uses_regular_in_october() -> void:
	_time_system.current_day = 271
	var month: int = _time_system.get_current_month()
	assert_eq(month, 10, "Day 271 should be October")
	_zones._update_muzak_track()
	assert_false(
		_zones._using_christmas_muzak,
		"Should use regular muzak in October"
	)


func test_time_system_month_cycles() -> void:
	_time_system.current_day = 1
	assert_eq(_time_system.get_current_month(), 1, "Day 1 = January")
	_time_system.current_day = 30
	assert_eq(_time_system.get_current_month(), 1, "Day 30 = January")
	_time_system.current_day = 31
	assert_eq(_time_system.get_current_month(), 2, "Day 31 = February")
	_time_system.current_day = 360
	assert_eq(_time_system.get_current_month(), 12, "Day 360 = December")
	_time_system.current_day = 361
	assert_eq(
		_time_system.get_current_month(), 1,
		"Day 361 = January (wraps)"
	)


func test_zones_unregister_on_exit_tree() -> void:
	var zones_node: HallwayAmbientZones = HallwayAmbientZones.new()
	add_child(zones_node)

	var ts: TimeSystem = TimeSystem.new()
	add_child(ts)
	ts.initialize()

	var cs: CustomerSystem = CustomerSystem.new()
	add_child(cs)

	zones_node.initialize(cs, ts)
	assert_true(
		AudioManager._zone_players.has(
			HallwayAmbientZones.ZONE_MUZAK
		)
	)

	remove_child(zones_node)
	zones_node.queue_free()
	ts.queue_free()
	cs.queue_free()
