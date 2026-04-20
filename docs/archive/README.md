# docs/archive/

Home for retired walkable-world scenes and scripts once the hub + drawer
refactor fully decouples the legacy 3D mall from runtime code paths.

## Current status (Phase 1)

`res://game/scenes/mall/mall_hub.tscn` is now the scene `GameManager`
transitions to after boot. `mall_hub.tscn` embeds `game_world.tscn` as a
child so the Phase 1 slice does not regress any existing systems while the
5-tier init path is still keyed to the legacy composition.

The following walkable-world scenes are still referenced by active code
(`game_world.gd`, `store_selector_system.gd`, `mall_hallway.gd`) and by
multiple tests. They will be moved here once those references are gone:

- `game/scenes/player/player.tscn`
- `game/scenes/player/player_controller.tscn`
- `game/scenes/world/mall_hallway.tscn`
- `game/scenes/world/storefront.tscn`
- `game/scenes/world/game_world.tscn` (retained as `mall_hub.tscn` child)

See ROADMAP.md Phase 1 and docs/research/management-hub-vs-walkable-world-patterns.md.
