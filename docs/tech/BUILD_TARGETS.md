# Build Targets

Target platforms, export configuration, display settings, and hardware requirements.

---

## Platform Targets

### macOS (Primary)

- **Status**: Primary development platform
- **Architecture**: Universal binary (x86_64 + ARM64 via Godot's universal export)
- **Minimum OS**: macOS 12 Monterey
- **Export template**: macOS (official Godot export templates)
- **Distribution**: Direct download initially, Steam later
- **Notarization**: Required for distribution outside the App Store. Godot supports ad-hoc signing, but proper notarization needs an Apple Developer account.
- **App bundle**: Standard `.app` bundle inside a `.dmg` disk image

### Windows (Near-Term)

- **Status**: Second priority, targeted after macOS is stable
- **Architecture**: x86_64 (64-bit only)
- **Minimum OS**: Windows 10
- **Export template**: Windows Desktop (official Godot export templates)
- **Distribution**: Direct download, then Steam
- **Installer**: No installer needed -- ship as a zip with the executable. Consider Inno Setup later for Steam-independent distribution.
- **Console window**: Disabled in release builds (toggle in export settings)

### Linux (Future)

- **Status**: Not actively targeted but Godot supports it natively
- **Notes**: If we ship on Steam, Linux builds are essentially free. Test before listing.

### Web / Mobile

- **Status**: Not planned
- **Rationale**: The game is designed for desktop interaction (mouse, keyboard, screen distance). 3D performance on web/mobile would require significant compromises.

## Display Settings

### Default Configuration
- **Resolution**: 1920x1080 (windowed)
- **Minimum resolution**: 1280x720
- **Fullscreen**: Supported, toggled via settings or F11
- **Stretch mode**: `canvas_items` (2D UI scales with window, 3D viewport adapts)
- **Stretch aspect**: `keep` (maintains aspect ratio, letterboxes if needed)
- **V-Sync**: Enabled by default
- **Target framerate**: 60 FPS (no cap, but systems are designed around 60 FPS tick)

### Multi-Monitor
- No explicit multi-monitor support needed
- Game remembers window position and size between sessions
- Fullscreen uses the monitor the window is on

### HiDPI / Retina
- Godot handles HiDPI automatically with `canvas_items` stretch mode
- UI assets should be authored at 2x and scaled down, not the reverse
- Font rendering uses Godot's built-in MSDF for clean scaling

## Renderer

- **Renderer**: Forward+ (Godot's default desktop renderer)
- **Why Forward+**: Best quality for desktop, supports all lighting and shader features, no need for Mobile or Compatibility renderer limitations
- **Anti-aliasing**: MSAA 2x for 3D geometry, FXAA as optional post-process
- **Shadows**: Medium quality directional + omni lights for store interiors
- **Global illumination**: Not needed -- stores are small interiors with baked-style lighting
- **Post-processing**: Minimal. Slight bloom on neon signs, subtle vignette. No heavy effects.

## Export Templates

Godot requires export templates to build release binaries. These are downloaded once per Godot version.

1. Open Godot
2. Go to Editor > Manage Export Templates
3. Click "Download and Install" for the current Godot version
4. Templates are stored in `~/.local/share/godot/export_templates/` (Linux/macOS) or `%APPDATA%\Godot\export_templates\` (Windows)

### Export Presets

Define these in Project > Export:

| Preset Name | Platform | Type | Notes |
|-------------|----------|------|-------|
| macOS Release | macOS | Release | Universal binary, signed |
| macOS Debug | macOS | Debug | For testing, includes debug symbols |
| Windows Release | Windows Desktop | Release | 64-bit, console hidden |
| Windows Debug | Windows Desktop | Debug | Console visible for log output |

## Minimum Hardware Estimate

These are rough estimates for comfortable 60 FPS gameplay:

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| CPU | Dual-core 2.0 GHz | Quad-core 2.5 GHz+ |
| RAM | 4 GB | 8 GB |
| GPU | Integrated (Intel UHD 620 / Apple M1) | Any dedicated GPU |
| Storage | 500 MB | 1 GB (with room for saves and mods) |
| Display | 1280x720 | 1920x1080 |

The game's 3D scenes are small-scale interiors with low-to-mid poly models. Performance should not be a problem on any hardware from the last 5-6 years. The main concern is Godot's Forward+ renderer requiring Vulkan -- very old integrated GPUs may need the Compatibility (OpenGL) renderer fallback.

## Build Automation

Not yet set up, but the plan is:

- GitHub Actions workflow for automated export on tag push
- Separate jobs for macOS and Windows
- Uses `godot --headless --export-release` command
- Artifacts uploaded to GitHub Releases
- Version number baked into the export from a `version.cfg` file
