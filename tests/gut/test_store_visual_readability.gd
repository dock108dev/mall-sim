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

# Register-screen emission floor. The screen sub-resource sits behind the
# ambient neon panels (1.7–1.8 energy); below this floor its green glow
# fails to read at the ~8–12m entrance spawn distance and the counter
# loses its "active POS terminal" beacon.
const REGISTER_SCREEN_MIN_EMISSION: float = 1.2
const BETA_VISUAL_LANDMARKS: Array[String] = [
	"ReadabilityProps/ZoneLighting/MainAisleWarmFill",
	"ReadabilityProps/ZoneLighting/CheckoutAmberFill",
	"ReadabilityProps/ZoneIdentity/CheckoutCeilingPractical",
	"ReadabilityProps/ZoneIdentity/AisleCeilingPractical",
	"ReadabilityProps/ZoneIdentity/ShelfCeilingPractical",
	"ReadabilityProps/ZoneIdentity/BackWallPurpleBandLeft",
	"ReadabilityProps/WallPosters/WallPosterC",
	"ReadabilityProps/ShelfFaceDressing/NewReleaseFaceA",
	"ReadabilityProps/FloorDisplayIsland/FrontCaseA",
	"ReadabilityProps/DayOneRouteMarkers/TrainingStopManager",
	"ReadabilityProps/DayOneRouteMarkers/TrainingStopRegister",
	"ReadabilityProps/DayOneRouteMarkers/TrainingStopBackroom",
	"ReadabilityProps/DayOneRouteMarkers/TrainingStopShelf",
]


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


func test_register_screen_emission_clears_spawn_distance_floor() -> void:
	var scene: PackedScene = load(RETRO_GAMES_SCENE_PATH)
	assert_not_null(scene, "retro_games.tscn must load")
	if scene == null:
		return
	var root: Node3D = scene.instantiate() as Node3D
	if root == null:
		return
	var screen: MeshInstance3D = root.get_node_or_null(
		"Checkout/Register/RegisterScreen"
	) as MeshInstance3D
	assert_not_null(
		screen, "Checkout/Register/RegisterScreen MeshInstance3D must exist",
	)
	if screen == null:
		root.free()
		return
	var mat: StandardMaterial3D = screen.get_surface_override_material(
		0
	) as StandardMaterial3D
	assert_not_null(
		mat,
		"RegisterScreen must carry a StandardMaterial3D override (register_screen_mat)",
	)
	if mat == null:
		root.free()
		return
	assert_true(
		mat.emission_enabled,
		"register_screen_mat must keep emission enabled so the POS screen glows",
	)
	assert_gte(
		mat.emission_energy_multiplier, REGISTER_SCREEN_MIN_EMISSION,
		(
			"register_screen_mat emission_energy_multiplier=%.2f must be >= %.2f "
			+ "so the green screen glow reads at the ~8–12m entrance spawn "
			+ "distance against the 1.7–1.8 ambient neon panels."
		) % [mat.emission_energy_multiplier, REGISTER_SCREEN_MIN_EMISSION],
	)
	root.free()


func test_beta_store_has_visual_landmark_overhaul_nodes() -> void:
	var scene: PackedScene = load(RETRO_GAMES_SCENE_PATH)
	assert_not_null(scene, "retro_games.tscn must load")
	if scene == null:
		return
	var root: Node3D = scene.instantiate() as Node3D
	if root == null:
		return
	for node_path: String in BETA_VISUAL_LANDMARKS:
		assert_not_null(
			root.get_node_or_null(node_path),
			"Beta visual landmark missing: %s" % node_path
		)
	root.free()


func test_beta_store_visual_lighting_clears_readability_floor() -> void:
	var scene: PackedScene = load(RETRO_GAMES_SCENE_PATH)
	assert_not_null(scene, "retro_games.tscn must load")
	if scene == null:
		return
	var root: Node3D = scene.instantiate() as Node3D
	if root == null:
		return
	var main_fill: OmniLight3D = root.get_node_or_null(
		"ReadabilityProps/ZoneLighting/MainAisleWarmFill"
	) as OmniLight3D
	var checkout_fill: OmniLight3D = root.get_node_or_null(
		"ReadabilityProps/ZoneLighting/CheckoutAmberFill"
	) as OmniLight3D
	assert_not_null(main_fill, "Main aisle fill light must exist")
	assert_not_null(checkout_fill, "Checkout fill light must exist")
	if main_fill != null:
		assert_gte(
			main_fill.light_energy, 0.65,
			"Main aisle fill must be bright enough to reduce the gray wash"
		)
	if checkout_fill != null:
		assert_gte(
			checkout_fill.light_energy, 0.5,
			"Checkout fill must keep the tutorial target readable"
		)
	root.free()


func test_beta_store_removes_floating_unanchored_zone_signs() -> void:
	var scene: PackedScene = load(RETRO_GAMES_SCENE_PATH)
	assert_not_null(scene, "retro_games.tscn must load")
	if scene == null:
		return
	var root: Node3D = scene.instantiate() as Node3D
	if root == null:
		return
	for node_path: String in [
		"ZoneLabels/CheckoutBacking",
		"ZoneLabels/CheckoutLabel",
		"ZoneLabels/TradeInsBacking",
		"ZoneLabels/TradeInsLabel",
	]:
		var node: Node3D = root.get_node_or_null(node_path) as Node3D
		assert_not_null(node, "Expected optional sign node %s" % node_path)
		if node != null:
			assert_false(
				node.visible,
				"%s must stay hidden until it has a physical fixture anchor" % node_path
			)
	root.free()


func test_side_wall_used_consoles_label_is_not_backside_mirrored() -> void:
	var scene: PackedScene = load(RETRO_GAMES_SCENE_PATH)
	assert_not_null(scene, "retro_games.tscn must load")
	if scene == null:
		return
	var root: Node3D = scene.instantiate() as Node3D
	if root == null:
		return
	var label: Label3D = root.get_node_or_null(
		"ZoneLabels/UsedConsolesLabel"
	) as Label3D
	assert_not_null(label, "UsedConsolesLabel must exist")
	if label != null:
		assert_false(
			label.double_sided,
			"UsedConsolesLabel must not render mirrored on its backside"
		)
	root.free()


func test_ceiling_practicals_are_retail_scale_not_giant_planes() -> void:
	var scene: PackedScene = load(RETRO_GAMES_SCENE_PATH)
	assert_not_null(scene, "retro_games.tscn must load")
	if scene == null:
		return
	var root: Node3D = scene.instantiate() as Node3D
	if root == null:
		return
	var practical: MeshInstance3D = root.get_node_or_null(
		"ReadabilityProps/ZoneIdentity/CheckoutCeilingPractical"
	) as MeshInstance3D
	assert_not_null(practical, "Checkout ceiling practical must exist")
	if practical == null:
		root.free()
		return
	var mesh: BoxMesh = practical.mesh as BoxMesh
	assert_not_null(mesh, "Ceiling practical must use the shared BoxMesh")
	if mesh != null:
		assert_lte(
			mesh.size.x,
			0.9,
			"Ceiling practicals must stay small enough to read as fixtures"
		)
	var mat: StandardMaterial3D = practical.get_surface_override_material(
		0
	) as StandardMaterial3D
	assert_not_null(mat, "Ceiling practical must carry a StandardMaterial3D")
	if mat != null:
		assert_lte(
			mat.emission_energy_multiplier,
			0.55,
			"Ceiling practicals must not bloom into oversized flat yellow planes"
		)
	root.free()
