## Verifies the composite Day-1 playable readiness audit that runs above
## StoreReadyContract: state-driven evaluation of the ten invariants, the
## signal-driven trigger off StoreDirector.store_ready, and the read-only
## guarantee that the check never mutates game state.
extends GutTest


const _STORE_ID: StringName = &"retro_games"


class FakeInventorySystem extends Node:
	var _backroom_count: int = 0

	func set_backroom_count(value: int) -> void:
		_backroom_count = value

	func get_backroom_items_for_store(_store_id: String) -> Array:
		var out: Array = []
		for i in range(_backroom_count):
			out.append({"id": "item_%d" % i})
		return out


class FakeShelfSlot extends Node:
	var _occupied: bool = false

	func _ready() -> void:
		add_to_group("shelf_slot")

	func set_occupied(value: bool) -> void:
		_occupied = value

	func is_available() -> bool:
		return not _occupied


class FakePlayerBody extends Node3D:
	func _ready() -> void:
		add_to_group("player")


var _saved_objective_payload: Dictionary = {}


func before_each() -> void:
	_saved_objective_payload = ObjectiveRail._current_payload.duplicate()
	AuditLog.clear()
	GameState.reset_new_game()
	InputFocus._reset_for_tests()
	CameraAuthority._reset_for_tests()
	ObjectiveRail._current_payload = {}


func after_each() -> void:
	AuditLog.clear()
	GameState.reset_new_game()
	InputFocus._reset_for_tests()
	CameraAuthority._reset_for_tests()
	ObjectiveRail._current_payload = _saved_objective_payload


# ── Helpers ───────────────────────────────────────────────────────────────────


func _setup_pass_state() -> Dictionary:
	GameState.set_active_store(_STORE_ID)
	InputFocus.push_context(InputFocus.CTX_STORE_GAMEPLAY)

	var player: FakePlayerBody = FakePlayerBody.new()
	player.name = "TestPlayer"
	add_child_autofree(player)

	var camera: Camera3D = Camera3D.new()
	add_child_autofree(camera)
	CameraAuthority.request_current(camera, &"player_fp")

	var fixture: Node3D = Node3D.new()
	fixture.name = "TestFixture"
	fixture.add_to_group("fixture")
	add_child_autofree(fixture)

	var slot: FakeShelfSlot = FakeShelfSlot.new()
	slot.name = "TestShelfSlot"
	add_child_autofree(slot)

	var inventory: FakeInventorySystem = FakeInventorySystem.new()
	inventory.name = "InventorySystem"
	inventory.set_backroom_count(3)
	add_child_autofree(inventory)

	EventBus.objective_changed.emit(
		{"text": "Stock the shelves", "action": "Open inventory"}
	)

	return {
		"player": player,
		"camera": camera,
		"fixture": fixture,
		"slot": slot,
		"inventory": inventory,
	}


# ── Pass path ────────────────────────────────────────────────────────────────


func test_evaluate_returns_empty_when_all_conditions_met() -> void:
	_setup_pass_state()
	var failure: Dictionary = Day1ReadinessAudit.evaluate_for_test(_STORE_ID)
	assert_true(
		failure.is_empty(),
		"All 10 conditions must pass on a clean Day-1 entry; got %s" % failure
	)


func test_store_ready_signal_records_pass_on_audit_log() -> void:
	_setup_pass_state()
	AuditLog.clear()
	StoreDirector.store_ready.emit(_STORE_ID)
	var entries: Array[Dictionary] = AuditLog.recent(16)
	var found: bool = false
	for entry: Dictionary in entries:
		if (
			entry.get("status") == "PASS"
			and entry.get("checkpoint") == &"day1_playable_ready"
		):
			found = true
			break
	assert_true(
		found,
		"StoreDirector.store_ready must trigger pass_check(&day1_playable_ready)"
	)


# ── Failure path: each condition reports first ───────────────────────────────


func test_fail_when_active_store_id_mismatches() -> void:
	_setup_pass_state()
	GameState.set_active_store(&"some_other_store")
	var failure: Dictionary = Day1ReadinessAudit.evaluate_for_test(_STORE_ID)
	assert_eq(
		failure.get("name"), "active_store_id",
		"active_store_id mismatch must be the first reported failure"
	)


func test_fail_when_no_player_node_in_scene() -> void:
	var fixtures: Dictionary = _setup_pass_state()
	(fixtures["player"] as FakePlayerBody).remove_from_group("player")
	var failure: Dictionary = Day1ReadinessAudit.evaluate_for_test(_STORE_ID)
	assert_eq(
		failure.get("name"), "player_spawned",
		"missing player-group node must surface player_spawned as the failure"
	)
	assert_eq(
		failure.get("value"), "0",
		"player_spawned failure must report the observed count of 0"
	)


func test_fail_when_camera_source_not_in_allowlist() -> void:
	_setup_pass_state()
	var foreign_cam: Camera3D = Camera3D.new()
	add_child_autofree(foreign_cam)
	CameraAuthority.request_current(foreign_cam, &"main_menu")
	var failure: Dictionary = Day1ReadinessAudit.evaluate_for_test(_STORE_ID)
	assert_eq(
		failure.get("name"), "camera_source",
		"camera_source outside the allowlist must surface as the failure"
	)


func test_camera_source_allowlist_accepts_player_fp() -> void:
	_setup_pass_state()
	# _setup_pass_state already activates the camera with source=&"player_fp",
	# so a clean run must not trip the camera_source check.
	var failure: Dictionary = Day1ReadinessAudit.evaluate_for_test(_STORE_ID)
	assert_true(
		failure.is_empty(),
		"&\"player_fp\" must be in _ALLOWED_CAMERA_SOURCES; got %s" % failure
	)


func test_fail_when_viewport_has_no_current_camera() -> void:
	var fixtures: Dictionary = _setup_pass_state()
	# CameraAuthority still reports source=&"player_fp", but the viewport's
	# active Camera3D becomes null once the camera is cleared. This catches
	# the gap where the source label is correct but rendering is broken.
	var camera: Camera3D = fixtures["camera"] as Camera3D
	camera.clear_current()
	var failure: Dictionary = Day1ReadinessAudit.evaluate_for_test(_STORE_ID)
	assert_eq(
		failure.get("name"), "camera_current",
		"a null viewport camera must surface camera_current as the failure"
	)
	assert_eq(
		failure.get("value"), "null",
		"camera_current failure must report the observed value of null"
	)


func test_fail_when_input_focus_not_store_gameplay() -> void:
	_setup_pass_state()
	InputFocus._reset_for_tests()
	InputFocus.push_context(InputFocus.CTX_MAIN_MENU)
	var failure: Dictionary = Day1ReadinessAudit.evaluate_for_test(_STORE_ID)
	assert_eq(
		failure.get("name"), "input_focus",
		"non-gameplay input context must be the reported failure"
	)


func test_fail_when_no_stockable_shelf_slot() -> void:
	var fixtures: Dictionary = _setup_pass_state()
	(fixtures["slot"] as FakeShelfSlot).set_occupied(true)
	var failure: Dictionary = Day1ReadinessAudit.evaluate_for_test(_STORE_ID)
	assert_eq(
		failure.get("name"), "stockable_shelf_slots",
		"a fully-occupied scene must report no stockable slots"
	)


func test_fail_when_backroom_empty() -> void:
	var fixtures: Dictionary = _setup_pass_state()
	(fixtures["inventory"] as FakeInventorySystem).set_backroom_count(0)
	var failure: Dictionary = Day1ReadinessAudit.evaluate_for_test(_STORE_ID)
	assert_eq(
		failure.get("name"), "backroom_count",
		"an empty backroom must surface backroom_count as the failure"
	)


func test_fail_when_first_sale_already_complete() -> void:
	_setup_pass_state()
	GameState.set_flag(&"first_sale_complete", true)
	var failure: Dictionary = Day1ReadinessAudit.evaluate_for_test(_STORE_ID)
	assert_eq(
		failure.get("name"), "first_sale_complete",
		"a sale already recorded must surface first_sale_complete as failure"
	)


func test_fail_when_no_active_objective() -> void:
	_setup_pass_state()
	ObjectiveRail._current_payload = {}
	var failure: Dictionary = Day1ReadinessAudit.evaluate_for_test(_STORE_ID)
	assert_eq(
		failure.get("name"), "objective_active",
		"missing objective must surface objective_active as failure"
	)


func test_store_ready_signal_records_failure_when_unprepared() -> void:
	# No setup — most conditions miss. The first failing condition is
	# active_store_id (GameState was reset and is empty).
	AuditLog.clear()
	StoreDirector.store_ready.emit(_STORE_ID)
	var entries: Array[Dictionary] = AuditLog.recent(16)
	var matched: Dictionary = {}
	for entry: Dictionary in entries:
		if (
			entry.get("status") == "FAIL"
			and entry.get("checkpoint") == &"day1_playable_failed"
		):
			matched = entry
			break
	assert_false(
		matched.is_empty(),
		"StoreDirector.store_ready must record day1_playable_failed when state misses"
	)
	assert_string_contains(
		String(matched.get("reason", "")), "active_store_id",
		"failure reason must name the first failing condition"
	)


# ── Read-only guarantee ──────────────────────────────────────────────────────


func test_evaluation_does_not_mutate_game_state() -> void:
	_setup_pass_state()
	var before_active: StringName = GameState.active_store_id
	var before_money: int = GameState.money
	var before_day: int = GameState.day
	var before_focus_depth: int = InputFocus.depth()
	var before_focus_top: StringName = InputFocus.current()
	var before_camera_source: StringName = CameraAuthority.current_source()
	var before_flags: Dictionary = GameState.flags.duplicate(true)

	Day1ReadinessAudit.evaluate_for_test(_STORE_ID)

	assert_eq(GameState.active_store_id, before_active,
		"evaluate must not change active_store_id")
	assert_eq(GameState.money, before_money,
		"evaluate must not change money")
	assert_eq(GameState.day, before_day,
		"evaluate must not change day")
	assert_eq(InputFocus.depth(), before_focus_depth,
		"evaluate must not change InputFocus stack depth")
	assert_eq(InputFocus.current(), before_focus_top,
		"evaluate must not change InputFocus top context")
	assert_eq(CameraAuthority.current_source(), before_camera_source,
		"evaluate must not change CameraAuthority source")
	assert_eq(GameState.flags, before_flags,
		"evaluate must not change game flags")
