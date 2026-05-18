extends GutTest

const SCENE_PATH: String = "res://game/scenes/stores/retro_games.tscn"
const PROMPT_SCENE_PATH: String = "res://game/scenes/ui/interaction_prompt.tscn"
const EVENT_ID: String = "day01_wrong_console_parent"
const REQUIRED_VISIBLE_ZONE_LABELS: Array[String] = [
	"CHECKOUT",
	"SHELVES",
	"STAFF PICKS",
	"TRADE-INS",
	"BACKROOM",
]

var _root: Node3D = null
var _saved_state: GameManager.State
var _saved_day: int


func before_each() -> void:
	_saved_state = GameManager.current_state
	_saved_day = GameManager.get_current_day()
	GameManager.current_state = GameManager.State.STORE_VIEW
	GameManager.set_current_day(1)
	BetaRunState.reset_new_run()
	InputFocus._reset_for_tests()
	ModalQueue._reset_for_tests()
	_register_unlock_entries()
	var scene: PackedScene = load(SCENE_PATH)
	assert_not_null(scene, "Retro Games scene must load")
	if scene == null:
		return
	_root = scene.instantiate() as Node3D
	add_child(_root)
	await get_tree().process_frame
	await get_tree().process_frame


func after_each() -> void:
	ModalQueue._reset_for_tests()
	InputFocus._reset_for_tests()
	if is_instance_valid(_root):
		_root.free()
	_root = null
	BetaRunState.reset_new_run()
	GameManager.current_state = _saved_state
	GameManager.set_current_day(_saved_day)


func test_day_one_prompts_are_visible_only_on_the_active_beat() -> void:
	var controller: BetaDayOneController = _controller()
	if controller == null:
		return

	_assert_active_prompt("BetaDayOneCustomer", "Talk to customer")
	_assert_inactive("BetaBackroomPickup")
	_assert_inactive("BetaRestockShelf")
	_assert_inactive("BetaDayEndTrigger")

	await _choose_customer_option(&"refuse_return")
	await _acknowledge_customer_result()
	_assert_active_prompt("BetaBackroomPickup", "Check back room inventory")
	_assert_inactive("BetaDayOneCustomer")
	_assert_inactive("BetaRestockShelf")
	_assert_inactive("BetaDayEndTrigger")

	controller.on_beta_backroom_pickup_interacted()
	await get_tree().process_frame
	_assert_active_prompt("BetaRestockShelf", "Stock shelf")
	assert_true(BetaRunState.carrying_stock, "Back-room pickup must set carrying state")

	controller.on_beta_restock_interacted()
	await get_tree().process_frame
	_assert_active_prompt("BetaDayEndTrigger", "Close day")
	_assert_inactive("BetaBackroomPickup")
	_assert_inactive("BetaRestockShelf")


func test_decision_modal_opens_from_customer_interaction_with_authored_data() -> void:
	var prompt: CanvasLayer = load(PROMPT_SCENE_PATH).instantiate() as CanvasLayer
	add_child_autofree(prompt)
	EventBus.interactable_focused.emit("[E] Talk to customer")
	assert_true(
		(prompt.get_node("PanelContainer") as PanelContainer).visible,
		"Precondition: interaction prompt is visible before the modal opens"
	)

	var controller: BetaDayOneController = _controller()
	if controller == null:
		return
	controller.on_beta_customer_interacted()
	await get_tree().process_frame

	var decision: BetaDecisionCardPanel = controller.get("_decision_panel") as BetaDecisionCardPanel
	assert_not_null(decision, "Customer interaction must own a decision modal")
	if decision == null:
		return
	assert_true(decision.visible, "Customer interaction must open the decision modal")
	assert_eq(InputFocus.current(), InputFocus.CTX_MODAL)
	assert_eq(
		String((controller.get("_active_event") as Dictionary).get("id", "")),
		EVENT_ID,
		"Decision modal must be sourced from the Day 1 customer event"
	)
	assert_eq((decision.get("_title_label") as Label).text, "Wrong Platform")
	assert_string_contains(
		(decision.get("_body_label") as RichTextLabel).text,
		"sealed copy",
		"Modal body must render the authored customer-event body copy"
	)
	var buttons: Array = decision.get("_choice_buttons") as Array
	assert_eq(buttons.size(), 3, "All three customer choices must render")
	assert_eq(get_viewport().gui_get_focus_owner(), buttons[0])

	await get_tree().create_timer(0.2).timeout
	assert_false(
		(prompt.get_node("PanelContainer") as PanelContainer).visible,
		"Interaction prompt must be suppressed while the decision modal owns focus"
	)


func test_clean_exchange_result_acknowledges_without_modal_leak() -> void:
	await _assert_choice_result_flow(&"clean_exchange", "Exchange Accepted")


func test_upsell_bundle_result_acknowledges_without_modal_leak() -> void:
	await _assert_choice_result_flow(&"upsell_bundle", "Bundle Sold")


func test_refuse_return_result_acknowledges_without_modal_leak() -> void:
	await _assert_choice_result_flow(&"refuse_return", "Exchange Refused")


func test_restock_requires_carrying_and_repeated_stocking_does_not_duplicate() -> void:
	var controller: BetaDayOneController = _controller()
	if controller == null:
		return
	await _choose_customer_option(&"refuse_return")
	await _acknowledge_customer_result()
	controller.set("_stage", BetaDayOneController.STAGE_STOCK_SHELF)
	BetaRunState.carrying_stock = false

	controller.on_beta_restock_interacted()
	await get_tree().process_frame
	assert_false(
		bool(controller.is_objective_completed(&"stock_shelf")),
		"Stocking must fail closed when the player is not carrying stock"
	)
	assert_eq(_spawned_shelf_item_count(), 0, "No shelf stock may appear without carry state")

	BetaRunState.carrying_stock = true
	controller.on_beta_restock_interacted()
	await get_tree().process_frame
	var first_count: int = _spawned_shelf_item_count()
	assert_gt(first_count, 0, "Successful stocking must spawn visible shelf items")
	controller.on_beta_restock_interacted()
	await get_tree().process_frame
	assert_eq(
		_spawned_shelf_item_count(),
		first_count,
		"Repeated stocking input must not duplicate visible shelf items"
	)


func test_summary_continue_routes_to_day_two_placeholder_without_content_dependency() -> void:
	var controller: BetaDayOneController = _controller()
	if controller == null:
		return
	controller._on_choice_selected(&"refuse_return", {"cash": 0, "reputation": -3})
	await get_tree().process_frame
	controller.on_beta_backroom_pickup_interacted()
	await get_tree().process_frame
	controller.on_beta_restock_interacted()
	await get_tree().process_frame
	controller.set("_events_by_day", {1: controller.get("_day_events")})
	controller._on_day_close_confirmed()
	await get_tree().process_frame

	var summary: BetaDaySummaryPanel = controller.get("_summary_panel") as BetaDaySummaryPanel
	assert_not_null(summary, "Close day must open the summary panel")
	if summary == null:
		return
	assert_true(summary.visible)
	assert_eq((summary.get("_title_label") as Label).text, "Day 1 Summary")
	assert_string_contains((summary.get("_metrics_label") as RichTextLabel).text, "Sales:")
	assert_eq((summary.get("_continue_button") as Button).text, "Continue to next day")

	(summary.get("_continue_button") as Button).pressed.emit()
	await get_tree().process_frame
	var placeholder: ModalPanel = controller.get("_day_two_placeholder_panel") as ModalPanel
	assert_not_null(placeholder, "Continue must route to a Day 2 placeholder panel")
	if placeholder == null:
		return
	assert_true(placeholder.visible, "Missing Day 2 content must not soft-lock Continue")
	assert_eq(BetaRunState.day, 2)
	assert_eq(GameManager.get_current_day(), 2)
	assert_eq(InputFocus.current(), InputFocus.CTX_MODAL)


func test_required_zone_labels_props_and_debug_surfaces_are_validation_ready() -> void:
	for expected_text: String in REQUIRED_VISIBLE_ZONE_LABELS:
		var label: Label3D = _visible_label_with_text(expected_text)
		assert_not_null(label, "%s zone label must exist and be visible" % expected_text)
		if label != null:
			assert_gte(label.pixel_size, 0.007, "%s must remain readable" % expected_text)

	var props: Node = _root.get_node_or_null("ReadabilityProps")
	assert_not_null(props, "ReadabilityProps must ship with the Day 1 scene")
	if props != null:
		for path: String in [
			"DayOneRouteMarkers",
			"FloorDisplayIsland",
			"WallPosters",
			"CartRackProductStacks",
		]:
			var prop_node: Node = props.get_node_or_null(path)
			assert_not_null(prop_node, "ReadabilityProps/%s must exist" % path)
			assert_true(
				prop_node is Node3D and (prop_node as Node3D).visible,
				"ReadabilityProps/%s must be visible by default" % path
			)

	var debug_overlay: CanvasLayer = _controller().get("_debug_overlay") as CanvasLayer
	assert_not_null(debug_overlay, "Beta debug overlay must be available for QA capture mode")
	if debug_overlay != null:
		var panel: PanelContainer = debug_overlay.get("_panel") as PanelContainer
		assert_not_null(panel, "Debug overlay must own a panel")
		if panel != null:
			assert_false(panel.visible, "Debug overlay must be hidden by default")


func test_new_game_reset_clears_day_cash_flags_and_carry_state() -> void:
	BetaRunState.day = 2
	BetaRunState.cash = 99
	BetaRunState.carrying_stock = true
	BetaRunState.flags[&"choice_refuse_return"] = true
	GameManager.begin_new_run()

	assert_eq(BetaRunState.day, 1)
	assert_eq(BetaRunState.cash, 0)
	assert_false(BetaRunState.carrying_stock)
	assert_true(BetaRunState.flags.is_empty(), "New Game reset must clear prior run flags")
	assert_eq(GameManager.get_current_day(), 1)


func _assert_choice_result_flow(choice_id: StringName, expected_headline: String) -> void:
	await _choose_customer_option(choice_id)
	var controller: BetaDayOneController = _controller()
	var result: ModalPanel = controller.get("_customer_result_panel") as ModalPanel
	assert_not_null(result, "Customer choice must open a result screen")
	if result == null:
		return
	assert_true(result.visible)
	assert_eq((result.get("_title_label") as Label).text, expected_headline)
	assert_eq(BetaRunState.input_mode, BetaRunState.INPUT_MODE_CUSTOMER_RESULT)
	assert_eq(controller.current_stage(), BetaDayOneController.STAGE_TALK_TO_CUSTOMER)

	await _acknowledge_customer_result()
	assert_false(result.visible, "Acknowledgement must close the customer result")
	assert_eq(BetaRunState.input_mode, BetaRunState.INPUT_MODE_GAMEPLAY)
	assert_ne(InputFocus.current(), InputFocus.CTX_MODAL)
	assert_eq(controller.current_stage(), BetaDayOneController.STAGE_BACK_ROOM_INVENTORY)


func _choose_customer_option(choice_id: StringName) -> void:
	var controller: BetaDayOneController = _controller()
	if controller == null:
		return
	controller.on_beta_customer_interacted()
	await get_tree().process_frame
	var decision: BetaDecisionCardPanel = controller.get("_decision_panel") as BetaDecisionCardPanel
	assert_not_null(decision, "Decision card must open before selecting a choice")
	if decision == null:
		return
	var button: Button = _choice_button(decision, choice_id)
	assert_not_null(button, "Choice button %s must exist" % String(choice_id))
	if button == null:
		return
	button.pressed.emit()
	await get_tree().process_frame


func _acknowledge_customer_result() -> void:
	var controller: BetaDayOneController = _controller()
	if controller == null:
		return
	var result: ModalPanel = controller.get("_customer_result_panel") as ModalPanel
	assert_not_null(result, "Customer result must exist before acknowledgement")
	if result == null:
		return
	var button: Button = result.get("_continue_button") as Button
	assert_not_null(button, "Customer result must own Continue")
	if button == null:
		return
	button.pressed.emit()
	await get_tree().process_frame


func _choice_button(decision: BetaDecisionCardPanel, choice_id: StringName) -> Button:
	var event_data: Dictionary = _controller().get("_active_event") as Dictionary
	var choices: Array = event_data.get("choices", []) as Array
	var buttons: Array = decision.get("_choice_buttons") as Array
	for idx: int in range(choices.size()):
		var choice: Dictionary = choices[idx] as Dictionary
		if StringName(str(choice.get("id", ""))) == choice_id and idx < buttons.size():
			return buttons[idx] as Button
	return null


func _assert_active_prompt(parent_name: String, expected_label: String) -> void:
	var interactable: Interactable = _interactable(parent_name)
	assert_not_null(interactable, "%s/Interactable must exist" % parent_name)
	if interactable == null:
		return
	assert_true(interactable.enabled, "%s must be enabled for the active beat" % parent_name)
	assert_true(interactable.can_interact(), "%s must accept interaction" % parent_name)
	assert_eq(interactable.get_prompt_label(), expected_label)


func _assert_inactive(parent_name: String) -> void:
	var interactable: Interactable = _interactable(parent_name)
	assert_not_null(interactable, "%s/Interactable must exist" % parent_name)
	if interactable == null:
		return
	assert_false(interactable.enabled, "%s must not expose a prompt outside its beat" % parent_name)


func _interactable(parent_name: String) -> Interactable:
	if _root == null:
		return null
	return _root.get_node_or_null("%s/Interactable" % parent_name) as Interactable


func _controller() -> BetaDayOneController:
	return get_tree().get_first_node_in_group("beta_day_one_controller") as BetaDayOneController


func _spawned_shelf_item_count() -> int:
	var shelf: Node = _root.get_node_or_null("BetaRestockShelf")
	if shelf == null:
		return 0
	var count: int = 0
	for child: Node in shelf.get_children():
		if String(child.name).begins_with("BetaShelfItem"):
			count += 1
	return count


func _visible_label_with_text(text: String) -> Label3D:
	for label: Label3D in _gather_labels(_root):
		if label.visible and label.text.strip_edges() == text:
			return label
	return null


func _gather_labels(node: Node) -> Array[Label3D]:
	var labels: Array[Label3D] = []
	if node == null:
		return labels
	if node is Label3D:
		labels.append(node as Label3D)
	for child: Node in node.get_children():
		labels.append_array(_gather_labels(child))
	return labels


func _register_unlock_entries() -> void:
	var display_names: Dictionary = {
		"employee_register_access": "Register Access",
		"employee_stocking_trained": "Stocking Certification",
		"employee_closing_certified": "Closing Certification",
	}
	for unlock_id: String in display_names.keys():
		if ContentRegistry.exists(unlock_id):
			continue
		ContentRegistry.register_entry(
			{"id": unlock_id, "display_name": String(display_names[unlock_id])},
			"unlock"
		)
	UnlockSystemSingleton.initialize()
