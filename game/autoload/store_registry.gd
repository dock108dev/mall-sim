## StoreRegistry — sole owner of the `store_id -> StoreRegistryEntry` map
## (ISSUE-019, ownership.md row "store catalog / id resolution").
##
## Pure lookup table. Does NOT load scenes, does NOT instantiate controllers,
## does NOT cache PackedScenes. StoreDirector (ISSUE-008) consumes
## `resolve(store_id)` as the first step of `enter_store`; a null return is
## converted into a FAIL result there.
##
## Unknown ids fail loud: `push_error` + AuditLog.fail + return null. There is
## no silent empty-string fallback — DESIGN.md §1.2 ("Fail Loud, Never Grey").
extends Node

const CHECKPOINT_RESOLVE: StringName = &"store_registry_resolve"

var _entries: Dictionary = {}


func _ready() -> void:
	_seed_defaults()


## Registers an entry. Asserts on null/empty inputs (programmer error) and
## fails loud on duplicate ids (push_error + AuditLog.fail, no overwrite) —
## the registry is the single source of truth, silent overwrites would let
## two callers disagree on what a store_id means. Returns true on success.
func register(entry: StoreRegistryEntry) -> bool:
	assert(entry != null, "StoreRegistry.register: null entry")
	assert(entry.store_id != &"", "StoreRegistry.register: empty store_id")
	assert(entry.scene_path != "", "StoreRegistry.register: empty scene_path for %s" % entry.store_id)
	if _entries.has(entry.store_id):
		_fail("duplicate register store_id=%s (kept original)" % entry.store_id)
		return false
	_entries[entry.store_id] = entry
	return true


## Returns the entry for `store_id`, or null if unknown. Unknown ids emit
## `push_error` + AuditLog.fail so the failure is observable in headless CI.
func resolve(store_id: StringName) -> StoreRegistryEntry:
	if store_id == &"":
		_fail("empty store_id")
		return null
	if not _entries.has(store_id):
		_fail("unknown store_id: %s" % store_id)
		return null
	var entry: StoreRegistryEntry = _entries[store_id]
	_pass("store_id=%s path=%s" % [store_id, entry.scene_path])
	return entry


## Convenience wrapper used by callers that only need the scene path (e.g.
## StoreDirector's first-step lookup, contract tests). Returns "" when the
## id is unknown — the underlying `resolve()` already emits push_error +
## AuditLog.fail, so the empty string is just a no-silent-throw signal.
func resolve_scene(store_id: StringName) -> String:
	var entry: StoreRegistryEntry = resolve(store_id)
	if entry == null:
		return ""
	return entry.scene_path


## Returns true if `store_id` is registered. Does not log — for callers that
## want a silent existence probe (e.g. UI gating).
func has(store_id: StringName) -> bool:
	return _entries.has(store_id)


## All registered ids, for iteration (mall hub card rendering, contract tests).
func all_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for k in _entries.keys():
		out.append(k as StringName)
	return out


## Test seam — clears the registry. Tests that exercise registration paths
## should call this in `before_each` and re-seed as needed.
func _reset_for_tests() -> void:
	_entries.clear()


func _seed_defaults() -> void:
	# Sneaker Citadel — Phase 1 vertical-slice store (ROADMAP Phase 1).
	# scene_path/controller_script point at the planned files; the registry is
	# pure data and does not require the targets to exist yet. StoreDirector
	# will surface a load failure separately (and loudly) when the time comes.
	register(StoreRegistryEntry.new(
		&"sneaker_citadel",
		"res://game/scenes/stores/sneaker_citadel/store_sneaker_citadel.tscn",
		null,
		"Sneaker Citadel",
		{}
	))


func _pass(detail: String) -> void:
	var log: Node = _audit_log()
	if log != null and log.has_method("pass_check"):
		log.pass_check(CHECKPOINT_RESOLVE, detail)


func _fail(reason: String) -> void:
	push_error("[StoreRegistry] %s" % reason)
	var log: Node = _audit_log()
	if log != null and log.has_method("fail_check"):
		log.fail_check(CHECKPOINT_RESOLVE, reason)


func _audit_log() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var root: Window = tree.root
	if root == null:
		return null
	return root.get_node_or_null("AuditLog")
