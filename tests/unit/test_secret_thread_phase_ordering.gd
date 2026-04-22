## GUT unit tests for SecretThreadSystem phase-ordering validation,
## thread_resolved signal emission, and passive-player safety.
extends GutTest


var _system: SecretThreadSystem


func before_each() -> void:
	_system = SecretThreadSystem.new()
	add_child_autofree(_system)


# ── _validate_phase_ordering ──────────────────────────────────────────────────


func test_valid_phases_two_signals_before_substrate() -> void:
	var def: Dictionary = {
		"id": "valid_thread",
		"phases": [
			{"type": "surface"},
			{"type": "signal"},
			{"type": "signal"},
			{"type": "substrate"},
		],
	}
	var err: String = _system._validate_phase_ordering(def)
	assert_eq(err, "", "Two signal phases before substrate should pass")


func test_valid_phases_more_than_two_signals() -> void:
	var def: Dictionary = {
		"id": "many_signals",
		"phases": [
			{"type": "surface"},
			{"type": "signal"},
			{"type": "signal"},
			{"type": "signal"},
			{"type": "substrate"},
		],
	}
	assert_eq(_system._validate_phase_ordering(def), "")


func test_invalid_zero_signals_before_substrate() -> void:
	var def: Dictionary = {
		"id": "no_signals",
		"phases": [
			{"type": "surface"},
			{"type": "substrate"},
		],
	}
	var err: String = _system._validate_phase_ordering(def)
	assert_ne(err, "", "Zero signal phases before substrate must be an error")


func test_invalid_one_signal_before_substrate() -> void:
	var def: Dictionary = {
		"id": "one_signal",
		"phases": [
			{"type": "surface"},
			{"type": "signal"},
			{"type": "substrate"},
		],
	}
	var err: String = _system._validate_phase_ordering(def)
	assert_ne(err, "", "One signal phase before substrate must be an error")


func test_no_phases_key_skips_validation() -> void:
	var def: Dictionary = {
		"id": "legacy_no_phases",
		"steps": [],
	}
	assert_eq(_system._validate_phase_ordering(def), "",
		"Thread without 'phases' key must skip validation")


func test_no_substrate_phase_is_valid() -> void:
	var def: Dictionary = {
		"id": "no_substrate",
		"phases": [
			{"type": "surface"},
			{"type": "signal"},
		],
	}
	assert_eq(_system._validate_phase_ordering(def), "")


func test_all_json_threads_pass_phase_ordering() -> void:
	var file: FileAccess = FileAccess.open(
		"res://game/content/meta/secret_threads.json", FileAccess.READ
	)
	if not file:
		pass_test("secret_threads.json not found — skipping")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is not Array:
		fail_test("secret_threads.json must be a JSON array")
		return
	for entry: Variant in (parsed as Array):
		if entry is not Dictionary:
			continue
		var err: String = _system._validate_phase_ordering(entry as Dictionary)
		assert_eq(
			err, "",
			"Thread '%s' failed phase ordering: %s" % [
				str((entry as Dictionary).get("id", "?")), err
			]
		)


# ── thread_resolved emission ──────────────────────────────────────────────────


func _make_simple_def(override: Dictionary = {}) -> Dictionary:
	var base: Dictionary = {
		"id": "simple_resolve",
		"display_name": "Simple",
		"resettable": false,
		"timeout_days": 0,
		"preconditions": [
			{"type": "day_reached", "value": 2},
		],
		"reveal_moment": "",
		"reward": {"type": "cash", "amount": 50.0},
	}
	for k: String in override:
		base[k] = override[k]
	return base


func test_thread_resolved_emits_resolved_on_completion() -> void:
	_system._thread_defs = [_make_simple_def()]
	_system._init_thread_states()
	var received: Array[String] = []
	EventBus.thread_resolved.connect(
		func(_tid: String, rt: String) -> void: received.append(rt)
	)
	for day: int in range(1, 6):
		_system._on_day_started(day)
	assert_has(received, "resolved",
		"thread_resolved must emit 'resolved' on normal completion")


func test_thread_resolved_emits_non_resolved_on_timeout() -> void:
	var def: Dictionary = _make_simple_def({
		"id": "timeout_thread",
		"timeout_days": 3,
		"preconditions": [{"type": "day_reached", "value": 1}],
		"reward": {},
	})
	_system._thread_defs = [def]
	_system._init_thread_states()
	var received: Array[String] = []
	EventBus.thread_resolved.connect(
		func(_tid: String, rt: String) -> void: received.append(rt)
	)
	# Activate on day 1, then time out (timeout_days=3 means fail by day 4)
	for day: int in range(1, 8):
		_system._on_day_started(day)
	assert_has(received, "non_resolved",
		"thread_resolved must emit 'non_resolved' on timeout")


func test_thread_resolved_resolution_type_is_string() -> void:
	_system._thread_defs = [_make_simple_def()]
	_system._init_thread_states()
	var types: Array = []
	EventBus.thread_resolved.connect(
		func(_tid: String, rt: String) -> void: types.append(rt)
	)
	for day: int in range(1, 6):
		_system._on_day_started(day)
	for rt: Variant in types:
		assert_true(
			rt == "resolved" or rt == "non_resolved",
			"resolution_type must be 'resolved' or 'non_resolved', got: " + str(rt)
		)


# ── four required thread IDs present in JSON ──────────────────────────────────


func test_required_thread_ids_present() -> void:
	var file: FileAccess = FileAccess.open(
		"res://game/content/meta/secret_threads.json", FileAccess.READ
	)
	if not file:
		fail_test("secret_threads.json not found")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is not Array:
		fail_test("secret_threads.json must be a JSON array")
		return
	var ids: Array[String] = []
	for entry: Variant in (parsed as Array):
		if entry is Dictionary:
			ids.append(str((entry as Dictionary).get("id", "")))
	var required: Array[String] = [
		"regular_at_food_court",
		"skeptic_critic",
		"ghost_tenant_7b",
		"mall_legend",
	]
	for req: String in required:
		assert_has(ids, req, "secret_threads.json must contain thread id '%s'" % req)


# ── non_resolution_path flag ──────────────────────────────────────────────────


func test_all_required_threads_have_non_resolution_path() -> void:
	var file: FileAccess = FileAccess.open(
		"res://game/content/meta/secret_threads.json", FileAccess.READ
	)
	if not file:
		fail_test("secret_threads.json not found")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is not Array:
		fail_test("Expected JSON array")
		return
	var required_ids: Array[String] = [
		"regular_at_food_court",
		"skeptic_critic",
		"ghost_tenant_7b",
		"mall_legend",
	]
	for entry: Variant in (parsed as Array):
		if entry is not Dictionary:
			continue
		var id: String = str((entry as Dictionary).get("id", ""))
		if id in required_ids:
			assert_true(
				bool((entry as Dictionary).get("non_resolution_path", false)),
				"Thread '%s' must have non_resolution_path = true" % id
			)
