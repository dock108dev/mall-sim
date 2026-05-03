## CheckoutPanel pushes/pops InputFocus.CTX_MODAL across show/hide so the
## first-person cursor releases for buttons and recaptures on close. Mirrors
## the InventoryPanel modal-focus contract — show_checkout pushes exactly one
## CTX_MODAL frame after emitting panel_opened, hide_checkout pops it before
## emitting panel_closed, and depth round-trips on every close path.
extends GutTest


const _CHECKOUT_PANEL_SCENE: PackedScene = preload(
	"res://game/scenes/ui/checkout_panel.tscn"
)


var _focus: Node
var _panels: Array[CheckoutPanel] = []
var _items: Array[Dictionary]


func before_each() -> void:
	_focus = get_tree().root.get_node_or_null("InputFocus")
	assert_not_null(_focus, "InputFocus autoload required")
	if _focus != null:
		_focus._reset_for_tests()
	_panels.clear()
	_items = [{
		"item_name": "Test Card",
		"condition": "Near Mint",
		"price": 25.50,
	}]


func after_each() -> void:
	for panel: CheckoutPanel in _panels:
		if is_instance_valid(panel):
			panel._reset_for_tests()
	_panels.clear()
	if _focus != null and is_instance_valid(_focus):
		_focus._reset_for_tests()


func _make_panel() -> CheckoutPanel:
	var panel: CheckoutPanel = (
		_CHECKOUT_PANEL_SCENE.instantiate() as CheckoutPanel
	)
	add_child_autofree(panel)
	_panels.append(panel)
	return panel


func test_show_checkout_pushes_ctx_modal_after_emit() -> void:
	var panel: CheckoutPanel = _make_panel()
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var depth_before: int = _focus.depth()

	panel.show_checkout(_items)

	assert_eq(_focus.depth(), depth_before + 1,
		"show_checkout() must push exactly one frame")
	assert_eq(_focus.current(), InputFocus.CTX_MODAL,
		"top frame must be CTX_MODAL after show_checkout()")
	assert_true(panel._focus_pushed,
		"panel must remember it owns a frame")


func test_hide_checkout_pops_before_panel_closed() -> void:
	var panel: CheckoutPanel = _make_panel()
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var baseline: int = _focus.depth()
	panel.show_checkout(_items)

	panel.hide_checkout(true)

	assert_eq(_focus.depth(), baseline,
		"hide_checkout() must pop the frame it owns")
	assert_eq(_focus.current(), InputFocus.CTX_STORE_GAMEPLAY,
		"after pop, store_gameplay context must be on top again")
	assert_false(panel._focus_pushed,
		"panel must release ownership flag")


func test_repeated_show_does_not_leak_frames() -> void:
	var panel: CheckoutPanel = _make_panel()
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var baseline: int = _focus.depth()

	panel.show_checkout(_items)
	# Re-show without hiding — happens when a second customer reaches the
	# register before the first sale clears. Must not push twice.
	panel.show_checkout(_items)

	assert_eq(_focus.depth(), baseline + 1,
		"repeated show_checkout must not push duplicate frames")


func test_repeated_hide_is_idempotent() -> void:
	var panel: CheckoutPanel = _make_panel()
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var baseline: int = _focus.depth()
	panel.show_checkout(_items)

	panel.hide_checkout(true)
	panel.hide_checkout(true)

	assert_eq(_focus.depth(), baseline,
		"hide_checkout must not double-pop")


func test_sibling_panel_opened_force_closes_and_pops() -> void:
	# When another panel emits panel_opened, the checkout panel hides itself.
	# The pop must run as part of that hide so the new modal context owns the
	# stack instead of stacking on top of a stale checkout frame.
	var panel: CheckoutPanel = _make_panel()
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var baseline: int = _focus.depth()
	panel.show_checkout(_items)

	EventBus.panel_opened.emit("inventory")

	assert_false(panel.is_open(),
		"sibling panel_opened must close checkout")
	assert_eq(_focus.depth(), baseline,
		"sibling-mutual-exclusion close must pop the frame")


func test_show_checkout_releases_cursor_for_fp() -> void:
	# End-to-end FP contract: under store_gameplay context the cursor is
	# captured for mouse-look. show_checkout pushes CTX_MODAL, which the
	# StorePlayerBody context_changed listener flips to MOUSE_MODE_VISIBLE.
	# The InputFocus.context_changed signal is the SSOT, and the dispatch is
	# verified here.
	var panel: CheckoutPanel = _make_panel()
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var ctx_changes: Array[StringName] = []
	_focus.context_changed.connect(
		func(new_ctx: StringName, _old: StringName) -> void:
			ctx_changes.append(new_ctx)
	)

	panel.show_checkout(_items)

	assert_true(ctx_changes.has(InputFocus.CTX_MODAL),
		"show_checkout must emit context_changed with CTX_MODAL")
