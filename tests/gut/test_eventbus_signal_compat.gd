## ISSUE-166 EventBus signal compatibility audit for game/scripts.
extends GutTest
const EVENT_BUS_PATH := "res://game/autoload/event_bus.gd"
const GAME_SCRIPTS_DIR := "res://game/scripts"
const GAME_AUTOLOAD_DIR := "res://game/autoload"
const GAME_SCENES_DIR := "res://game/scenes"
const CONNECT_WRAPPER_PREFIX := "_connect"
const SAFE_CONNECT_WRAPPER := "_safe_connect"

var _declared_signal_arity: Dictionary = {}
var _signal_references: Array[Dictionary] = []
var _connect_calls: Array[Dictionary] = []
var _emit_calls: Array[Dictionary] = []
func before_all() -> void:
	_declared_signal_arity = _parse_declared_signals(EVENT_BUS_PATH)
	_scan_game_scripts()

func test_issue_166_declared_signal_inventory_loaded() -> void:
	assert_gt(
		_declared_signal_arity.size(), 0,
		"EventBus should declare signals for compatibility auditing"
	)

func test_issue_166_all_referenced_signals_are_declared() -> void:
	var missing: Array[String] = []
	for ref: Dictionary in _signal_references:
		var signal_name: String = ref.get("signal", "")
		if _declared_signal_arity.has(signal_name):
			continue
		missing.append(
			"%s:%d -> %s"
			% [
				ref.get("path", "?"),
				int(ref.get("line", -1)),
				signal_name,
			]
		)
	assert_true(
		missing.is_empty(),
		"Referenced but undeclared EventBus signals:\n%s"
		% "\n".join(missing)
	)

func test_issue_166_emit_calls_match_declared_arity() -> void:
	var mismatches: Array[String] = []
	for emit_call: Dictionary in _emit_calls:
		var signal_name: String = emit_call.get("signal", "")
		if not _declared_signal_arity.has(signal_name):
			continue
		var expected: int = _declared_signal_arity.get(signal_name, -1)
		var actual: int = int(emit_call.get("arg_count", -1))
		if expected == actual:
			continue
		mismatches.append(
			"%s:%d -> %s.emit expected %d args, got %d"
			% [
				emit_call.get("path", "?"),
				int(emit_call.get("line", -1)),
				signal_name,
				expected,
				actual,
			]
		)
	assert_true(
		mismatches.is_empty(),
		"EventBus emit arity mismatches:\n%s"
		% "\n".join(mismatches)
	)

func test_issue_166_connect_handlers_are_arity_compatible() -> void:
	var mismatches: Array[String] = []
	for conn: Dictionary in _connect_calls:
		var signal_name: String = conn.get("signal", "")
		if not _declared_signal_arity.has(signal_name):
			continue
		var handler_name: String = conn.get("handler", "")
		if handler_name.is_empty():
			continue
		var sig_arity: int = _declared_signal_arity.get(signal_name, -1)
		var min_args: int = int(conn.get("handler_min", -1))
		var max_args: int = int(conn.get("handler_max", -1))
		if min_args < 0 or max_args < 0:
			continue
		if sig_arity >= min_args and sig_arity <= max_args:
			continue
		mismatches.append(
			"%s:%d -> %s.connect(%s) signal args=%d, handler accepts %d..%d"
			% [
				conn.get("path", "?"),
				int(conn.get("line", -1)),
				signal_name,
				handler_name,
				sig_arity,
				min_args,
				max_args,
			]
		)
	assert_true(
		mismatches.is_empty(),
		"EventBus connect handler arity mismatches:\n%s"
		% "\n".join(mismatches)
	)

func test_issue_166_no_orphaned_signals_in_runtime_game_code() -> void:
	var referenced: Dictionary = {}
	for ref: Dictionary in _signal_references:
		referenced[ref.get("signal", "")] = true
	var orphans: Array[String] = []
	for signal_name: String in _declared_signal_arity.keys():
		if referenced.has(signal_name):
			continue
		orphans.append(signal_name)
	orphans.sort()
	assert_true(
		orphans.is_empty(),
		"Declared EventBus signals not referenced by any game script:\n%s"
		% "\n".join(orphans)
	)

func test_issue_166_audit_inventory_contains_connect_and_emit_calls() -> void:
	assert_gt(
		_connect_calls.size(), 0,
		"Expected connect call inventory in game/scripts"
	)
	assert_gt(
		_emit_calls.size(), 0,
		"Expected emit call inventory in game/scripts"
	)

func _parse_declared_signals(path: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(path)
	var regex: RegEx = RegEx.new()
	var ok: Error = regex.compile(
		"(?s)signal\\s+([A-Za-z0-9_]+)\\s*\\((.*?)\\)"
	)
	if ok != OK:
		return {}

	var result: Dictionary = {}
	for match: RegExMatch in regex.search_all(text):
		var signal_name: String = match.get_string(1)
		var params_raw: String = match.get_string(2)
		result[signal_name] = _count_top_level_arguments(params_raw)
	return result

func _scan_game_scripts() -> void:
	_signal_references.clear()
	_connect_calls.clear()
	_emit_calls.clear()

	for path: String in _list_gd_files_recursive(GAME_SCRIPTS_DIR):
		_scan_script(path)
	for path: String in _list_gd_files_recursive(GAME_AUTOLOAD_DIR):
		_scan_script(path)
	for path: String in _list_gd_files_recursive(GAME_SCENES_DIR):
		_scan_script(path)

func _scan_script(path: String) -> void:
	var text: String = FileAccess.get_file_as_string(path)
	var fn_ranges: Dictionary = _extract_function_arity_ranges(text)
	var calls: Array[Dictionary] = _extract_eventbus_member_calls(path, text)
	for call: Dictionary in calls:
		var signal_name: String = call.get("signal", "")
		if signal_name.is_empty():
			continue
		_signal_references.append(
			{
				"path": path,
				"line": int(call.get("line", -1)),
				"signal": signal_name,
			}
		)
		if call.get("method", "") == "emit":
			var args: Array[String] = _split_top_level_arguments(
				String(call.get("args", ""))
			)
			_emit_calls.append(
				{
					"path": path,
					"line": int(call.get("line", -1)),
					"signal": signal_name,
					"arg_count": args.size(),
				}
			)
		elif call.get("method", "") == "connect":
			_record_connect_call(path, call, fn_ranges)
	var dynamic_emit_calls: Array[Dictionary] = _extract_emit_signal_calls(path, text)
	for emit_call: Dictionary in dynamic_emit_calls:
		_signal_references.append(
			{
				"path": path,
				"line": int(emit_call.get("line", -1)),
				"signal": String(emit_call.get("signal", "")),
			}
		)
		_emit_calls.append(emit_call)

	var wrapper_calls: Array[Dictionary] = _extract_connect_wrapper_calls(path, text)
	for wrap: Dictionary in wrapper_calls:
		_signal_references.append(
			{
				"path": path,
				"line": int(wrap.get("line", -1)),
				"signal": String(wrap.get("signal", "")),
			}
		)
		_record_connect_call(path, wrap, fn_ranges)

func _record_connect_call(
	path: String,
	call: Dictionary,
	fn_ranges: Dictionary
) -> void:
	var handler_name: String = String(call.get("handler", ""))
	var handler_min: int = -1
	var handler_max: int = -1
	if fn_ranges.has(handler_name):
		var range: Dictionary = fn_ranges[handler_name]
		handler_min = int(range.get("min", -1))
		handler_max = int(range.get("max", -1))
	_connect_calls.append(
		{
			"path": path,
			"line": int(call.get("line", -1)),
			"signal": String(call.get("signal", "")),
			"handler": handler_name,
			"handler_min": handler_min,
			"handler_max": handler_max,
		}
	)

func _extract_function_arity_ranges(text: String) -> Dictionary:
	var regex: RegEx = RegEx.new()
	var ok: Error = regex.compile(
		"(?m)^func\\s+([A-Za-z0-9_]+)\\s*\\(([^)]*)\\)"
	)
	if ok != OK:
		return {}

	var ranges: Dictionary = {}
	for match: RegExMatch in regex.search_all(text):
		var fn_name: String = match.get_string(1)
		var params_raw: String = match.get_string(2)
		var params: Array[String] = _split_top_level_arguments(params_raw)
		var min_args: int = 0
		var max_args: int = params.size()
		for param: String in params:
			if param.find("=") >= 0:
				continue
			min_args += 1
		ranges[fn_name] = {"min": min_args, "max": max_args}
	return ranges

func _extract_eventbus_member_calls(
	path: String,
	text: String
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var cursor: int = 0
	while true:
		var idx: int = text.find("EventBus.", cursor)
		if idx < 0:
			break
		var sig_start: int = idx + "EventBus.".length()
		var sig_end: int = _scan_identifier_end(text, sig_start)
		if sig_end <= sig_start:
			cursor = idx + 1
			continue
		var signal_name: String = text.substr(sig_start, sig_end - sig_start)
		var dot_idx: int = sig_end
		if dot_idx >= text.length() or text[dot_idx] != ".":
			cursor = sig_end
			continue
		var method_start: int = dot_idx + 1
		var method_end: int = _scan_identifier_end(text, method_start)
		if method_end <= method_start:
			cursor = method_start
			continue
		var method_name: String = text.substr(
			method_start,
			method_end - method_start
		)
		if method_name not in ["emit", "connect", "is_connected", "disconnect"]:
			cursor = method_end
			continue

		var paren_open: int = _skip_spaces(text, method_end)
		if paren_open >= text.length() or text[paren_open] != "(":
			cursor = method_end
			continue
		var paren_close: int = _find_matching_paren(text, paren_open)
		if paren_close < 0:
			cursor = paren_open + 1
			continue
		var args_raw: String = text.substr(
			paren_open + 1,
			paren_close - paren_open - 1
		)
		var line_no: int = _line_number_at(text, idx)
		var entry: Dictionary = {
			"path": path,
			"line": line_no,
			"signal": signal_name,
			"method": method_name,
			"args": args_raw,
		}
		if method_name == "connect":
			var args: Array[String] = _split_top_level_arguments(args_raw)
			if not args.is_empty():
				entry["handler"] = _extract_identifier(args[0])
		result.append(entry)
		cursor = paren_close + 1
	return result

func _extract_emit_signal_calls(
	path: String,
	text: String
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var cursor: int = 0
	while true:
		var idx: int = text.find("EventBus.emit_signal", cursor)
		if idx < 0:
			break
		var open_idx: int = _skip_spaces(
			text, idx + "EventBus.emit_signal".length()
		)
		if open_idx >= text.length() or text[open_idx] != "(":
			cursor = idx + 1
			continue
		var close_idx: int = _find_matching_paren(text, open_idx)
		if close_idx < 0:
			cursor = open_idx + 1
			continue
		var args_raw: String = text.substr(
			open_idx + 1,
			close_idx - open_idx - 1
		)
		var args: Array[String] = _split_top_level_arguments(args_raw)
		if args.is_empty():
			cursor = close_idx + 1
			continue
		var signal_name: String = _extract_signal_name_literal(args[0])
		if signal_name.is_empty():
			cursor = close_idx + 1
			continue
		result.append(
			{
				"path": path,
				"line": _line_number_at(text, idx),
				"signal": signal_name,
				"arg_count": maxi(0, args.size() - 1),
			}
		)
		cursor = close_idx + 1
	return result

func _extract_signal_name_literal(raw: String) -> String:
	var literal: String = raw.strip_edges()
	if literal.begins_with("&\"") and literal.ends_with("\"") and literal.length() >= 3:
		return literal.substr(2, literal.length() - 3)
	if literal.begins_with("\"") and literal.ends_with("\"") and literal.length() >= 2:
		return literal.substr(1, literal.length() - 2)
	if literal.begins_with("'") and literal.ends_with("'") and literal.length() >= 2:
		return literal.substr(1, literal.length() - 2)
	return ""

func _extract_connect_wrapper_calls(
	path: String,
	text: String
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var regex: RegEx = RegEx.new()
	var ok: Error = regex.compile("(?m)([_A-Za-z0-9]+)\\s*\\(")
	if ok != OK:
		return result

	for match: RegExMatch in regex.search_all(text):
		var fn_name: String = match.get_string(1)
		if not _is_connect_wrapper_name(fn_name):
			continue
		var call_start: int = match.get_start(0)
		var open_idx: int = match.get_end(0) - 1
		var close_idx: int = _find_matching_paren(text, open_idx)
		if close_idx < 0:
			continue
		var args_raw: String = text.substr(
			open_idx + 1,
			close_idx - open_idx - 1
		)
		var args: Array[String] = _split_top_level_arguments(args_raw)
		if args.size() < 2:
			continue
		var first_arg: String = args[0].strip_edges()
		if not first_arg.begins_with("EventBus."):
			continue
		var signal_name: String = _extract_identifier(
			first_arg.trim_prefix("EventBus.")
		)
		var handler_name: String = _extract_identifier(args[1])
		if signal_name.is_empty():
			continue
		result.append(
			{
				"path": path,
				"line": _line_number_at(text, call_start),
				"signal": signal_name,
				"method": "connect",
				"handler": handler_name,
			}
		)
	return result

func _is_connect_wrapper_name(fn_name: String) -> bool:
	if fn_name == SAFE_CONNECT_WRAPPER:
		return true
	if fn_name.begins_with(CONNECT_WRAPPER_PREFIX):
		return true
	return false

func _count_top_level_arguments(args_raw: String) -> int:
	if args_raw.strip_edges().is_empty():
		return 0
	return _split_top_level_arguments(args_raw).size()

func _split_top_level_arguments(args_raw: String) -> Array[String]:
	var result: Array[String] = []
	var current: String = ""
	var paren_depth: int = 0
	var square_depth: int = 0
	var brace_depth: int = 0
	var quote: String = ""
	var escaped: bool = false

	for i: int in args_raw.length():
		var ch: String = args_raw[i]
		if not quote.is_empty():
			current += ch
			if escaped:
				escaped = false
				continue
			if ch == "\\":
				escaped = true
				continue
			if ch == quote:
				quote = ""
			continue

		if ch == "\"" or ch == "'":
			quote = ch
			current += ch
			continue

		match ch:
			"(":
				paren_depth += 1
			")":
				paren_depth = maxi(0, paren_depth - 1)
			"[":
				square_depth += 1
			"]":
				square_depth = maxi(0, square_depth - 1)
			"{":
				brace_depth += 1
			"}":
				brace_depth = maxi(0, brace_depth - 1)
			",":
				if paren_depth == 0 and square_depth == 0 and brace_depth == 0:
					var arg: String = current.strip_edges()
					if not arg.is_empty():
						result.append(arg)
					current = ""
					continue
		current += ch

	var tail: String = current.strip_edges()
	if not tail.is_empty():
		result.append(tail)
	return result

func _extract_identifier(raw: String) -> String:
	var regex: RegEx = RegEx.new()
	if regex.compile("^\\s*([A-Za-z_][A-Za-z0-9_]*)") != OK:
		return ""
	var match: RegExMatch = regex.search(raw)
	if match == null:
		return ""
	return match.get_string(1)

func _scan_identifier_end(text: String, start_idx: int) -> int:
	var idx: int = start_idx
	while idx < text.length() and _is_ident_char(text[idx]):
		idx += 1
	return idx

func _is_ident_char(ch: String) -> bool:
	return (ch >= "a" and ch <= "z") \
		or (ch >= "A" and ch <= "Z") \
		or (ch >= "0" and ch <= "9") \
		or ch == "_"

func _skip_spaces(text: String, idx: int) -> int:
	while idx < text.length() and text[idx] in [" ", "\t", "\r", "\n"]:
		idx += 1
	return idx

func _find_matching_paren(text: String, open_idx: int) -> int:
	if open_idx >= text.length() or text[open_idx] != "(":
		return -1
	var depth: int = 0
	var quote: String = ""
	var escaped: bool = false
	for i: int in range(open_idx, text.length()):
		var ch: String = text[i]
		if not quote.is_empty():
			if escaped:
				escaped = false
				continue
			if ch == "\\":
				escaped = true
				continue
			if ch == quote:
				quote = ""
			continue
		if ch == "\"" or ch == "'":
			quote = ch
			continue
		if ch == "(":
			depth += 1
		elif ch == ")":
			depth -= 1
			if depth == 0:
				return i
	return -1

func _line_number_at(text: String, idx: int) -> int:
	if idx <= 0:
		return 1
	var line: int = 1
	for i: int in idx:
		if text[i] == "\n":
			line += 1
	return line

func _list_gd_files_recursive(root_path: String) -> Array[String]:
	var files: Array[String] = []
	_walk_dir(root_path, files)
	files.sort()
	return files

func _walk_dir(dir_path: String, files: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var name: String = dir.get_next()
		if name.is_empty():
			break
		if name.begins_with("."):
			continue
		var child_path: String = "%s/%s" % [dir_path, name]
		if dir.current_is_dir():
			_walk_dir(child_path, files)
			continue
		if child_path.get_extension() == "gd":
			files.append(child_path)
	dir.list_dir_end()
