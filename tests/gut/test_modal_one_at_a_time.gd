## Enforces the "one blocking modal at a time" invariant across the beta
## Day-1 critical path. Three contracts are covered:
##
##   1. CheckoutPanel.show_checkout() refuses to open when ModalQueue is
##      already busy (a higher-priority panel is on screen). The CTX_MODAL
##      depth must stay at 1 — no orphaned frame can leak into the next
##      modal's lifetime.
##   2. BetaDaySummaryPanel routes through ModalQueue at DAY_SUMMARY
##      priority and dedups on repeated requests for the same panel
##      instance, so a double-invoke of the close-day handler can never
##      enqueue two summary requests.
##   3. InteractionPrompt's `_can_show()` returns false while CTX_MODAL is
##      the active context, so the bottom prompt cannot bleed through a
##      modal.
extends GutTest


const CheckoutPanelScene: PackedScene = preload(
	"res://game/scenes/ui/checkout_panel.tscn"
)
const BetaDaySummaryPanelScript: GDScript = preload(
	"res://game/scripts/beta/beta_day_summary_panel.gd"
)
const InteractionPromptScene: PackedScene = preload(
	"res://game/scenes/ui/interaction_prompt.tscn"
)
const ModalPanelScript: GDScript = preload(
	"res://game/scripts/ui/modal_panel.gd"
)


var _focus: Node
var _queue: Node
var _items: Array[Dictionary]


func before_each() -> void:
	_focus = get_tree().root.get_node_or_null("InputFocus")
	_queue = get_tree().root.get_node_or_null("ModalQueue")
	assert_not_null(_focus, "InputFocus autoload required")
	assert_not_null(_queue, "ModalQueue autoload required")
	if _focus != null:
		_focus._reset_for_tests()
	if _queue != null:
		_queue._reset_for_tests()
	_items = [{
		"item_name": "Test Card",
		"condition": "Near Mint",
		"price": 25.50,
	}]


func after_each() -> void:
	if _queue != null and is_instance_valid(_queue):
		_queue._reset_for_tests()
	if _focus != null and is_instance_valid(_focus):
		_focus._reset_for_tests()


# ── CheckoutPanel defers when ModalQueue is busy ────────────────────────────

func test_checkout_does_not_open_when_modal_queue_is_busy() -> void:
	# Park a non-checkout ModalPanel on the queue at DAY_SUMMARY priority so
	# `ModalQueue.is_busy()` returns true and CTX_MODAL is owned by another
	# panel.
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var blocker: ModalPanel = ModalPanelScript.new() as ModalPanel
	blocker.visible = false
	add_child_autofree(blocker)
	_queue.request_open(blocker, _queue.Priority.DAY_SUMMARY)
	assert_true(_queue.is_busy(), "blocker must own the queue")
	var depth_before: int = _focus.depth()

	var checkout: CheckoutPanel = (
		CheckoutPanelScene.instantiate() as CheckoutPanel
	)
	add_child_autofree(checkout)
	checkout.show_checkout(_items)

	assert_false(
		checkout.is_open(),
		"show_checkout must refuse to open while ModalQueue is busy"
	)
	assert_eq(
		_focus.depth(), depth_before,
		"refused show_checkout must not push a second CTX_MODAL frame"
	)
	assert_false(
		checkout._focus_pushed,
		"refused show_checkout must not mark itself as owning a frame"
	)
	blocker.close()


func test_checkout_refusal_emits_sale_declined() -> void:
	# CheckoutSystem treats `checkout_started → sale_declined` as a no-sale
	# resolution. Emitting on refusal lets the pipeline state machine drain
	# instead of stranding the customer mid-checkout.
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var blocker: ModalPanel = ModalPanelScript.new() as ModalPanel
	blocker.visible = false
	add_child_autofree(blocker)
	_queue.request_open(blocker, _queue.Priority.DAY_SUMMARY)

	var checkout: CheckoutPanel = (
		CheckoutPanelScene.instantiate() as CheckoutPanel
	)
	add_child_autofree(checkout)
	watch_signals(checkout)
	checkout.show_checkout(_items)

	assert_signal_emitted(
		checkout, "sale_declined",
		"Refused show_checkout must emit sale_declined so the pipeline drains"
	)
	blocker.close()


func test_checkout_opens_normally_when_queue_is_idle() -> void:
	# Negative control: when ModalQueue is empty, show_checkout still works
	# exactly as before — the gate only fires for the busy case.
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	assert_false(_queue.is_busy(), "queue must start idle")
	var depth_before: int = _focus.depth()

	var checkout: CheckoutPanel = (
		CheckoutPanelScene.instantiate() as CheckoutPanel
	)
	add_child_autofree(checkout)
	checkout.show_checkout(_items)

	assert_true(checkout.is_open(), "show_checkout must open when queue is idle")
	assert_eq(
		_focus.depth(), depth_before + 1,
		"normal show_checkout must push exactly one CTX_MODAL frame"
	)
	checkout.hide_checkout(true)


# ── BetaDaySummaryPanel idempotency ─────────────────────────────────────────

func test_summary_dedups_repeated_show_requests() -> void:
	# Calling `show_summary` twice on the same panel must not enqueue a
	# second request — ModalQueue dedups by panel instance. This guards the
	# `_on_day_close_confirmed → _summary_spawned` controller-side guard:
	# even if a re-emit slips past, the queue refuses to double-stack.
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var panel: BetaDaySummaryPanel = (
		BetaDaySummaryPanelScript.new() as BetaDaySummaryPanel
	)
	add_child_autofree(panel)
	var payload: Dictionary = {
		"day": 1,
		"cash": 0,
		"cash_delta": 0,
		"starting_cash": 0,
		"sales_revenue": 0,
		"rent_paid": 50,
		"net_profit": -50,
		"customers_helped": 0,
		"items_stocked": 0,
		"sales_completed": 0,
		"shelf_inventory_remaining": 0,
		"backroom_inventory_remaining": 0,
		"shift_note": "",
		"hidden_thread_note": "",
		"reputation_delta": 0,
	}

	panel.show_summary(payload)
	panel.show_summary(payload)

	assert_eq(
		_queue.active_panel(), panel,
		"the only active panel must be the single summary instance"
	)
	assert_eq(
		_queue.pending_count(), 0,
		"the second show_summary call must not enqueue a duplicate entry"
	)
	panel.close()


func test_modal_queue_depth_stays_at_one_during_summary() -> void:
	# Defends the "no orphaned CTX_MODAL frames after any combination of
	# checkout + queued modal" acceptance criterion: opening the summary,
	# attempting to open checkout (which must refuse), then closing the
	# summary returns the InputFocus depth to its pre-modal baseline.
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var baseline: int = _focus.depth()
	var summary: BetaDaySummaryPanel = (
		BetaDaySummaryPanelScript.new() as BetaDaySummaryPanel
	)
	add_child_autofree(summary)
	summary.show_summary({"day": 1})

	# While the summary owns CTX_MODAL the depth is baseline + 1.
	assert_eq(_focus.depth(), baseline + 1)
	assert_eq(_focus.current(), InputFocus.CTX_MODAL)

	# Attempt to open checkout — must refuse without pushing a second frame.
	var checkout: CheckoutPanel = (
		CheckoutPanelScene.instantiate() as CheckoutPanel
	)
	add_child_autofree(checkout)
	checkout.show_checkout(_items)
	assert_eq(
		_focus.depth(), baseline + 1,
		"checkout refusal must not push a second CTX_MODAL frame"
	)

	summary.close()
	assert_eq(
		_focus.depth(), baseline,
		"after summary close the InputFocus depth must return to baseline"
	)


# ── BetaDaySummaryPanel renders Money/Rent/Profit lines ─────────────────────

func test_summary_renders_rent_sales_profit_lines() -> void:
	# BRAINDUMP First-Day Flow Step 6 — rent / sales / profit must be
	# legible on the summary surface. The Money RichTextLabel template
	# binds them as integers so the assertions check substring presence
	# rather than exact format (typography may shift in future passes).
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var panel: BetaDaySummaryPanel = (
		BetaDaySummaryPanelScript.new() as BetaDaySummaryPanel
	)
	add_child_autofree(panel)
	panel.show_summary({
		"day": 1,
		"cash": 150,
		"cash_delta": 100,
		"starting_cash": 50,
		"sales_revenue": 100,
		"rent_paid": 50,
		"net_profit": 50,
	})

	var metrics: RichTextLabel = (
		panel.get("_metrics_label") as RichTextLabel
	)
	assert_not_null(metrics, "Panel must own _metrics_label")
	if metrics == null:
		return
	var text: String = metrics.text
	assert_true(
		text.contains("Sales") and text.contains("100"),
		"Money section must render Sales line; got: '%s'" % text
	)
	assert_true(
		text.contains("Rent") and text.contains("50"),
		"Money section must render Rent line; got: '%s'" % text
	)
	assert_true(
		text.contains("Profit"),
		"Money section must render Profit line; got: '%s'" % text
	)
	panel.close()


func test_summary_renders_negative_profit_with_sign() -> void:
	# Zero-sales Day 1 with non-zero rent must read as a loss, not as "+$50".
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var panel: BetaDaySummaryPanel = (
		BetaDaySummaryPanelScript.new() as BetaDaySummaryPanel
	)
	add_child_autofree(panel)
	panel.show_summary({
		"day": 1,
		"cash": -50,
		"cash_delta": -50,
		"starting_cash": 0,
		"sales_revenue": 0,
		"rent_paid": 50,
		"net_profit": -50,
	})

	var metrics: RichTextLabel = (
		panel.get("_metrics_label") as RichTextLabel
	)
	if metrics == null:
		return
	var text: String = metrics.text
	assert_true(
		text.contains("Profit") and text.contains("-$50"),
		"Loss day must render Profit with a minus sign; got: '%s'" % text
	)
	panel.close()


# ── InteractionPrompt hides while CTX_MODAL is active ───────────────────────

func test_interaction_prompt_hidden_while_ctx_modal_active() -> void:
	# Walks the prompt through the exact runtime path: an active
	# interactable focus fires `_on_interactable_focused`, then a CTX_MODAL
	# push fires `_on_input_focus_changed` via the autoload's signal. The
	# panel must end up not visible.
	#
	# InteractionPrompt._can_show() suppresses in MAIN_MENU/DAY_SUMMARY, and
	# the default GameManager state when no prior test set one is MAIN_MENU.
	# Force STORE_VIEW so the gameplay-context branch is exercised, then
	# restore so siblings don't leak.
	var saved_state: GameManager.State = GameManager.current_state
	GameManager.current_state = GameManager.State.STORE_VIEW
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var prompt: CanvasLayer = (
		InteractionPromptScene.instantiate() as CanvasLayer
	)
	add_child_autofree(prompt)
	await get_tree().process_frame
	# Sanity: in gameplay context the prompt can show when focused.
	prompt._on_interactable_focused("Press E to use")
	await get_tree().process_frame
	var inner_panel: PanelContainer = (
		prompt.get("_panel") as PanelContainer
	)
	assert_not_null(inner_panel, "Prompt must own an inner _panel")
	if inner_panel == null:
		GameManager.current_state = saved_state
		return
	assert_true(
		inner_panel.visible,
		"Prompt must be visible while a target is focused in gameplay context"
	)

	# Push CTX_MODAL — the prompt's `_on_input_focus_changed` listener must
	# call `_refresh_visibility`, which `_can_show` will deny, fading the
	# panel out.
	_focus.push_context(InputFocus.CTX_MODAL)
	await get_tree().process_frame
	assert_false(
		prompt._can_show(),
		"_can_show() must return false while CTX_MODAL is on top"
	)
	GameManager.current_state = saved_state


func test_interaction_prompt_resumes_after_ctx_modal_pop() -> void:
	# Mirror of the above — popping CTX_MODAL must let the prompt show
	# again on the same hovered target. Force STORE_VIEW so _can_show()
	# clears its game-state guard.
	var saved_state: GameManager.State = GameManager.current_state
	GameManager.current_state = GameManager.State.STORE_VIEW
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var prompt: CanvasLayer = (
		InteractionPromptScene.instantiate() as CanvasLayer
	)
	add_child_autofree(prompt)
	await get_tree().process_frame
	prompt._on_interactable_focused("Press E to use")
	_focus.push_context(InputFocus.CTX_MODAL)
	await get_tree().process_frame
	assert_false(prompt._can_show(), "blocked while CTX_MODAL is on top")

	_focus.pop_context()
	await get_tree().process_frame
	assert_true(
		prompt._can_show(),
		"_can_show() must return true again after CTX_MODAL is popped"
	)
	GameManager.current_state = saved_state


# ── Named-version contracts (ISSUE-010 ACs) ─────────────────────────────────
# Same surface area as the tests above, named per the acceptance criteria so
# the AC checklist resolves directly against a passing test function.

func test_checkout_panel_deferred_when_modal_queue_busy() -> void:
	# AC: open a queued modal, trigger checkout_started, assert
	# CheckoutPanel.show_checkout() defers/rejects when ModalQueue.is_busy().
	# The deferred call must not push a second CTX_MODAL frame and must emit
	# sale_declined so the upstream CheckoutSystem pipeline can drain.
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var blocker: ModalPanel = ModalPanelScript.new() as ModalPanel
	blocker.visible = false
	add_child_autofree(blocker)
	_queue.request_open(blocker, _queue.Priority.DAY_SUMMARY)
	assert_true(
		_queue.is_busy(),
		"Pre-condition: ModalQueue must be busy after the blocker is enqueued"
	)
	var depth_before: int = _focus.depth()

	var checkout: CheckoutPanel = (
		CheckoutPanelScene.instantiate() as CheckoutPanel
	)
	add_child_autofree(checkout)
	watch_signals(checkout)

	# Drive the checkout open through the CheckoutSystem's checkout_started
	# signal so the deferral path under test matches the runtime entry point
	# rather than a direct show_checkout() call.
	EventBus.checkout_started.emit(_items, checkout)
	await get_tree().process_frame

	assert_false(
		checkout.is_open(),
		"show_checkout (via checkout_started) must defer while ModalQueue is busy"
	)
	assert_eq(
		_focus.depth(), depth_before,
		"Deferred show_checkout must not push a second CTX_MODAL frame"
	)
	assert_false(
		checkout._focus_pushed,
		"Deferred show_checkout must not mark itself as owning a CTX_MODAL frame"
	)
	assert_signal_emitted(
		checkout, "sale_declined",
		"Deferred show_checkout must emit sale_declined so the pipeline drains"
	)
	blocker.close()


func test_interaction_prompt_hidden_during_ctx_modal() -> void:
	# AC: push CTX_MODAL via InputFocus; assert InteractionPrompt is hidden;
	# pop CTX_MODAL; assert InteractionPrompt is shown again on the same
	# hovered target. Drives the inner PanelContainer's visibility directly
	# so the assertions cover the visible-state contract rather than only
	# the `_can_show()` guard.
	#
	# Game state is set explicitly so the test works in isolation —
	# InteractionPrompt suppresses itself in MAIN_MENU/DAY_SUMMARY, and the
	# default state when no prior test has set one is MAIN_MENU. Restored
	# after the test so we don't leak into siblings in this file.
	var saved_state: GameManager.State = GameManager.current_state
	GameManager.current_state = GameManager.State.STORE_VIEW
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var prompt: CanvasLayer = (
		InteractionPromptScene.instantiate() as CanvasLayer
	)
	add_child_autofree(prompt)
	await get_tree().process_frame
	prompt._on_interactable_focused("Press E to use")
	await get_tree().process_frame
	var inner_panel: PanelContainer = prompt.get("_panel") as PanelContainer
	assert_not_null(inner_panel, "Prompt must own an inner _panel")
	if inner_panel == null:
		GameManager.current_state = saved_state
		return
	assert_true(
		inner_panel.visible,
		"Pre-condition: prompt must be visible while focused in gameplay context"
	)

	_focus.push_context(InputFocus.CTX_MODAL)
	# The fade-out tween lands on `_panel.hide` via tween_callback; wait
	# past the FADE_DURATION (0.15 s) so the hide callback runs before the
	# visibility assertion.
	await get_tree().create_timer(0.2).timeout
	assert_false(
		inner_panel.visible,
		"InteractionPrompt must be hidden while CTX_MODAL is on the focus stack"
	)

	_focus.pop_context()
	# The fade-in side runs synchronously inside `_refresh_visibility` —
	# `_panel.visible = true` is set before the tween starts, so a single
	# process frame is enough for the assertion.
	await get_tree().process_frame
	assert_true(
		inner_panel.visible,
		"InteractionPrompt must reappear after CTX_MODAL is popped with a focus target still set"
	)
	GameManager.current_state = saved_state
