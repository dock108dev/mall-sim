# Configuration and Deployment

## Project configuration

Key current settings in `project.godot`:

- application name: `Mallcore Sim`
- description: `A retail simulator inspired by 2000s mall and store culture.`
- version: `0.1.0`
- main scene: `res://game/scenes/bootstrap/boot.tscn`
- project features: `4.6` with `Forward Plus`
- icon: `res://icon.svg`
- custom theme: `res://game/resources/ui/mall_theme.tres`
- translations: English and Spanish translation resources
- enabled editor plugin: `res://addons/gut/plugin.cfg`

The autoload list is documented in [Architecture](architecture.md).

## Input and runtime settings

`project.godot` currently defines action groups for:

- movement and interaction
- debug toggle
- inventory, orders, staff, and pricing panel toggles
- camera orbit, pan, and zoom
- build mode toggle and fixture rotation
- time speed changes and pause

Use `project.godot` as the source of truth for exact bindings.

## User data and persistence

Runtime persistence uses Godot `user://` paths:

- settings: `user://settings.cfg`
- save index: `user://save_index.cfg`
- saves: `user://save_slot_<n>.json`

`SaveManager` currently:

- supports one auto-save slot plus three manual slots
- caps save-file reads at `10 MiB`
- writes save files atomically through a temporary file and rename

## Checked-in integrations

The checked-in integrations documented in this repository are:

- Godot editor/runtime through `project.godot`
- GUT through `addons/gut/` and `.gutconfig.json`
- helper scripts in `scripts/` for import and Godot execution
- GitHub Actions workflows for validation and tagged exports
- `gdtoolkit` linting in CI

## Export presets

`export_presets.cfg` currently defines:

| Preset | Export path in preset | Notes |
| --- | --- | --- |
| `Windows Desktop` | `exports/windows/MallcoreSim.exe` | x86_64, embedded PCK, built-in code signing disabled. |
| `macOS` | `exports/macos/MallcoreSim.zip` | universal architecture, minimum macOS `10.15`, built-in code signing disabled. |
| `Linux/X11` | `exports/linux/MallcoreSim.x86_64` | Linux desktop preset checked in for local export use. |

All current presets exclude `.aidlc`, `docs`, `tests`, `game/tests`,
`addons/gut`, `game/addons/gut`, `.godot`, Markdown, text files, `.gitignore`,
and `.gutconfig.json` from export payloads.

## Local export

From the editor:

1. Open `project.godot`.
2. Confirm export templates are installed for your Godot version.
3. Open **Project -> Export**.
4. Select the target preset.
5. Export a release build.

For command-line export, import assets first with:

```bash
bash scripts/godot_import.sh
```

Then use Godot's `--export-release` with the preset name.

## GitHub Actions workflows

### Validation workflow

`.github/workflows/validate.yml` runs on pushes and pull requests to `main` and
currently includes:

1. `lint-docs` for required-file and repository-shape checks
2. `gut-tests` for Godot install, import, and headless GUT execution
3. `lint-gdscript` for non-blocking `gdlint`

Current documented mismatch: `lint-docs` still checks for a root `CLAUDE.md`
file even though the active project docs set is `README.md` plus `docs/`.

### Export workflow

`.github/workflows/export.yml` runs on tags matching `v*` and currently:

1. validates `export_presets.cfg`
2. installs Godot plus export templates
3. imports project assets
4. exports Windows and macOS release artifacts
5. uploads short-retention build artifacts
6. creates a GitHub release from those tagged artifacts

Linux is not currently exported by the release workflow even though a Linux
preset exists locally.

## Version-sensitive deployment note

The project file declares Godot `4.6` features, `validate.yml` installs
Godot `4.6.2-stable`, and `export.yml` still declares `GODOT_VERSION: "4.3"`.
That version split is the main deployment caveat in the checked-in automation.
