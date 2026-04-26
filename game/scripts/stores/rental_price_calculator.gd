## Pure rental-pricing helpers used by VideoRentalStoreController.
## Extracted to keep the controller under the gdlint max-file-lines limit.
class_name RentalPriceCalculator
extends RefCounted


## Returns the lifecycle multiplier for a rental item definition on the given day.
static func compute_lifecycle_factor(
	def: ItemDefinition, current_day: int
) -> float:
	var phase: String = (
		def.lifecycle_phase if not def.lifecycle_phase.is_empty() else def.rarity
	)
	if phase == "ultra_new" or phase == "new":
		var release: int = def.release_day if def.release_day > 0 else def.release_date
		if release > 0:
			var age: int = current_day - release
			if age < 0:
				return PriceResolver.LIFECYCLE_MULTIPLIERS.get("ultra_new", 1.35)
			if age < 7:
				return PriceResolver.LIFECYCLE_MULTIPLIERS.get("ultra_new", 1.35)
			if age < 21:
				return PriceResolver.LIFECYCLE_MULTIPLIERS.get("new", 1.15)
	if phase == "ultra_new":
		return PriceResolver.LIFECYCLE_MULTIPLIERS.get("ultra_new", 1.35)
	if phase == "new":
		return PriceResolver.LIFECYCLE_MULTIPLIERS.get("new", 1.15)
	return PriceResolver.LIFECYCLE_MULTIPLIERS.get("common", 1.0)


## Returns a condition-based rental price factor: worn items rent for less.
static func compute_condition_factor(condition: String) -> float:
	match condition:
		"mint", "near_mint":
			return 1.0
		"good":
			return 1.0
		"fair":
			return 0.90
		"poor":
			return 0.80
	return 1.0
