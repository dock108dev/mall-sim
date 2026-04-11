## Persisted player settings (volume, resolution, controls).
extends Node


const SETTINGS_PATH := "user://settings.cfg"

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

## Supported locales — add entries here when new CSV columns are added.
const SUPPORTED_LOCALES: Array[Dictionary] = [
	{"code": "en", "name": "English"},
	{"code": "es", "name": "Español"},
]

## Default bindings captured from InputMap at startup.
var _default_bindings: Dictionary = {}


func _ready() -> void:
	_capture_default_bindings()


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
	_save_keybindings(config)
	var save_err: Error = config.save(SETTINGS_PATH)
	if save_err != OK:
		push_warning(
			"Settings: failed to save '%s' — %s"
			% [SETTINGS_PATH, error_string(save_err)]
		)


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		if FileAccess.file_exists(SETTINGS_PATH):
			push_warning(
				"Settings: failed to parse '%s' — using defaults" % SETTINGS_PATH
			)
		return
	master_volume = config.get_value("audio", "master_volume", 1.0)
	music_volume = config.get_value("audio", "music_volume", 0.8)
	sfx_volume = config.get_value("audio", "sfx_volume", 1.0)
	ambient_volume = config.get_value("audio", "ambient_volume", 0.8)
	fullscreen = config.get_value("display", "fullscreen", true)
	vsync = config.get_value("display", "vsync", true)
	var res_x: int = config.get_value("display", "resolution_x", 1920)
	var res_y: int = config.get_value("display", "resolution_y", 1080)
	resolution = Vector2i(res_x, res_y)
	ui_scale = clampf(
		config.get_value("display", "ui_scale", 1.0),
		UI_SCALE_MIN, UI_SCALE_MAX
	)
	font_size = clampi(
		config.get_value("display", "font_size", FontSize.MEDIUM),
		FontSize.SMALL, FontSize.EXTRA_LARGE
	)
	colorblind_mode = config.get_value(
		"display", "colorblind_mode", false
	)
	locale = config.get_value("locale", "language", "en")
	_load_keybindings(config)
	apply_settings()


func apply_settings() -> void:
	_apply_audio()
	_apply_display()
	_apply_ui_scale()
	_apply_font_size()
	_apply_locale()


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
		var keycode_val: int = config.get_value("input", action, -1)
		if keycode_val < 0:
			continue
		if not InputMap.has_action(action):
			continue
		var new_event := InputEventKey.new()
		new_event.physical_keycode = keycode_val as Key
		rebind_action(action, new_event)


func _apply_ui_scale() -> void:
	var window: Window = get_window()
	if window == null:
		return
	window.content_scale_factor = ui_scale


func _apply_font_size() -> void:
	var theme: Theme = ThemeDB.get_project_theme()
	if theme == null:
		return
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
	var old_locale: String = TranslationServer.get_locale()
	TranslationServer.set_locale(locale)
	if old_locale != locale:
		EventBus.locale_changed.emit(locale)


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
	var ambient_idx: int = AudioServer.get_bus_index("Ambient")
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
