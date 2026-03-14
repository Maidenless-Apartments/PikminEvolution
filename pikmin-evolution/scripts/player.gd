extends CharacterBody3D

@export var speed := 6.0
@export var jump_velocity := 4.5
var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
@onready var anim_tree: AnimationTree = $AnimationTree

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
		
	if Input.is_action_pressed("eat"):
		anim_tree.set("parameters/conditions/is_eating", true)
		anim_tree.set("parameters/conditions/is_idle", false)
	
	input_dir = input_dir.normalized()

	var direction = Vector3(input_dir.x, 0, input_dir.y)

	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	if not is_on_floor():
		velocity.y -= gravity * delta

	move_and_slide()
	
	if input_dir.length() > 0.1:
		anim_tree.set("parameters/conditions/is_walking", true)
		anim_tree.set("parameters/conditions/is_idle", false)
		anim_tree.set("parameters/conditions/is_eating", false)
	else:
		anim_tree.set("parameters/conditions/is_walking", false)
		anim_tree.set("parameters/conditions/is_idle", true)
	
