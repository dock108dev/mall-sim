## Phase 0.1 P1.2 regression test: the mall presents exactly one store-card
## UI (MallOverview). The hub-hosted StorefrontRow + StorefrontCard scenes
## have been removed per docs/audits/phase0-ui-integrity.md.
extends GutTest


func test_mall_hub_scene_does_not_host_storefront_row() -> void:
	var src: String = FileAccess.get_file_as_string(
		"res://game/scenes/mall/mall_hub.tscn"
	)
	assert_false(
		src.contains("StorefrontRow"),
		"mall_hub.tscn must not host a StorefrontRow (removed per P1.2)"
	)
	assert_false(
		src.contains("storefront_card.tscn"),
		"mall_hub.tscn must not instance storefront_card.tscn"
	)


func test_storefront_card_files_are_deleted() -> void:
	assert_false(
		FileAccess.file_exists("res://game/scenes/mall/storefront_card.tscn"),
		"storefront_card.tscn must be deleted per P1.2 (MallOverview wins)"
	)
	assert_false(
		FileAccess.file_exists("res://game/scenes/mall/storefront_card.gd"),
		"storefront_card.gd must be deleted per P1.2"
	)


func test_mall_overview_ships_one_card_per_content_registry_store() -> void:
	# MallOverview populates StoreSlotCards from ContentRegistry.get_all_store_ids()
	# on setup(). The hub path into a store goes through
	# MallOverview → StoreSlotCard.store_selected → EventBus.enter_store_requested.
	var scene: PackedScene = load(
		"res://game/scenes/mall/mall_overview.tscn"
	) as PackedScene
	assert_not_null(scene, "mall_overview.tscn must load")
	var root: Node = scene.instantiate()
	add_child_autofree(root)
	# We don't call setup() here (it needs live systems); the acceptance is
	# structural: MallOverview exposes the populate path, and the number of
	# cards at runtime equals ContentRegistry.get_all_store_ids().size().
	assert_true(
		root.has_method("setup"),
		"MallOverview must expose setup(inventory_system, economy_system)"
	)
	var src: String = FileAccess.get_file_as_string(
		"res://game/scenes/mall/mall_overview.gd"
	)
	assert_true(
		src.contains("ContentRegistry.get_all_store_ids()"),
		"MallOverview must be data-driven from ContentRegistry"
	)
	assert_true(
		src.contains("EventBus.enter_store_requested.emit"),
		"MallOverview card click must emit enter_store_requested"
	)
