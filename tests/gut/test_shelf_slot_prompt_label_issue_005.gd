## ISSUE-005: ShelfSlot.get_prompt_label() returns state-sensitive text so the
## InteractionPrompt HUD reads `[E] Stock <name>` on an empty slot during
## placement mode and `[E] Slot occupied` on an occupied slot. The Cash
## Register interactable in retro_games.tscn already returns `Checkout
## Cash Register` from the default Interactable label path, which the
## interaction ray turns into `[E] Checkout Cash Register`.
extends GutTest


const _ShelfSlotScript: GDScript = preload(
	"res://game/scripts/stores/shelf_slot.gd"
)
const _InteractableScript: GDScript = preload(
	"res://game/scripts/components/interactable.gd"
)
const _RetroGamesScene: PackedScene = preload(
	"res://game/scenes/stores/retro_games.tscn"
)


func _make_slot(display_name: String = "Cartridge Slot") -> ShelfSlot:
	var slot: ShelfSlot = _ShelfSlotScript.new()
	slot.display_name = display_name
	add_child_autofree(slot)
	return slot


func test_default_label_outside_placement_mode_is_stock_plus_name() -> void:
	var slot: ShelfSlot = _make_slot("Cartridge Slot")
	assert_eq(
		slot.get_prompt_label(),
		"Stock Cartridge Slot",
		"Outside placement mode the slot should fall back to the verb+name default"
	)


func test_empty_slot_in_placement_mode_label_is_stock_plus_name() -> void:
	var slot: ShelfSlot = _make_slot("Cartridge Slot")
	EventBus.placement_mode_entered.emit()
	assert_eq(
		slot.get_prompt_label(),
		"Stock Cartridge Slot",
		"Empty slot during placement mode should prompt 'Stock <name>'"
	)


func test_occupied_slot_in_placement_mode_label_is_occupied() -> void:
	var slot: ShelfSlot = _make_slot("Cartridge Slot")
	# place_item directly bypasses inventory_system; that is fine for a label
	# unit test because the label only reads _placement_active and _occupied.
	slot.place_item("test_item_001", "cartridge")
	EventBus.placement_mode_entered.emit()
	assert_eq(
		slot.get_prompt_label(),
		"Slot occupied",
		"Occupied slot during placement mode should prompt 'Slot occupied'"
	)


func test_register_default_label_is_checkout_plus_name() -> void:
	# Register is a vanilla Interactable in retro_games.tscn with
	# prompt_text="Checkout" and display_name="Cash Register". The default
	# get_prompt_label() yields "Checkout Cash Register"; the InteractionRay
	# prepends "[E] " before emitting on EventBus.
	var register: Interactable = _InteractableScript.new()
	register.interaction_type = Interactable.InteractionType.REGISTER
	register.display_name = "Cash Register"
	register.prompt_text = "Checkout"
	add_child_autofree(register)
	assert_eq(
		register.get_prompt_label(),
		"Checkout Cash Register",
		"Register prompt label drives the `[E] Checkout` cue (prefix added by the ray)"
	)


func test_retro_games_register_node_has_checkout_prompt_data() -> void:
	# Acceptance criteria require the Cash Register in retro_games.tscn to
	# carry interaction_type=REGISTER, display_name="Cash Register", and
	# prompt_text="Checkout" so the InteractionPrompt reads `[E] Checkout
	# Cash Register` whenever the player aims at it.
	var scene: Node = _RetroGamesScene.instantiate()
	add_child_autofree(scene)
	var register: Node = scene.get_node_or_null("Checkout/Register")
	assert_not_null(
		register, "retro_games.tscn must expose Checkout/Register"
	)
	if register == null:
		return
	assert_true(
		register is Interactable,
		"Checkout/Register must use the Interactable script"
	)
	var as_interactable: Interactable = register as Interactable
	assert_eq(
		as_interactable.interaction_type,
		Interactable.InteractionType.REGISTER,
		"Register interaction_type must be REGISTER"
	)
	assert_eq(
		as_interactable.display_name, "Cash Register"
	)
	assert_eq(
		as_interactable.prompt_text, "Checkout"
	)


func test_retro_games_shelf_slots_default_label_is_stock_plus_display_name() -> void:
	# Verify each shelf slot scene-data combination produces a readable
	# `Stock <display_name>` from the Interactable contract — feeds the
	# `[E] Stock <display_name>` HUD cue per the ISSUE-005 acceptance.
	var scene: Node = _RetroGamesScene.instantiate()
	add_child_autofree(scene)
	var seen_names: Dictionary = {}
	for node: Node in _collect_shelf_slots(scene):
		var slot: ShelfSlot = node as ShelfSlot
		var label: String = slot.get_prompt_label()
		seen_names[slot.display_name] = true
		assert_true(
			label.begins_with("Stock "),
			"ShelfSlot '%s' must produce a 'Stock ...' prompt by default (got '%s')" %
				[slot.display_name, label]
		)
	assert_true(
		seen_names.size() > 0,
		"retro_games.tscn must contain at least one ShelfSlot"
	)


func _collect_shelf_slots(root: Node) -> Array[ShelfSlot]:
	var out: Array[ShelfSlot] = []
	for child: Node in root.get_children():
		if child is ShelfSlot:
			out.append(child as ShelfSlot)
		out.append_array(_collect_shelf_slots(child))
	return out
