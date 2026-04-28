## Seeds user://gut_temp_directory/gut_editor_config.json when absent.
##
## GutBottomPanel._ready() (an @tool Control loaded by the GUT editor plugin)
## calls load_options() on this path during every headless --import run. If
## the file does not exist GUT prints an ERROR: line that triggers the CI
## push_error gate. Running this script once after --import (which creates the
## directory via GutEditorGlobals.create_temp_directory()) ensures the file
## exists before the GUT test run.
extends SceneTree


func _init() -> void:
	var dir_path := "user://gut_temp_directory"
	var config_path := dir_path + "/gut_editor_config.json"
	DirAccess.make_dir_recursive_absolute(dir_path)
	if not FileAccess.file_exists(config_path):
		var f := FileAccess.open(config_path, FileAccess.WRITE)
		if f:
			f.store_string("{}")
	quit(0)
