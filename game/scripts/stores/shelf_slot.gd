## A single slot on a shelf or display fixture that can hold one item.
class_name ShelfSlot
extends Interactable

signal slot_changed(slot: ShelfSlot)

const _CARD_PACK_SCENE: PackedScene = preload(
	"res://game/assets/models/props/placeholder_prop_card_pack.tscn"
)
const _SHELF_PRODUCT_SCENE: PackedScene = preload(
	"res://game/assets/models/props/placeholder_prop_shelf_product.tscn"
)
const _SPORTS_MEMORABILIA_SCENE: PackedScene = preload(
	"res://game/assets/models/props/placeholder_prop_sports_memorabilia.tscn"
)
const _GAME_CARTRIDGE_SCENE: PackedScene = preload(
	"res://game/assets/models/props/placeholder_prop_game_cartridge.tscn"
)
const _GAME_CONSOLE_SCENE: PackedScene = preload(
	"res://game/assets/models/props/prop_game_console.tscn"
)
const _VHS_TAPE_SCENE: PackedScene = preload(
	"res://game/assets/models/props/placeholder_prop_vhs_tape.tscn"
)
const _ELECTRONICS_DEVICE_SCENE: PackedScene = preload(
	"res://game/assets/models/props/placeholder_prop_electronics_device.tscn"
)
const CATEGORY_SCENES: Dictionary = {
	"trading_cards": _CARD_PACK_SCENE,
	"sealed_packs": _CARD_PACK_SCENE,
	"sealed_product": _SHELF_PRODUCT_SCENE,
	"memorabilia": _SPORTS_MEMORABILIA_SCENE,
	"cartridge": _GAME_CARTRIDGE_SCENE,
	"console": _GAME_CONSOLE_SCENE,
	"accessory": _SHELF_PRODUCT_SCENE,
	"guide": _SHELF_PRODUCT_SCENE,
	"vhs_tapes": _VHS_TAPE_SCENE,
	"dvd_titles": _VHS_TAPE_SCENE,
	"snacks": _SHELF_PRODUCT_SCENE,
	"merchandise": _SHELF_PRODUCT_SCENE,
	"portable_audio": _ELECTRONICS_DEVICE_SCENE,
	"digital_camera": _ELECTRONICS_DEVICE_SCENE,
	"gadget": _ELECTRONICS_DEVICE_SCENE,
	"audio_equipment": _ELECTRONICS_DEVICE_SCENE,
	"portable_gaming": _ELECTRONICS_DEVICE_SCENE,
}
const DEFAULT_ITEM_SCENE: PackedScene = _SHELF_PRODUCT_SCENE

const HIGHLIGHT_EMPTY := Color(0.2, 0.8, 0.2)
const HIGHLIGHT_OCCUPIED := Color(0.9, 0.2, 0.2)
# accent_interact #5BB8E8 at alpha 0.35 — shown only when stocking cursor matches
const STOCKING_TINT := Color(91.0 / 255.0, 184.0 / 255.0, 232.0 / 255.0, 0.35)
const PROMPT_NO_ITEM_SELECTED: String = "Select an inventory item first"
const PROMPT_SHELF_FULL: String = "Shelf full"
const STOCK_VERB_FORMAT: String = "stock %s"

@export var slot_id: String = ""
@export var fixture_id: String = ""
@export var slot_size: String = "standard"
## Category filter for stocking highlights. Empty string accepts any category.
@export var accepted_category: String = ""

var _occupied: bool = false
var _held_item_id: String = ""
var _item_node: Node3D = null
var _placement_active: bool = false
var _info_label: Label3D = null
var _label_accent: Color = Color.WHITE
var _label_focus_active: bool = false
var _authored_display_name: String = ""
var _authored_prompt_text: String = ""
var _pending_item_name: String = ""

@onready var _empty_mesh: MeshInstance3D = _resolve_empty_mesh()


func _ready() -> void:
	interaction_type = InteractionType.SHELF_SLOT
	if display_name.is_empty():
		display_name = "Shelf Slot"
	# Shelf slots are stocked, not generically "interacted with". Only override
	# when the scene left the inherited Interactable default in place so authored
	# verbs (e.g. "Inspect") still win.
	if action_verb == "Interact":
		action_verb = "Stock"
	add_to_group("shelf_slot")
	super._ready()
	# Capture authored prompt fields AFTER super._ready() so the base resolves
	# the verb default. _refresh_prompt_state() restores these whenever the slot
	# is in the "default" state (occupied + not in placement mode).
	_authored_display_name = display_name
	_authored_prompt_text = prompt_text
	_update_empty_indicator()
	EventBus.placement_mode_entered.connect(_on_placement_entered)
	EventBus.placement_mode_exited.connect(_on_placement_exited)
	EventBus.placement_hint_requested.connect(_on_placement_hint_requested)
	EventBus.stocking_cursor_active.connect(_on_stocking_cursor_active)
	EventBus.stocking_cursor_inactive.connect(_on_stocking_cursor_inactive)
	# Label3D shows only while the interaction ray is focused on this slot.
	# At FP eye height a permanently-visible label renders ~30–40 cm wide and
	# clutters the view; hover-gated visibility keeps the in-world price tag
	# readable when the player aims at the item and silent otherwise.
	focused.connect(_on_label_focused)
	unfocused.connect(_on_label_unfocused)
	slot_changed.connect(_on_self_slot_changed)
	_refresh_prompt_state()


## Returns whether an item is currently placed in this slot.
func is_occupied() -> bool:
	return _occupied


## Returns true if this slot can accept an item.
func is_available() -> bool:
	return not _occupied


## Returns the instance ID of the placed item, or empty string if empty.
func get_item_instance_id() -> String:
	if _occupied:
		return _held_item_id
	return ""


## Returns the instance ID of the held item, or empty StringName if empty.
func get_item_id() -> StringName:
	return StringName(get_item_instance_id())


## Returns the maximum number of items this slot can hold.
func get_capacity() -> int:
	return 1


## Returns the number of items currently occupying this slot (0 or 1).
func get_occupied() -> int:
	return 1 if _occupied else 0


## Places an item into this slot, returning true on success.
## Returning false on a re-stock of an occupied slot is a typed contract,
## not a silent failure — see docs/audits/error-handling-report.md EH-01.
func place_item(instance_id: String, category: String = "") -> bool:
	if _occupied:
		return false
	_held_item_id = instance_id
	_occupied = true
	_spawn_item_mesh(category)
	_update_empty_indicator()
	slot_changed.emit(self)
	return true


## Assigns an item to this slot by canonical instance ID, returning true on success.
func assign_item(id: StringName) -> bool:
	return place_item(String(id))


## Removes the item from this slot and returns its instance ID.
## Empty string on an already-empty slot is a typed contract, not a silent
## failure — see docs/audits/error-handling-report.md EH-01.
func remove_item() -> String:
	if not _occupied:
		return ""
	var item_id: String = _held_item_id
	_held_item_id = ""
	_occupied = false
	_free_item_mesh()
	_update_empty_indicator()
	clear_display_data()
	slot_changed.emit(self)
	return item_id


## Removes the held item and restores availability.
func deassign() -> void:
	remove_item()


## Displays item name, condition, and price above this slot as a billboard label.
## Creates the Label3D on first call; subsequent calls update text in place.
func set_display_data(item_name: String, condition: String, price: float) -> void:
	if not _info_label:
		_info_label = Label3D.new()
		# Sized for the fixed isometric/orthographic store camera at
		# pitch=52° / ortho_size_default=10. Smaller values render as a
		# pixel-soup smudge on the overhead view.
		_info_label.pixel_size = 0.005
		_info_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_info_label.no_depth_test = true
		_info_label.font_size = 48
		_info_label.outline_size = 6
		_info_label.outline_modulate = Color(0.05, 0.07, 0.12, 0.85)
		_info_label.position = Vector3(0.0, 0.32, 0.0)
		_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_info_label.modulate = _label_accent
		add_child(_info_label)
	_info_label.text = "%s\n%s  $%.2f" % [item_name, condition.capitalize(), price]
	_info_label.visible = _label_focus_active


## Sets the accent color used for the info label text. Applies immediately if
## the label already exists.
func apply_accent(color: Color) -> void:
	_label_accent = color
	if _info_label:
		_info_label.modulate = color


## Hides the info label without destroying it.
func clear_display_data() -> void:
	if _info_label:
		_info_label.visible = false


## Shows or hides the translucent empty-slot indicator.
func _update_empty_indicator() -> void:
	if not is_node_ready() or _empty_mesh == null:
		return
	_empty_mesh.visible = (not _occupied) and _placement_active


## Spawns a placeholder scene representing the placed item.
func _spawn_item_mesh(category: String) -> void:
	_free_item_mesh()
	var scene: PackedScene = CATEGORY_SCENES.get(
		category, DEFAULT_ITEM_SCENE
	)
	var instance: Node3D = scene.instantiate()
	_item_node = instance
	add_child(instance)


## Frees the item node if it exists.
func _free_item_mesh() -> void:
	if _item_node and is_instance_valid(_item_node):
		_item_node.queue_free()
		_item_node = null


func _resolve_empty_mesh() -> MeshInstance3D:
	var placeholder: MeshInstance3D = get_node_or_null(
		"PlaceholderMesh"
	) as MeshInstance3D
	if placeholder:
		return placeholder
	return get_node_or_null("Marker") as MeshInstance3D


## State-aware prompt label that mirrors the player-facing HUD label. Format
## matches InteractionRay._build_action_label so this method and the runtime
## label stay in lockstep. State is driven by display_name and prompt_text,
## which _refresh_prompt_state() rewrites whenever placement / occupancy /
## pending-item-name change.
func get_prompt_label() -> String:
	var verb: String = prompt_text.strip_edges()
	var target_name: String = display_name.strip_edges()
	if verb.is_empty() and target_name.is_empty():
		return ""
	if target_name.is_empty():
		return "Press E to %s" % verb.to_lower()
	if verb.is_empty():
		return target_name
	return "%s — Press E to %s" % [target_name, verb.to_lower()]


## Returns true when the slot would accept the given category. Empty
## accepted_category accepts any item (unfiltered counter / impulse slots).
func accepts_category(item_category: String) -> bool:
	if accepted_category.is_empty():
		return true
	return accepted_category == item_category


## Recomputes display_name and prompt_text for the current state so the
## InteractionPrompt and PlacementHintUI HUD reflect the slot accurately.
func _refresh_prompt_state() -> void:
	if _placement_active and _occupied:
		display_name = PROMPT_SHELF_FULL
		prompt_text = ""
		return
	if _placement_active and not _pending_item_name.is_empty():
		display_name = _authored_display_name
		prompt_text = STOCK_VERB_FORMAT % _pending_item_name
		return
	if not _occupied:
		display_name = PROMPT_NO_ITEM_SELECTED
		prompt_text = ""
		return
	display_name = _authored_display_name
	prompt_text = _authored_prompt_text


func _on_self_slot_changed(_slot: ShelfSlot) -> void:
	_refresh_prompt_state()


func _on_placement_hint_requested(item_name: String) -> void:
	_pending_item_name = item_name
	_refresh_prompt_state()


## Overrides base highlight to use green/red during placement mode.
func highlight() -> void:
	if _placement_active:
		_apply_placement_highlight()
		return
	super.highlight()


## Overrides base unhighlight to clear placement highlights too.
func unhighlight() -> void:
	super.unhighlight()


func _on_label_focused() -> void:
	_label_focus_active = true
	if _info_label:
		_info_label.visible = true


func _on_label_unfocused() -> void:
	_label_focus_active = false
	if _info_label:
		_info_label.visible = false


func _on_placement_entered() -> void:
	_placement_active = true
	_update_empty_indicator()
	_refresh_prompt_state()


func _on_placement_exited() -> void:
	_placement_active = false
	_pending_item_name = ""
	if _highlight_active:
		unhighlight()
	_update_empty_indicator()
	_refresh_prompt_state()


func _on_stocking_cursor_active(item_category: StringName) -> void:
	if _occupied or _empty_mesh == null:
		return
	if not accepts_category(String(item_category)):
		return
	_apply_stocking_highlight()


func _on_stocking_cursor_inactive() -> void:
	_clear_stocking_highlight()


func _apply_stocking_highlight() -> void:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = STOCKING_TINT
	_empty_mesh.set_surface_override_material(0, mat)


func _clear_stocking_highlight() -> void:
	if _empty_mesh == null:
		return
	_empty_mesh.set_surface_override_material(0, null)


## Applies green (empty) or red (occupied) emission highlight.
func _apply_placement_highlight() -> void:
	if _highlight_active:
		return
	_highlight_active = true

	var mesh_node: MeshInstance3D = _find_mesh_instance()
	if not mesh_node:
		return

	var emission_color: Color
	if _occupied:
		emission_color = HIGHLIGHT_OCCUPIED
	else:
		emission_color = HIGHLIGHT_EMPTY

	_original_materials.clear()
	var surface_count: int = (
		mesh_node.get_surface_override_material_count()
	)
	for i: int in range(surface_count):
		var mat: Material = mesh_node.get_surface_override_material(i)
		if not mat and mesh_node.mesh:
			mat = mesh_node.mesh.surface_get_material(i)
		_original_materials.append(mat)

		var highlight_mat := StandardMaterial3D.new()
		if mat is StandardMaterial3D:
			highlight_mat = (mat as StandardMaterial3D).duplicate()
		highlight_mat.emission_enabled = true
		highlight_mat.emission = emission_color
		highlight_mat.emission_energy_multiplier = 0.8
		mesh_node.set_surface_override_material(i, highlight_mat)
