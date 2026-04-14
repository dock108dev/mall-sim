# Material Audit — StandardMaterial3D Roughness & Metallic Ranges

Audit performed for ISSUE-052. All materials in `game/assets/materials/` and inline
store scene materials reviewed against the unified range table.

## Unified Range Table

| Surface Type     | Roughness Range | Metallic Range |
|------------------|-----------------|----------------|
| Floor            | 0.7 – 0.9      | 0.0            |
| Wall             | 0.8 – 0.95     | 0.0            |
| Counter / Shelf  | 0.4 – 0.7      | 0.0 – 0.2     |
| Metal Fixture    | 0.2 – 0.4      | 0.8 – 1.0     |

No material may use roughness = 0.0 (mirror) or roughness = 1.0 (chalk).

## Floor Materials

| File | Roughness | Metallic | Status |
|------|-----------|----------|--------|
| mat_floor_tile_cream.tres | 0.82 | 0.0 | OK |
| mat_floor_wood_warm.tres | 0.88 | 0.0 | OK |
| mat_floor_carpet_navy.tres | 0.9 | 0.0 | Fixed (was 0.95) |
| mat_hallway_floor.tres | 0.8 | 0.0 | OK |
| mat_floor_concrete_textured.tres | 0.9 | 0.0 | OK |
| mat_floor_tile_textured.tres | 0.82 | 0.0 | OK |

## Wall Materials

| File | Roughness | Metallic | Status |
|------|-----------|----------|--------|
| mat_wall_cream.tres | 0.92 | 0.0 | OK |
| mat_hallway_wall.tres | 0.9 | 0.0 | OK |
| mat_wall_warm_white.tres | 0.9 | 0.0 | OK |
| mat_wall_surface_textured.tres | 0.92 | 0.0 | OK |

## Counter / Shelf Materials

| File | Roughness | Metallic | Status |
|------|-----------|----------|--------|
| mat_laminate_counter.tres | 0.7 | 0.0 | OK |
| mat_wood_dark.tres | 0.65 | 0.0 | Fixed (was 0.85) |
| mat_wood_medium.tres | 0.6 | 0.0 | Fixed (was 0.85) |
| mat_wood_light.tres | 0.55 | 0.0 | Fixed (was 0.83) |
| mat_wood_grain_textured.tres | 0.6 | 0.0 | Fixed (was 0.85) |
| mat_door_wood.tres | 0.68 | 0.0 | OK |
| mat_sign_backing.tres | 0.85 | 0.0 | OK (signage, not shelf) |
| lectern_mat (pocket_creatures inline) | 0.6 | 0.0 | OK |
| frame_mat (all stores inline) | 0.7 | 0.0 | OK |

## Metal Fixture Materials

| File | Roughness | Metallic | Status |
|------|-----------|----------|--------|
| mat_metal_brushed.tres | 0.35 | 0.85 | Fixed (was R:0.6 M:0.25) |
| mat_metal_dark.tres | 0.3 | 0.9 | Fixed (was R:0.65 M:0.3) |
| mat_trash_can.tres | 0.35 | 0.85 | Fixed (was R:0.7 M:0.2) |
| threshold_mat (consumer_electronics) | 0.35 | 0.85 | Fixed (M was 0.7) |
| threshold_mat (pocket_creatures) | 0.35 | 0.85 | Fixed (M was 0.7) |
| threshold_mat (retro_games) | 0.35 | 0.85 | Fixed (M was 0.7) |
| threshold_mat (sports_memorabilia) | 0.35 | 0.85 | Fixed (M was 0.7) |
| threshold_mat (video_rental) | 0.35 | 0.85 | Fixed (M was 0.7) |

## Other Materials (Not in Range Table)

These materials fall outside the four surface categories and are left as-is.

| File | Roughness | Metallic | Category |
|------|-----------|----------|----------|
| mat_ceiling_warm.tres | 0.95 | 0.0 | Ceiling |
| mat_glass_display.tres | 0.15 | 0.1 | Glass |
| mat_storefront_glass.tres | 0.08 | 0.2 | Glass |
| mat_glass_storefront_textured.tres | 0.2 | 0.1 | Glass |
| mat_storefront_facade.tres | 0.78 | 0.0 | Facade |
| mat_directory_sign.tres | 0.8 | 0.1 | Signage |
| mat_plant_foliage.tres | 0.92 | 0.0 | Foliage |
| mat_fluorescent_panel.tres | emissive | — | Lighting |
| mat_slot_marker.tres | — | — | UI marker |
| mat_slot_empty.tres | — | — | UI marker |
| mat_poster_*.tres | 0.95 | 0.0 | Paper/poster |
| mat_product_*.tres | 0.7–0.95 | 0.0–0.15 | Product |
| crt_screen_mat (video_rental) | emissive | — | CRT screen |
| sign_backing_mat (all stores) | emissive | — | Sign lighting |

## Extremes Check

No material uses roughness = 0.0 or roughness = 1.0.
Minimum roughness in project: 0.08 (storefront glass — intentional for clear glass).
Maximum roughness in project: 0.95 (ceiling, posters — matte surfaces outside range table).
