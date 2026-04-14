## Validates customer_profiles.json — 8 NPC archetypes with correct data.
extends GutTest


const ARCHETYPE_IDS: Array[String] = [
	"power_shopper",
	"window_browser",
	"food_court_camper",
	"social_butterfly",
	"reluctant_companion",
	"impulse_buyer",
	"speed_runner",
	"teen_pack_member",
]

const VALID_STORE_IDS: Array[String] = [
	"sports",
	"retro_games",
	"rentals",
	"pocket_creatures",
	"electronics",
]


func test_eight_archetypes_loaded() -> void:
	for archetype_id: String in ARCHETYPE_IDS:
		var customers: Array[CustomerTypeDefinition] = (
			DataLoader.get_all_customers()
		)
		var found: bool = false
		for c: CustomerTypeDefinition in customers:
			if c.id == archetype_id:
				found = true
				break
		assert_true(
			found,
			"Archetype '%s' should be loaded" % archetype_id
		)


func test_archetypes_resolve_in_registry() -> void:
	for archetype_id: String in ARCHETYPE_IDS:
		var canonical: StringName = ContentRegistry.resolve(archetype_id)
		assert_ne(
			canonical, &"",
			"Archetype '%s' should resolve in ContentRegistry"
			% archetype_id
		)


func test_archetype_fields_valid() -> void:
	var customers: Array[CustomerTypeDefinition] = (
		DataLoader.get_all_customers()
	)
	for c: CustomerTypeDefinition in customers:
		if c.id not in ARCHETYPE_IDS:
			continue
		assert_false(
			c.customer_name.is_empty(),
			"'%s' should have a display name" % c.id
		)
		assert_false(
			c.description.is_empty(),
			"'%s' should have a description" % c.id
		)
		assert_true(
			c.patience >= 0.0 and c.patience <= 1.0,
			"'%s' patience (%.2f) should be in 0.0–1.0" % [c.id, c.patience]
		)
		assert_true(
			c.price_sensitivity >= 0.0 and c.price_sensitivity <= 1.0,
			"'%s' price_sensitivity (%.2f) should be in 0.0–1.0"
			% [c.id, c.price_sensitivity]
		)
		assert_true(
			c.impulse_buy_chance >= 0.0 and c.impulse_buy_chance <= 1.0,
			"'%s' impulse_buy_chance (%.2f) should be in 0.0–1.0"
			% [c.id, c.impulse_buy_chance]
		)


func test_archetype_store_types_valid() -> void:
	var customers: Array[CustomerTypeDefinition] = (
		DataLoader.get_all_customers()
	)
	for c: CustomerTypeDefinition in customers:
		if c.id not in ARCHETYPE_IDS:
			continue
		assert_gt(
			c.store_types.size(), 0,
			"'%s' should have at least one store type" % c.id
		)
		for store_id: String in c.store_types:
			assert_has(
				VALID_STORE_IDS, store_id,
				"'%s' store type '%s' should be a valid store ID"
				% [c.id, store_id]
			)
