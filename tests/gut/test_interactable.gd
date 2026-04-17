## Tests Interactable component: signals, enabled flag, and interaction dispatch.
extends GutTest


var _interactable: Interactable
var _interacted_count: int = 0
var _focused_count: int = 0
var _unfocused_count: int = 0
var _bus_interacted_count: int = 0
const _OUTLINE_MATERIAL_PATH := "res://game/assets/shaders/mat_outline_highlight.tres"


func before_each() -> void:
	_interacted_count = 0
	_focused_count = 0
	_unfocused_count = 0
	_bus_interacted_count = 0

	_interactable = Interactable.new()
	_interactable.interaction_type = Interactable.InteractionType.ITEM
	_interactable.display_name = "Test Object"

	_interactable.interacted.connect(_on_interacted)
	_interactable.focused.connect(_on_focused)
	_interactable.unfocused.connect(_on_unfocused)
	EventBus.interactable_interacted.connect(_on_bus_interacted)

	add_child_autofree(_interactable)


func after_each() -> void:
	if EventBus.interactable_interacted.is_connected(_on_bus_interacted):
		EventBus.interactable_interacted.disconnect(_on_bus_interacted)


func _on_interacted(_target: Interactable) -> void:
	_interacted_count += 1


func _on_focused() -> void:
	_focused_count += 1


func _on_unfocused() -> void:
	_unfocused_count += 1


func _on_bus_interacted(_target: Interactable, _type: int) -> void:
	_bus_interacted_count += 1


func test_collision_layer_set_to_interaction_layer() -> void:
	assert_eq(
		_interactable.collision_layer, Interactable.INTERACTABLE_LAYER,
		"Should set collision_layer to INTERACTABLE_LAYER"
	)


func test_collision_mask_is_zero() -> void:
	assert_eq(
		_interactable.collision_mask, 0,
		"Should set collision_mask to 0"
	)


func test_added_to_interactable_group() -> void:
	assert_true(
		_interactable.is_in_group("interactable"),
		"Should be in the 'interactable' group"
	)


func test_default_prompt_from_interaction_type() -> void:
	assert_eq(
		_interactable.interaction_prompt, "Examine",
		"Should default to PROMPT_VERBS for ITEM type"
	)


func test_custom_prompt_preserved() -> void:
	var custom: Interactable = Interactable.new()
	custom.interaction_prompt = "Custom Action"
	add_child_autofree(custom)
	assert_eq(
		custom.interaction_prompt, "Custom Action",
		"Should preserve a non-empty custom prompt"
	)


func test_enabled_defaults_to_true() -> void:
	assert_true(
		_interactable.enabled,
		"Should default enabled to true"
	)


func test_interact_emits_local_signal() -> void:
	_interactable.interact()
	assert_eq(
		_interacted_count, 1,
		"Should emit interacted signal"
	)


func test_interact_emits_eventbus_signal() -> void:
	_interactable.interact()
	assert_eq(
		_bus_interacted_count, 1,
		"Should emit EventBus.interactable_interacted"
	)


func test_interact_blocked_when_disabled() -> void:
	_interactable.enabled = false
	_interactable.interact()
	assert_eq(
		_interacted_count, 0,
		"Should not emit interacted when disabled"
	)
	assert_eq(
		_bus_interacted_count, 0,
		"Should not emit EventBus signal when disabled"
	)


func test_focused_signal_emittable() -> void:
	_interactable.focused.emit()
	assert_eq(
		_focused_count, 1,
		"focused signal should be connectable and emittable"
	)


func test_unfocused_signal_emittable() -> void:
	_interactable.unfocused.emit()
	assert_eq(
		_unfocused_count, 1,
		"unfocused signal should be connectable and emittable"
	)


func test_highlight_unhighlight_without_mesh() -> void:
	_interactable.highlight()
	assert_true(
		_interactable._highlight_active,
		"highlight() should set flag even without mesh"
	)
	_interactable.unhighlight()
	assert_false(
		_interactable._highlight_active,
		"unhighlight() should clear flag"
	)


func test_outline_shader_material_configured_with_default_pulse() -> void:
	var material := load(_OUTLINE_MATERIAL_PATH) as ShaderMaterial
	assert_not_null(material, "Outline highlight material should load")
	assert_not_null(material.shader, "Outline highlight material should reference a shader")
	assert_eq(
		material.shader.resource_path,
		"res://game/assets/shaders/outline_highlight.gdshader",
		"Outline material should use the committed outline shader"
	)
	assert_eq(
		material.get_shader_parameter("outline_width"),
		0.012,
		"Default outline_width should remain visible without being oversized"
	)
	assert_eq(
		material.get_shader_parameter("pulse_speed"),
		1.5,
		"Default pulse_speed should provide a noticeable hover pulse"
	)
	assert_eq(
		material.get_shader_parameter("pulse_intensity"),
		0.15,
		"Default pulse_intensity should keep the outline subtle"
	)


func test_highlight_applies_outline_next_pass_to_mesh_surface() -> void:
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	var base_material := StandardMaterial3D.new()
	mesh.set_surface_override_material(0, base_material)
	_interactable.add_child(mesh)

	_interactable.highlight()

	var highlighted := mesh.get_surface_override_material(0)
	assert_not_null(highlighted, "Highlight should preserve a surface material")
	assert_not_same(
		highlighted,
		base_material,
		"Highlight should duplicate the base material before adding next_pass"
	)
	assert_not_null(
		highlighted.next_pass,
		"Highlight should attach the outline material as next_pass"
	)
	assert_true(
		highlighted.next_pass is ShaderMaterial,
		"Highlight next_pass should be a shader material"
	)
	assert_eq(
		(highlighted.next_pass as ShaderMaterial).shader.resource_path,
		"res://game/assets/shaders/outline_highlight.gdshader",
		"Highlight should use the outline shader"
	)

	_interactable.unhighlight()

	assert_same(
		mesh.get_surface_override_material(0),
		base_material,
		"Unhighlight should restore the original surface material"
	)


func test_multiple_interactables_independent() -> void:
	var second: Interactable = Interactable.new()
	second.interaction_type = Interactable.InteractionType.REGISTER
	second.display_name = "Register"
	add_child_autofree(second)

	_interactable.interact()
	assert_eq(
		_interacted_count, 1,
		"Only the called interactable should emit"
	)


func test_re_enable_allows_interaction() -> void:
	_interactable.enabled = false
	_interactable.interact()
	assert_eq(_interacted_count, 0, "Should block while disabled")

	_interactable.enabled = true
	_interactable.interact()
	assert_eq(_interacted_count, 1, "Should work after re-enabling")
