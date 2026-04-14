## Tests CustomerNavConfig position extraction from Marker3D children.
extends GutTest


var _config: CustomerNavConfig


func before_each() -> void:
	_config = CustomerNavConfig.new()
	add_child_autofree(_config)


func test_get_entry_position() -> void:
	var marker := Marker3D.new()
	marker.position = Vector3(1.0, 0.0, 2.5)
	_config.add_child(marker)
	_config.entry_point = marker
	assert_eq(
		_config.get_entry_position(),
		Vector3(1.0, 0.0, 2.5),
		"Should return entry_point position"
	)


func test_get_entry_position_warns_when_null() -> void:
	var pos: Vector3 = _config.get_entry_position()
	assert_eq(pos, Vector3.ZERO, "Should return ZERO when unassigned")


func test_get_browse_positions() -> void:
	var wp1 := Marker3D.new()
	wp1.position = Vector3(1.0, 0.0, 0.0)
	_config.add_child(wp1)
	var wp2 := Marker3D.new()
	wp2.position = Vector3(2.0, 0.0, -1.0)
	_config.add_child(wp2)
	_config.browse_waypoints = [wp1, wp2]
	var positions: Array[Vector3] = _config.get_browse_positions()
	assert_eq(positions.size(), 2)
	assert_eq(positions[0], Vector3(1.0, 0.0, 0.0))
	assert_eq(positions[1], Vector3(2.0, 0.0, -1.0))


func test_get_browse_positions_empty() -> void:
	var positions: Array[Vector3] = _config.get_browse_positions()
	assert_eq(positions.size(), 0)


func test_get_checkout_position() -> void:
	var marker := Marker3D.new()
	marker.position = Vector3(3.0, 0.0, 1.0)
	_config.add_child(marker)
	_config.checkout_approach = marker
	assert_eq(
		_config.get_checkout_position(),
		Vector3(3.0, 0.0, 1.0),
		"Should return checkout_approach position"
	)


func test_get_exit_position() -> void:
	var marker := Marker3D.new()
	marker.position = Vector3(0.0, 0.0, 5.0)
	_config.add_child(marker)
	_config.exit_point = marker
	assert_eq(
		_config.get_exit_position(),
		Vector3(0.0, 0.0, 5.0),
		"Should return exit_point position"
	)


func test_max_concurrent_customers_default() -> void:
	assert_eq(
		_config.max_concurrent_customers, 4,
		"Default should be 4"
	)
