## Tests that ToastNotificationUI panels match the visual spec from the
## BRAINDUMP toast notification design: rounded dark panel with a 3 px
## category-tinted left border, 12 px horizontal / 8 px vertical padding,
## compact fixed width, uniform 92 % white text at 15 px, and an animation
## contract of 0.15 s slide-in plus 0.4 s fade-out.
extends GutTest


var _ui: ToastNotificationUI


func before_each() -> void:
	_ui = ToastNotificationUI.new()
	_ui.size = Vector2(1152, 648)
	add_child_autofree(_ui)


# ── Card geometry ─────────────────────────────────────────────────────────────


func test_panel_width_is_compact_beta_lane() -> void:
	assert_eq(
		ToastNotificationUI.TOAST_WIDTH, 300.0,
		"Toast panels must stay compact while fitting upper-right lane copy"
	)


func test_panel_min_height_is_compact() -> void:
	# The single-line floor matches the BRAINDUMP "max 60 px tall for
	# single-line" allowance and never grows past the two-line ceiling.
	assert_lte(
		ToastNotificationUI.TOAST_MIN_HEIGHT, 60.0,
		"Toast panels must fit a single line within 60 px"
	)
	assert_lte(
		ToastNotificationUI.TOAST_MAX_HEIGHT, 80.0,
		"Toast panels must cap two-line content at 80 px"
	)


func test_toast_lane_sits_left_of_right_panel() -> void:
	var viewport_width: float = 1152.0
	var right_panel_left: float = (
		viewport_width
		- ToastNotificationUI.TOAST_RIGHT_PANEL_INSET
		- ToastNotificationUI.TOAST_RIGHT_PANEL_WIDTH
	)
	var target_x: float = _ui._target_x_for_viewport(viewport_width)
	assert_lte(
		target_x + ToastNotificationUI.TOAST_WIDTH,
		right_panel_left - ToastNotificationUI.TOAST_RIGHT_PANEL_GAP,
		"Toast lane must not overlap the right panel"
	)
	assert_ne(
		target_x,
		(viewport_width - ToastNotificationUI.TOAST_WIDTH) / 2.0,
		"Toast lane must not be centered like a modal"
	)


func test_toast_lane_sits_left_of_right_panel_at_720p() -> void:
	var viewport_width: float = 1280.0
	var right_panel_left: float = (
		viewport_width
		- ToastNotificationUI.TOAST_RIGHT_PANEL_INSET
		- ToastNotificationUI.TOAST_RIGHT_PANEL_WIDTH
	)
	var target_x: float = _ui._target_x_for_viewport(viewport_width)
	assert_lte(
		target_x + ToastNotificationUI.TOAST_WIDTH,
		right_panel_left - ToastNotificationUI.TOAST_RIGHT_PANEL_GAP,
		"Toast lane must preserve a right-panel gap at 1280 px wide"
	)


func test_visible_toast_rect_does_not_overlap_right_panel_band() -> void:
	EventBus.toast_requested.emit("Training: talk to the manager.", &"system", 3.0)
	var viewport_width: float = _ui.get_viewport_rect().size.x
	var right_panel_left: float = (
		viewport_width
		- ToastNotificationUI.TOAST_RIGHT_PANEL_INSET
		- ToastNotificationUI.TOAST_RIGHT_PANEL_WIDTH
	)
	var rect: Rect2 = _ui.get_active_panel_rect()
	assert_lte(
		rect.position.x + rect.size.x,
		right_panel_left - ToastNotificationUI.TOAST_RIGHT_PANEL_GAP,
		"Rendered toast rect must stop before the right-panel safe zone"
	)


# ── Stylebox spec ─────────────────────────────────────────────────────────────


func test_panel_background_is_dark_translucent() -> void:
	EventBus.toast_requested.emit("Visual check", &"system", 3.0)
	var sb: StyleBoxFlat = _stylebox(_ui._active_panel)
	assert_not_null(sb, "Active panel must own a StyleBoxFlat override")
	if sb:
		assert_eq(
			sb.bg_color, ToastNotificationUI.PANEL_BG_COLOR,
			"Panel background must match the dark semi-transparent spec"
		)
		assert_almost_eq(
			sb.bg_color.a, 0.85, 0.01,
			"Background alpha must be 0.85 (semi-transparent dark)"
		)


func test_panel_corners_are_rounded_six() -> void:
	EventBus.toast_requested.emit("Corner check", &"system", 3.0)
	var sb: StyleBoxFlat = _stylebox(_ui._active_panel)
	assert_not_null(sb)
	if sb:
		for corner: int in [
			sb.corner_radius_top_left,
			sb.corner_radius_top_right,
			sb.corner_radius_bottom_left,
			sb.corner_radius_bottom_right,
		]:
			assert_eq(
				corner, ToastNotificationUI.PANEL_CORNER_RADIUS,
				"Every corner must use the spec radius (6 px)"
			)


func test_panel_has_left_border_only() -> void:
	EventBus.toast_requested.emit("Border check", &"sale", 3.0)
	var sb: StyleBoxFlat = _stylebox(_ui._active_panel)
	assert_not_null(sb)
	if sb:
		assert_eq(
			sb.border_width_left, ToastNotificationUI.LEFT_BORDER_WIDTH,
			"Left border must be 3 px"
		)
		assert_eq(sb.border_width_top, 0, "Top border must be 0 px")
		assert_eq(sb.border_width_right, 0, "Right border must be 0 px")
		assert_eq(sb.border_width_bottom, 0, "Bottom border must be 0 px")


# ── Text spec ────────────────────────────────────────────────────────────────


func test_label_text_color_is_uniform_92_percent_white() -> void:
	EventBus.toast_requested.emit("Text check", &"sale", 3.0)
	var label: Label = _find_label(_ui._active_panel)
	assert_not_null(label)
	if label:
		var color: Color = label.get_theme_color("font_color")
		assert_eq(
			color, ToastNotificationUI.TEXT_COLOR,
			"All toasts must use the uniform 92 % white text colour"
		)


func test_label_font_size_is_15_px() -> void:
	EventBus.toast_requested.emit("Size check", &"system", 3.0)
	var label: Label = _find_label(_ui._active_panel)
	assert_not_null(label)
	if label:
		assert_eq(
			label.get_theme_font_size("font_size"),
			ToastNotificationUI.TEXT_FONT_SIZE,
			"Font size must match the spec (15 px)"
		)


func test_label_is_visible_text_owner_without_covering_button() -> void:
	EventBus.toast_requested.emit("Training: talk to the manager.", &"system", 3.0)
	var label: Label = _find_label(_ui._active_panel)
	assert_not_null(label, "Toast card must contain the visible message label")
	if label:
		assert_eq(label.text, "Training: talk to the manager.")
		assert_true(label.visible, "Toast label must be visible")
		assert_eq(label.modulate.a, 1.0, "Toast label must not be faded out locally")
	assert_eq(
		_find_buttons(_ui._active_panel).size(),
		0,
		"Toast cards must not add a full-rect Button over the text"
	)


func test_label_padding_matches_spec() -> void:
	EventBus.toast_requested.emit("Padding", &"system", 3.0)
	var margin: MarginContainer = _find_margin(_ui._active_panel)
	assert_not_null(margin, "Toast must wrap label in a MarginContainer")
	if margin:
		# Left margin includes the 3 px left border so text doesn't visually
		# crowd the colored stripe.
		assert_eq(
			margin.get_theme_constant("margin_left"),
			ToastNotificationUI.PADDING_HORIZONTAL
				+ ToastNotificationUI.LEFT_BORDER_WIDTH,
			"Left margin must clear the 3 px border plus the 12 px horizontal pad"
		)
		assert_eq(
			margin.get_theme_constant("margin_right"),
			ToastNotificationUI.PADDING_HORIZONTAL,
			"Right margin must match the 12 px horizontal pad"
		)
		assert_eq(
			margin.get_theme_constant("margin_top"),
			ToastNotificationUI.PADDING_VERTICAL,
			"Top margin must match the 8 px vertical pad"
		)
		assert_eq(
			margin.get_theme_constant("margin_bottom"),
			ToastNotificationUI.PADDING_VERTICAL,
			"Bottom margin must match the 8 px vertical pad"
		)


# ── Animation spec ───────────────────────────────────────────────────────────


func test_slide_in_duration_is_quarter_second() -> void:
	# Spec: "slide in from the right edge (0.15 s ease-out) on appear, not
	# snap in." Verifying the const guards against future unintentional drift.
	assert_eq(
		ToastNotificationUI.SLIDE_IN_DURATION, 0.15,
		"Slide-in duration must match the BRAINDUMP spec (0.15 s)"
	)


func test_fade_out_duration_is_four_tenths() -> void:
	# Spec: "fade out over 0.4 s at the end of the display duration."
	assert_eq(
		ToastNotificationUI.FADE_OUT_DURATION, 0.4,
		"Fade-out duration must match the BRAINDUMP spec (0.4 s)"
	)


# ── Helpers ───────────────────────────────────────────────────────────────────


func _stylebox(panel: PanelContainer) -> StyleBoxFlat:
	if not is_instance_valid(panel):
		return null
	return panel.get_theme_stylebox("panel") as StyleBoxFlat


func _find_label(panel: PanelContainer) -> Label:
	if not is_instance_valid(panel):
		return null
	for child: Node in panel.get_children():
		if child is MarginContainer:
			for inner: Node in child.get_children():
				if inner is Label:
					return inner as Label
	return null


func _find_margin(panel: PanelContainer) -> MarginContainer:
	if not is_instance_valid(panel):
		return null
	for child: Node in panel.get_children():
		if child is MarginContainer:
			return child as MarginContainer
	return null


func _find_buttons(root: Node) -> Array[Button]:
	var buttons: Array[Button] = []
	if root == null:
		return buttons
	for child: Node in root.get_children():
		if child is Button:
			buttons.append(child as Button)
		buttons.append_array(_find_buttons(child))
	return buttons
