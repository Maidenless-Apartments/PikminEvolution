extends CharacterBody3D

@export var speed := 6.0
@export var jump_velocity := 4.5
var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))

func _physics_process(delta):
	var input_dir = Vector2.ZERO
	
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1
	if Input.is_action_pressed("move_forward"):
		input_dir.y -= 1
	if Input.is_action_pressed("move_back"):
		input_dir.y += 1
	
	input_dir = input_dir.normalized()

	var direction = Vector3(input_dir.x, 0, input_dir.y)

	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	if not is_on_floor():
		velocity.y -= gravity * delta

	move_and_slide()
