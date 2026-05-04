## ShelfSlot.get_prompt_label() returns state-sensitive text that mirrors the
## InteractionPrompt / PlacementHintUI HUD label.
##
## States covered:
##   - Empty slot, no placement mode → "Select an inventory item first"
##     (player has not yet picked an item from the inventory)
##   - Empty slot in placement mode with a selected item name →
##     "<slot> — Press E to stock <item>"
##   - Empty slot in placement mode without a selected item name →
##     "Select an inventory item first" (legacy/test entry without an item)
##   - Occupied slot in placement mode → "Shelf full" (no E cue)
##   - Occupied slot, no placement mode → "<slot>" with no E cue (E on
##     an occupied slot is a no-op in InventoryPanel, so the prompt drops
##     the dead "Press E to stock" hint)
##
## The Cash Register interactable in retro_games.tscn ships
## display_name="Cash Register" + prompt_text="Checkout" so the base
## Interactable.get_prompt_label returns "Checkout Cash Register".
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


func before_each() -> void:
	# Ensure no placement-mode signals leak into the next test.
	EventBus.placement_mode_exited.emit()


func _make_slot(slot_display_name: String = "Cartridge Slot") -> ShelfSlot:
	var slot: ShelfSlot = _ShelfSlotScript.new()
	slot.display_name = slot_display_name
	add_child_autofree(slot)
	return slot


func test_default_label_outside_placement_mode_is_select_first() -> void:
	var slot: ShelfSlot = _make_slot("Cartridge Slot")
	assert_eq(
		slot.get_prompt_label(),
		ShelfSlot.PROMPT_NO_ITEM_SELECTED,
		"Empty slot outside placement mode should hint that an inventory item must be selected first"
	)


func test_empty_slot_in_placement_mode_with_item_shows_stock_item_label() -> void:
	var slot: ShelfSlot = _make_slot("Cartridge Slot")
	EventBus.placement_mode_entered.emit()
	EventBus.placement_hint_requested.emit("Game X")
	assert_eq(
		slot.get_prompt_label(),
		"Cartridge Slot — Press E to stock game x",
		"Empty slot during placement with selected item should produce the stock prompt"
	)


func test_empty_slot_in_placement_mode_without_item_falls_back_to_select_first() -> void:
	var slot: ShelfSlot = _make_slot("Cartridge Slot")
	EventBus.placement_mode_entered.emit()
	# No placement_hint_requested emit — covers the legacy/test path.
	assert_eq(
		slot.get_prompt_label(),
		ShelfSlot.PROMPT_NO_ITEM_SELECTED,
		"Empty slot in placement mode with no item name should fall back to select-first"
	)


func test_occupied_slot_in_placement_mode_label_is_shelf_full() -> void:
	var slot: ShelfSlot = _make_slot("Cartridge Slot")
	# place_item directly bypasses inventory_system; that is fine for a label
	# unit test because the label only reads _placement_active and _occupied.
	slot.place_item("test_item_001", "cartridges")
	EventBus.placement_mode_entered.emit()
	assert_eq(
		slot.get_prompt_label(),
		ShelfSlot.PROMPT_SHELF_FULL,
		"Occupied slot during placement mode should prompt 'Shelf full'"
	)


func test_occupied_slot_outside_placement_mode_drops_press_e_cue() -> void:
	var slot: ShelfSlot = _make_slot("Cartridge Slot")
	slot.place_item("test_item_002", "cartridges")
	# Not in placement mode — pressing E on an occupied slot is a no-op in
	# InventoryPanel._on_interactable_interacted (the open() branch is gated
	# on `not slot.is_occupied()`), so the prompt must drop the verb and
	# render the bare slot name without a "Press E" cue.
	assert_eq(
		slot.get_prompt_label(),
		"Cartridge Slot",
		"Occupied slot outside placement mode must show the bare slot name "
		+ "without a dead 'Press E to stock' cue"
	)
	assert_eq(
		slot.prompt_text, "",
		"Occupied slot outside placement mode must clear prompt_text so "
		+ "InteractionRay._build_action_label suppresses the E cue"
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


func test_retro_games_shelf_slots_default_to_select_first() -> void:
	# Default state across every authored ShelfSlot in the scene is
	# "Select an inventory item first" because none of them are in
	# placement mode and none start occupied.
	var scene: Node = _RetroGamesScene.instantiate()
	add_child_autofree(scene)
	var slots: Array[ShelfSlot] = _collect_shelf_slots(scene)
	assert_true(
		slots.size() > 0,
		"retro_games.tscn must contain at least one ShelfSlot"
	)
	for slot: ShelfSlot in slots:
		assert_eq(
			slot.get_prompt_label(),
			ShelfSlot.PROMPT_NO_ITEM_SELECTED,
			"Empty unselected slot must hint to select an inventory item first"
		)


func test_retro_games_cib_display_fixture_present() -> void:
	# AC: the cib_display fixture (6 slots, accepts cartridges) must be
	# locatable in the scene.
	var scene: Node = _RetroGamesScene.instantiate()
	add_child_autofree(scene)
	var cib_slots: Array[ShelfSlot] = []
	for slot: ShelfSlot in _collect_shelf_slots(scene):
		if slot.fixture_id == "cib_display":
			cib_slots.append(slot)
	assert_eq(
		cib_slots.size(), 6,
		"retro_games.tscn must expose 6 cib_display ShelfSlot nodes"
	)
	for slot: ShelfSlot in cib_slots:
		assert_true(
			slot.accepts_category("cartridges"),
			"cib_display slot %s must accept cartridges" % slot.slot_id
		)
		assert_false(
			slot.accepts_category("consoles"),
			"cib_display slot %s must reject non-cartridge categories" % slot.slot_id
		)


func _collect_shelf_slots(root: Node) -> Array[ShelfSlot]:
	var out: Array[ShelfSlot] = []
	for child: Node in root.get_children():
		if child is ShelfSlot:
			out.append(child as ShelfSlot)
		out.append_array(_collect_shelf_slots(child))
	return out
