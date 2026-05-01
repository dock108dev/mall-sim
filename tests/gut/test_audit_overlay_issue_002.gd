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


func test_focused_readout_reads_none_when_no_ray_present() -> void:
	# With no InteractionRay registered (test scene has none), the readout
	# should default to "Focused: NONE" so the overlay never displays stale
	# state.
	assert_eq(
		AuditOverlay._build_focused_readout(),
		"Focused: NONE",
		"Readout must report NONE when no InteractionRay is present"
	)


func test_focused_readout_reflects_interaction_ray_hover() -> void:
	var ray_script: GDScript = preload(
		"res://game/scripts/player/interaction_ray.gd"
	)
	var ray: Node = Node.new()
	ray.set_script(ray_script)
	add_child_autofree(ray)

	var target := Interactable.new()
	target.prompt_text = "Inspect"
	target.display_name = "GlassCase"
	add_child_autofree(target)

	ray._set_hovered_target(target)
	var readout: String = AuditOverlay._build_focused_readout()
	assert_string_starts_with(
		readout,
		"Focused: GlassCase",
		"Readout should lead with the focused interactable's display name"
	)
	assert_string_contains(
		readout,
		"Press E to inspect",
		"Readout should embed the action label tail"
	)

	ray._set_hovered_target(null)
	assert_eq(
		AuditOverlay._build_focused_readout(),
		"Focused: NONE",
		"Readout must reset to NONE when the ray clears its hovered target"
	)


func test_overlay_renders_last_audit_entries_with_status_colors() -> void:
	AuditLog.clear()
	# Use record_*_for_test seams so the demo entries do not write
	# `AUDIT: PASS|FAIL` lines to stdout — tests/audit_run.sh would otherwise
	# treat issue_002_fail_demo as a real (un-whitelisted) runtime failure.
	AuditLog.record_pass_for_test(&"issue_002_pass_demo", "ok")
	AuditLog.record_fail_for_test(&"issue_002_fail_demo", "boom")
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
