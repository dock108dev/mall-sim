## Verifies ISSUE-029 placeholder textures and materials are present and wired into scenes.
extends GutTest


const ALLOWED_TEXTURE_SIZES: Array[int] = [256, 512]
const REQUIRED_TEXTURES: Array[Dictionary] = [
	{"path": "res://game/assets/textures/tex_wood_grain_albedo.png"},
	{"path": "res://game/assets/textures/tex_floor_concrete_albedo.png"},
	{"path": "res://game/assets/textures/tex_floor_tile_albedo.png"},
	{"path": "res://game/assets/textures/tex_wall_surface_albedo.png"},
	{"path": "res://game/assets/textures/tex_glass_storefront_albedo.png"},
	{"path": "res://game/assets/textures/tex_product_retro_games_albedo.png"},
	{"path": "res://game/assets/textures/tex_product_video_rental_albedo.png"},
	{"path": "res://game/assets/textures/tex_product_pocket_creatures_albedo.png"},
	{"path": "res://game/assets/textures/tex_product_sports_memorabilia_albedo.png"},
	{"path": "res://game/assets/textures/tex_product_consumer_electronics_albedo.png"},
]
const REQUIRED_MATERIALS: Array[Dictionary] = [
	{
		"material": "res://game/assets/materials/mat_wood_grain_textured.tres",
		"texture": "res://game/assets/textures/tex_wood_grain_albedo.png",
	},
	{
		"material": "res://game/assets/materials/mat_floor_concrete_textured.tres",
		"texture": "res://game/assets/textures/tex_floor_concrete_albedo.png",
	},
	{
		"material": "res://game/assets/materials/mat_floor_tile_textured.tres",
		"texture": "res://game/assets/textures/tex_floor_tile_albedo.png",
	},
	{
		"material": "res://game/assets/materials/mat_wall_surface_textured.tres",
		"texture": "res://game/assets/textures/tex_wall_surface_albedo.png",
	},
	{
		"material": "res://game/assets/materials/mat_glass_storefront_textured.tres",
		"texture": "res://game/assets/textures/tex_glass_storefront_albedo.png",
	},
	{
		"material": "res://game/assets/materials/mat_product_retro_games_textured.tres",
		"texture": "res://game/assets/textures/tex_product_retro_games_albedo.png",
	},
	{
		"material": "res://game/assets/materials/mat_product_video_rental_textured.tres",
		"texture": "res://game/assets/textures/tex_product_video_rental_albedo.png",
	},
	{
		"material": "res://game/assets/materials/mat_product_pocket_creatures_textured.tres",
		"texture": "res://game/assets/textures/tex_product_pocket_creatures_albedo.png",
	},
	{
		"material": "res://game/assets/materials/mat_product_sports_memorabilia_textured.tres",
		"texture": "res://game/assets/textures/tex_product_sports_memorabilia_albedo.png",
	},
	{
		"material": "res://game/assets/materials/mat_product_consumer_electronics_textured.tres",
		"texture": "res://game/assets/textures/tex_product_consumer_electronics_albedo.png",
	},
]


func test_required_placeholder_textures_exist_and_use_supported_sizes() -> void:
	var texture_dir: PackedStringArray = DirAccess.get_files_at("res://game/assets/textures")
	var png_count: int = 0
	for file_name: String in texture_dir:
		if file_name.ends_with(".png"):
			png_count += 1

	assert_gte(
		png_count,
		REQUIRED_TEXTURES.size(),
		"Placeholder texture directory should contain at least 10 PNG textures"
	)

	for texture_def: Dictionary in REQUIRED_TEXTURES:
		var texture_path: String = texture_def["path"]
		var texture: Texture2D = load(texture_path) as Texture2D
		assert_not_null(texture, "Texture should load: %s" % texture_path)
		if texture == null:
			continue

		assert_eq(
			texture.get_width(),
			texture.get_height(),
			"Texture should be square: %s" % texture_path
		)
		assert_true(
			ALLOWED_TEXTURE_SIZES.has(texture.get_width()),
			"Texture should be 256x256 or 512x512: %s" % texture_path
		)


func test_textured_materials_reference_required_albedo_maps() -> void:
	for material_def: Dictionary in REQUIRED_MATERIALS:
		var material_path: String = material_def["material"]
		var texture_path: String = material_def["texture"]
		var material: StandardMaterial3D = load(material_path) as StandardMaterial3D
		assert_not_null(material, "Material should load: %s" % material_path)
		if material == null:
			continue

		assert_not_null(
			material.albedo_texture,
			"Material should include an albedo texture: %s" % material_path
		)
		if material.albedo_texture == null:
			continue

		assert_eq(
			material.albedo_texture.resource_path,
			texture_path,
			"Material should reference the expected texture: %s" % material_path
		)
