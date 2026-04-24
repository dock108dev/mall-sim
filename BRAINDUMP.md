# MALLCORE SIM — BRAINDUMP (VISUAL DESIGN + ART DIRECTION)

*Phase 0.1 wiring cleanup shipped 2026-04-24 — see [docs/audits/phase0-ui-integrity.md](docs/audits/phase0-ui-integrity.md). This braindump is about **what the game should look like**, not whether it wires up.*

---

## CURRENT VISUAL STATE (OBSERVED)

- Launch → main menu ✓
- New Game → mall overview shows 5 `StoreSlotCard`s over a dim-blue backdrop ✓
- Click a store → 3D interior renders, camera fixed at `(0, 1.8, 2.2)` with ~17° down-tilt ✓
- Interior shows: **cream wall + spotlight + shelves made of BoxMesh primitives + 40–90 green translucent cubes marking empty slots**
- Nothing moves. No mouse-orbit. No drift. No idle animation. No customer silhouettes. No audio detail. The store is a **diorama under glass**.
- The 2D chrome (HUD top bar, objective rail, tutorial bar, KPI strip) renders but is tonally divorced from the 3D — flat dark-brown HUD over washed cream-beige store.

---

## CORE PROBLEM SUMMARY

This is not a **rendering** problem and it is not a **content** problem.

It is a **visual identity** problem and an **atmosphere** problem.

- Every store shares the same BoxMesh vocabulary → stores feel interchangeable
- Every empty slot uses the same translucent green cube → shelves look *wrong*, not *unstocked*
- Every material is flat-color PBR with no texture map → no texture = no period
- The HUD and the world use two disconnected palettes → they read as two games stitched together
- There is zero environmental motion → customers, lights, props are static. The mall feels abandoned.
- There is one camera pose per store, frozen → the scene feels like a screenshot, not a place

**The game currently shows the skeleton of a retail sim. It does not yet show a mall.**

---

## THE MALL WE PROMISED (DESIGN CEILING)

Per `docs/research/mall-aesthetic-direction.md` §2, the art direction is locked:

> *"The mall at 3 PM vs. the mall at 3 AM."*
>
> **Day layer** (gameplay): Y2K optimism + 90s nostalgia. Warm fluorescents, laminated countertops, vinyl booth seating, faded carpet.
>
> **Night layer** (off-hours, backrooms, late game): Dead-mall liminal + vaporwave ghost. Emergency exits. Sodium dusk. HVAC drone.

Per `docs/design.md` §4:
> *"One dominant background, one panel tone, one accent, one highlight per screen. Violating this rule produces the 'brown soup' anti-pattern."*

Per `docs/decisions/0001-mall-presentation-model.md`: this is a **clickable management hub**, not a walkable world. The 3D store interior is a **stylized diorama** that the player orbits, not occupies. The camera is the only presence.

The visual north-star: **open any store for the first time, and within 1 second the player says out loud, "oh — *this* kind of store."**

Retro Games = warm CRT amber + green neon accent + visible cartridge clutter.
Pocket Creatures = bright fluorescents + teal holo glow + tournament felt tables.
Video Rental = magenta late-fee neon + blue plastic tape cases + popcorn-lit concession.
Electronics = cool cyan kiosk glow + brushed chrome + demo-unit blue screens.
Sports Memorabilia = warm wood + glass display cases + framed photo reds.

Right now every store is a cream-walled room with green cubes in it. We are 100% behind the ceiling.

---

## BREAKPOINTS (VISUAL, CRITICAL)

### 1. EVERYTHING IS BOXMESH. ZERO MODELED ASSETS.

- `game/assets/models/` has **no `.gltf`, `.fbx`, or `.obj` files**. Not one.
- Every fixture, shelf, counter, CRT, register, tournament table is a `BoxMesh` SubResource with a flat-color StandardMaterial3D.
- `game/assets/materials/` has **59 `mat_*.tres` files**. Of those, only `mat_slot_marker` has transparency/emission. None of them reference texture maps with real detail.
- Product materials exist (`mat_product_trading_cards`, `mat_product_cartridge`, `mat_product_vhs_tapes`, etc.) but **none are referenced in any store scene** — product geometry is unspawned.

**Implication:** We cannot produce a 2000s mall look with BoxMeshes + flat colors. Not with more lighting, not with more shaders. The fundamental vocabulary is missing.

---

### 2. THE SLOT MARKER IS LOUD AND PERMANENT

- `mat_slot_marker.tres`: `albedo_color = Color(0.2, 0.8, 0.3, 0.7)`, `transparency = 1`. Bright translucent green.
- Every empty shelf in every store fills with these. Sports Memorabilia = 21. Retro Games = 40. Pocket Creatures = 32. Consumer Electronics = 40+. Video Rental = similar.
- `shelf_slot.gd` shows the marker while empty and swaps to a product mesh when stocked. Today the stocking never happens in the default empty-game state, so the markers dominate every frame.

**Implication:** The player's first look at any store is: **a big green pulsing grid of "not yet."** That is a UI sketch, not a store. The marker needs to be whisper-quiet or invisible until the player is actually holding an item to place.

---

### 3. THERE IS NO MOTION IN THE WORLD

- No `AnimationPlayer` nodes in any store scene.
- No `GPUParticles3D` anywhere.
- No customer silhouettes, shoppers, ambient characters walking the hallway.
- No flickering fluorescent, no rotating ceiling fan, no idle register light pulse.
- `day_phase_lighting.gd` tweens light energy across the day — that's the only motion in-world, and it's slow enough to be imperceptible.
- The camera is nailed to the floor.

**Implication:** A mall without motion is a diorama of a mall. Even ONE idle-animated prop (a CRT flickering, a sign buzzing, a customer walking past the storefront) would shift the perception from "dead level" to "place people are in."

---

### 4. HUD AND WORLD DON'T SHARE A VOCABULARY

- HUD uses `world_base #13100D` / `panel_surface #1F1A16` (dark brown-black chrome), `text_primary #F4E9D4` (cream).
- Stores use cream walls (`0.9, 0.85, 0.75`), warm wood floors, cream ceilings. The world palette is PALE. The HUD palette is DARK.
- There is no transition. The top bar ends, the 3D begins, and the tones argue.

Per `docs/style/visual-grammar.md`:
> *"Accent = band + outline + CTA only. Never use a store accent as a panel body fill, global HUD color, or body text color."*

This rule is enforced on the 2D HUD. It is **not** enforced in the 3D world — each store uses its accent color as emission/fill/tint on lights and walls. That's correct for the 3D; what's missing is a **HUD adapter**: when the player is in Retro Games, the HUD's accent band picks up CRT Amber. When in Pocket Creatures, Holo Teal. The 2D chrome should signal which store we're in without relying on the text label.

---

### 5. THE CAMERA IS A PHOTOGRAPH

- Hub mode instantiates the store, activates `StoreCamera` at a fixed pose, never touches it again.
- No mouse drag to orbit. No right-click pan. No scroll-to-zoom. No subtle idle-sway.
- `game/scripts/world/build_mode_camera.gd` **already has** orbit + pan + zoom + transition logic — it's used for build mode only. It is unused for store-view camera.
- `OrbitPivot` Marker3D exists in every store at `(0, 1.2, 0)` — a pivot point waiting for a camera that orbits it. Nothing orbits it.

**Implication:** The tooling for a live store view already exists. We are shipping a static JPEG when we have a rotating camera one import away.

---

### 6. LIGHTING IS TECHNICALLY CORRECT AND EMOTIONALLY FLAT

- Every store has 3–8 lights (key + fill + accent). Shadows enabled on a subset. Sports/Electronics have warm accent lights. Retro Games has warm+green neon fills. Pocket Creatures has 6 fluorescent overheads + 4 display spotlights.
- What's missing:
  - No rim-light or back-light to separate fixtures from walls
  - No visible volumetric glow on neon panels (fog/god-rays)
  - No flicker, no hum, no breathing intensity
  - No sunset/overnight variation baked into the hub (the day phase system exists — light energy isn't varied enough for the player to notice)
- The CRT screen mats emit (0.35, 0.95, 0.58) at `emission_energy_multiplier = 1.2`. They look painted, not alive. A phosphor-glow shader + subtle flicker turns them into televisions.

---

### 7. STOREFRONTS ARE INVISIBLE FROM INSIDE

- Each store has a `Storefront` node: SilhouettePanels (dark silhouette), FrameLeft/Right (wood frame), FrameHeader, SignBacking (emissive), SignName + SignTagline (Label3D), SignLight (OmniLight3D warm).
- These assets exist. They render fine when seen from outside. **The player never sees them from outside** — there is no hub-hallway view, no approach. The player clicks a card and teleports inside.
- Consequence: all the handcrafted storefront art is used once, for 400ms during the crossfade, and never again.

---

## REUSABLE BUILDING BLOCKS (DO NOT REBUILD THESE)

An agent doing visual work MUST use these before writing new code:

| Need | Use this | File |
|---|---|---|
| Orbit / pan / zoom camera with Tween transitions | `BuildModeCamera` | `game/scripts/world/build_mode_camera.gd` |
| Camera ownership / single-current assertion | `CameraAuthority.request_current(cam, source)` | `game/autoload/camera_authority.gd` |
| Hover highlight shader on 3D interactable | `Interactable.highlight()` + `mat_outline_highlight.tres` | `game/scripts/components/interactable.gd` |
| Hover tint on 2D Controls | `InteractableHover` (`self_modulate` → `ACCENT_INTERACT`) | `game/scripts/ui/interactable_hover.gd` |
| Delayed hover tooltip at cursor | `TooltipManager.show_tooltip(text, pos)` + `TooltipTrigger` | `game/autoload/tooltip_manager.gd` |
| "[E] to interact" contextual hint | `InteractionPrompt` listening to `EventBus.interactable_focused` | `game/scenes/ui/interaction_prompt.tscn` |
| One-unit shelf slot with empty→stocked mesh swap | `ShelfSlot` (extends Interactable) | `game/scripts/stores/shelf_slot.gd` |
| Day/night light interpolation | `DayPhaseLighting` tweening `DirectionalLight3D` | `game/scripts/world/day_phase_lighting.gd` |
| CRT scanline post-process shader | `crt_overlay.gdshader` | `game/resources/shaders/crt_overlay.gdshader` |
| Modal open/close tween pattern | `PanelAnimator.modal_open / slide_open / stagger_fade_in` | `game/scripts/ui/panel_animator.gd` |

When proposing a change, the PR description must name which of these is being reused. New camera controllers, new hover shaders, new tooltip panels are not permitted — refactor the existing one or quote the ADR overriding it.

---

## VISUAL GRAMMAR — LOCKED

Per `docs/style/visual-grammar.md` — treat as unmovable:

### Neutral chrome (HUD, panels, text)
- `world_base` `#13100D` deepest bg
- `panel_surface` `#1F1A16` drawer/HUD body
- `panel_raised` `#2E2722` buttons, rows
- `text_primary` `#F4E9D4` (15.1:1 vs panel_surface — AAA)
- `text_muted` `#B8A88C` labels, metadata

### Semantic accents (state only, not identity)
- `accent_interact` `#5BB8E8` hover outline, CTA
- `accent_success` `#6DCF5A` profit, positive
- `accent_warning` `#F2B81C` low stock, pending
- `accent_danger` `#E53E2B` failed sale, error

### Store identity accents (band + outline + CTA only, never body fill)
- Retro Games — CRT Amber `#E8A547`
- Pocket Creatures — Holo Teal `#2EB5A8`
- Video Rental — Late-Fee Magenta `#E04E8C`
- Electronics — CRT Cyan `#3AA8D8`
- Sports Memorabilia — Grading Crimson `#E85555`

### Typography (18pt minimum body — non-negotiable)
- h1 TitleLabel 32pt
- h2 HeaderLabel 24pt
- body Label 18pt
- caption CaptionLabel 14pt (timestamps/footnotes ONLY)

Any new UI that drops below 18pt for body or introduces a color outside this palette is a merge-blocker.

---

## PRIORITY-ORDERED DESIGN PASSES

Each pass is one discrete PR. **Where a pass lists multiple options, pick exactly ONE** — do not fork the codebase with parallel implementations. The "PICK ONE" line is explicit in each case.

---

### D0 — Quiet the slot markers

**Why first:** highest signal-to-effort ratio. Every store gets 30–50% less visual noise instantly. No models required.

- `mat_slot_marker.tres` currently `albedo_color = (0.2, 0.8, 0.3, 0.7)` with full transparency. The bright green sells "broken build," not "empty shelf."
- Two valid options. **PICK ONE:**
  - **Option A (recommended, invisible-until-interactable):** make the marker **invisible by default** (`alpha = 0`). When the player opens the Inventory panel AND hovers a stockable item, raycast the scene to show only the markers that can accept that item at `alpha = 0.35` with `accent_interact #5BB8E8` tint. `shelf_slot.gd` already has the visibility toggle (`_empty_mesh.visible`) — wire it to a new `EventBus.stocking_cursor_active(item_category)` signal.
  - **Option B (simple, whisper-quiet):** set marker to `albedo = Color(0.45, 0.4, 0.35, 0.12)` — a faint warm grey at 12% alpha. Reads as "there's a slot here" but doesn't scream. No new code.

**Do not implement both.** Option A is correct long-term but costs wiring. Option B is a 1-file change.

**Verify:** screenshot any store → no green pulsing grid. Sample center brightness per store should stay in the 0.55–0.85 range.

---

### D1 — The first real prop (one store, not five)

**Why second:** BoxMeshes are the tax on every other visual pass. Buy back a prop vocabulary for ONE store, use it to prove the pipeline.

Per `docs/decisions/0002-vertical-slice-store.md`, the vertical-slice store is **Retro Games**. Propagate: the first modeled assets land there.

The target vocabulary for Retro Games (per `docs/research/mall-aesthetic-direction.md`):
- ~6–10 low-poly cartridge meshes (colored plastic + paper label decal)
- ~3 console shell meshes (SNES-era, PS1-era, N64-era silhouettes)
- 1 CRT monitor mesh (already partially built — `crt_body_mesh` + `crt_screen_mesh` exist as SubResources; upgrade to a single .gltf import)
- 1 counter / register mesh to replace the BoxMesh counter
- 2 wall poster Decals (imported from `game/assets/posters/` if present, else authored as emissive Quads)

**PICK ONE sourcing path:**
- **Path A (CC0 kitbash):** Import Kenney or Quaternius CC0 low-poly retail pack, retexture to our palette. Ships in ~1 PR, looks generic but functional.
- **Path B (bespoke authoring):** Author 10–15 meshes in Blender matching the exact storefront-sign silhouettes already in-scene. Slower (~2–3 PRs) but distinctive.
- **Path C (Godot `CSGMesh3D` primitives):** Compose cartridges/consoles from CSG shapes in-editor. Slightly better than BoxMesh, no external assets. Cheap interim.

**Recommendation:** Path A — CC0 kitbash. The vertical slice doesn't need bespoke art; it needs *enough* art to sell "retail store." Bespoke is Phase 6 content work.

**Acceptance:** Retro Games shelf cells fill with cartridge meshes (not green cubes) when `InventorySystem.get_stock(&"retro_games").size() > 0`. Camera-screenshot shows recognizable retail clutter.

---

### D2 — Camera that moves

**Why third:** Even an empty room feels alive with a camera that drifts. Turning the photograph into a view unlocks most of the "feels dead" feedback.

`BuildModeCamera` already does orbit + pan + zoom + Tween transitions around a pivot. Repoint it at `OrbitPivot` inside each store.

**PICK ONE motion model:**
- **Model A (subtle Ken-Burns idle):** Camera slowly drifts around the OrbitPivot on a small orbital radius (0.5–1m over 20s) with a gentle sine-wave vertical bob. No input — pure ambient motion. Player feels the room without controlling it. Consistent with "management hub, not walkable world."
- **Model B (drag-to-orbit):** Right-click-drag rotates the camera around `OrbitPivot` (±30° yaw, ±15° pitch, snaps back if released). Scroll-wheel zooms (3m–6m). Middle-click pans (clamped to floor bounds). Same controls as build mode.
- **Model C (fixed pose with breathing):** Keep the static pose. Add a 0.5° micro-rotation sine-wave sway over 8s. Cheapest option, most surprising "it's alive" gain per LOC.

**Recommendation:** Model A. It's autonomous (no input-handling stack to reason about), matches the "clickable hub" philosophy, and still makes the room feel breathing. Model B is correct long-term but invites tutorial/accessibility questions.

**Acceptance:** enter any store → within 2s the camera begins a slow arc around `OrbitPivot`. 4-store-cycle video captures distinct camera paths without the player touching input.

---

### D3 — Lighting that breathes

**Why fourth:** once props and camera move, static lighting becomes the next weakest link. Lights are already in scene; this pass is about modulating them.

Three discrete effects. **PICK ONE:**
- **Effect A (fluorescent flicker):** Tween `OmniLight3D.light_energy` on 1–2 ceiling fluorescents per store across a noise curve (95–100% most of the time, occasional 80% dip over 60ms). No shader. One autoload script reused across all 5 stores.
- **Effect B (neon volumetric glow):** Add a post-process glow pass tuned for store accent emissives. Retro Games' green/amber panels glow in the air. Requires `Environment.glow_enabled = true` (already on) + per-light `light_volumetric_fog_energy` tuning per store. Visually bigger win than flicker; per-store parameter tuning cost.
- **Effect C (CRT screen animated shader):** Replace the static emissive material on CRT meshes with a shader that cycles through 4–5 solid-color "TV static" frames over 2s. One shader, applied per-store to the CRT/kiosk/demo mesh.

**Recommendation:** Effect C. Localized, self-contained, one shader, and it hits the single biggest store-identity prop (the CRT) across three stores at once (Retro Games, Electronics, implicitly Video Rental through a tape-preview monitor).

**Acceptance:** CRT and kiosk screens cycle through a slow TV-static loop. No constant colors; imagery changes over time.

---

### D4 — HUD adopts store identity

**Why fifth:** after D0–D3, the 3D view has motion and identity. The HUD still sits in a different palette. Close the loop.

Currently HUD is dark-brown chrome regardless of where the player is. Per visual-grammar locks, store accents are "band + outline + CTA only" — perfect for the objective rail.

**PICK ONE binding point:**
- **Binding A (objective-rail accent):** The 4px band at the top of `ObjectiveRail` picks up the active store's accent color. Retro Games → amber band. Hub → `accent_interact #5BB8E8` default. One signal (`EventBus.store_entered`), one property (`_band.color`).
- **Binding B (top-bar corner highlight):** Bottom 2px of the top-HUD strip gets tinted with store accent. More visible; risks clashing with `Rep: 50 — Destination Shop` colored text.
- **Binding C (full HUD re-theme per store):** Apply a `Theme` variation per store that swaps button accent colors, focus outlines, and CTA hover tints to the store's color. Big consistency win; significant theme authoring cost.

**Recommendation:** Binding A. Smallest diff, clearest signal, stays inside the visual-grammar rules.

**Acceptance:** Enter Retro Games → 4px amber band appears under the objective rail. Exit to hub → band returns to default interact blue.

---

### D5 — Storefronts become useful

**Why last:** the handcrafted storefront assets (sign, silhouette, frame, emissive backing) deserve more than 400ms of screen time during the crossfade. This pass decides where else they show.

Today the crossfade is: hub cards → fade-out → store interior. Storefront is never visible.

**PICK ONE surface for storefront reuse:**
- **Surface A (hub-card diorama preview):** Each `StoreSlotCard` in `MallOverview` embeds a tiny `SubViewport` rendering the storefront sign + silhouette + a single idle animation (sign-light breath, for example). The card is a live mini-diorama, not a static label.
- **Surface B (transition frame):** The crossfade pauses for 600ms on a "storefront beauty shot" composed as a fixed camera angle showing the storefront sign filling the frame, before swapping to interior.
- **Surface C (mall-map screen):** Add a new screen (triggered by `M` or a tab) showing a 2D mall directory with all 5 storefronts side-by-side as iso renders. Revive `docs/research/mall-aesthetic-direction.md` diegetic map idea.

**Recommendation:** Surface A. It's the smallest addition that reuses existing assets and adds "the mall is alive" signal on the hub page (before the player has even chosen a store). SubViewport + per-card StoreCamera is exactly what Godot is designed for. Already-authored storefront assets carry their weight.

**Acceptance:** hub overview shows 5 mini-dioramas, each rendering its own storefront in ~100×80px, animated. Clicking the card still routes into the store.

---

## ANTI-PATTERNS FOR THIS WORK (DO NOT SHIP)

Per `docs/design.md` §10 and the visual-grammar doc:

| Anti-pattern | Sign of it | Consequence |
|---|---|---|
| Brown soup | HUD panel tone applied to 3D world materials, or vice versa | Merge-blocker |
| Store accent as body fill | Panel bg = CRT Amber; Retro Games wall painted Amber | Merge-blocker |
| Below-18pt body text | New label at 14pt, 16pt, or `font_size = 12` | Merge-blocker |
| Reinvented camera controller | New `class_name StoreOrbitCamera extends Camera3D` | Merge-blocker — reuse `BuildModeCamera` |
| Reinvented outline shader | New `mat_glow_highlight.tres` next to the existing `mat_outline_highlight.tres` | Merge-blocker |
| Art authored outside palette | `Color(0.6, 0.2, 0.9, 1)` appears in any .tres or .tscn | Merge-blocker |
| Parallel prop pipelines | PR adds both `.gltf` imports AND new `CSGMesh3D` props for the same fixture | Merge-blocker — PICK ONE pipeline (see D1) |
| Ambient motion that jitters input | Camera drift in D2 responds to mouse movement or steals focus | Merge-blocker |

---

## NORTH STAR (CLARITY TEST)

If a visual change does not answer **all three**, it does not belong yet:

1. **Which of the 5 stores does this make more itself?** (If the answer is "all of them equally" — you're working on chrome, which is fine, but flag it.)
2. **What part of the existing building-block table does this reuse?** (If nothing — justify or reuse.)
3. **What does the player feel in the first 5 seconds of the change that they didn't before?**

---

## TARGET STATE (60-SECOND FIRST IMPRESSION)

When this is right, the first 60 seconds after clicking New Game should feel like:

- I see five mini-mall storefronts, each already alive — a neon hum, a sign-light breath
- I pick one. The camera slides in.
- I am inside a recognizable **retail store**, not a diorama. The walls have character. The ceiling has fluorescents. There's a CRT flicker from the back corner.
- The camera is drifting slightly on its own axis. I can see the storefront from the inside, through the storefront frame.
- The HUD at the top has a thin amber band that wasn't there a moment ago — *I am in Retro Games specifically*.
- There are empty shelves, but they are **quiet**. When I open inventory, they **light up** to show me where things go.
- I place a cartridge. The marker disappears. A small plastic cartridge mesh appears. I hear a clack.
- I want to keep going.

That's the game.

---

## WHAT THIS BRAINDUMP DOES NOT COVER

- **Audio direction** — `docs/research/mall-aesthetic-direction.md` §6–7 covers music/SFX. A separate audio braindump should follow.
- **Diegetic HUD items** (receipt-paper dialog boxes, laminated Season Planner inventory, photo-booth save strips) — locked in the research doc, deferred until D5.
- **Night-layer / dead-mall mode** — the "3 AM" half of the central tension. Deferred until D0–D5 ship the "3 PM" baseline.
- **Tournament / event visual telegraphs** — Phase 3 roadmap territory.

These are known. They are not this cycle's scope.
