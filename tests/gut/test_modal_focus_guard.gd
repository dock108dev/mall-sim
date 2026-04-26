## ISSUE-004: Modal input ownership — SettingsPanel and MilestonesPanel must push
## CTX_MODAL on open, pop it on close, and expose the same _focus_pushed /
## _reset_for_tests contract as InventoryPanel (ISSUE-008).
extends GutTest


const _SETTINGS_SCENE: PackedScene = preload(
	"res://game/scenes/ui/settings_panel.tscn"
)
const _MILESTONES_SCENE: PackedScene = preload(
	"res://game/scenes/ui/milestones_panel.tscn"
)


var _focus: Node
var _panels: Array[Node] = []


func before_each() -> void:
	_focus = get_tree().root.get_node_or_null("InputFocus")
	assert_not_null(_focus, "InputFocus autoload required")
	if _focus != null:
		_focus._reset_for_tests()
	_panels.clear()


func after_each() -> void:
	for panel: Node in _panels:
		if is_instance_valid(panel) and panel.has_method("_reset_for_tests"):
			panel._reset_for_tests()
	_panels.clear()
	if _focus != null and is_instance_valid(_focus):
		_focus._reset_for_tests()


# ── SettingsPanel ────────────────────────────────────────────────────────────


func test_settings_open_pushes_ctx_modal() -> void:
	var panel: SettingsPanel = _make_settings()
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var depth_before: int = _focus.depth()

	panel.open()

	assert_eq(
		_focus.depth(), depth_before + 1,
		"settings open() must push exactly one frame"
	)
	assert_eq(
		_focus.current(), InputFocus.CTX_MODAL,
		"top frame must be CTX_MODAL after settings open()"
	)
	assert_true(panel._focus_pushed, "panel must record it owns a frame")


func test_settings_close_pops_ctx_modal() -> void:
	var panel: SettingsPanel = _make_settings()
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var baseline: int = _focus.depth()
	panel.open()

	panel.close()

	assert_eq(_focus.depth(), baseline, "close() must pop the modal frame")
	assert_eq(
		_focus.current(), InputFocus.CTX_STORE_GAMEPLAY,
		"prior context restored after settings close()"
	)
	assert_false(panel._focus_pushed)


func test_settings_double_open_is_idempotent() -> void:
	var panel: SettingsPanel = _make_settings()
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var baseline: int = _focus.depth()

	panel.open()
	panel.open()

	assert_eq(
		_focus.depth(), baseline + 1,
		"second open() must not push a second frame"
	)
	panel.close()
	assert_eq(_focus.depth(), baseline)


func test_settings_double_close_is_idempotent() -> void:
	var panel: SettingsPanel = _make_settings()
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var baseline: int = _focus.depth()

	panel.open()
	panel.close()
	panel.close()

	assert_eq(_focus.depth(), baseline, "second close() must not pop a frame it does not own")


func test_settings_repeated_open_close_no_leak() -> void:
	var panel: SettingsPanel = _make_settings()
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var baseline: int = _focus.depth()

	for i: int in range(4):
		panel.open()
		assert_eq(_focus.depth(), baseline + 1, "iteration %d: open pushes 1 frame" % i)
		panel.close()
		assert_eq(_focus.depth(), baseline, "iteration %d: close restores baseline" % i)


func test_settings_backdrop_visible_while_open() -> void:
	var panel: SettingsPanel = _make_settings()
	assert_false(panel._backdrop.visible, "backdrop hidden before open")

	panel.open()
	assert_true(panel._backdrop.visible, "backdrop shown when panel open")

	panel.close()
	assert_false(panel._backdrop.visible, "backdrop hidden after close")


func test_settings_reset_for_tests_clears_flag_without_popping() -> void:
	var panel: SettingsPanel = _make_settings()
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	panel.open()
	assert_true(panel._focus_pushed)

	panel._reset_for_tests()

	assert_false(panel._focus_pushed, "_reset_for_tests clears the flag")
	assert_eq(
		_focus.current(), InputFocus.CTX_MODAL,
		"_reset_for_tests must NOT call pop_context"
	)


func test_settings_exit_tree_pops_dangling_frame() -> void:
	var panel: SettingsPanel = _SETTINGS_SCENE.instantiate() as SettingsPanel
	add_child(panel)
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var baseline: int = _focus.depth()
	panel.open()
	assert_eq(_focus.depth(), baseline + 1)

	remove_child(panel)
	panel.free()

	assert_eq(_focus.depth(), baseline, "_exit_tree must pop the dangling CTX_MODAL frame")


func test_settings_ctx_modal_while_open() -> void:
	var panel: SettingsPanel = _make_settings()
	panel.open()
	assert_eq(
		InputFocus.current(),
		InputFocus.CTX_MODAL,
		"InputFocus.current() must return CTX_MODAL while settings is open"
	)
	panel.close()


# ── MilestonesPanel ──────────────────────────────────────────────────────────


func test_milestones_open_pushes_ctx_modal() -> void:
	var panel: MilestonesPanel = _make_milestones()
	_focus.push_context(InputFocus.CTX_MALL_HUB)
	var depth_before: int = _focus.depth()

	panel.open()

	assert_eq(
		_focus.depth(), depth_before + 1,
		"milestones open() must push exactly one frame"
	)
	assert_eq(
		_focus.current(), InputFocus.CTX_MODAL,
		"top frame must be CTX_MODAL after milestones open()"
	)
	assert_true(panel._focus_pushed)


func test_milestones_close_pops_ctx_modal() -> void:
	var panel: MilestonesPanel = _make_milestones()
	_focus.push_context(InputFocus.CTX_MALL_HUB)
	var baseline: int = _focus.depth()
	panel.open()

	panel.close()

	assert_eq(_focus.depth(), baseline, "close() must pop the modal frame")
	assert_eq(
		_focus.current(), InputFocus.CTX_MALL_HUB,
		"prior context restored after milestones close()"
	)
	assert_false(panel._focus_pushed)


func test_milestones_immediate_close_pops_cleanly() -> void:
	var panel: MilestonesPanel = _make_milestones()
	_focus.push_context(InputFocus.CTX_MALL_HUB)
	var baseline: int = _focus.depth()
	panel.open()

	panel.close(true)

	assert_eq(_focus.depth(), baseline, "close(immediate=true) must restore depth")


func test_milestones_double_open_is_idempotent() -> void:
	var panel: MilestonesPanel = _make_milestones()
	_focus.push_context(InputFocus.CTX_MALL_HUB)
	var baseline: int = _focus.depth()

	panel.open()
	panel.open()

	assert_eq(_focus.depth(), baseline + 1, "second open() must not push a second frame")
	panel.close()
	assert_eq(_focus.depth(), baseline)


func test_milestones_repeated_open_close_no_leak() -> void:
	var panel: MilestonesPanel = _make_milestones()
	_focus.push_context(InputFocus.CTX_MALL_HUB)
	var baseline: int = _focus.depth()

	for i: int in range(4):
		panel.open()
		assert_eq(_focus.depth(), baseline + 1, "iteration %d: open pushes 1 frame" % i)
		panel.close(true)
		assert_eq(_focus.depth(), baseline, "iteration %d: close restores baseline" % i)


func test_milestones_backdrop_visible_while_open() -> void:
	var panel: MilestonesPanel = _make_milestones()
	assert_false(panel._backdrop.visible, "backdrop hidden before open")

	panel.open()
	assert_true(panel._backdrop.visible, "backdrop shown when panel open")

	panel.close(true)
	assert_false(panel._backdrop.visible, "backdrop hidden after close")


func test_milestones_sibling_panel_opened_pops_cleanly() -> void:
	var panel: MilestonesPanel = _make_milestones()
	_focus.push_context(InputFocus.CTX_MALL_HUB)
	var baseline: int = _focus.depth()
	panel.open()

	EventBus.panel_opened.emit("inventory")

	assert_eq(
		_focus.depth(), baseline,
		"forced-close from sibling panel_opened must pop the milestones frame"
	)
	assert_false(panel.is_open())
	assert_false(panel._focus_pushed)


func test_milestones_reset_for_tests_clears_flag_without_popping() -> void:
	var panel: MilestonesPanel = _make_milestones()
	_focus.push_context(InputFocus.CTX_MALL_HUB)
	panel.open()
	assert_true(panel._focus_pushed)

	panel._reset_for_tests()

	assert_false(panel._focus_pushed)
	assert_eq(_focus.current(), InputFocus.CTX_MODAL, "_reset_for_tests must NOT pop_context")


func test_milestones_exit_tree_pops_dangling_frame() -> void:
	var panel: MilestonesPanel = _MILESTONES_SCENE.instantiate() as MilestonesPanel
	add_child(panel)
	_focus.push_context(InputFocus.CTX_MALL_HUB)
	var baseline: int = _focus.depth()
	panel.open()
	assert_eq(_focus.depth(), baseline + 1)

	remove_child(panel)
	panel.free()

	assert_eq(_focus.depth(), baseline, "_exit_tree must pop the dangling CTX_MODAL frame")


func test_milestones_ctx_modal_while_open() -> void:
	var panel: MilestonesPanel = _make_milestones()
	panel.open()
	assert_eq(
		InputFocus.current(),
		InputFocus.CTX_MODAL,
		"InputFocus.current() must return CTX_MODAL while milestones panel is open"
	)
	panel.close(true)


# ── Helpers ───────────────────────────────────────────────────────────────────


func _make_settings() -> SettingsPanel:
	var panel: SettingsPanel = _SETTINGS_SCENE.instantiate() as SettingsPanel
	add_child_autofree(panel)
	_panels.append(panel)
	return panel


func _make_milestones() -> MilestonesPanel:
	var panel: MilestonesPanel = _MILESTONES_SCENE.instantiate() as MilestonesPanel
	add_child_autofree(panel)
	_panels.append(panel)
	return panel
