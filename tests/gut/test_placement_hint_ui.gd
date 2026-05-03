## Tests for the persistent placement hint banner that surfaces while the
## player is choosing a shelf slot to drop an item into. The banner must be
## visible even when CTX_MODAL is on the InputFocus stack (which suppresses
## InteractionPrompt during the same window).
extends GutTest


const HINT_SCENE: PackedScene = preload(
	"res://game/scenes/ui/placement_hint_ui.tscn"
)


var _hint: PlacementHintUI


func before_each() -> void:
	_hint = HINT_SCENE.instantiate() as PlacementHintUI
	add_child_autofree(_hint)


func test_starts_hidden() -> void:
	assert_false(
		_hint.visible,
		"PlacementHintUI should be hidden until placement begins"
	)


func test_visible_on_placement_hint_requested() -> void:
	EventBus.placement_hint_requested.emit("Cartridge")
	assert_true(
		_hint.visible,
		"Hint should appear when placement_hint_requested fires"
	)


func test_message_includes_item_name() -> void:
	EventBus.placement_hint_requested.emit("Wonder Cartridge")
	assert_string_contains(
		_hint._message_label.text, "Wonder Cartridge",
		"Hint message should include the item name being placed"
	)


func test_message_falls_back_when_item_name_empty() -> void:
	EventBus.placement_hint_requested.emit("")
	assert_true(
		_hint.visible,
		"Hint should still surface even when no item name is supplied"
	)
	assert_false(
		_hint._message_label.text.is_empty(),
		"Hint must show fallback prompt when item name is empty"
	)


func test_hidden_on_placement_mode_exited() -> void:
	EventBus.placement_hint_requested.emit("Cartridge")
	EventBus.placement_mode_exited.emit()
	assert_false(
		_hint.visible,
		"Hint should disappear when placement mode ends"
	)


func test_does_not_block_mouse_input() -> void:
	EventBus.placement_hint_requested.emit("Cartridge")
	assert_eq(
		_hint.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"Hint must let clicks pass through so the player can click slots"
	)


func test_visible_when_ctx_modal_active() -> void:
	# Reproduces the exact runtime ordering: CTX_MODAL is on the focus stack
	# (panel just hid via _close_keeping_modal_focus) when the hint is shown.
	# The banner must NOT consult InputFocus the way InteractionPrompt does.
	InputFocus.push_context(InputFocus.CTX_MODAL)
	EventBus.placement_hint_requested.emit("Cartridge")
	assert_true(
		_hint.visible,
		"Hint must surface even while CTX_MODAL is on the focus stack"
	)
	InputFocus.pop_context()


func test_focused_slot_label_replaces_hint_during_placement() -> void:
	# During placement the InteractionRay still emits interactable_focused
	# while the InteractionPrompt overlay is suppressed by CTX_MODAL. The
	# banner must surface the slot-specific label so the player still reads
	# slot-state feedback (Stock/Shelf full/Wrong category).
	EventBus.placement_hint_requested.emit("Wonder Cartridge")
	EventBus.interactable_focused.emit("Cartridge Slot — Press E to stock wonder cartridge")
	assert_eq(
		_hint._message_label.text,
		"Cartridge Slot — Press E to stock wonder cartridge",
		"Banner must show the focused slot's HUD label during placement"
	)


func test_focused_slot_label_ignored_outside_placement() -> void:
	# Outside placement mode the banner must stay hidden — InteractionPrompt
	# owns the focus-target prompt in normal play.
	EventBus.interactable_focused.emit("Cartridge Slot — Press E to stock")
	assert_false(
		_hint.visible,
		"Banner must remain hidden when no placement is in flight"
	)


func test_unfocus_during_placement_restores_default_message() -> void:
	EventBus.placement_hint_requested.emit("Wonder Cartridge")
	EventBus.interactable_focused.emit("Shelf full")
	EventBus.interactable_unfocused.emit()
	assert_string_contains(
		_hint._message_label.text, "Wonder Cartridge",
		"Banner must revert to the item-aware default after focus clears"
	)


func test_shelf_actions_emits_hint_with_item_name() -> void:
	# The shelf actions helper is the integration boundary between the
	# inventory panel and this banner; verify it forwards the item name.
	var actions := InventoryShelfActions.new()
	var item := ItemInstance.new()
	var def := ItemDefinition.new()
	def.item_name = "Holographic Booster Pack"
	item.definition = def

	var captured_names: Array[String] = []
	var capture := func(name: String) -> void:
		captured_names.append(name)
	EventBus.placement_hint_requested.connect(capture)

	actions.enter_placement_mode(item)
	EventBus.placement_hint_requested.disconnect(capture)
	actions.exit_placement_mode()

	assert_eq(captured_names.size(), 1,
		"enter_placement_mode must emit placement_hint_requested exactly once")
	assert_eq(captured_names[0], "Holographic Booster Pack",
		"Emitted hint payload must carry the item display name")
