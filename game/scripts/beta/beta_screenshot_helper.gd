## Screenshot capture for the beta validation harness (Section 7 of the
## beta-readability brief). F10 saves a PNG of the current viewport to
## `user://screenshots/<timestamp>_<scene>.png` so visual regressions on the
## named beats (title, store post-intro, customer, decision modal, etc.) can
## be diffed manually without a full image-diff pipeline.
##
## Resolves the OS-specific user dir on first save:
##   * macOS:   ~/Library/Application Support/Godot/app_userdata/<project>/screenshots/
##   * Linux:   ~/.local/share/godot/app_userdata/<project>/screenshots/
##   * Windows: %APPDATA%\Godot\app_userdata\<project>\screenshots\
##
## Reaches the path on demand via `OS.get_user_data_dir()` for reporting in
## the on-screen toast so the player knows where the file landed.
extends CanvasLayer

const SAVE_DIR: String = "user://screenshots"
const TOAST_DURATION: float = 2.5
## Cap the scene-slug component of the saved filename. Godot already strips
## '/' and ':' from `Node.name`, but the slug still flows into a path on
## disk; bounding it (and the allowed charset below) is defense-in-depth so
## a future renamed scene cannot land an oversized or weirdly-glyphed
## filename in `user://screenshots/`.
const _MAX_SLUG_LENGTH: int = 48

var _toast: Label = null
var _toast_timer: float = 0.0


func _ready() -> void:
	if not _capture_enabled():
		queue_free()
		return
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS

	_toast = Label.new()
	_toast.add_theme_font_size_override("font_size", 14)
	_toast.add_theme_color_override("font_color", Color(0.957, 0.914, 0.831, 1.0))
	_toast.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03, 1.0))
	_toast.add_theme_constant_override("outline_size", 4)
	_toast.anchor_left = 0.5
	_toast.anchor_right = 0.5
	_toast.anchor_top = 0.0
	_toast.anchor_bottom = 0.0
	_toast.offset_left = -240
	_toast.offset_top = 18
	_toast.offset_right = 240
	_toast.offset_bottom = 56
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.visible = false
	add_child(_toast)


func _input(event: InputEvent) -> void:
	if not _capture_enabled():
		return
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode != KEY_F10:
		return
	_capture()


func _process(delta: float) -> void:
	if not _toast.visible:
		return
	_toast_timer -= delta
	if _toast_timer <= 0.0:
		_toast.visible = false


func _capture_enabled() -> bool:
	return OS.is_debug_build() or ProjectSettings.get_setting(
		"debug/beta_screenshot_capture_enabled",
		false
	)


func _capture() -> void:
	var dir_err: int = DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	if dir_err != OK and dir_err != ERR_ALREADY_EXISTS:
		_show_toast("Screenshot failed: cannot create %s (err=%d)" % [SAVE_DIR, dir_err])
		return

	var image: Image = get_viewport().get_texture().get_image()
	if image == null:
		_show_toast("Screenshot failed: viewport texture unavailable")
		return

	var filename: String = "%s_%s.png" % [_timestamp(), _scene_slug()]
	var path: String = "%s/%s" % [SAVE_DIR, filename]
	var save_err: int = image.save_png(path)
	if save_err != OK:
		_show_toast("Screenshot failed: save_png err=%d" % save_err)
		return

	var absolute: String = ProjectSettings.globalize_path(path)
	_show_toast("Saved: %s" % absolute)


func _timestamp() -> String:
	var d: Dictionary = Time.get_datetime_dict_from_system()
	return "%04d%02d%02d_%02d%02d%02d" % [
		int(d.get("year", 0)),
		int(d.get("month", 0)),
		int(d.get("day", 0)),
		int(d.get("hour", 0)),
		int(d.get("minute", 0)),
		int(d.get("second", 0)),
	]


func _scene_slug() -> String:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return "scene"
	var raw: String = String(scene.name).to_lower()
	var sanitized: String = ""
	for i: int in range(raw.length()):
		var codepoint: int = raw.unicode_at(i)
		if (codepoint >= 0x30 and codepoint <= 0x39) \
				or (codepoint >= 0x61 and codepoint <= 0x7A) \
				or codepoint == 0x5F:
			sanitized += char(codepoint)
		elif codepoint == 0x20 or codepoint == 0x2D:
			sanitized += "_"
	if sanitized.is_empty():
		sanitized = "scene"
	if sanitized.length() > _MAX_SLUG_LENGTH:
		sanitized = sanitized.substr(0, _MAX_SLUG_LENGTH)
	return sanitized


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.visible = true
	_toast_timer = TOAST_DURATION
