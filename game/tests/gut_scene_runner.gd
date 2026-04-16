## Configures GUT to discover project tests from game/tests.
extends "res://addons/gut/gui/GutRunner.gd"

const GUT_CONFIG: GDScript = preload("res://addons/gut/gut_config.gd")
const TEST_DIR: String = "res://game/tests/"
const TEST_PREFIX: String = "test_"
const TIMEOUT_PER_TEST: float = 5.0

var _active_test_name: String = ""
var _active_test_token: int = 0


func _ready() -> void:
	ran_from_editor = false
	gut_config = _create_gut_config()
	gut.start_test.connect(_on_gut_start_test)
	gut.end_test.connect(_on_gut_end_test)
	super._ready()
	call_deferred("run_tests")


func _create_gut_config() -> RefCounted:
	var config: RefCounted = GUT_CONFIG.new()
	config.options.configured_dirs = [TEST_DIR]
	config.options.dirs = [TEST_DIR]
	config.options.prefix = TEST_PREFIX
	config.options.should_exit = false
	config.options.should_exit_on_success = false
	config.options.log_level = 1
	config.options.compact_mode = false
	config.options.include_subdirs = false
	return config


func _on_gut_start_test(test_name: String) -> void:
	_active_test_name = test_name
	_active_test_token += 1
	_watch_test_timeout(_active_test_token, test_name)


func _on_gut_end_test() -> void:
	_active_test_name = ""
	_active_test_token += 1


func _watch_test_timeout(token: int, test_name: String) -> void:
	await get_tree().create_timer(TIMEOUT_PER_TEST).timeout
	if token != _active_test_token or test_name != _active_test_name:
		return

	gut._fail("Test exceeded %.1f second timeout." % TIMEOUT_PER_TEST)
