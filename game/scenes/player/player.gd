## First/third-person player controller with WASD movement and mouse look.
extends CharacterBody3D

@export var move_speed: float = 5.0
@export var mouse_sensitivity: float = 0.002
@export var interaction_range: float = 3.0

@onready var camera: Camera3D = $Camera3D
@onready var interaction_ray: RayCast3D = $Camera3D/InteractionRay

var _looking_at: Node = null


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clampf(camera.rotation.x, -PI / 2.0, PI / 2.0)

	if event.is_action_pressed("interact") and _looking_at:
		EventBus.player_interacted.emit(_looking_at)

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)

	# Simple gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	move_and_slide()
	_check_interaction()


func _check_interaction() -> void:
	if interaction_ray and interaction_ray.is_colliding():
		var collider := interaction_ray.get_collider()
		if collider and collider.is_in_group("interactable"):
			_looking_at = collider
			return
	_looking_at = null
