## Verifies the retro games checkout counter surfaces the manual-checkout
## E-press prompt for the BRAINDUMP Day-1 first sale. The register node now
## carries `RegisterInteractable`, which gates `can_interact()` on a head-of-
## queue customer parked at the counter and arms a "Press E to ring up
## customer" prompt only while the customer is waiting. Idle / no-customer
## state surfaces a muted "No customer waiting" via `get_disabled_reason()`.
extends GutTest


const _SCENE_PATH: String = "res://game/scenes/stores/retro_games.tscn"

var _root: Node3D = null


func before_all() -> void:
	var scene: PackedScene = load(_SCENE_PATH)
	assert_not_null(scene, "Retro Games scene should load")
	_root = scene.instantiate() as Node3D
	add_child(_root)


func after_all() -> void:
	if is_instance_valid(_root):
		_root.free()
	_root = null


func test_register_node_uses_register_interactable_script() -> void:
	var counter: Node = _checkout_counter_interactable()
	assert_not_null(
		counter, "checkout_counter/Interactable must exist in retro_games scene"
	)
	assert_true(
		counter is RegisterInteractable,
		"checkout_counter/Interactable must use the RegisterInteractable script "
		+ "so the Day-1 manual-checkout E-press is wired"
	)


func test_idle_register_disables_interaction_with_muted_reason() -> void:
	var counter: RegisterInteractable = (
		_checkout_counter_interactable() as RegisterInteractable
	)
	assert_not_null(counter)
	assert_false(
		counter.can_interact(),
		"Idle register must not be interactable until a customer queues"
	)
	assert_eq(
		counter.get_disabled_reason(),
		RegisterInteractable.PROMPT_NO_CUSTOMER,
		"Idle prompt must surface 'No customer waiting' as the muted reason"
	)


func test_register_advertises_ring_up_verb_for_e_cue() -> void:
	var counter: RegisterInteractable = (
		_checkout_counter_interactable() as RegisterInteractable
	)
	assert_not_null(counter)
	assert_eq(
		counter.prompt_text, RegisterInteractable.PROMPT_DEFAULT_VERB,
		"Register prompt_text must read the ring-up verb so the HUD can "
		+ "compose 'Press E to ring up customer' on customer arrival"
	)


func _checkout_counter_interactable() -> Node:
	return _root.get_node_or_null("checkout_counter/Interactable")
