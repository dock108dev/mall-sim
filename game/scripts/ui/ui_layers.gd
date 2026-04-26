## Canonical CanvasLayer band assignments. Reference these constants from any
## code that creates a CanvasLayer dynamically and sets `.layer`. Do NOT
## retrofit `.tscn` files to script-driven layers — keep `.tscn` values literal
## so the editor and external tools can see them. See ISSUE-007 and
## docs/research/canvas-layer-z-order-conflicts.md for the full band table.
class_name UILayers
extends RefCounted

const WORLDSPACE: int = 5
const HUB_CHROME: int = 20
const HUD: int = 30
const RAIL: int = 40
const TUTORIAL: int = 50
const WORLD_PROMPT: int = 60
const DRAWER: int = 70
const MODAL: int = 80
const PAUSE: int = 90
const SYSTEM: int = 100
const POST_FX: int = 110
const DEBUG: int = 120
