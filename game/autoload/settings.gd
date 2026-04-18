## Persisted player settings (volume, resolution, controls).
extends Node


signal preference_changed(key: StringName, value: Variant)

var settings_path: String = "user://settings.cfg"

const COMMON_RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]

## Actions that can be rebound by the player.
const REBINDABLE_ACTIONS: Array[String] = [
	"move_forward",
	"move_back",
	"move_left",
	"move_right",
	"interact",
	"time_toggle_pause",
	"time_speed_1",
	"time_speed_2",
	"time_speed_4",
	"toggle_inventory",
	"toggle_build_mode",
	"toggle_debug",
	"toggle_orders",
	"toggle_staff",
	"rotate_fixture",
	"orbit_left",
	"orbit_right",
]

## Font size presets: Small, Medium, Large, Extra Large.
enum FontSize { SMALL, MEDIUM, LARGE, EXTRA_LARGE }

const FONT_SIZE_VALUES: Array[int] = [12, 14, 18, 22]
const FONT_SIZE_LABEL_KEYS: Array[String] = [
	"SETTINGS_FONT_SMALL", "SETTINGS_FONT_MEDIUM",
	"SETTINGS_FONT_LARGE", "SETTINGS_FONT_EXTRA_LARGE",
]

const UI_SCALE_MIN: float = 0.75
const UI_SCALE_MAX: float = 1.50
const UI_SCALE_STEP: float = 0.05
const MAX_PERSISTED_KEYCODE: int = 33554431
const MAX_SETTINGS_FILE_BYTES: int = 262144

var master_volume: float = 1.0
var music_volume: float = 0.8
var sfx_volume: float = 1.0
var ambient_volume: float = 0.8
var fullscreen: bool = true
var vsync: bool = true
var resolution: Vector2i = Vector2i(1920, 1080)
var ui_scale: float = 1.0
var font_size: int = FontSize.MEDIUM
var colorblind_mode: bool = false
var locale: String = "en"
var display_mode: int = 1
var control_scheme: int = 0

## Supported locales — add entries here when new CSV columns are added.
const SUPPORTED_LOCALES: Array[Dictionary] = [
	{"code": "en", "name": "English"},
	{"code": "es", "name": "Español"},
]

const VOLUME_BUS_MAP: Dictionary = {
	&"master_volume": &"Master",
	&"music_volume": &"Music",
	&"sfx_volume": &"SFX",
	&"ambient_volume": &"Ambience",
}

const PREFERENCE_DEFAULTS: Dictionary = {
	&"master_volume": 1.0,
	&"music_volume": 0.8,
	&"sfx_volume": 1.0,
	&"ambient_volume": 0.8,
	&"display_mode": 1,
	&"control_scheme": 0,
	&"language": "en",
}

## Default bindings captured from InputMap at startup.
var _default_bindings: Dictionary = {}


func _ready() -> void:
	_capture_default_bindings()
	load_settings()
	apply_settings()
	_apply_locale_preference()
	preference_changed.connect(_on_preference_changed)


func _capture_default_bindings() -> void:
	for action: String in REBINDABLE_ACTIONS:
		if not InputMap.has_action(action):
			continue
		var events: Array[InputEvent] = InputMap.action_get_events(action)
		if not events.is_empty():
			_default_bindings[action] = events[0].duplicate()


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "ambient_volume", ambient_volume)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "vsync", vsync)
	config.set_value("display", "resolution_x", resolution.x)
	config.set_value("display", "resolution_y", resolution.y)
	config.set_value("display", "ui_scale", ui_scale)
	config.set_value("display", "font_size", font_size)
	config.set_value("display", "colorblind_mode", colorblind_mode)
	config.set_value("locale", "language", locale)
	config.set_value("preferences", "display_mode", display_mode)
	config.set_value("preferences", "control_scheme", control_scheme)
	_save_keybindings(config)
	var save_err: Error = config.save(settings_path)
	if save_err != OK:
		push_warning(
			"Settings: failed to save '%s' — %s"
			% [settings_path, error_string(save_err)]
		)


## Compatibility wrapper used by boot sequence.
func load() -> void:
	load_settings()


func load_settings() -> void:
	var config := ConfigFile.new()
	if FileAccess.file_exists(settings_path):
		var settings_file: FileAccess = FileAccess.open(
			settings_path, FileAccess.READ
		)
		if settings_file and settings_file.get_length() > MAX_SETTINGS_FILE_BYTES:
			settings_file.close()
			push_warning(
				(
					"Settings: '%s' exceeds maximum supported size (%d bytes) — using defaults"
					% [settings_path, MAX_SETTINGS_FILE_BYTES]
				)
			)
			_restore_defaults_after_failed_load()
			return
		if settings_file:
			settings_file.close()
	if config.load(settings_path) != OK:
		if FileAccess.file_exists(settings_path):
			push_warning(
				"Settings: failed to parse '%s' — using defaults" % settings_path
			)
			_restore_defaults_after_failed_load()
		return
	master_volume = _get_config_float(
		config, "audio", "master_volume", 1.0, 0.0, 1.0
	)
	music_volume = _get_config_float(
		config, "audio", "music_volume", 0.8, 0.0, 1.0
	)
	sfx_volume = _get_config_float(
		config, "audio", "sfx_volume", 1.0, 0.0, 1.0
	)
	ambient_volume = _get_config_float(
		config, "audio", "ambient_volume", 0.8, 0.0, 1.0
	)
	fullscreen = _get_config_bool(config, "display", "fullscreen", true)
	vsync = _get_config_bool(config, "display", "vsync", true)
	var res_x: int = _get_config_positive_int(
		config, "display", "resolution_x", 1920
	)
	var res_y: int = _get_config_positive_int(
		config, "display", "resolution_y", 1080
	)
	resolution = Vector2i(res_x, res_y)
	ui_scale = _get_config_float(
		config, "display", "ui_scale", 1.0, UI_SCALE_MIN, UI_SCALE_MAX
	)
	font_size = _get_config_int(
		config, "display", "font_size",
		FontSize.MEDIUM, FontSize.SMALL, FontSize.EXTRA_LARGE
	)
	colorblind_mode = _get_config_bool(
		config, "display", "colorblind_mode", false
	)
	locale = _get_config_string(config, "locale", "language", "en")
	display_mode = _get_config_int(
		config, "preferences", "display_mode", 1
	)
	control_scheme = _get_config_int(
		config, "preferences", "control_scheme", 0
	)
	_load_keybindings(config)
	apply_settings()


func apply_settings() -> void:
	_apply_audio()
	_apply_display()
	_apply_ui_scale()
	_apply_font_size()
	_apply_locale()


func reset_to_defaults() -> void:
	master_volume = 1.0
	music_volume = 0.8
	sfx_volume = 1.0
	ambient_volume = 0.8
	fullscreen = true
	vsync = true
	resolution = Vector2i(1920, 1080)
	ui_scale = 1.0
	font_size = FontSize.MEDIUM
	colorblind_mode = false
	locale = "en"
	display_mode = 1
	control_scheme = 0
	reset_keybindings_to_defaults()
	apply_settings()


func _restore_defaults_after_failed_load() -> void:
	reset_to_defaults()


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	var idx: int = AudioServer.get_bus_index("Master")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(master_volume))


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	var idx: int = AudioServer.get_bus_index("Music")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(music_volume))


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	var idx: int = AudioServer.get_bus_index("SFX")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(sfx_volume))


## Returns the current value for a named preference key.
func get_preference(key: StringName) -> Variant:
	match key:
		&"master_volume": return master_volume
		&"music_volume": return music_volume
		&"sfx_volume": return sfx_volume
		&"ambient_volume": return ambient_volume
		&"display_mode": return display_mode
		&"control_scheme": return control_scheme
		&"language": return locale
		_:
			push_warning(
				"Settings: unknown preference key '%s'" % key
			)
			return null


## Sets a named preference with type validation and idempotency guard.
func set_preference(key: StringName, value: Variant) -> void:
	if value == null:
		push_error(
			"Settings: null value for preference '%s'" % key
		)
		return
	if not PREFERENCE_DEFAULTS.has(key):
		push_warning(
			"Settings: unknown preference key '%s'" % key
		)
		return
	var expected_type: int = typeof(PREFERENCE_DEFAULTS[key])
	var actual_type: int = typeof(value)
	if expected_type == TYPE_FLOAT and actual_type == TYPE_INT:
		value = float(value)
		actual_type = TYPE_FLOAT
	if actual_type != expected_type:
		push_error(
			"Settings: type mismatch for '%s' — expected %s, got %s"
			% [key, type_string(expected_type),
				type_string(actual_type)]
		)
		return
	if expected_type == TYPE_FLOAT:
		value = clampf(value as float, 0.0, 1.0)
	var old_value: Variant = get_preference(key)
	if old_value == value:
		return
	match key:
		&"master_volume": master_volume = value as float
		&"music_volume": music_volume = value as float
		&"sfx_volume": sfx_volume = value as float
		&"ambient_volume": ambient_volume = value as float
		&"display_mode": display_mode = value as int
		&"control_scheme": control_scheme = value as int
		&"language": locale = value as String
	preference_changed.emit(String(key), value)
	EventBus.preference_changed.emit(String(key), value)


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	var window: Window = get_window()
	if window == null:
		return
	if fullscreen:
		window.mode = Window.MODE_FULLSCREEN
	else:
		window.mode = Window.MODE_WINDOWED
		window.size = resolution


## Rebind a single action to a new key event in InputMap.
func rebind_action(action: String, new_event: InputEventKey) -> void:
	if not InputMap.has_action(action):
		push_warning("Settings: cannot rebind unknown action '%s'" % action)
		return
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, new_event)


## Reset all rebindable actions to their default bindings.
func reset_keybindings_to_defaults() -> void:
	for action: String in REBINDABLE_ACTIONS:
		if not _default_bindings.has(action):
			continue
		if not InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		var default_event: InputEvent = _default_bindings[action]
		InputMap.action_add_event(action, default_event.duplicate())


## Get the default InputEvent for an action, or null if none.
func get_default_event(action: String) -> InputEvent:
	if _default_bindings.has(action):
		return _default_bindings[action]
	return null


## Find which rebindable action uses the given physical keycode.
func find_action_for_keycode(keycode: Key) -> String:
	for action: String in REBINDABLE_ACTIONS:
		var events: Array[InputEvent] = InputMap.action_get_events(action)
		for event: InputEvent in events:
			if event is InputEventKey:
				var key_ev := event as InputEventKey
				if key_ev.physical_keycode == keycode:
					return action
	return ""


func _save_keybindings(config: ConfigFile) -> void:
	for action: String in REBINDABLE_ACTIONS:
		var events: Array[InputEvent] = InputMap.action_get_events(action)
		if events.is_empty():
			config.set_value("input", action, -1)
			continue
		var event: InputEvent = events[0]
		if event is InputEventKey:
			var key_ev := event as InputEventKey
			config.set_value("input", action, key_ev.physical_keycode)


func _load_keybindings(config: ConfigFile) -> void:
	if not config.has_section("input"):
		return
	for action: String in REBINDABLE_ACTIONS:
		if not config.has_section_key("input", action):
			continue
		var keycode_val: int = _get_config_int(
			config, "input", action, -1
		)
		if keycode_val < 0:
			continue
		if keycode_val > MAX_PERSISTED_KEYCODE:
			push_warning(
				"Settings: ignoring out-of-range keycode %d for action '%s'"
				% [keycode_val, action]
			)
			continue
		if not InputMap.has_action(action):
			continue
		var new_event := InputEventKey.new()
		new_event.physical_keycode = keycode_val as Key
		rebind_action(action, new_event)


func _get_config_bool(
	config: ConfigFile,
	section: String,
	key: String,
	default_value: bool
) -> bool:
	if not config.has_section_key(section, key):
		return default_value
	var value: Variant = config.get_value(section, key, default_value)
	if value is bool:
		return value as bool
	_warn_invalid_config_type(section, key, "bool", value)
	return default_value


func _get_config_float(
	config: ConfigFile,
	section: String,
	key: String,
	default_value: float,
	min_value: float = -INF,
	max_value: float = INF
) -> float:
	if not config.has_section_key(section, key):
		return default_value
	var value: Variant = config.get_value(section, key, default_value)
	var parsed: float = default_value
	if value is float:
		parsed = value as float
	elif value is int:
		parsed = float(value as int)
	else:
		_warn_invalid_config_type(section, key, "float", value)
		return default_value
	if is_nan(parsed) or is_inf(parsed):
		_warn_invalid_config_value(section, key, "finite float", parsed)
		return default_value
	return clampf(parsed, min_value, max_value)


func _get_config_int(
	config: ConfigFile,
	section: String,
	key: String,
	default_value: int,
	min_value: int = -2147483648,
	max_value: int = 2147483647
) -> int:
	if not config.has_section_key(section, key):
		return default_value
	var value: Variant = config.get_value(section, key, default_value)
	if value is not int:
		_warn_invalid_config_type(section, key, "int", value)
		return default_value
	return clampi(value as int, min_value, max_value)


func _get_config_positive_int(
	config: ConfigFile,
	section: String,
	key: String,
	default_value: int
) -> int:
	var value: int = _get_config_int(config, section, key, default_value)
	if value <= 0:
		_warn_invalid_config_value(section, key, "positive int", value)
		return default_value
	return value


func _get_config_string(
	config: ConfigFile,
	section: String,
	key: String,
	default_value: String
) -> String:
	if not config.has_section_key(section, key):
		return default_value
	var value: Variant = config.get_value(section, key, default_value)
	if value is String:
		return value as String
	_warn_invalid_config_type(section, key, "String", value)
	return default_value


func _warn_invalid_config_type(
	section: String,
	key: String,
	expected_type: String,
	value: Variant
) -> void:
	_warn_invalid_config_value(
		section,
		key,
		expected_type,
		"%s (%s)" % [type_string(typeof(value)), value]
	)


func _warn_invalid_config_value(
	section: String,
	key: String,
	expected: String,
	value: Variant
) -> void:
	push_warning(
		(
			"Settings: invalid value for [%s] %s in '%s' — expected %s, got %s; using default"
			% [section, key, settings_path, expected, value]
		)
	)


func _apply_ui_scale() -> void:
	var window: Window = get_window()
	if window == null:
		return
	window.content_scale_factor = ui_scale


func _apply_font_size() -> void:
	var theme: Theme = ThemeDB.get_project_theme()
	if theme == null:
		return
	if font_size < FontSize.SMALL or font_size > FontSize.EXTRA_LARGE:
		push_warning(
			"Settings: font_size %d out of range, falling back to default"
			% font_size
		)
		font_size = FontSize.MEDIUM
	var px: int = FONT_SIZE_VALUES[font_size]
	# Scale proportionally from Medium (14px) baseline
	var ratio: float = float(px) / 14.0
	theme.set_font_size("font_size", "Label", px)
	theme.set_font_size("font_size", "Button", px)
	theme.set_font_size("font_size", "CheckButton", px)
	theme.set_font_size("font_size", "OptionButton", px)
	theme.set_font_size("font_size", "LineEdit", px)
	theme.set_font_size("font_size", "SpinBox", px)
	theme.set_font_size("font_size", "TabContainer", px)
	theme.set_font_size("font_size", "PopupMenu", px)
	theme.set_font_size("font_size", "RichTextLabel", px)
	theme.set_font_size(
		"font_size", "TooltipLabel", maxi(int(px * 0.875), 10)
	)
	theme.set_font_size(
		"font_size", "HeaderLabel", int(22.0 * ratio)
	)
	theme.set_font_size(
		"font_size", "TitleLabel", int(28.0 * ratio)
	)


func _apply_locale() -> void:
	_apply_locale_preference()


func _apply_locale_preference() -> void:
	var resolved: String = locale
	if resolved.is_empty():
		resolved = "en"
		locale = resolved
	if not _is_supported_locale(resolved):
		push_warning(
			"Settings: unsupported locale '%s', falling back to 'en'"
			% resolved
		)
		resolved = "en"
		locale = resolved
	var old_locale: String = TranslationServer.get_locale()
	TranslationServer.set_locale(resolved)
	if old_locale != resolved:
		EventBus.locale_changed.emit(resolved)


func _is_supported_locale(value: String) -> bool:
	for entry: Dictionary in SUPPORTED_LOCALES:
		if str(entry.get("code", "")) == value:
			return true
	return false


func _on_preference_changed(key: StringName, _value: Variant) -> void:
	if key == &"language":
		_apply_locale_preference()


func _apply_audio() -> void:
	var master_idx: int = AudioServer.get_bus_index("Master")
	if master_idx >= 0:
		AudioServer.set_bus_volume_db(
			master_idx, linear_to_db(master_volume)
		)
	var music_idx: int = AudioServer.get_bus_index("Music")
	if music_idx >= 0:
		AudioServer.set_bus_volume_db(
			music_idx, linear_to_db(music_volume)
		)
	var sfx_idx: int = AudioServer.get_bus_index("SFX")
	if sfx_idx >= 0:
		AudioServer.set_bus_volume_db(
			sfx_idx, linear_to_db(sfx_volume)
		)
	var ambient_idx: int = AudioServer.get_bus_index("Ambience")
	if ambient_idx < 0:
		ambient_idx = AudioServer.get_bus_index("Ambient")
	if ambient_idx >= 0:
		AudioServer.set_bus_volume_db(
			ambient_idx, linear_to_db(ambient_volume)
		)


func _apply_display() -> void:
	var window: Window = get_window()
	_validate_resolution()
	if fullscreen:
		window.mode = Window.MODE_FULLSCREEN
	else:
		window.mode = Window.MODE_WINDOWED
		window.size = resolution

	if vsync:
		DisplayServer.window_set_vsync_mode(
			DisplayServer.VSYNC_ENABLED
		)
	else:
		DisplayServer.window_set_vsync_mode(
			DisplayServer.VSYNC_DISABLED
		)


## Ensures the saved resolution is valid for the current display.
## Falls back to 1920x1080 or the screen size if resolution is too large.
func _validate_resolution() -> void:
	var screen_size: Vector2i = DisplayServer.screen_get_size()
	if screen_size.x <= 0 or screen_size.y <= 0:
		return
	if resolution.x > screen_size.x or resolution.y > screen_size.y:
		# Find largest valid common resolution
		var fallback: Vector2i = COMMON_RESOLUTIONS[0]
		for res: Vector2i in COMMON_RESOLUTIONS:
			if res.x <= screen_size.x and res.y <= screen_size.y:
				fallback = res
		push_warning(
			"Settings: resolution %s exceeds screen %s, using %s"
			% [resolution, screen_size, fallback]
		)
		resolution = fallback
