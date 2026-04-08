# Mall Layout

This document defines the physical layout of the mall environment — store positions, hallways, common areas, and expansion zones.

---

## Design Goals

- Support 5+ store positions with room to grow
- Navigation between stores should feel natural and quick (< 15 seconds walk)
- Common areas add atmosphere and break up the retail monotony
- The layout should feel like a real small-to-mid-size 2000s indoor mall
- Expansion zones are clearly marked for future content

## Floor Plan

```
                    ╔═══════════════════════════════════════════════╗
                    ║                  FOOD COURT                  ║
                    ║   [Tables]  [Tables]  [Tables]  [Tables]     ║
                    ║        [Fountain]                            ║
                    ╠════════╦══════════════════════╦═══════════════╣
                    ║        ║                      ║               ║
     ╔══════════════╣  HALL  ║    CENTRAL ATRIUM    ║    HALL       ╠══════════════╗
     ║              ║   B    ║                      ║     C         ║              ║
     ║  STORE 3     ║        ║   [Benches]          ║               ║  STORE 5     ║
     ║  Video       ╠════════╣   [Directory]        ╠═══════════════╣  Electronics ║
     ║  Rental      ║        ║   [Planter]          ║               ║              ║
     ║              ║ STORE 4║                      ║  EXPANSION    ║              ║
     ╠══════════════╣ Pocket ║                      ║  ZONE B       ╠══════════════╣
     ║              ║Creature║                      ║  (Future)     ║              ║
     ║  EXPANSION   ║        ║                      ║               ║  EXPANSION   ║
     ║  ZONE A      ╠════════╣                      ╠═══════════════╣  ZONE C      ║
     ║  (Future)    ║        ║                      ║               ║  (Future)    ║
     ╚══════════════╣  HALL  ╠══════════════════════╣    HALL       ╠══════════════╝
                    ║   A    ║                      ║     D         ║
                    ╠════════╣                      ╠═══════════════╣
                    ║        ║                      ║               ║
                    ║ STORE 1║                      ║  STORE 2      ║
                    ║ Sports ║                      ║  Retro Games  ║
                    ║ Memora-║                      ║               ║
                    ║ bilia  ║                      ║               ║
                    ╠════════╩══════════════════════╩═══════════════╣
                    ║                                               ║
                    ║              MAIN ENTRANCE                    ║
                    ║         [Automatic Doors]                     ║
                    ╚═══════════════════════════════════════════════╝
```

## Store Positions

| Slot | Store Type | Wing | Size | Notes |
|------|-----------|------|------|-------|
| 1 | Sports Memorabilia | South-West (Hall A) | Small | Starter store, near entrance |
| 2 | Retro Game Store | South-East (Hall D) | Small | Second unlock, near entrance |
| 3 | Video Rental | West (Hall B) | Medium | Wider storefront for browsing |
| 4 | PocketCreatures | West-Central (Hall B) | Small | Adjacent to food court for kid traffic |
| 5 | Consumer Electronics | East (Hall C) | Medium | Larger footprint for demo units |

### Store Sizing

- **Small**: ~8m × 10m interior. 4-6 shelf units, 1 counter. Sports, Retro, PocketCreatures.
- **Medium**: ~10m × 12m interior. 6-8 shelf units, 1 counter, demo/display area. Video Rental, Electronics.
- **Large**: ~12m × 14m interior. Reserved for expansion or upgraded stores.

All stores share the same structural template (see `docs/architecture/SYSTEM_OVERVIEW.md` — StoreBase scene structure) but vary in interior dimensions and fixture count.

## Hallways

Four hallway segments connect the stores to the central atrium:

| Hallway | Connects | Width | Features |
|---------|----------|-------|----------|
| Hall A | Main Entrance ↔ Atrium (west) | 4m | Benches, mall directory, vending machine |
| Hall B | Atrium ↔ Food Court (west) | 4m | Potted plants, promotional banner stands |
| Hall C | Atrium ↔ Food Court (east) | 4m | Payphone bank, ATM, water fountain |
| Hall D | Main Entrance ↔ Atrium (east) | 4m | Gumball machines, claw machine |

Hallways use a consistent 4m width to allow comfortable two-way NPC traffic with the player. Floor material: terrazzo tile with brass inlay strips (era-appropriate).

## Central Atrium

The hub connecting all hallways. Open ceiling with skylights (simulated daylight based on TimeSystem). Features:

- **Mall directory**: Backlit sign showing store locations. Interactive — player can click to get directions.
- **Benches**: NPCs sit here between store visits. Adds life to the common space.
- **Planter**: Large potted ficus tree. Pure atmosphere.
- **Floor pattern**: Star/compass design in the terrazzo. Visual landmark.

Approximate size: 12m × 12m.

## Food Court

North end of the mall. Not a playable store — it's an atmospheric common area.

- 4 table clusters with chairs (NPCs eat here, adds ambient life)
- Counter-service food stalls along the back wall (non-interactive, decorative)
- Central fountain (water sound, visual focal point)
- Vending machines along the side walls

The food court serves as a customer reservoir — NPCs spawn here, eat, then walk to stores. This creates natural foot traffic patterns and makes the mall feel alive.

## Expansion Zones

Three reserved slots for future content (post-M3):

| Zone | Location | Intended Use |
|------|----------|-------------|
| Zone A | West, south of Store 3 | 6th store type (if added) or special event space |
| Zone B | East, between Stores 2 and 5 | 7th store type or mall services (arcade, photo booth) |
| Zone C | East, south of Store 5 | Overflow or seasonal pop-up store |

Expansion zones appear as vacant storefronts with "COMING SOON" or "FOR LEASE" signage. They're visible to the player from day one, creating anticipation and a sense that the mall is a growing space.

## Navigation

### NavMesh Coverage

A single `NavigationRegion3D` covers all walkable areas:
- All hallways
- Central atrium
- Food court
- Store interiors (each store adds its own nav region that connects to the hallway)

Store entrances are `NavigationLink3D` nodes that connect interior navmesh to hallway navmesh.

### Player Navigation

The player walks freely through all public areas. Store interiors are entered by walking through the doorway (no loading screen, no scene transition — stores are loaded as children of the mall scene).

### NPC Pathfinding

Customers use `NavigationAgent3D` with the following behavior:
1. Spawn at main entrance or food court
2. Navigate to target store entrance
3. Enter store, switch to store-interior browsing behavior
4. Exit store, optionally visit another store or leave
5. Navigate to main entrance and despawn

Avoidance is handled by `NavigationAgent3D`'s built-in avoidance. Max simultaneous NPCs in the mall: ~20 (tunable based on performance).

## Lighting

- **Hallways**: Overhead fluorescent panels (slightly warm white, 4000K). Even coverage, no dramatic shadows.
- **Atrium**: Skylight providing directional light that shifts with time of day. Supplemented by recessed ceiling lights.
- **Food court**: Brighter, cooler lighting. Hanging pendant lights over tables.
- **Store interiors**: Each store controls its own lighting (warm for sports/retro, cool for electronics, bright for card shop, dim-warm for video rental).
- **Time of day**: Skylight brightness and color temperature shift across the day cycle. Evening lighting feels cozier (dimmer skylight, warmer artificial light).

## Audio Zones

- **Hallways/Atrium**: Mall ambiance — distant chatter, footsteps on tile, faint muzak from overhead speakers
- **Food court**: Crowd noise, clinking, food court ambiance layered over mall base
- **Store interiors**: Each store has its own ambient track (defined in store_definitions.json) that cross-fades with mall ambiance at the doorway
- **Transitions**: 1-second cross-fade between zones using Godot's `AudioBus` system

## Scene Structure

```
MallScene (Node3D)
  +- Environment (WorldEnvironment, lighting, sky)
  +- NavigationRegion3D (covers all public walkable areas)
  |   +- MallGeometry (StaticBody3D — floors, walls, ceiling)
  |   +- Atrium (furniture, directory, planter)
  |   +- HallwayA (benches, vending, directory)
  |   +- HallwayB (plants, banners)
  |   +- HallwayC (payphone, ATM)
  |   +- HallwayD (gumball, claw machine)
  |   +- FoodCourt (tables, fountain, stalls)
  +- StorefrontSlots
  |   +- Slot1 (NavigationLink3D + Area3D entrance trigger)
  |   +- Slot2
  |   +- Slot3
  |   +- Slot4
  |   +- Slot5
  |   +- ExpansionA (vacant storefront)
  |   +- ExpansionB (vacant storefront)
  |   +- ExpansionC (vacant storefront)
  +- SpawnPoints
  |   +- MainEntrance (customer spawn/despawn)
  |   +- FoodCourtSeats (customer idle positions)
  +- AudioZones (Area3D nodes for ambient crossfade triggers)
```

## Metrics

| Measurement | Value | Rationale |
|-------------|-------|-----------|
| Total walkable area | ~800 m² | Feels like a small indoor mall wing |
| Entrance to farthest store | ~40m | < 15 second walk at player speed |
| Hallway width | 4m | Comfortable for 3-wide NPC traffic |
| Ceiling height (hallways) | 4m | Standard mall feel |
| Ceiling height (atrium) | 8m | Open, airy, skylights visible |
| Max simultaneous NPCs | ~20 | Tunable, balances life vs performance |
