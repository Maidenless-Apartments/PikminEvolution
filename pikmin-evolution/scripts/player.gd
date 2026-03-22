extends CharacterBody3D

signal hunger_changed(current, max_value)
signal pikmin_eaten_changed(value)
signal died
signal stage_changed(stage)

@export var speed := 2.5
@export var jump_velocity := 4.5
@export var eat_total_duration: float = 1.633
@export var eat_hitbox_delay: float = 0.43
@export var eat_hitbox_duration: float = 0.28
@export var shake_total_duration: float = 1.6333
@export var roar_total_duration: float = 3.0417
@export var stage1_model: PackedScene
@export var stage2_model: PackedScene
@export var max_hunger: float = 100.0
@export var hunger_decay_per_second: float = 2.0
@export var hunger_gain_on_eat: float = 6.0
var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
@export var camera_turn_speed := 2.5
@export var camera_pitch_speed := 2.0
@onready var camera_pivot = $cameraPivot
@onready var pitch_pivot: Node3D = $cameraPivot/pitchPivot
@onready var visual_root = $visualRoot
@onready var eat_timer: Timer = $eatTimer
@onready var hitbox_timer: Timer = $hitboxTimer
@onready var shake_timer: Timer = $shakeTimer
@onready var roar_timer: Timer = $roarTimer
@onready var collision = $CollisionShape3D
@onready var shake_area: Area3D = $shakeArea
@onready var roar_area: Area3D = $roarArea

var is_dead: bool = false
var is_attacking: bool = false
var is_shaking : bool = false
var is_roaring: bool = false
var can_shake: bool = false
var can_roar: bool = false
var eat_targets_hit: Array[Node] = []
var mouth_size = 3
var pitch := 0.0
var pikmin_eaten: int = 0
var grown_up: bool = false
var grown_up2: bool = false
var current_model: Node = null
var growth_stage := 0
var anim_tree: AnimationTree
var anim_state: AnimationNodeStateMachinePlayback
var eat_hitbox: Area3D
var threshold1: int = 20
var threshold2: int = 60
var hunger: float = 100.0

func _ready() -> void:
	set_model(stage1_model)
	anim_tree.active = true
	eat_hitbox.monitoring = false
	eat_timer.one_shot = true
	hitbox_timer.one_shot = true
	shake_timer.one_shot = true
	roar_timer.one_shot = true

	eat_timer.timeout.connect(_on_eat_timer_timeout)
	hitbox_timer.timeout.connect(_on_hitbox_timer_timeout)
	shake_timer.timeout.connect(_on_shake_timer_timeout)
	roar_timer.timeout.connect(_on_roar_timer_timeout)
	
func _process(delta: float) -> void:
	if is_dead:
		return
	
	change_hunger(-hunger_decay_per_second * delta)
	
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

	if not is_attacking and not is_shaking and not is_roaring:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	if not is_on_floor():
		velocity.y -= gravity * delta
		
	if Input.is_action_just_pressed("eat") and not is_attacking and not is_shaking and not is_roaring:
		start_eat_attack()
	elif Input.is_action_just_pressed("shake") and not is_attacking and not is_shaking and not is_roaring and can_shake:
		start_shake()
	elif Input.is_action_just_pressed("roar") and not is_attacking and not is_shaking and not is_roaring and can_roar:
		start_roar()
	if is_attacking:
		pass
	elif is_shaking:
		pass
	elif is_roaring:
		pass
	elif input_dir.length() > 0.1:
		anim_state.travel("Walk")
		move_and_slide()
	else:
		anim_state.travel("Idle")
		
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
	check_growth()
	
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
		pikmin_eaten_changed.emit(pikmin_eaten)
		change_hunger(hunger_gain_on_eat)
		
func start_shake() -> void:
	is_shaking = true
	anim_state.travel("Shake")
	
	await get_tree().create_timer(0.3).timeout
	if is_shaking:
		do_shake_effect()
	
	shake_timer.start(shake_total_duration)
	
func do_shake_effect() -> void:
	for body in shake_area.get_overlapping_bodies():
		if body.is_in_group("eatables") and body.has_method("repel_from"):
			body.repel_from(global_position)
	
func _on_shake_timer_timeout() -> void:
	end_shake()
	
func _on_roar_timer_timeout() -> void:
	end_roar()
	
func end_shake() -> void:
	is_shaking = false
	anim_state.travel("Idle")
	
func start_roar() -> void:
	is_roaring = true
	anim_state.travel("Roar")
	
	await get_tree().create_timer(0.5).timeout
	if is_roaring:
		do_roar_effect()
	
	roar_timer.start(roar_total_duration)
	
func do_roar_effect() -> void:
	for body in roar_area.get_overlapping_bodies():
		if body.is_in_group("eatables") and body.has_method("freeze_for"):
			body.freeze_for(6.0)
			
func end_roar() -> void:
	is_roaring = false
	anim_state.travel("Idle")
	
func check_growth():
	if not grown_up and pikmin_eaten >= threshold1:
		grow()
	if not grown_up2 and pikmin_eaten >= threshold2:
		grow2()
		
func grow():
	grown_up = true
	scale = Vector3(2.0, 2.0, 2.0)

	var hit = eat_hitbox
	hit.scale = Vector3(2.0, 2.0, 2.0)
	mouth_size = 10
	can_shake = true
	hunger_decay_per_second = 4.0
	hunger_gain_on_eat = 10
	stage_changed.emit()
	
func grow2():
	grown_up2 = true
	growth_stage = 2
	set_model(stage2_model)
	scale = Vector3(4.0, 4.0, 4.0)

	mouth_size = 60
	eat_total_duration = 4.0417
	eat_hitbox_delay = 1.23
	eat_hitbox_duration = 2.57
	can_roar = true
	hunger_decay_per_second = 10
	hunger_gain_on_eat = 12
	stage_changed.emit()
	
func set_model(model_scene: PackedScene):
	if model_scene == null:
		return
	
	if current_model:
		current_model.queue_free()
	
	current_model = model_scene.instantiate()
	visual_root.add_child(current_model)
	current_model.position = Vector3.ZERO
	current_model.rotation = Vector3.ZERO
	
	anim_tree = current_model.get_node("AnimationTree")
	anim_state = anim_tree.get("parameters/playback")
	
	eat_hitbox = current_model.get_node("eatHitBox")
	eat_hitbox.monitoring = false

	if not eat_hitbox.body_entered.is_connected(_on_eat_hitbox_body_entered):
		eat_hitbox.body_entered.connect(_on_eat_hitbox_body_entered)
		
func change_hunger(amount: float) -> void:
	if is_dead:
		return
	
	hunger = clamp(hunger + amount, 0.0, max_hunger)
	hunger_changed.emit(hunger, max_hunger)
	
	if hunger <= 0.0:
		die_from_starvation()
		
func take_damage(amount: float) -> void:
	change_hunger(-amount)
	
func die_from_starvation() -> void:
	if is_dead:
		return
	
	is_dead = true
	died.emit()
