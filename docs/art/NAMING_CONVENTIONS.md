# Naming Conventions - Mallcore Sim

## General Rules

- All filenames are **lowercase**.
- Use **underscores** (`_`) as separators. No spaces, no hyphens, no camelCase.
- No special characters. Alphanumeric and underscores only.
- Keep names descriptive but concise. Avoid abbreviations that are not obvious.
- Placeholder assets that should be replaced later use the `placeholder_` prefix.

## Asset Categories

The following category tokens are used across all naming patterns:

| Token       | Description                                      |
|-------------|--------------------------------------------------|
| `prop`      | Small movable objects: products, decor, tools     |
| `fixture`   | Store furniture: shelves, counters, racks, kiosks |
| `character` | Player characters, NPCs, customers, staff         |
| `ui`        | Interface elements: buttons, icons, panels        |
| `vfx`       | Visual effects: particles, shaders, overlays      |
| `env`       | Environment pieces: walls, floors, storefronts    |

## 3D Models

Pattern: `[category]_[subcategory]_[descriptor].glb`

Examples:
- `prop_food_hotdog.glb`
- `prop_clothing_tshirt_folded.glb`
- `prop_electronics_headphones.glb`
- `fixture_shelf_wooden_4slot.glb`
- `fixture_counter_checkout.glb`
- `fixture_rack_circular.glb`
- `character_customer_casual_01.glb`
- `character_staff_cashier.glb`
- `env_wall_storefront_glass.glb`
- `env_floor_tile_checkered.glb`

Use numbered suffixes (`_01`, `_02`) only when there are multiple visual
variants of the same logical object.

## Textures

Pattern: `tex_[object]_[type].png`

Texture type suffixes:

| Suffix     | Map Type        |
|------------|-----------------|
| `_albedo`  | Base color      |
| `_normal`  | Normal map      |
| `_emission`| Emission map    |
| `_mask`    | Channel-packed mask (R=metallic, G=roughness, B=AO) |

Examples:
- `tex_shelf_wooden_albedo.png`
- `tex_shelf_wooden_normal.png`
- `tex_floor_tile_albedo.png`
- `tex_customer_casual_01_albedo.png`
- `tex_storefront_neon_emission.png`

Atlas textures use the `atlas_` prefix instead of a specific object name:
- `tex_atlas_food_court_albedo.png`
- `tex_atlas_clothing_props_albedo.png`

## Materials

Pattern: `mat_[name].tres`

Materials describe the visual quality, not the specific object, so they can be
shared across multiple meshes.

Examples:
- `mat_wood_dark.tres`
- `mat_wood_light.tres`
- `mat_metal_brushed.tres`
- `mat_plastic_glossy_red.tres`
- `mat_fabric_cotton_blue.tres`
- `mat_glass_storefront.tres`

## Scenes

Pattern: `[type]_[name].tscn`

The type token matches the asset category.

Examples:
- `fixture_shelf_wall.tscn`
- `fixture_counter_checkout.tscn`
- `prop_food_hotdog.tscn`
- `character_customer_casual_01.tscn`
- `env_storefront_clothing.tscn`

## UI Assets

Pattern: `ui_[element]_[state].png`

State suffixes:

| Suffix      | Meaning         |
|-------------|-----------------|
| `_default`  | Normal state    |
| `_hover`    | Mouse hover     |
| `_pressed`  | Active/clicked  |
| `_disabled` | Greyed out      |
| `_focused`  | Keyboard focus  |

Examples:
- `ui_button_default.png`
- `ui_button_hover.png`
- `ui_button_pressed.png`
- `ui_icon_cart.png`
- `ui_panel_inventory.png`
- `ui_cursor_grab.png`

## Placeholder Assets

Temporary assets that will be replaced with final art use the `placeholder_`
prefix prepended to the normal name:

- `placeholder_prop_food_hotdog.glb`
- `placeholder_fixture_shelf_wooden_4slot.tscn`
- `placeholder_tex_shelf_wooden_albedo.png`

This makes it easy to search the repo for all placeholders that still need
final art: search for files matching `placeholder_*`.

## Directory Structure Reference

```
assets/
  models/
    props/
    fixtures/
    characters/
    env/
  textures/
    props/
    fixtures/
    characters/
    env/
    ui/
  materials/
  scenes/
    fixtures/
    props/
    characters/
    env/
```
