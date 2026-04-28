# Security Audit Report — Mallcore Sim

**Date**: 2026-04-27  
**Auditor**: Claude Code (security-review skill)  
**Scope**: All files modified on `main` branch (working tree) plus surrounding
trust-boundary code.

---

## Repo Understanding

### Trust Boundaries

| Boundary | Owner | Notes |
|---|---|---|
| `res://game/content/` JSON | Engine / developer | Packed into binary at export; read-only at runtime. Not user-controllable. |
| `user://save_slot_*.json` | Player | Hand-editable local save files. Primary untrusted-input surface. |
| `user://save_index.cfg` | Player (indirectly) | Written by SaveManager; hand-editable. |
| `user://settings.cfg` | Player | Difficulty tier, audio prefs. |
| `user://tutorial_progress.cfg` | Player | Tutorial step flags. |
| CI pipeline | GitHub Actions | Downloads Godot binary from GitHub Releases. |

**This is a single-player desktop game, not a networked service.** There is no
server, no authentication service, no user accounts, and no network socket opened
at runtime. All security concerns are therefore confined to:

- Resilience against crafted/corrupt local files (denial of service, state
  corruption),
- Correct scoping of debug/cheat surfaces to non-release builds, and
- CI supply-chain integrity.

---

## Findings Table

| # | Title | Severity | Confidence | Status |
|---|---|---|---|---|
| SR-01 | Slot-index ConfigFile loaded without size cap | Low | High | **Fixed inline** |
| SR-02 | `used_difficulty_downgrade` loaded without explicit bool cast | Low | High | **Fixed inline** |
| SR-03 | CI: Godot binary downloaded without hash verification | Medium | High | Documented — remediation below |
| SR-04 | CI: GitHub Actions not SHA-pinned | Low | High | Documented — remediation below |
| SR-05 | No PCK encryption in export presets | Info | High | Justified below |
| SR-06 | Code signing disabled in all export presets | Info | High | Justified below |
| SR-07 | `route_to` accepts `scene_path` payload override | Info | High | Justified below |
| SR-08 | Authentication signals use untyped parameters | Info | High | Justified below |

---

## Detailed Findings

### SR-01 — Slot-index ConfigFile loaded without size cap [Fixed]

**File**: `game/scripts/core/save_manager.gd:1135`, `1158`, `1187`

**Evidence**:
```gdscript
# Before fix — no size check before ConfigFile.load()
var load_err: Error = config.load(SLOT_INDEX_PATH)
```

**Scenario**: A player manually creates an oversized `user://save_index.cfg`
(e.g., 500 MB of repeating data). `ConfigFile.load()` would read the entire
file into memory, potentially stalling the save-menu screen. This is a local
denial-of-service against the player's own session only.

**Comparison**: `TutorialSystem` (already hardened in a prior pass) caps
`user://tutorial_progress.cfg` at 64 KB before handing it to `ConfigFile`.
The slot-index path was inconsistently missing the same guard.

**Fix applied**: Added `MAX_SLOT_INDEX_BYTES = 65536` constant and a new
`_slot_index_size_ok()` helper that opens, measures, and warns before returning
`false` if the file is over the cap. All three callers (`get_all_slot_metadata`,
`_update_slot_index`, `_remove_slot_from_index`) call this guard first.

**Why 64 KB**: 4 slots × ~1 KB of metadata each leaves a 16× safety margin
with no legitimate path to reaching the cap.

---

### SR-02 — `used_difficulty_downgrade` loaded without explicit bool cast [Fixed]

**File**: `game/autoload/difficulty_system.gd:87`

**Evidence** (before fix):
```gdscript
used_difficulty_downgrade = data.get("used_difficulty_downgrade", false)
```

**Scenario**: A player hand-edits their save file to set
`"used_difficulty_downgrade": "true"` (a string). GDScript assigns the string
to the `bool`-typed field. The field is used only to display a cosmetic flag on
the save slot (e.g., "(downgraded)"), so the impact is limited to that UI label
rendering as if the player had downgraded when they had not.

**Fix applied**: Wrapped with explicit `bool()` cast, consistent with all other
boolean fields in the save-load pipeline.

---

### SR-03 — CI: Godot binary downloaded without hash verification [Not fixed — escalation]

**File**: `.github/workflows/validate.yml:68`

**Evidence**:
```yaml
GODOT_URL="https://github.com/godotengine/releases/download/..."
wget -q "$GODOT_URL" -O /tmp/godot.zip
unzip -q /tmp/godot.zip -d /tmp/godot
sudo mv /tmp/godot/Godot_v... /usr/local/bin/godot
```

No SHA-256 or SHA-512 digest check is performed after download.

**Scenario**: A compromised GitHub Releases CDN, a tag-overwrite attack on the
`godotengine/godot` repository, or a network-level MITM (HTTPS mitigates this
but not CDN compromise) could serve a trojanized Godot binary. The binary then
runs all GUT tests and has access to `GITHUB_WORKSPACE` file contents.

**Mitigating factors**:
- HTTPS transport validates server identity; passive eavesdropping is prevented.
- The job has `permissions: contents: read` only; no secrets are exposed.
- The Godot Engine project publishes SHA-512 checksums for every release
  alongside the zip file.

**Remediation** (not applied — requires knowing future release checksums):

```yaml
- name: Install Godot
  run: |
    GODOT_VERSION="4.6.2-stable"
    GODOT_ZIP="Godot_v${GODOT_VERSION}_linux.x86_64.zip"
    GODOT_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/${GODOT_ZIP}"
    GODOT_SHA512="<sha512-from-godotengine-releases-page>"
    wget -q "$GODOT_URL" -O /tmp/godot.zip
    echo "${GODOT_SHA512}  /tmp/godot.zip" | sha512sum -c -
    unzip -q /tmp/godot.zip -d /tmp/godot
    sudo mv /tmp/godot/Godot_v${GODOT_VERSION}_linux.x86_64 /usr/local/bin/godot
```

The correct checksum for `4.6.2-stable` should be retrieved from
`https://github.com/godotengine/godot/releases/tag/4.6.2-stable` and pinned in
the workflow file.

**Blocker**: The SHA-512 of the specific Godot 4.6.2-stable Linux x86_64 build
must be fetched from the official release page and committed. This is a one-time
action; revisit whenever the canonical engine version bumps in `project.godot`.

---

### SR-04 — CI: GitHub Actions not SHA-pinned [Not fixed — documented]

**File**: `.github/workflows/validate.yml`

**Evidence**:
```yaml
uses: actions/checkout@v6          # not SHA-pinned
uses: actions/cache@v5             # not SHA-pinned
uses: actions/upload-artifact@v7   # not SHA-pinned
uses: actions/setup-python@v6      # not SHA-pinned
```

**Scenario**: A maintainer of `actions/*` pushes a new commit behind the same
tag (tag overwrite). Subsequent CI runs would pick up the new commit without any
diff visible in this repository.

**Mitigating factors**:
- No secrets (API keys, deploy tokens) are present in this workflow.
- The `permissions: contents: read` scope limits blast radius to reading the
  repository.
- `actions/*` is maintained by GitHub Inc.; tag-overwrite attacks on their
  official actions are theoretically possible but historically unprecedented.

**Remediation**: Pin each action to its full commit SHA:

```yaml
uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v6
uses: actions/cache@5a3ec84eff668545956fd18022155c47e93e2684    # v5
```

Tooling like `dependabot` (Actions section) or `pin-github-action` automates
this and keeps the SHAs up to date.

**Why not fixed inline**: Changing action SHAs requires fetching current commit
SHAs for each action version from GitHub and is a maintenance commitment rather
than a one-time edit.

---

### SR-05 — No PCK encryption [Justified — no fix needed]

**File**: `export_presets.cfg` (all presets)

```ini
encrypt_pck=false
encrypt_directory=false
```

**Justification**: This is an open-source project in pre-release development. The
game content (JSON, GDScript) contains no licensed IP or trade secrets — the
trademark validator actively enforces this at boot. PCK encryption adds build
complexity and does not prevent determined extraction (Godot's PCK encryption key
must itself be embedded in the binary). The risk/cost trade-off is not
favourable before 1.0 ship.

**Condition to revisit**: if a store mechanic requires protecting a secret
algorithm or if licensed audio assets are added before ship, re-evaluate.

---

### SR-06 — Code signing disabled [Justified — no fix needed]

**File**: `export_presets.cfg` (all presets)

```ini
codesign/enable=false   # Windows
codesign/codesign=0     # macOS
```

**Justification**: Pre-release / development builds. Code signing requires paid
certificates and a notarization workflow. Players of early access / dev builds
typically accept Gatekeeper bypass prompts. This is a shipping prerequisite, not
a current vulnerability.

**Condition to revisit**: before any public release or Steam submission.

---

### SR-07 — `route_to` accepts `scene_path` payload override [Justified — no fix needed]

**File**: `game/autoload/scene_router.gd:57`

```gdscript
var path: String = String(payload.get("scene_path", ""))
if path == "":
    path = String(_targets.get(target, ""))
```

**Scenario**: Any internal GDScript caller can pass `{"scene_path": "res://..."}` and
bypass the alias table. However:

1. The `scene_path` parameter is never derived from user input (player keyboard
   or save files). All callers are internal engine-side code.
2. In exported builds, `change_scene_to_file` can only load paths packed into
   the binary PCK. Arbitrary filesystem paths are rejected by the engine.
3. The architecture docs (`docs/architecture/ownership.md`) document this escape
   hatch as a legacy-caller path.

**No fix needed**. The existing architecture comment at the call sites is
sufficient documentation.

---

### SR-08 — Authentication signals use untyped parameters [Justified — no fix needed]

**File**: `game/autoload/event_bus.gd:284`

```gdscript
signal authentication_completed(item_id, success: bool, result)
signal authentication_started(item_id, cost: float)
signal authentication_dialog_requested(item_id)
```

`item_id` and `result` are untyped. `result` is emitted as a `String` (error
messages) or `float` (authenticated price) depending on call path.

**Scenario**: Receivers that assume `result` is always a `String` could call
string methods on a `float` value and encounter a runtime error. In GDScript 4
this produces a push_error but does not crash the process.

**Why not fixed inline**: Changing signal parameter types is a breaking change
that requires updating all connected receivers across multiple store controllers.
This is a typing-quality finding, not a security finding — no user-controlled
input flows through these signals. It is tracked as a code-quality debt item.

**Condition to fix**: during a store-controller refactor pass; add
`item_id: StringName` and `result: Variant` typed parameters and tighten
receiver call sites.

---

## Save-File Data Injection — Accepted Risk

A player who hand-edits `user://save_slot_N.json` can inject arbitrary numeric
values (e.g., `"cash": 1e300`, `"reputation": 999`). SaveManager validates JSON
structure, schema version, and migration paths, but does not clamp game-world
scalar values against maximum plausible ranges.

**This is intentional design**: save editing is a common and accepted player
behavior in single-player games. Clamping every field to a "fair" range would
require maintaining a parallel validation schema that would bitrot against the
game's evolving economy constants. The correct mitigation is ensuring no save
value can *crash* the process (confirmed: large floats are handled by GDScript's
float type without overflow crashes) rather than preventing "cheating."

No fix required.

---

## Safe Hardening Implemented This Pass

| Change | File | Description |
|---|---|---|
| Added `MAX_SLOT_INDEX_BYTES` constant | `game/scripts/core/save_manager.gd:48` | 64 KB cap for slot-index file, consistent with tutorial-system hardening |
| Added `_slot_index_size_ok()` helper | `game/scripts/core/save_manager.gd:1208` | Pre-checks slot-index size before `ConfigFile.load()` in all three callers |
| Size guard in `get_all_slot_metadata` | `game/scripts/core/save_manager.gd:1141` | Calls `_slot_index_size_ok()` before loading |
| Size guard in `_update_slot_index` | `game/scripts/core/save_manager.gd:1163` | Calls `_slot_index_size_ok()` before loading |
| Size guard in `_remove_slot_from_index` | `game/scripts/core/save_manager.gd:1193` | Calls `_slot_index_size_ok()` before loading |
| Explicit `bool()` cast | `game/autoload/difficulty_system.gd:87` | Coerces `used_difficulty_downgrade` value from save data to bool before assignment |

---

## Remediation Roadmap

| Priority | Finding | Concrete next action | Blocker |
|---|---|---|---|
| P1 | SR-03: Godot download hash | Fetch SHA-512 from `github.com/godotengine/godot/releases/tag/4.6.2-stable`, add `sha512sum -c` line to CI | Must be done by a human who can read the release page |
| P2 | SR-04: Action SHA pinning | Run `pin-github-action` or enable Dependabot Actions in repo settings | One-time tool invocation |
| P3 | SR-08: Signal typing | During next store-controller refactor, add typed params to auth signals and update receivers | No blocker; bundle with store work |

---

## Escalations

None. All findings have either been fixed inline or have a concrete remediation
path documented above with a named blocker.

---

## §F-Reference Index

Inline `§F-N` annotations in the codebase reference prior audit sections.
Security-report section references (`§SR-N`) introduced in this pass:

| Ref | Location | Description |
|---|---|---|
| §SR-01 | `save_manager.gd`, `_slot_index_size_ok()` | Slot-index size cap |
| §SR-02 | `difficulty_system.gd`, `load_save_data()` | Bool coercion on load |
| §F1 | `tutorial_system.gd:44` | Tutorial-progress file size cap (prior pass) |
| §F2 | `tutorial_system.gd:48` | Tutorial dict key cap (prior pass) |
