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
const PRODUCT_COVER_PATHS: Array[String] = [
	"res://game/assets/products/product_dungeon_dad_64.svg",
	"res://game/assets/products/product_space_mall_3.svg",
	"res://game/assets/products/product_kart_clerk_deluxe.svg",
	"res://game/assets/products/product_pixel_pets_moon_mix.svg",
]
const PRODUCT_TEXTURE_PATHS: Array[String] = [
	"res://game/assets/products/product_dungeon_dad_64.png",
	"res://game/assets/products/product_space_mall_3.png",
	"res://game/assets/products/product_kart_clerk_deluxe.png",
	"res://game/assets/products/product_pixel_pets_moon_mix.png",
]
const PRODUCT_COVER_TITLES: Array[String] = [
	"DUNGEON",
	"SPACE",
	"KART CLERK",
	"PIXEL PETS",
]

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
const BACKROOM_MIN_DOORWAY_WIDTH: float = 2.4
const BETA_VISUAL_LANDMARKS: Array[String] = [
	"ReadabilityProps/ZoneLighting/MainAisleWarmFill",
	"ReadabilityProps/ZoneLighting/CheckoutAmberFill",
	"ReadabilityProps/ZoneIdentity/CheckoutCeilingPractical",
	"ReadabilityProps/ZoneIdentity/AisleCeilingPractical",
	"ReadabilityProps/ZoneIdentity/ShelfCeilingPractical",
	"ReadabilityProps/ZoneIdentity/BackWallPurpleBandLeft",
	"ReadabilityProps/ZoneIdentity/BackroomFloorMat",
	"ReadabilityProps/ProductDisplayRows/ShelfProductBacker",
	"ReadabilityProps/ShelfFaceDressing/NewReleaseFaceA",
	"ReadabilityProps/FloorDisplayIsland/FrontCaseA",
	"ReadabilityProps/DayOneRouteMarkers/TrainingStopManager",
	"ReadabilityProps/DayOneRouteMarkers/TrainingStopRegister",
	"ReadabilityProps/DayOneRouteMarkers/TrainingStopBackroom",
	"ReadabilityProps/DayOneRouteMarkers/TrainingStopShelf",
	"ReadabilityProps/ProductDisplayRows/DungeonDad64_ShelfA",
	"ReadabilityProps/ProductDisplayRows/SpaceMall3_ShelfA",
	"ReadabilityProps/ProductDisplayRows/KartClerkDeluxe_ShelfA",
	"ReadabilityProps/ProductDisplayRows/PixelPetsMoonMix_ShelfA",
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


func test_product_cover_svgs_exist_and_carry_named_art() -> void:
	for i: int in PRODUCT_COVER_PATHS.size():
		var path: String = PRODUCT_COVER_PATHS[i]
		assert_true(FileAccess.file_exists(path), "Product cover missing: %s" % path)
		assert_true(
			FileAccess.file_exists(PRODUCT_TEXTURE_PATHS[i]),
			"Runtime product texture missing: %s" % PRODUCT_TEXTURE_PATHS[i]
		)
		var file := FileAccess.open(path, FileAccess.READ)
		assert_not_null(file, "Product cover must be readable: %s" % path)
		if file == null:
			continue
		var source: String = file.get_as_text()
		assert_true(
			source.contains(PRODUCT_COVER_TITLES[i]),
			"Product cover %s must include the in-universe title text" % path
		)


func test_product_display_rows_have_at_least_four_named_products() -> void:
	var scene: PackedScene = load(RETRO_GAMES_SCENE_PATH)
	assert_not_null(scene, "retro_games.tscn must load")
	if scene == null:
		return
	var root: Node3D = scene.instantiate() as Node3D
	if root == null:
		return
	var product_nodes: Array[Node] = []
	_collect_group_nodes(root, &"product_display", product_nodes)
	assert_gte(
		product_nodes.size(),
		4,
		"Beta store must render at least four named product displays"
	)
	for required_name: String in [
		"DungeonDad64_ShelfA",
		"SpaceMall3_ShelfA",
		"KartClerkDeluxe_ShelfA",
		"PixelPetsMoonMix_ShelfA",
	]:
		assert_not_null(
			root.find_child(required_name, true, false),
			"Missing named product display %s" % required_name
		)
	root.free()


func test_product_display_rows_use_svg_cover_textures() -> void:
	var scene: PackedScene = load(RETRO_GAMES_SCENE_PATH)
	assert_not_null(scene, "retro_games.tscn must load")
	if scene == null:
		return
	var root: Node3D = scene.instantiate() as Node3D
	if root == null:
		return
	for node_path: String in [
		"ReadabilityProps/ProductDisplayRows/DungeonDad64_ShelfA",
		"ReadabilityProps/ProductDisplayRows/SpaceMall3_ShelfA",
		"ReadabilityProps/ProductDisplayRows/KartClerkDeluxe_ShelfA",
		"ReadabilityProps/ProductDisplayRows/PixelPetsMoonMix_ShelfA",
	]:
		var product: MeshInstance3D = root.get_node_or_null(node_path) as MeshInstance3D
		assert_not_null(product, "Missing product cover mesh: %s" % node_path)
		if product == null:
			continue
		var mat: StandardMaterial3D = product.get_surface_override_material(
			0
		) as StandardMaterial3D
		assert_not_null(mat, "Product cover must use a StandardMaterial3D")
		if mat != null:
			assert_not_null(
				mat.albedo_texture,
				"Product cover %s must bind an SVG texture" % node_path
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


func test_readability_props_remain_visual_only() -> void:
	var scene: PackedScene = load(RETRO_GAMES_SCENE_PATH)
	assert_not_null(scene, "retro_games.tscn must load")
	if scene == null:
		return
	var root: Node3D = scene.instantiate() as Node3D
	if root == null:
		return
	var readability_root: Node = root.get_node_or_null("ReadabilityProps")
	assert_not_null(readability_root, "ReadabilityProps must exist")
	if readability_root != null:
		assert_false(
			_has_collision_shape_descendant(readability_root),
			"Visual overhaul props must not add collision shapes"
		)
		assert_false(
			_has_area_descendant(readability_root),
			"Visual overhaul props must not add new interactable areas"
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


func test_product_wall_posters_stay_hidden_until_physically_anchored() -> void:
	var scene: PackedScene = load(RETRO_GAMES_SCENE_PATH)
	assert_not_null(scene, "retro_games.tscn must load")
	if scene == null:
		return
	var root: Node3D = scene.instantiate() as Node3D
	if root == null:
		return
	for node_path: String in [
		"ReadabilityProps/WallPosters/WallPosterA",
		"ReadabilityProps/WallPosters/WallPosterB",
		"ReadabilityProps/WallPosters/WallPosterC",
		"ReadabilityProps/WallPosters/WallPosterD",
	]:
		var node: Node3D = root.get_node_or_null(node_path) as Node3D
		assert_not_null(node, "Expected product poster node %s" % node_path)
		if node != null:
			assert_false(
				node.visible,
				"%s must stay hidden; named products should sit on rails or shelves"
				% node_path
			)
	root.free()


func test_backroom_entry_reads_as_service_bay_not_tiny_closet() -> void:
	var scene: PackedScene = load(RETRO_GAMES_SCENE_PATH)
	assert_not_null(scene, "retro_games.tscn must load")
	if scene == null:
		return
	var root: Node3D = scene.instantiate() as Node3D
	if root == null:
		return
	var left_wall: Node3D = root.get_node_or_null(
		"BetaBackroomWallFrontLeft"
	) as Node3D
	var right_wall: Node3D = root.get_node_or_null(
		"BetaBackroomWallFrontRight"
	) as Node3D
	var floor_mat: MeshInstance3D = root.get_node_or_null(
		"ReadabilityProps/ZoneIdentity/BackroomFloorMat"
	) as MeshInstance3D
	assert_not_null(left_wall, "Backroom left front partition must exist")
	assert_not_null(right_wall, "Backroom right front partition must exist")
	assert_not_null(floor_mat, "Backroom floor mat must mark the service bay")
	if left_wall != null and right_wall != null:
		var left_mesh: MeshInstance3D = left_wall.get_node_or_null(
			"WallMesh"
		) as MeshInstance3D
		var right_mesh: MeshInstance3D = right_wall.get_node_or_null(
			"WallMesh"
		) as MeshInstance3D
		assert_not_null(left_mesh, "Backroom left front partition needs a mesh")
		assert_not_null(right_mesh, "Backroom right front partition needs a mesh")
		if left_mesh != null and right_mesh != null:
			var left_box: BoxMesh = left_mesh.mesh as BoxMesh
			var right_box: BoxMesh = right_mesh.mesh as BoxMesh
			assert_not_null(left_box, "Left partition must use a BoxMesh")
			assert_not_null(right_box, "Right partition must use a BoxMesh")
			if left_box != null and right_box != null:
				var left_edge: float = left_wall.position.x + left_box.size.x * 0.5
				var right_edge: float = right_wall.position.x - right_box.size.x * 0.5
				assert_gte(
					right_edge - left_edge,
					BACKROOM_MIN_DOORWAY_WIDTH,
					"Backroom doorway must stay wide enough to read as a service bay"
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


func _collect_group_nodes(root: Node, group_name: StringName, out: Array[Node]) -> void:
	if root.is_in_group(group_name):
		out.append(root)
	for child: Node in root.get_children():
		_collect_group_nodes(child, group_name, out)


func _has_collision_shape_descendant(root: Node) -> bool:
	for child: Node in root.get_children():
		if child is CollisionShape3D:
			return true
		if _has_collision_shape_descendant(child):
			return true
	return false


func _has_area_descendant(root: Node) -> bool:
	for child: Node in root.get_children():
		if child is Area3D:
			return true
		if _has_area_descendant(child):
			return true
	return false
