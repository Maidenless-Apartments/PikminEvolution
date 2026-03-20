extends CharacterBody3D

@export var speed := 2.5
@export var jump_velocity := 4.5
@export var eat_total_duration: float = 1.633
@export var eat_hitbox_delay: float = 0.43
@export var eat_hitbox_duration: float = 0.28
@export var stage1_model: PackedScene
@export var stage2_model: PackedScene
var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var anim_state = $AnimationTree.get("parameters/playback")
@export var camera_turn_speed := 2.5
@export var camera_pitch_speed := 2.0
@onready var camera_pivot = $cameraPivot
@onready var pitch_pivot: Node3D = $cameraPivot/pitchPivot
@onready var visual_root = $CollisionShape3D
@onready var eat_hitbox: Area3D = $CollisionShape3D/eatHitBox
@onready var eat_timer: Timer = $eatTimer
@onready var hitbox_timer: Timer = $hitboxTimer
@onready var visuals = $CollisionShape3D/bulborbGLB2
@onready var collision = $CollisionShape3D

var is_attacking: bool = false
var eat_targets_hit: Array[Node] = []
var mouth_size = 3
var pitch := 0.0
var pikmin_eaten: int = 0
var grown_up: bool = false
var grown_up2: bool = false

func _ready() -> void:
	anim_tree.active = true
	eat_hitbox.monitoring = false
	eat_timer.one_shot = true
	eat_timer.one_shot = true

	eat_timer.timeout.connect(_on_eat_timer_timeout)
	hitbox_timer.timeout.connect(_on_hitbox_timer_timeout)
	eat_hitbox.body_entered.connect(_on_eat_hitbox_body_entered)
	
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
		input_dir.y += 1
	if Input.is_action_pressed("move_back"):
		input_dir.y -= 1
	
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
		visual_root.look_at(visual_root.global_position - direction, Vector3.UP, true)

	if not is_attacking:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	if not is_on_floor():
		velocity.y -= gravity * delta
		
	if Input.is_action_just_pressed("eat") and not is_attacking:
		start_eat_attack()
	elif not is_attacking:
		if input_dir.length() > 0.1:
			anim_state.travel("Walk")
		else:
			anim_state.travel("Idle")

	move_and_slide()
		
func start_eat_attack() -> void:
	is_attacking = true
	eat_targets_hit.clear()
	anim_state.travel("Eat")
	
	eat_timer.start(eat_total_duration)
	
	await get_tree().create_timer(eat_hitbox_delay).timeout
	if is_attacking:
		enable_eat_hitbox()
		hitbox_timer.start(eat_hitbox_duration)
	
func end_eat_attack() -> void:
	is_attacking = false
	eat_hitbox.monitoring = false
	anim_state.travel("Idle")
	
func enable_eat_hitbox() -> void:
	eat_targets_hit.clear()
	eat_hitbox.monitoring = true
	
	for body in eat_hitbox.get_overlapping_bodies():
		_try_hit_body(body)
	
func disable_eat_hitbox() -> void:
	eat_hitbox.monitoring = false
	
func _on_hitbox_timer_timeout() -> void:
	disable_eat_hitbox()

func _on_eat_timer_timeout() -> void:
	is_attacking = false
	disable_eat_hitbox()
	
func _on_eat_hitbox_body_entered(body: Node3D) -> void:
	_try_hit_body(body)
		
func _try_hit_body(body: Node) -> void:
	if not is_attacking:
		return
	
	if len(eat_targets_hit) >= mouth_size:
		return
		
	if body.is_in_group("eatables"):
		body.die()
		eat_targets_hit.append(body)
		pikmin_eaten += 1
		check_growth()
	
func check_growth():
	if not grown_up and pikmin_eaten >= 2:
		grow()
	if not grown_up2 and pikmin_eaten >= 5:
		grow2()
		
func grow():
	grown_up = true
	scale = Vector3(2.0, 2.0, 2.0)

	var hit = eat_hitbox
	hit.scale = Vector3(2.0, 2.0, 2.0)
	mouth_size = 10
	
func grow2():
	grown_up2 = true
	scale = Vector3(4.0, 4.0, 4.0)

	var hit = eat_hitbox
	hit.scale = Vector3(4.0, 4.0, 4.0)
	mouth_size = 100
