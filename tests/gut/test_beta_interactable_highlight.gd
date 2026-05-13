## Beta Day-1 interactable highlight contract.
##
## The hover outline is the player's single visual signal that an in-world
## object is interactable. The contract for Day-1 is:
##   * Every beta interactable shares one outline color and width — there is
##     no per-class custom highlight style. A consistent rim across the
##     customer, back-room pickup, restock shelf, day-end trigger, and hidden
##     clue is what teaches "this can be pressed".
##   * The outline applies on hover (via `highlight()`) and clears on unhover
##     (via `unhighlight()`), guarded by `_highlight_active` so repeated
##     `highlight()` calls on the same target are idempotent (no flicker).
##   * Disabled interactables are filtered upstream in InteractionRay so they
##     are never passed to `_set_hovered_target` — but `highlight()` itself
##     stays a no-op safe pure visual call (defense in depth).
extends GutTest

const _BETA_INTERACTABLE_SCRIPTS: Array[GDScript] = [
	preload("res://game/scripts/beta/beta_day1_customer_interactable.gd"),
	preload("res://game/scripts/beta/beta_backroom_pickup_interactable.gd"),
	preload("res://game/scripts/beta/beta_restock_interactable.gd"),
	preload("res://game/scripts/beta/beta_day_end_trigger_interactable.gd"),
	preload("res://game/scripts/beta/beta_hidden_clue_interactable.gd"),
]


func _build(script: GDScript) -> Interactable:
	var node: Interactable = Interactable.new()
	node.set_script(script)
	add_child_autofree(node)
	return node


func test_all_beta_interactables_share_the_default_highlight_color() -> void:
	# AC: "same color across all 5 beta Day 1 interactables — no per-class
	# custom highlight styles." Verified by asserting each subclass leaves
	# `highlight_color` at the base default rather than overriding it.
	var expected: Color = Color(1.0, 0.95, 0.85, 0.7)
	for script: GDScript in _BETA_INTERACTABLE_SCRIPTS:
		var node: Interactable = _build(script)
		assert_eq(
			node.highlight_color,
			expected,
			"%s should inherit the default warm-white outline" % script.resource_path
		)


func test_all_beta_interactables_share_the_default_outline_width() -> void:
	for script: GDScript in _BETA_INTERACTABLE_SCRIPTS:
		var node: Interactable = _build(script)
		assert_eq(
			node.highlight_outline_width,
			0.012,
			"%s should inherit the default outline width" % script.resource_path
		)


func test_highlight_idempotent_does_not_flicker() -> void:
	# AC: "if the InteractionRay hovers the same target across multiple
	# frames, the outline is stable (no per-frame toggle)." Each
	# beta interactable must stay highlight-active across repeated calls.
	for script: GDScript in _BETA_INTERACTABLE_SCRIPTS:
		var node: Interactable = _build(script)
		var mesh: MeshInstance3D = MeshInstance3D.new()
		mesh.mesh = BoxMesh.new()
		mesh.set_surface_override_material(0, StandardMaterial3D.new())
		node.add_child(mesh)

		node.highlight()
		var first_pass: Material = mesh.get_surface_override_material(0).next_pass
		node.highlight()
		var second_pass: Material = mesh.get_surface_override_material(0).next_pass

		assert_true(
			node._highlight_active,
			"%s should remain highlight-active after redundant highlight()" % script.resource_path
		)
		assert_same(
			first_pass,
			second_pass,
			"%s should not rebuild the outline material on repeat highlight()" % script.resource_path
		)


func test_unhighlight_restores_original_material() -> void:
	# AC: "look away → outline gone." The unhighlight path must restore the
	# pre-hover material so the outline does not linger after the ray clears.
	for script: GDScript in _BETA_INTERACTABLE_SCRIPTS:
		var node: Interactable = _build(script)
		var mesh: MeshInstance3D = MeshInstance3D.new()
		mesh.mesh = BoxMesh.new()
		var base: StandardMaterial3D = StandardMaterial3D.new()
		mesh.set_surface_override_material(0, base)
		node.add_child(mesh)

		node.highlight()
		node.unhighlight()

		assert_false(
			node._highlight_active,
			"%s should clear highlight flag on unhighlight()" % script.resource_path
		)
		assert_same(
			mesh.get_surface_override_material(0),
			base,
			"%s should restore the original surface material on unhighlight()" % script.resource_path
		)


func test_outline_material_uses_warm_white_color() -> void:
	# Pins the shipped material color so an editor save that drops the value
	# back to teal (the prior default) is caught at test time, not in QA.
	var material: ShaderMaterial = load(
		"res://game/assets/shaders/mat_outline_highlight.tres"
	) as ShaderMaterial
	assert_not_null(material, "Outline highlight material should load")
	if material == null:
		return
	var color: Color = material.get_shader_parameter("outline_color") as Color
	assert_almost_eq(color.r, 1.0, 0.001, "Outline red channel should be warm-white")
	assert_almost_eq(color.g, 0.95, 0.001, "Outline green channel should be warm-white")
	assert_almost_eq(color.b, 0.85, 0.001, "Outline blue channel should be warm-white")
	assert_almost_eq(color.a, 0.7, 0.001, "Outline alpha should be 0.7 for a subtle rim")
