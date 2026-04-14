## Test runner that configures GUT to discover tests in game/tests/.
extends Node2D

const GUT_RUNNER: PackedScene = preload(
	"res://addons/gut/gui/GutRunner.tscn"
)
const GUT_CONFIG: GDScript = preload("res://addons/gut/gut_config.gd")

const TEST_DIR: String = "res://game/tests/"
const TEST_PREFIX: String = "test_"


func _ready() -> void:
	call_deferred("_launch_runner")


func _launch_runner() -> void:
	var runner: Node2D = GUT_RUNNER.instantiate()
	runner.ran_from_editor = false

	var config: RefCounted = GUT_CONFIG.new()
	config.options.dirs = [TEST_DIR]
	config.options.prefix = TEST_PREFIX
	config.options.should_exit = false
	config.options.should_exit_on_success = false
	config.options.log_level = 1
	config.options.compact_mode = false
	config.options.include_subdirs = false

	runner.gut_config = config
	add_child(runner)
	runner.run_tests()
