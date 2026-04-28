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
	_seed_from_content_registry()
	# Autoload init order seeds StoreRegistry before DataLoader runs, so the
	# initial pass is empty. Re-seed when DataLoader emits content_loaded.
	var bus: Node = _autoload("EventBus")
	if bus != null and bus.has_signal("content_loaded"):
		bus.content_loaded.connect(_seed_from_content_registry)


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


## Seeds the registry from ContentRegistry (the SSOT per
## docs/decisions/0007-remove-sneaker-citadel.md).
## Runs after ContentRegistry has loaded `store_definitions.json`; if content
## isn't ready yet the registry is left empty — callers fail loud through
## `resolve()` rather than returning stale data.
func _seed_from_content_registry() -> void:
	var content: Node = _autoload("ContentRegistry")
	if content == null:
		return
	if not content.has_method("get_all_store_ids"):
		return
	var ids: Array[StringName] = content.get_all_store_ids()
	for store_id: StringName in ids:
		if _entries.has(store_id):
			continue
		var scene_path: String = ""
		if content.has_method("get_scene_path"):
			scene_path = content.get_scene_path(store_id)
		if scene_path.is_empty():
			continue
		var display_name: String = String(store_id)
		if content.has_method("get_display_name"):
			display_name = content.get_display_name(store_id)
		register(StoreRegistryEntry.new(
			store_id, scene_path, null, display_name, {}
		))


func _autoload(name_str: String) -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var root: Window = tree.root
	if root == null:
		return null
	return root.get_node_or_null(name_str)


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
