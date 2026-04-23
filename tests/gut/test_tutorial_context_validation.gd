## ISSUE-004: fails the build if any tutorial step references an
## `interactable_id` that does not resolve to an Interactable in the bound
## store scene.
extends GutTest


func _collect_interactable_ids(root: Node, out: Dictionary) -> void:
	if root is Interactable:
		var it := root as Interactable
		out[String(it.resolve_interactable_id())] = true
	for child: Node in root.get_children():
		_collect_interactable_ids(child, out)


func test_every_tutorial_step_references_a_real_interactable() -> void:
	TutorialContextSystem.reload()
	var context_ids: Array[String] = TutorialContextSystem.get_context_ids()
	assert_gt(
		context_ids.size(), 0,
		"tutorial_contexts.json should define at least one context"
	)

	var failures: Array[String] = []
	for context_id: String in context_ids:
		var context: Dictionary = TutorialContextSystem.get_context(
			StringName(context_id)
		)
		var scene_path: String = String(context.get("scene_path", ""))
		if scene_path.is_empty():
			failures.append(
				"context '%s' missing scene_path" % context_id
			)
			continue
		var packed: PackedScene = load(scene_path) as PackedScene
		if packed == null:
			failures.append(
				"context '%s' scene '%s' failed to load"
				% [context_id, scene_path]
			)
			continue
		var root: Node = packed.instantiate()
		add_child_autofree(root)
		var ids: Dictionary = {}
		_collect_interactable_ids(root, ids)

		var steps: Array = TutorialContextSystem.get_steps(
			StringName(context_id)
		)
		assert_gt(
			steps.size(), 0,
			"context '%s' should define at least one step" % context_id
		)
		for step_variant: Variant in steps:
			if not (step_variant is Dictionary):
				failures.append(
					"context '%s' has non-dict step" % context_id
				)
				continue
			var step: Dictionary = step_variant as Dictionary
			var ref: String = String(step.get("interactable_id", ""))
			var step_id: String = String(step.get("id", "<unnamed>"))
			if ref.is_empty():
				failures.append(
					"context '%s' step '%s' missing interactable_id"
					% [context_id, step_id]
				)
				continue
			if not ids.has(ref):
				failures.append(
					"context '%s' step '%s' references unknown interactable_id '%s' in %s"
					% [context_id, step_id, ref, scene_path]
				)

	assert_eq(
		failures.size(), 0,
		"tutorial context validation failed:\n  - %s"
		% "\n  - ".join(failures)
	)
