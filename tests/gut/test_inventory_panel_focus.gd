## ISSUE-008: InventoryPanel pushes/pops InputFocus.CTX_MODAL across open/close.
## Verifies the modal-focus contract: open() pushes exactly one CTX_MODAL frame
## (after emitting panel_opened), close() pops it (before emitting panel_closed),
## depth round-trips on every close path, mutual-exclusion forced-close stays
## consistent, scene_ready force-closes, and _exit_tree cleans up.
extends GutTest

const _INVENTORY_PANEL_SCENE: PackedScene = preload(
	"res://game/scenes/ui/inventory_panel.tscn"
)


var _focus: Node
var _data_loader: DataLoader
var _inventory_system: InventorySystem
var _previous_data_loader: DataLoader
var _previous_store_id: StringName
var _panels: Array[InventoryPanel] = []


func before_each() -> void:
	_focus = get_tree().root.get_node_or_null("InputFocus")
	assert_not_null(_focus, "InputFocus autoload required")
	if _focus != null:
		_focus._reset_for_tests()
	_panels.clear()
	_data_loader = DataLoader.new()
	_data_loader.load_all_content()
	_previous_data_loader = GameManager.data_loader
	_previous_store_id = GameManager.current_store_id
	GameManager.data_loader = _data_loader
	_inventory_system = InventorySystem.new()
	add_child_autofree(_inventory_system)
	_inventory_system.initialize(_data_loader)


func after_each() -> void:
	# Clear panel bookkeeping BEFORE resetting the focus stack so
	# autofreed panels' _exit_tree does not see stale _focus_pushed
	# against an emptied stack.
	for panel: InventoryPanel in _panels:
		if is_instance_valid(panel):
			panel._reset_for_tests()
	_panels.clear()
	GameManager.data_loader = _previous_data_loader
	GameManager.current_store_id = _previous_store_id
	if _focus != null and is_instance_valid(_focus):
		_focus._reset_for_tests()


func _make_panel() -> InventoryPanel:
	var panel: InventoryPanel = (
		_INVENTORY_PANEL_SCENE.instantiate() as InventoryPanel
	)
	panel.inventory_system = _inventory_system
	add_child_autofree(panel)
	_panels.append(panel)
	return panel


func test_open_pushes_ctx_modal_after_emit() -> void:
	var panel: InventoryPanel = _make_panel()
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var depth_before: int = _focus.depth()
	var ctx_before: StringName = _focus.current()
	assert_eq(ctx_before, InputFocus.CTX_STORE_GAMEPLAY)

	panel.open()

	assert_eq(_focus.depth(), depth_before + 1,
		"open() must push exactly one frame")
	assert_eq(_focus.current(), InputFocus.CTX_MODAL,
		"top frame must be CTX_MODAL after open()")
	assert_true(panel._focus_pushed,
		"panel must remember it owns a frame")


func test_close_pops_before_emitting_panel_closed() -> void:
	var panel: InventoryPanel = _make_panel()
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var baseline: int = _focus.depth()
	panel.open()

	# panel_closed must arrive AFTER pop, so subscribers observing
	# InputFocus.current() during close() see the prior context, not CTX_MODAL.
	var observed_ctx_at_close: Array[StringName] = []
	var observer := func(panel_name: String) -> void:
		if panel_name == "inventory":
			observed_ctx_at_close.append(_focus.current())
	EventBus.panel_closed.connect(observer)

	panel.close(true)

	EventBus.panel_closed.disconnect(observer)
	assert_eq(_focus.depth(), baseline,
		"close() must pop the modal frame")
	assert_eq(_focus.current(), InputFocus.CTX_STORE_GAMEPLAY,
		"prior context restored after close()")
	assert_false(panel._focus_pushed)
	assert_eq(observed_ctx_at_close.size(), 1,
		"panel_closed should fire exactly once")
	assert_eq(observed_ctx_at_close[0], InputFocus.CTX_STORE_GAMEPLAY,
		"panel_closed must fire AFTER pop_modal_focus")


func test_immediate_close_round_trips_depth() -> void:
	var panel: InventoryPanel = _make_panel()
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var baseline: int = _focus.depth()
	panel.open()
	panel.close(true)
	assert_eq(_focus.depth(), baseline,
		"close(immediate=true) must restore depth")


func test_repeated_open_close_does_not_leak_frames() -> void:
	var panel: InventoryPanel = _make_panel()
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var baseline: int = _focus.depth()
	for i: int in range(5):
		panel.open()
		assert_eq(_focus.depth(), baseline + 1,
			"iteration %d: open should push 1 frame" % i)
		panel.close(true)
		assert_eq(_focus.depth(), baseline,
			"iteration %d: close should restore baseline" % i)


func test_double_open_is_idempotent() -> void:
	var panel: InventoryPanel = _make_panel()
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var baseline: int = _focus.depth()
	panel.open()
	panel.open()
	assert_eq(_focus.depth(), baseline + 1,
		"second open() must not push a second frame")
	panel.close(true)
	assert_eq(_focus.depth(), baseline)


func test_double_close_is_idempotent() -> void:
	var panel: InventoryPanel = _make_panel()
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var baseline: int = _focus.depth()
	panel.open()
	panel.close(true)
	panel.close(true)
	assert_eq(_focus.depth(), baseline,
		"second close() must not pop a frame it does not own")


func test_forced_close_via_sibling_panel_opened_pops_cleanly() -> void:
	var panel: InventoryPanel = _make_panel()
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var baseline: int = _focus.depth()
	panel.open()
	# Simulate a sibling panel announcing it opened. Inventory's
	# _on_panel_opened must call close(true), which pops cleanly because
	# CTX_MODAL is still on top (sibling has not yet pushed its own frame).
	EventBus.panel_opened.emit("pricing")
	assert_eq(_focus.depth(), baseline,
		"forced-close from sibling panel_opened must pop our frame")
	assert_false(panel.is_open())
	assert_false(panel._focus_pushed)


func test_scene_ready_force_closes_panel() -> void:
	var panel: InventoryPanel = _make_panel()
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var baseline: int = _focus.depth()
	panel.open()
	# Drive the panel's scene_ready listener directly. (Calling
	# SceneRouter.scene_ready.emit() would also trigger InputFocus's
	# deferred audit, which is exercised by its own integration tests.)
	panel._on_scene_ready(&"mall_hub", {})
	assert_false(panel.is_open(),
		"panel must auto-close on scene_ready")
	assert_eq(_focus.depth(), baseline,
		"after scene_ready force-close, only the prior context remains")


func test_exit_tree_pops_dangling_frame() -> void:
	var panel: InventoryPanel = (
		_INVENTORY_PANEL_SCENE.instantiate() as InventoryPanel
	)
	panel.inventory_system = _inventory_system
	add_child(panel)
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var baseline: int = _focus.depth()
	panel.open()
	assert_eq(_focus.depth(), baseline + 1)
	# Free the panel without calling close() first — _exit_tree must clean up.
	remove_child(panel)
	panel.free()
	assert_eq(_focus.depth(), baseline,
		"_exit_tree must pop the dangling CTX_MODAL frame")


func test_reset_for_tests_clears_focus_pushed_without_popping() -> void:
	var panel: InventoryPanel = _make_panel()
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	panel.open()
	assert_true(panel._focus_pushed)
	panel._reset_for_tests()
	assert_false(panel._focus_pushed,
		"_reset_for_tests clears the bookkeeping flag")
	# Stack still has the frame because _reset_for_tests does not pop.
	# Pair this with InputFocus._reset_for_tests() to fully reset.
	assert_eq(_focus.current(), InputFocus.CTX_MODAL,
		"_reset_for_tests must NOT call pop_context")
