## Tests for the `BetaHUD` autoload — the session-level owner of the
## persistent beta HUD panels (right panel + event log).
##
## Covers the ownership / lifetime contract:
##   - `BetaHUD._ready` spawns one `BetaRightPanel` and one
##     `BetaEventLogPanel` as direct children; they live for the whole
##     process.
##   - `activate(day)` / `deactivate()` toggle visibility and
##     `is_active()` together as a session-level pair.
##   - `activate(day)` reseeds the right panel from the current
##     `BetaRunState.day` and the active controller's `_objectives` for
##     passive milestones — idempotent across repeated calls.
##   - `BetaHUD` does **not** subscribe to `EventBus.fp_mode_changed`; its
##     own session state is independent of FP mode.
extends GutTest


## Lightweight stand-in for `BetaDayOneController` so the panel's
## controller-group lookup in `seed_for_day` finds a node carrying an
## `_objectives` array without dragging the full beta scene into the test.
const _FAKE_CONTROLLER: GDScript = preload(
	"res://tests/gut/_fixtures/beta_controller_stub.gd"
)


const _OBJECTIVES_DAY_1: Array[Dictionary] = [
	{
		"id": "talk_to_customer",
		"stage": "talk_to_customer",
		"label": "Day 1: Help the customer at the register.",
		"action": "Talk to the customer",
		"key": "E",
		"target_path": "BetaDayOneCustomer/Interactable",
		"time_cost_minutes": 30,
		"required": true,
	},
	{
		"id": "back_room_inventory",
		"stage": "back_room_inventory",
		"label": "Day 1: Check today's back room stock.",
		"action": "Check inventory",
		"key": "E",
		"target_path": "BetaBackroomPickup/Interactable",
		"time_cost_minutes": 30,
		"required": true,
	},
	{
		"id": "stock_shelf",
		"stage": "stock_shelf",
		"label": "Day 1: Put a few items on the used games shelf.",
		"action": "Stock the shelf",
		"key": "E",
		"target_path": "BetaRestockShelf/Interactable",
		"time_cost_minutes": 60,
		"required": true,
	},
]


func before_each() -> void:
	InputFocus._reset_for_tests()
	BetaRunState.reset_new_run()
	# Start every test from the "no session active" baseline. The autoload
	# persists across tests, so a previous test that called `activate` would
	# otherwise leak `_active = true` into the next case.
	BetaHUD.deactivate()


func _install_stub_controller(
	objectives: Array[Dictionary] = _OBJECTIVES_DAY_1
) -> Node:
	var stub: Node = _FAKE_CONTROLLER.new()
	stub.set("_objectives", objectives.duplicate())
	stub.add_to_group("beta_day_one_controller")
	add_child_autofree(stub)
	return stub


# ── autoload presence ─────────────────────────────────────────────────────────

func test_autoload_is_registered_and_owns_both_panels() -> void:
	assert_not_null(
		BetaHUD,
		"BetaHUD must be registered as an autoload (project.godot)"
	)
	assert_not_null(
		BetaHUD.get_right_panel(),
		"BetaHUD must own a BetaRightPanel child"
	)
	assert_not_null(
		BetaHUD.get_event_log_panel(),
		"BetaHUD must own a BetaEventLogPanel child"
	)


func test_panels_are_direct_children_of_betahud() -> void:
	var right: BetaRightPanel = BetaHUD.get_right_panel()
	var log: BetaEventLogPanel = BetaHUD.get_event_log_panel()
	assert_eq(
		right.get_parent(), BetaHUD,
		"BetaRightPanel must be a direct child of the BetaHUD autoload"
	)
	assert_eq(
		log.get_parent(), BetaHUD,
		"BetaEventLogPanel must be a direct child of the BetaHUD autoload"
	)


# ── activate / deactivate session contract ────────────────────────────────────

func test_activate_marks_session_active_and_shows_panels() -> void:
	_install_stub_controller()
	BetaHUD.activate(BetaRunState.day)
	assert_true(
		BetaHUD.is_active(),
		"is_active() must return true after activate()"
	)
	assert_true(
		BetaHUD.get_right_panel().visible,
		"Right panel must be visible after activate()"
	)
	assert_true(
		BetaHUD.get_event_log_panel().visible,
		"Event log panel must be visible after activate()"
	)


func test_deactivate_marks_session_inactive_and_hides_panels() -> void:
	_install_stub_controller()
	BetaHUD.activate(BetaRunState.day)
	BetaHUD.deactivate()
	assert_false(
		BetaHUD.is_active(),
		"is_active() must return false after deactivate()"
	)
	assert_false(
		BetaHUD.get_right_panel().visible,
		"Right panel must hide after deactivate()"
	)
	assert_false(
		BetaHUD.get_event_log_panel().visible,
		"Event log panel must hide after deactivate()"
	)


# ── seed_for_day / activate-after-day-started safety ─────────────────────────

func test_activate_seeds_right_panel_header_from_day_argument() -> void:
	_install_stub_controller()
	BetaRunState.day = 2
	BetaHUD.activate(2)
	assert_true(
		BetaHUD.get_right_panel().get_header_text().begins_with("DAY 2 —"),
		"Right panel header must reflect the activate(day) argument; got '%s'"
		% BetaHUD.get_right_panel().get_header_text()
	)


func test_activate_seeds_objectives_from_active_controller() -> void:
	_install_stub_controller()
	BetaHUD.activate(BetaRunState.day)
	assert_eq(
		BetaHUD.get_right_panel().get_visible_item_count(),
		_OBJECTIVES_DAY_1.size(),
		"seed_for_day must rebuild milestones from the active controller"
	)
	var first_id: StringName = StringName(
		str(_OBJECTIVES_DAY_1[0].get("id", ""))
	)
	assert_eq(
		BetaHUD.get_right_panel().get_item_glyph(first_id), "•",
		"Seeded milestone must paint as pending"
	)


func test_activate_after_day_started_already_fired_still_shows_day_n() -> void:
	# AC: the day-transition scenario. Day 2's `day_started` fires inside
	# the controller's `_reset_scene_for_day` BEFORE the new controller's
	# `_ready` calls `BetaHUD.activate(2)`. activate must force-seed so the
	# right panel still ends up on Day 2.
	_install_stub_controller()
	BetaRunState.day = 2
	EventBus.day_started.emit(2)
	await get_tree().process_frame
	BetaHUD.activate(2)
	assert_true(
		BetaHUD.get_right_panel().get_header_text().begins_with("DAY 2 —"),
		(
			"activate(2) must force-seed the right panel to Day 2 even "
			+ "when day_started already fired; got '%s'"
		) % BetaHUD.get_right_panel().get_header_text()
	)
	assert_eq(
		BetaHUD.get_right_panel().get_visible_item_count(),
		_OBJECTIVES_DAY_1.size(),
		"activate-after-day_started must still rebuild the milestone rows"
	)


func test_seed_for_day_is_idempotent() -> void:
	# Calling activate twice in a row must leave the panel in the same
	# rendered state: same header, same row count, same pending row.
	_install_stub_controller()
	BetaHUD.activate(1)
	var header_after_first: String = BetaHUD.get_right_panel().get_header_text()
	var count_after_first: int = BetaHUD.get_right_panel().get_visible_item_count()
	var first_id: StringName = StringName(
		str(_OBJECTIVES_DAY_1[0].get("id", ""))
	)
	var glyph_after_first: String = BetaHUD.get_right_panel().get_item_glyph(
		first_id
	)
	BetaHUD.activate(1)
	assert_eq(
		BetaHUD.get_right_panel().get_header_text(), header_after_first,
		"Repeated activate(1) must produce the same header text"
	)
	assert_eq(
		BetaHUD.get_right_panel().get_visible_item_count(), count_after_first,
		"Repeated activate(1) must produce the same row count"
	)
	assert_eq(
		BetaHUD.get_right_panel().get_item_glyph(first_id), glyph_after_first,
		"Repeated activate(1) must leave the milestone in the same state"
	)


# ── FP-mode independence ──────────────────────────────────────────────────────

func test_betahud_does_not_connect_fp_mode_changed() -> void:
	# Scope clarification on the issue: BetaHUD must NOT subscribe to
	# `EventBus.fp_mode_changed`. Inspect the signal's connection list and
	# assert no entry targets the autoload instance.
	var connections: Array = EventBus.fp_mode_changed.get_connections()
	for entry: Dictionary in connections:
		var callable: Callable = entry.get("callable") as Callable
		assert_ne(
			callable.get_object(), BetaHUD,
			(
				"BetaHUD must not connect to EventBus.fp_mode_changed; "
				+ "found '%s' bound to the autoload"
			) % callable.get_method()
		)


func test_fp_toggle_does_not_change_betahud_active_state() -> void:
	_install_stub_controller()
	BetaHUD.activate(BetaRunState.day)
	EventBus.fp_mode_changed.emit(true)
	await get_tree().process_frame
	assert_true(
		BetaHUD.is_active(),
		"BetaHUD.is_active() must remain true through an FP-mode toggle"
	)
	EventBus.fp_mode_changed.emit(false)
	await get_tree().process_frame
	assert_true(
		BetaHUD.is_active(),
		"BetaHUD.is_active() must remain true after FP mode exits"
	)


# ── persistence across day-controller teardown ────────────────────────────────

func test_panels_survive_stub_controller_teardown() -> void:
	# Simulates the day-transition scenario: a `BetaDayOneController`-shaped
	# node enters the tree, the autoload activates, the controller is freed,
	# and the panels are still alive and parented to BetaHUD.
	var stub: Node = _install_stub_controller()
	BetaHUD.activate(BetaRunState.day)
	var right_before: BetaRightPanel = BetaHUD.get_right_panel()
	var log_before: BetaEventLogPanel = BetaHUD.get_event_log_panel()
	stub.queue_free()
	await get_tree().process_frame
	assert_true(
		is_instance_valid(right_before),
		"BetaRightPanel must outlive the day controller"
	)
	assert_true(
		is_instance_valid(log_before),
		"BetaEventLogPanel must outlive the day controller"
	)
	assert_eq(
		right_before.get_parent(), BetaHUD,
		"BetaRightPanel must remain parented to BetaHUD after controller teardown"
	)
