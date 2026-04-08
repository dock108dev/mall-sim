# Asset Pipeline - Mallcore Sim

## Overview

This document defines the asset creation pipeline for Mallcore Sim targeting
Godot 4.x. All assets are placeholder-quality until the pipeline is validated
end-to-end. No final art should be committed to the repo yet.

## Modeling Standards

### Polygon Budgets

| Category   | Triangle Range  | Notes                                    |
|------------|-----------------|------------------------------------------|
| Small props| 500 - 2,000     | Products, small decor, handheld items    |
| Fixtures   | 1,000 - 5,000   | Shelves, counters, kiosks, benches       |
| Characters | 3,000 - 8,000   | Customers, staff, NPCs                   |
| Env pieces | 2,000 - 10,000  | Wall sections, floor tiles, storefronts  |

- Keep geometry clean: no n-gons, no overlapping faces, no interior faces.
- Bevel visible hard edges slightly for better shading (1-2 edge loops).
- Merge vertices at seams. Export with normals, no need for tangents initially.

### Modeling Tips

- Model at real-world scale in meters, then apply the 1.2x product scale in-engine.
- Keep origin at the base center of each object for easy placement on shelves/floors.
- Flat-bottom geometry for props so they sit cleanly on surfaces without clipping.

## Texture Standards

| Asset Size   | Texture Resolution | Format |
|--------------|--------------------|--------|
| Small props  | 512 x 512          | .png   |
| Large fixtures| 1024 x 1024       | .png   |
| Characters   | 1024 x 1024        | .png   |
| UI elements  | Power-of-two, as needed | .png |

- Use texture atlases where possible. Group related props onto shared sheets.
- Albedo textures carry most of the visual information. Keep them clean and readable.
- Normal maps are optional for the initial pass. Add only where they meaningfully
  improve silhouette reads (e.g., brick walls, fabric folds).
- No roughness/metallic maps initially. Encode material variation through
  StandardMaterial3D parameters directly.

## Materials

- Use Godot `StandardMaterial3D` for all assets initially.
- Minimal custom shader use until performance profiling demands it.
- Set albedo color tints on materials rather than baking color into every texture.
  This allows recoloring props cheaply (e.g., shirts in 5 colors from 1 texture).
- Material resource files use `.tres` format and live alongside their textures.

## File Formats

| Type       | Format | Notes                                    |
|------------|--------|------------------------------------------|
| 3D models  | .glb   | Binary glTF. Do not use .gltf + .bin.    |
| Textures   | .png   | 8-bit RGBA. Use sRGB for albedo.         |
| Materials  | .tres  | Godot resource format.                   |
| Scenes     | .tscn  | Godot text scene format.                 |

## Godot Import Settings

- 3D models: default import with "Generate Tangents" off, "Mesh Compression" on.
- Textures: VRAM Compressed (S3TC/BPTC for desktop). Filter: Linear Mipmap.
- Albedo textures: sRGB color space. Normal maps: Linear color space.
- Disable "Detect 3D" for UI textures to keep them pixel-crisp.

## Placeholder Assets

During prototyping, use Godot primitive meshes with colored `StandardMaterial3D`:

- **Products**: colored BoxMesh (0.2 x 0.3 x 0.1 m, tinted per category)
- **Shelves**: grey BoxMesh (1.5 x 1.8 x 0.4 m)
- **Characters**: CapsuleMesh (0.4 x 1.7 m) with a SphereMesh head
- **Counters**: BoxMesh (2.0 x 1.0 x 0.6 m)

Prefix all placeholder files with `placeholder_` so they are easy to find and
replace later. See NAMING_CONVENTIONS.md for full details.

## Pipeline Validation Checklist

Before committing final art, confirm the full round-trip works:

1. Model exports from DCC tool as .glb without errors
2. Godot imports the .glb and generates the expected mesh resource
3. Materials apply correctly (albedo color, texture, transparency if needed)
4. Asset places correctly in a test scene at the right scale and origin
5. Performance is acceptable with 50+ instances in a single store scene
6. Placeholder can be swapped for final art without breaking scene references
