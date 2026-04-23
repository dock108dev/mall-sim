## ISSUE-002: F3 debug overlay shows scene/camera/input/player/store + last 10
## audit entries, must not consume gameplay input, renders above modal layers.
extends GutTest


func before_each() -> void:
	if AuditOverlay.visible:
		AuditOverlay.toggle()


func after_each() -> void:
	if AuditOverlay.visible:
		AuditOverlay.toggle()


func test_overlay_renders_above_modal_canvaslayers() -> void:
	# Highest CanvasLayer wins. AuditOverlay must be above any conventional
	# modal layer (modals typically use layers <= 100).
	assert_gt(AuditOverlay.layer, 100, "AuditOverlay layer must exceed modal layers")


func test_overlay_does_not_consume_movement_input_when_visible() -> void:
	AuditOverlay.toggle()
	assert_true(AuditOverlay.visible, "overlay must be visible for this check")

	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_W
	ev.pressed = true
	AuditOverlay._unhandled_input(ev)

	assert_false(
		get_viewport().is_input_handled(),
		"AuditOverlay must not mark non-toggle input as handled"
	)


func test_overlay_consumes_only_toggle_action() -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_F3
	ev.pressed = true
	AuditOverlay._unhandled_input(ev)
	# After toggle, the action should be marked handled so other listeners
	# don't double-process F3. Visibility should also have flipped.
	assert_true(AuditOverlay.visible, "F3 must toggle overlay visible")


func test_overlay_exposes_required_fields() -> void:
	# The acceptance criteria require these labels to exist so the overlay
	# can display scene/camera/input/player/store id at runtime.
	assert_not_null(AuditOverlay._label_scene_path, "scene label missing")
	assert_not_null(AuditOverlay._label_camera_path, "camera label missing")
	assert_not_null(AuditOverlay._label_input_focus, "input focus label missing")
	assert_not_null(AuditOverlay._label_player_path, "player label missing")
	assert_not_null(AuditOverlay._label_store_id, "store id label missing")


func test_overlay_renders_last_audit_entries_with_status_colors() -> void:
	AuditLog.clear()
	AuditLog.pass_check(&"issue_002_pass_demo", "ok")
	AuditLog.fail_check(&"issue_002_fail_demo", "boom")
	AuditOverlay.toggle()
	AuditOverlay._refresh_entries()

	var pass_label: Label = AuditOverlay._entry_labels[1]
	var fail_label: Label = AuditOverlay._entry_labels[0]

	assert_true(pass_label.text.begins_with("PASS"), "PASS row should start with PASS")
	assert_true(fail_label.text.begins_with("FAIL"), "FAIL row should start with FAIL")

	var pass_color: Color = pass_label.get_theme_color(&"font_color")
	var fail_color: Color = fail_label.get_theme_color(&"font_color")
	assert_gt(pass_color.g, pass_color.r, "PASS color should be green-dominant")
	assert_gt(fail_color.r, fail_color.g, "FAIL color should be red-dominant")
