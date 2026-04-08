## Loads JSON content files from the content directory.
class_name DataLoader
extends RefCounted


static func load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_warning("DataLoader: file not found: %s" % path)
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return null
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("DataLoader: parse error in %s: %s" % [path, json.get_error_message()])
		return null
	return json.data


static func load_all_json_in(dir_path: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var dir := DirAccess.open(dir_path)
	if not dir:
		return results
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			var data = load_json(dir_path.path_join(file_name))
			if data is Dictionary:
				results.append(data)
		file_name = dir.get_next()
	return results
