## Pins the visual readability contract: customer body color must be
## saturated enough to stand out, the empty-slot placement marker must
## render with visible alpha plus emission, and the checkout-counter
## Label3D must stay within a non-floating scale budget. These properties
## let a Day-1 player tell apart customers, fixtures, empty slots, and
## checkout signage without runtime UI overlays.
extends GutTest

const SLOT_MARKER_PATH: String = "res://game/assets/materials/mat_slot_marker.tres"
const CUSTOMER_SCENE_PATH: String = "res://game/scenes/characters/customer.tscn"
const RETRO_GAMES_SCENE_PATH: String = "res://game/scenes/stores/retro_games.tscn"

# Slot-marker albedo alpha must be visible (not the historical 0.0 ghost
# value) so empty slots glow during placement mode against any shelf wood.
const SLOT_MARKER_MIN_ALPHA: float = 0.3

# A "saturated" hue: max(rgb) - min(rgb) >= 0.4. Pure gray (rgb equal) has
# saturation 0; the customer body color must clear this so the customer
# does not blend into the cream walls or brown floor.
const CUSTOMER_BODY_MIN_SATURATION: float = 0.4

# CheckoutSign pixel_size cap. With BILLBOARD_ENABLED + font_size ~40, a
# pixel_size above this draws a >=1m-wide floating banner above the
# register; the cap keeps the label readable but counter-scaled.
const CHECKOUT_SIGN_MAX_PIXEL_SIZE: float = 0.0035


func test_slot_marker_material_renders_visible_with_emission() -> void:
	var mat: StandardMaterial3D = load(SLOT_MARKER_PATH) as StandardMaterial3D
	assert_not_null(mat, "mat_slot_marker.tres must load as StandardMaterial3D")
	if mat == null:
		return
	assert_gte(
		mat.albedo_color.a, SLOT_MARKER_MIN_ALPHA,
		(
			"Slot-marker albedo alpha=%.2f must be >= %.2f so empty slots are "
			+ "visible during placement mode (historical 0.0 alpha rendered "
			+ "the marker invisible even when PlaceholderMesh.visible=true)."
		) % [mat.albedo_color.a, SLOT_MARKER_MIN_ALPHA],
	)
	assert_true(
		mat.emission_enabled,
		(
			"Slot marker must enable emission so empty slots glow against the "
			+ "shelf wood material instead of fading into it."
		),
	)


func test_customer_body_material_uses_saturated_color() -> void:
	var scene: PackedScene = load(CUSTOMER_SCENE_PATH)
	assert_not_null(scene, "customer.tscn must load")
	if scene == null:
		return
	var root: Node3D = scene.instantiate() as Node3D
	if root == null:
		return
	var body_mesh: MeshInstance3D = root.get_node_or_null(
		"BodyMesh"
	) as MeshInstance3D
	assert_not_null(body_mesh, "Customer/BodyMesh must exist")
	if body_mesh == null:
		root.free()
		return
	var body_mat: StandardMaterial3D = body_mesh.get_surface_override_material(
		0
	) as StandardMaterial3D
	assert_not_null(
		body_mat,
		"Customer BodyMesh must carry a StandardMaterial3D override",
	)
	if body_mat == null:
		root.free()
		return
	var c: Color = body_mat.albedo_color
	var saturation: float = maxf(maxf(c.r, c.g), c.b) - minf(minf(c.r, c.g), c.b)
	assert_gte(
		saturation, CUSTOMER_BODY_MIN_SATURATION,
		(
			"Customer body color rgb=(%.2f, %.2f, %.2f) saturation=%.2f must "
			+ "be >= %.2f so the customer reads as a distinctly colored "
			+ "shopper rather than a neutral gray prop."
		) % [c.r, c.g, c.b, saturation, CUSTOMER_BODY_MIN_SATURATION],
	)
	root.free()


func test_checkout_sign_scale_within_budget() -> void:
	var scene: PackedScene = load(RETRO_GAMES_SCENE_PATH)
	assert_not_null(scene, "retro_games.tscn must load")
	if scene == null:
		return
	var root: Node3D = scene.instantiate() as Node3D
	if root == null:
		return
	var sign: Label3D = root.get_node_or_null(
		"Checkout/Register/CheckoutSign"
	) as Label3D
	assert_not_null(
		sign, "Checkout/Register/CheckoutSign Label3D must exist",
	)
	if sign == null:
		root.free()
		return
	assert_lte(
		sign.pixel_size, CHECKOUT_SIGN_MAX_PIXEL_SIZE,
		(
			"CheckoutSign pixel_size=%.4f must be <= %.4f so the billboard "
			+ "label sits at counter scale rather than floating as a giant "
			+ "banner above the register."
		) % [sign.pixel_size, CHECKOUT_SIGN_MAX_PIXEL_SIZE],
	)
	root.free()
