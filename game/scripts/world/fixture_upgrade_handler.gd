## Handles fixture tier upgrades, cost calculation, and visual updates.
class_name FixtureUpgradeHandler
extends RefCounted

const TIER_COLORS: Dictionary = {
	FixtureDefinition.TierLevel.BASIC: Color(0.6, 0.6, 0.6),
	FixtureDefinition.TierLevel.IMPROVED: Color(0.3, 0.6, 0.9),
	FixtureDefinition.TierLevel.PREMIUM: Color(0.9, 0.75, 0.2),
}

const TIER_SCALE_BONUS: Dictionary = {
	FixtureDefinition.TierLevel.BASIC: 0.0,
	FixtureDefinition.TierLevel.IMPROVED: 0.05,
	FixtureDefinition.TierLevel.PREMIUM: 0.1,
}

var _placed_fixtures: Dictionary
var _data_loader: DataLoader
var _economy_system: EconomySystem
var _reputation_system: ReputationSystem


func initialize(
	placed_fixtures: Dictionary,
	data_loader: DataLoader,
	economy_system: EconomySystem,
	reputation_system: ReputationSystem
) -> void:
	_placed_fixtures = placed_fixtures
	_data_loader = data_loader
	_economy_system = economy_system
	_reputation_system = reputation_system


## Returns the current tier of a placed fixture.
func get_fixture_tier(fixture_id: String) -> int:
	var data: Dictionary = _placed_fixtures.get(fixture_id, {})
	return int(data.get("tier", FixtureDefinition.TierLevel.BASIC))


## Returns whether a fixture can be upgraded to the next tier.
func can_upgrade(fixture_id: String) -> bool:
	var data: Dictionary = _placed_fixtures.get(fixture_id, {})
	if data.is_empty():
		return false
	var current_tier: int = int(
		data.get("tier", FixtureDefinition.TierLevel.BASIC)
	)
	if current_tier >= FixtureDefinition.TierLevel.PREMIUM:
		return false
	var next_tier: int = current_tier + 1
	var rep_req: float = FixtureDefinition.get_rep_requirement(
		next_tier
	)
	if _get_current_reputation() < rep_req:
		return false
	var cost: float = get_upgrade_cost(fixture_id)
	return cost > 0.0


## Returns the cost to upgrade a fixture to the next tier.
func get_upgrade_cost(fixture_id: String) -> float:
	var data: Dictionary = _placed_fixtures.get(fixture_id, {})
	if data.is_empty():
		return 0.0
	var current_tier: int = int(
		data.get("tier", FixtureDefinition.TierLevel.BASIC)
	)
	var next_tier: int = current_tier + 1
	if next_tier > FixtureDefinition.TierLevel.PREMIUM:
		return 0.0
	var fixture_type: String = data.get("fixture_type", "") as String
	if not _data_loader:
		return 0.0
	var def: FixtureDefinition = _data_loader.get_fixture(
		fixture_type
	)
	if not def:
		return 0.0
	return def.get_upgrade_cost(next_tier)


## Returns the reason a fixture cannot be upgraded, or empty if eligible.
func get_upgrade_block_reason(fixture_id: String) -> String:
	var data: Dictionary = _placed_fixtures.get(fixture_id, {})
	if data.is_empty():
		return "Fixture not found"
	var current_tier: int = int(
		data.get("tier", FixtureDefinition.TierLevel.BASIC)
	)
	if current_tier >= FixtureDefinition.TierLevel.PREMIUM:
		return "Already at maximum tier"
	var next_tier: int = current_tier + 1
	var rep_req: float = FixtureDefinition.get_rep_requirement(
		next_tier
	)
	var current_rep: float = _get_current_reputation()
	if current_rep < rep_req:
		return "Requires reputation %.0f (current: %.0f)" % [
			rep_req, current_rep
		]
	var cost: float = get_upgrade_cost(fixture_id)
	if _economy_system and cost > _economy_system.get_cash():
		return "Insufficient funds ($%.0f needed)" % cost
	return ""


## Attempts to upgrade a placed fixture to the next tier.
func try_upgrade(fixture_id: String) -> bool:
	if not can_upgrade(fixture_id):
		var reason: String = get_upgrade_block_reason(fixture_id)
		if not reason.is_empty():
			EventBus.fixture_placement_invalid.emit(reason)
		return false

	var data: Dictionary = _placed_fixtures[fixture_id]
	var current_tier: int = int(
		data.get("tier", FixtureDefinition.TierLevel.BASIC)
	)
	var next_tier: int = current_tier + 1
	var cost: float = get_upgrade_cost(fixture_id)

	if cost > 0.0 and _economy_system:
		var tier_name: String = FixtureDefinition.get_tier_name(
			next_tier
		)
		if not _economy_system.deduct_cash(
			cost, "Fixture upgrade to %s" % tier_name
		):
			EventBus.fixture_placement_invalid.emit(
				"Insufficient funds"
			)
			return false

	data["tier"] = next_tier
	data["total_spent"] = (
		float(data.get("total_spent", 0.0)) + cost
	)
	_placed_fixtures[fixture_id] = data

	update_fixture_visual(fixture_id, next_tier)
	EventBus.fixture_upgraded.emit(fixture_id, next_tier)
	return true


## Returns effective slot count for a placed fixture (base + tier bonus).
func get_effective_slot_count(fixture_id: String) -> int:
	var data: Dictionary = _placed_fixtures.get(fixture_id, {})
	if data.is_empty():
		return 0
	var fixture_type: String = data.get("fixture_type", "") as String
	var tier: int = int(
		data.get("tier", FixtureDefinition.TierLevel.BASIC)
	)
	if _data_loader:
		var def: FixtureDefinition = _data_loader.get_fixture(
			fixture_type
		)
		if def:
			return def.get_slots_for_tier(tier)
	return 0


## Returns the purchase probability bonus for a placed fixture.
func get_fixture_prob_bonus(fixture_id: String) -> float:
	var data: Dictionary = _placed_fixtures.get(fixture_id, {})
	if data.is_empty():
		return 0.0
	var tier: int = int(
		data.get("tier", FixtureDefinition.TierLevel.BASIC)
	)
	return FixtureDefinition.TIER_PURCHASE_PROB_BONUS.get(
		tier, 0.0
	) as float


## Applies tier-based visual changes to a fixture's 3D mesh.
func update_fixture_visual(
	fixture_id: String, tier: int
) -> void:
	var mesh_node: Node = _find_fixture_mesh(fixture_id)
	if not mesh_node:
		return
	var color: Color = TIER_COLORS.get(
		tier, Color(0.6, 0.6, 0.6)
	) as Color
	var scale_bonus: float = TIER_SCALE_BONUS.get(tier, 0.0)
	if mesh_node is MeshInstance3D:
		var mi: MeshInstance3D = mesh_node as MeshInstance3D
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mi.material_override = mat
		mi.scale = Vector3.ONE * (1.0 + scale_bonus)


func _get_current_reputation() -> float:
	if _reputation_system:
		return _reputation_system.get_reputation()
	return 0.0


func _find_fixture_mesh(fixture_id: String) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if not tree:
		return null
	var root: Node = tree.current_scene
	if not root:
		return null
	return _find_node_recursive(root, fixture_id)


func _find_node_recursive(
	node: Node, target_name: String
) -> Node:
	if node.name == target_name:
		return node
	for child: Node in node.get_children():
		var found: Node = _find_node_recursive(
			child, target_name
		)
		if found:
			return found
	return null
