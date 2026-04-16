## Tests Storefront scene: geometry, sign, entry zone, and state transitions.
extends GutTest


var _storefront: Storefront
var _zone_entered_ids: Array[String] = []
var _zone_exited_ids: Array[String] = []
var _door_interacted_count: int = 0


func before_each() -> void:
	_zone_entered_ids.clear()
	_zone_exited_ids.clear()
	_door_interacted_count = 0

	_storefront = Storefront.new()
	_storefront.slot_index = 0
	_storefront.door_interacted.connect(_on_door_interacted)
	EventBus.storefront_zone_entered.connect(_on_zone_entered)
	EventBus.storefront_zone_exited.connect(_on_zone_exited)
	add_child_autofree(_storefront)


func after_each() -> void:
	if EventBus.storefront_zone_entered.is_connected(_on_zone_entered):
		EventBus.storefront_zone_entered.disconnect(_on_zone_entered)
	if EventBus.storefront_zone_exited.is_connected(_on_zone_exited):
		EventBus.storefront_zone_exited.disconnect(_on_zone_exited)


func _on_zone_entered(sid: String) -> void:
	_zone_entered_ids.append(sid)


func _on_zone_exited(sid: String) -> void:
	_zone_exited_ids.append(sid)


func _on_door_interacted(_sf: Storefront) -> void:
	_door_interacted_count += 1


func test_has_facade_static_body() -> void:
	var facade: StaticBody3D = _storefront.find_child(
		"FacadeBody", true, false
	) as StaticBody3D
	assert_not_null(facade, "FacadeBody StaticBody3D exists")

	var col_count: Array = [0]
	for child: Node in facade.get_children():
		if child is CollisionShape3D:
			col_count[0] += 1
	assert_gt(col_count[0], 0, "FacadeBody has CollisionShape3D children")


func test_has_sign_label() -> void:
	var label: Label3D = _storefront.find_child(
		"SignLabel", true, false
	) as Label3D
	assert_not_null(label, "SignLabel Label3D exists")


func test_has_entry_zone() -> void:
	var zone: Area3D = _storefront.find_child(
		"EntryZone", true, false
	) as Area3D
	assert_not_null(zone, "EntryZone Area3D exists")
	assert_true(zone.monitoring, "EntryZone is monitoring")

	var has_col: Array = [false]
	for child: Node in zone.get_children():
		if child is CollisionShape3D:
			has_col[0] = true
	assert_true(has_col[0], "EntryZone has a CollisionShape3D")


func test_has_door_body() -> void:
	var door: StaticBody3D = _storefront.find_child(
		"DoorBody", true, false
	) as StaticBody3D
	assert_not_null(door, "DoorBody StaticBody3D exists")


func test_sign_displays_store_name_when_owned() -> void:
	_storefront.set_owned("retro_games", "Retro Games")
	var label: Label3D = _storefront.find_child(
		"SignLabel", true, false
	) as Label3D
	assert_eq(label.text, "Retro Games")


func test_sign_shows_lease_when_available() -> void:
	_storefront.set_available(100.0)
	var label: Label3D = _storefront.find_child(
		"SignLabel", true, false
	) as Label3D
	assert_eq(label.text, "For Lease — $100/day")


func test_sign_shows_coming_soon_when_locked() -> void:
	_storefront.set_locked()
	var label: Label3D = _storefront.find_child(
		"SignLabel", true, false
	) as Label3D
	assert_eq(label.text, "Coming Soon")


func test_sign_shows_renovation() -> void:
	_storefront.set_renovation()
	var label: Label3D = _storefront.find_child(
		"SignLabel", true, false
	) as Label3D
	assert_eq(label.text, "Under Renovation")


func test_owned_sign_brighter_than_unowned() -> void:
	_storefront.set_available(50.0)
	var label: Label3D = _storefront.find_child(
		"SignLabel", true, false
	) as Label3D
	var unowned_brightness: float = label.modulate.get_luminance()

	_storefront.set_owned("test_store", "Test Store")
	var owned_brightness: float = label.modulate.get_luminance()

	assert_gt(
		owned_brightness,
		unowned_brightness,
		"Owned sign is brighter than unowned"
	)


func test_locked_sign_dimmer_than_available() -> void:
	_storefront.set_available(50.0)
	var label: Label3D = _storefront.find_child(
		"SignLabel", true, false
	) as Label3D
	var available_brightness: float = label.modulate.get_luminance()

	_storefront.set_locked()
	var locked_brightness: float = label.modulate.get_luminance()

	assert_lt(
		locked_brightness,
		available_brightness,
		"Locked sign is dimmer than available"
	)


func test_store_name_export_updates_sign() -> void:
	_storefront.is_owned = true
	_storefront.store_name = "Custom Name"
	var label: Label3D = _storefront.find_child(
		"SignLabel", true, false
	) as Label3D
	assert_eq(label.text, "Custom Name")


func test_set_owned_sets_store_name() -> void:
	_storefront.set_owned("video_rental", "Video Rental")
	assert_eq(_storefront.store_name, "Video Rental")
	assert_eq(_storefront.store_id, "video_rental")
	assert_true(_storefront.is_owned)


func test_entry_zone_ignores_non_player_body() -> void:
	_storefront.set_owned("test", "Test")
	_storefront._on_entry_zone_body_entered(Node3D.new())
	assert_eq(
		_zone_entered_ids.size(), 0,
		"Non-player body does not trigger zone entered"
	)


func test_entry_zone_ignores_empty_store_id() -> void:
	_storefront.set_available(50.0)
	var body := CharacterBody3D.new()
	body.add_to_group("player")
	add_child_autofree(body)
	_storefront._on_entry_zone_body_entered(body)
	assert_eq(
		_zone_entered_ids.size(), 0,
		"Empty store_id does not trigger zone entered"
	)


func test_entry_zone_emits_for_player() -> void:
	_storefront.set_owned("retro_games", "Retro Games")
	var body := CharacterBody3D.new()
	body.add_to_group("player")
	add_child_autofree(body)

	_storefront._on_entry_zone_body_entered(body)
	assert_eq(_zone_entered_ids.size(), 1)
	assert_eq(_zone_entered_ids[0], "retro_games")

	_storefront._on_entry_zone_body_exited(body)
	assert_eq(_zone_exited_ids.size(), 1)
	assert_eq(_zone_exited_ids[0], "retro_games")


func test_multiple_instances_no_conflicts() -> void:
	var second := Storefront.new()
	second.slot_index = 1
	add_child_autofree(second)

	second.set_owned("video_rental", "Video Rental")
	_storefront.set_owned("retro_games", "Retro Games")

	var label_a: Label3D = _storefront.find_child(
		"SignLabel", true, false
	) as Label3D
	var label_b: Label3D = second.find_child(
		"SignLabel", true, false
	) as Label3D

	assert_eq(label_a.text, "Retro Games")
	assert_eq(label_b.text, "Video Rental")


# ── Status Sign Tests ────────────────────────────────────────────────────────

func test_status_sign_exists() -> void:
	var label: Label3D = _storefront.find_child(
		"StatusSign", true, false
	) as Label3D
	assert_not_null(label, "StatusSign Label3D exists")


func test_lease_marker_exists() -> void:
	var marker: MeshInstance3D = _storefront.find_child(
		"LeaseMarker", true, false
	) as MeshInstance3D
	assert_not_null(marker, "LeaseMarker MeshInstance3D exists")


func test_status_sign_shows_for_lease_when_available() -> void:
	_storefront.set_available(100.0)
	var label: Label3D = _storefront.find_child(
		"StatusSign", true, false
	) as Label3D
	assert_eq(label.text, "FOR LEASE")
	assert_true(label.visible, "FOR LEASE label is visible")


func test_locked_lease_marker_uses_locked_material() -> void:
	_storefront.set_locked()
	assert_eq(
		_storefront.get_lease_marker_state(),
		&"locked",
		"Locked storefront should use the locked lease marker material"
	)


func test_available_lease_marker_uses_available_material() -> void:
	_storefront.set_available(100.0)
	assert_eq(
		_storefront.get_lease_marker_state(),
		&"available",
		"Available storefront should use the available lease marker material"
	)


func test_owned_storefront_hides_lease_marker() -> void:
	_storefront.set_owned("retro_games", "Retro Games")
	var marker: MeshInstance3D = _storefront.find_child(
		"LeaseMarker", true, false
	) as MeshInstance3D
	assert_false(marker.visible, "Owned storefront should hide the lease marker")


func test_status_sign_yellow_when_for_lease() -> void:
	_storefront.set_available(100.0)
	var label: Label3D = _storefront.find_child(
		"StatusSign", true, false
	) as Label3D
	assert_gt(label.modulate.r, 0.5, "FOR LEASE has yellow-ish red channel")
	assert_gt(label.modulate.g, 0.5, "FOR LEASE has yellow-ish green channel")
	assert_lt(label.modulate.b, 0.5, "FOR LEASE has low blue channel")


func test_status_sign_closed_when_owned_default() -> void:
	_storefront.set_owned("retro_games", "Retro Games")
	var label: Label3D = _storefront.find_child(
		"StatusSign", true, false
	) as Label3D
	assert_eq(label.text, "CLOSED")


func test_status_sign_red_when_closed() -> void:
	_storefront.set_owned("retro_games", "Retro Games")
	var label: Label3D = _storefront.find_child(
		"StatusSign", true, false
	) as Label3D
	assert_gt(label.modulate.r, 0.5, "CLOSED has high red")
	assert_lt(label.modulate.g, 0.5, "CLOSED has low green")


func test_status_sign_open_on_store_opened_signal() -> void:
	_storefront.set_owned("retro_games", "Retro Games")
	EventBus.store_opened.emit("retro_games")
	var label: Label3D = _storefront.find_child(
		"StatusSign", true, false
	) as Label3D
	assert_eq(label.text, "OPEN")


func test_status_sign_green_when_open() -> void:
	_storefront.set_owned("retro_games", "Retro Games")
	EventBus.store_opened.emit("retro_games")
	var label: Label3D = _storefront.find_child(
		"StatusSign", true, false
	) as Label3D
	assert_gt(label.modulate.g, 0.5, "OPEN has high green")
	assert_lt(label.modulate.r, 0.5, "OPEN has low red")


func test_status_sign_closed_on_store_closed_signal() -> void:
	_storefront.set_owned("retro_games", "Retro Games")
	EventBus.store_opened.emit("retro_games")
	EventBus.store_closed.emit("retro_games")
	var label: Label3D = _storefront.find_child(
		"StatusSign", true, false
	) as Label3D
	assert_eq(label.text, "CLOSED")


func test_status_sign_ignores_other_store_signals() -> void:
	_storefront.set_owned("retro_games", "Retro Games")
	EventBus.store_opened.emit("video_rental")
	var label: Label3D = _storefront.find_child(
		"StatusSign", true, false
	) as Label3D
	assert_eq(label.text, "CLOSED")


func test_status_sign_hidden_when_locked() -> void:
	_storefront.set_locked()
	var label: Label3D = _storefront.find_child(
		"StatusSign", true, false
	) as Label3D
	assert_false(label.visible, "Status sign hidden for locked storefront")


func test_status_sign_hidden_when_renovation() -> void:
	_storefront.set_renovation()
	var label: Label3D = _storefront.find_child(
		"StatusSign", true, false
	) as Label3D
	assert_false(label.visible, "Status sign hidden for renovation")


func test_status_sign_updates_on_hour_changed() -> void:
	_storefront.set_owned("retro_games", "Retro Games")
	EventBus.hour_changed.emit(Constants.STORE_OPEN_HOUR)
	var label: Label3D = _storefront.find_child(
		"StatusSign", true, false
	) as Label3D
	assert_eq(label.text, "OPEN")

	EventBus.hour_changed.emit(Constants.STORE_CLOSE_HOUR)
	assert_eq(label.text, "CLOSED")
