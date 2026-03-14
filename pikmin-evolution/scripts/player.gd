extends CharacterBody3D

@export var speed := 6.0
@export var jump_velocity := 4.5
var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
@onready var anim_tree: AnimationTree = $AnimationTree
@export var camera_turn_speed := 2.5
@export var camera_pitch_speed := 2.0
@onready var camera_pivot = $cameraPivot
@onready var pitch_pivot: Node3D = $cameraPivot/pitchPivot
@onready var visual_root = $bulborbGLB2

var pitch := 0.0

func _physics_process(delta):
	var input_dir = Vector2.ZERO
	
	# Left/right camera
	var cam_yaw_input := Input.get_axis("cam_left", "cam_right")
	if cam_yaw_input != 0.0:
		camera_pivot.rotate_y(-cam_yaw_input * camera_turn_speed * delta)

	# Up/down camera
	var cam_pitch_input := Input.get_axis("cam_up", "cam_down")
	if cam_pitch_input != 0.0:
		pitch += cam_pitch_input * camera_pitch_speed * delta
		pitch = clamp(pitch, deg_to_rad(-45), deg_to_rad(30))
		pitch_pivot.rotation.x = pitch
	
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

	var forward = -camera_pivot.transform.basis.z
	var right = camera_pivot.transform.basis.x

	# Keep movement flat on the ground
	forward.y = 0
	right.y = 0
	forward = forward.normalized()
	right = right.normalized()

	var direction = (right * input_dir.x + forward * input_dir.y).normalized()
	
	if direction.length() > 0.1:
		visual_root.look_at(visual_root.global_position + direction, Vector3.UP, true)

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
	
