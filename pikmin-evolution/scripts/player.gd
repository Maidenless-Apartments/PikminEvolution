extends CharacterBody3D

signal hunger_changed(current, max_value)
signal pikmin_eaten_changed(value)
signal died
signal stage_changed(stage)
signal eating(value)
signal shaking(value)
signal roaring(value)

const RUN_FOOTSTEP_SOUNDS = [
	preload("res://assets/audio/player/walking/Dirt Run 1.ogg"),
	preload("res://assets/audio/player/walking/Dirt Run 2.ogg")
]
const WALK_FOOTSTEP_SOUNDS = [
	preload("res://assets/audio/player/walking/Dirt Walk 1.ogg"),
	preload("res://assets/audio/player/walking/Dirt Walk 2.ogg")
]
const EAT_SOUND = preload("res://assets/audio/player/eating/Creature_Hiss_low_deep_015.wav")
const SHAKE_SOUND = preload("res://assets/audio/player/shaking/Creature_Hiss_low_deep_012.wav")
const ROAR_SOUND = preload("res://assets/audio/player/roaring/Creature_Roar_low_deep_003.wav")
const UPGRADE_SOUND = preload("res://assets/audio/player/upgrade2.mp3")
const PIKMIN_CRY_SOUND = preload("res://assets/audio/pikmin/cry4.mp3")

@export var speed := 5
@export var jump_velocity := 4.5
@export var eat_total_duration: float = 1.633
@export var eat_hitbox_delay: float = 0.43
@export var eat_hitbox_duration: float = 0.28
@export var shake_total_duration: float = 1.6333
@export var shake_hitbox_delay: float = 0.4
@export var shake_hitbox_duration: float = 1
@export var roar_total_duration: float = 3.0417
@export var roar_hitbox_delay: float = 1.5
@export var roar_hitbox_duration: float = 1.5
@export var stage1_model: PackedScene
@export var stage2_model: PackedScene
@export var max_hunger: float = 100.0
@export var hunger_decay_per_second: float = 1.0
@export var hunger_gain_on_eat: float = 6.0
var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
@export var camera_turn_speed := 2.5
@export var camera_pitch_speed := 2.0
@export var camera_distance_stage1_multiplier: float = 2.0
@export var camera_distance_stage2_multiplier: float = 6.0
@export var ability_radius_stage1_multiplier: float = 2.0
@export var ability_radius_stage2_multiplier: float = 4.0
@onready var camera_pivot = $cameraPivot
@onready var pitch_pivot: Node3D = $cameraPivot/pitchPivot
@onready var spring_arm: SpringArm3D = $cameraPivot/pitchPivot/SpringArm3D
@onready var visual_root = $visualRoot
@onready var eat_timer: Timer = $eatTimer
@onready var hitbox_timer: Timer = $hitboxTimer
@onready var shake_timer: Timer = $shakeTimer
@onready var roar_timer: Timer = $roarTimer
@onready var shake_hitbox_timer: Timer = $shakeHitboxTimer
@onready var roar_hitbox_timer: Timer = $roarHitboxTimer
@onready var collision = $CollisionShape3D
@onready var shake_area: Area3D = $shakeArea
@onready var roar_area: Area3D = $roarArea
@onready var shake_collision_shape: CollisionShape3D = $shakeArea/CollisionShape3D
@onready var growth_particles: GPUParticles3D = $growthParticles
@onready var movement_audio_player: AudioStreamPlayer3D = $movementAudioPlayer
@onready var action_audio_player: AudioStreamPlayer3D = $actionAudioPlayer

var is_dead: bool = false
var is_attacking: bool = false
var is_shaking : bool = false
var is_roaring: bool = false
var can_shake: bool = false
var can_roar: bool = false
var eat_targets_hit: Array[Node] = []
var shake_targets_hit: Array[Node] = []
var roar_targets_hit: Array[Node] = []
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
var base_camera_distance: float = 0.0
var base_camera_height: float = 0.0

func _ready() -> void:
	set_model(stage1_model)
	anim_tree.active = true
	base_camera_distance = spring_arm.spring_length
	base_camera_height = camera_pivot.position.y
	update_camera_distance()
	eat_hitbox.monitoring = false
	eat_timer.one_shot = true
	hitbox_timer.one_shot = true
	shake_timer.one_shot = true
	roar_timer.one_shot = true
	shake_hitbox_timer.one_shot = true
	roar_hitbox_timer.one_shot = true
	shake_area.monitoring = false
	roar_area.monitoring = false
	update_ability_hitbox_scale()

	eat_timer.timeout.connect(_on_eat_timer_timeout)
	hitbox_timer.timeout.connect(_on_hitbox_timer_timeout)
	shake_timer.timeout.connect(_on_shake_timer_timeout)
	roar_timer.timeout.connect(_on_roar_timer_timeout)
	shake_hitbox_timer.timeout.connect(_on_shake_hitbox_timer_timeout)
	roar_hitbox_timer.timeout.connect(_on_roar_hitbox_timer_timeout)

	if not shake_area.body_entered.is_connected(_on_shake_area_body_entered):
		shake_area.body_entered.connect(_on_shake_area_body_entered)
	if not roar_area.body_entered.is_connected(_on_roar_area_body_entered):
		roar_area.body_entered.connect(_on_roar_area_body_entered)

	if not movement_audio_player.finished.is_connected(_on_movement_audio_finished):
		movement_audio_player.finished.connect(_on_movement_audio_finished)

	movement_audio_player.volume_db = 3.0
	action_audio_player.volume_db = 3.0
	
func _process(delta: float) -> void:
	if is_dead or is_roaring or is_shaking:
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
	else:
		anim_state.travel("Idle")

	if is_shaking and shake_area.monitoring:
		do_shake_effect()
	if is_roaring and roar_area.monitoring:
		do_roar_effect()

	update_movement_audio(_should_play_movement_audio())

	move_and_slide()
		
func start_eat_attack() -> void:
	is_attacking = true
	eat_targets_hit.clear()
	anim_state.travel("Eat")
	eating.emit(1)
	
	eat_timer.start(eat_total_duration)
	
	await get_tree().create_timer(eat_hitbox_delay).timeout
	if is_attacking:
		enable_eat_hitbox()
		hitbox_timer.start(eat_hitbox_duration)
	
func end_eat_attack() -> void:
	is_attacking = false
	eat_hitbox.monitoring = false
	anim_state.travel("Idle")
	eating.emit(0)
	
func enable_eat_hitbox() -> void:
	eat_targets_hit.clear()
	eat_hitbox.monitoring = true
	play_action_sound(EAT_SOUND)
	
	for body in eat_hitbox.get_overlapping_bodies():
		_try_hit_body(body)
	
func disable_eat_hitbox() -> void:
	eat_hitbox.monitoring = false
	
func _on_hitbox_timer_timeout() -> void:
	disable_eat_hitbox()

func _on_eat_timer_timeout() -> void:
	end_eat_attack()
	check_growth()
	
func _on_eat_hitbox_body_entered(body: Node3D) -> void:
	_try_hit_body(body)
		
func _try_hit_body(body: Node) -> void:
	if not is_attacking:
		return
	
	if len(eat_targets_hit) >= mouth_size:
		return
		
	if body.is_in_group("eatables"):
		play_pikmin_cry_sound()
		body.die()
		eat_targets_hit.append(body)
		pikmin_eaten += 1
		pikmin_eaten_changed.emit(pikmin_eaten)
		change_hunger(hunger_gain_on_eat)

func play_pikmin_cry_sound() -> void:
	if PIKMIN_CRY_SOUND == null:
		return

	var scene_root := get_tree().current_scene
	if scene_root == null:
		return

	var cry_audio_player := AudioStreamPlayer3D.new()
	cry_audio_player.stream = PIKMIN_CRY_SOUND
	cry_audio_player.volume_db = 3.0
	scene_root.add_child(cry_audio_player)
	cry_audio_player.global_position = global_position
	cry_audio_player.finished.connect(cry_audio_player.queue_free)
	cry_audio_player.play()
		
func start_shake() -> void:
	is_shaking = true
	shake_targets_hit.clear()
	anim_state.travel("Shake")
	shaking.emit(1)

	shake_timer.start(shake_total_duration)

	await get_tree().create_timer(shake_hitbox_delay).timeout
	if is_shaking:
		enable_shake_hitbox()
		shake_hitbox_timer.start(shake_hitbox_duration)
	
func do_shake_effect() -> void:
	for body in _get_shake_targets_in_range():
		_try_shake_body(body)

func enable_shake_hitbox() -> void:
	shake_targets_hit.clear()
	shake_area.monitoring = true
	play_action_sound(SHAKE_SOUND)

	for body in _get_shake_targets_in_range():
		_try_shake_body(body)

func disable_shake_hitbox() -> void:
	shake_area.monitoring = false

func _on_shake_hitbox_timer_timeout() -> void:
	disable_shake_hitbox()

func _on_shake_area_body_entered(body: Node3D) -> void:
	_try_shake_body(body)

func _try_shake_body(body: Node) -> void:
	if not is_shaking:
		return

	if body in shake_targets_hit:
		return

	if body.is_in_group("eatables") and body.has_method("repel_from"):
		body.repel_from(global_position)
		shake_targets_hit.append(body)

func _get_shake_targets_in_range() -> Array[Node]:
	var targets: Array[Node] = []

	for body in shake_area.get_overlapping_bodies():
		if body not in targets:
			targets.append(body)

	var shake_radius := _get_shake_effect_radius()
	for candidate in get_tree().get_nodes_in_group("eatables"):
		if not (candidate is Node3D):
			continue

		var node := candidate as Node3D
		if node.global_position.distance_to(global_position) <= shake_radius and node not in targets:
			targets.append(node)

	return targets

func _get_shake_effect_radius() -> float:
	if shake_collision_shape == null:
		return 2.0

	var sphere_shape := shake_collision_shape.shape as SphereShape3D
	if sphere_shape == null:
		return 2.0

	var local_scale := shake_collision_shape.transform.basis.get_scale()
	var area_scale := shake_area.global_transform.basis.get_scale()
	var sx = abs(local_scale.x * area_scale.x)
	var sy = abs(local_scale.y * area_scale.y)
	var sz = abs(local_scale.z * area_scale.z)
	var max_scale = max(sx, max(sy, sz))

	return sphere_shape.radius * max_scale
	
func _on_shake_timer_timeout() -> void:
	end_shake()
	
func _on_roar_timer_timeout() -> void:
	end_roar()
	
func end_shake() -> void:
	is_shaking = false
	disable_shake_hitbox()
	anim_state.travel("Idle")
	shaking.emit(0)
	
func start_roar() -> void:
	is_roaring = true
	roar_targets_hit.clear()
	anim_state.travel("Roar")
	roaring.emit(1)

	roar_timer.start(roar_total_duration)

	await get_tree().create_timer(roar_hitbox_delay).timeout
	if is_roaring:
		enable_roar_hitbox()
		roar_hitbox_timer.start(roar_hitbox_duration)
	
func do_roar_effect() -> void:
	for body in roar_area.get_overlapping_bodies():
		_try_roar_body(body)

func enable_roar_hitbox() -> void:
	roar_targets_hit.clear()
	roar_area.monitoring = true
	play_action_sound(ROAR_SOUND)

	for body in roar_area.get_overlapping_bodies():
		_try_roar_body(body)

func disable_roar_hitbox() -> void:
	roar_area.monitoring = false

func _on_roar_hitbox_timer_timeout() -> void:
	disable_roar_hitbox()

func _on_roar_area_body_entered(body: Node3D) -> void:
	_try_roar_body(body)

func _try_roar_body(body: Node) -> void:
	if not is_roaring:
		return

	if body in roar_targets_hit:
		return

	if body.is_in_group("eatables") and body.has_method("freeze_for"):
		body.freeze_for(12.0)
		roar_targets_hit.append(body)
			
func end_roar() -> void:
	is_roaring = false
	disable_roar_hitbox()
	anim_state.travel("Idle")
	roaring.emit(0)
	
func check_growth():
	if not grown_up and pikmin_eaten >= threshold1:
		grow()
	if not grown_up2 and pikmin_eaten >= threshold2:
		grow2()
		
func grow():
	grown_up = true
	growth_stage = 1
	visual_root.scale = Vector3(2.0, 2.0, 2.0)
	update_camera_distance()
	update_ability_hitbox_scale()
	play_growth_particles(1.0)
	play_action_sound(UPGRADE_SOUND)

	mouth_size = 10
	can_shake = true
	hunger_decay_per_second = 2.0
	hunger_gain_on_eat = 10
	stage_changed.emit(1)
	
func grow2():
	grown_up2 = true
	growth_stage = 2
	set_model(stage2_model)
	visual_root.scale = Vector3(4.0, 4.0, 4.0)
	update_camera_distance()
	update_ability_hitbox_scale()
	play_growth_particles(1.6)
	play_action_sound(UPGRADE_SOUND)

	mouth_size = 60
	eat_total_duration = 4.0417
	eat_hitbox_delay = 1.23
	eat_hitbox_duration = 2.57
	shake_total_duration = 2.0417
	shake_hitbox_delay = 1.7
	shake_hitbox_duration = 0.3
	can_roar = true
	hunger_decay_per_second = 3.0
	hunger_gain_on_eat = 12
	stage_changed.emit(2)

func play_growth_particles(multiplier: float) -> void:
	if growth_particles == null:
		return

	growth_particles.scale = Vector3.ONE * multiplier
	growth_particles.restart()
	growth_particles.emitting = true
	
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

func update_camera_distance() -> void:
	if spring_arm == null:
		return

	var scale_factor := 1.0
	if growth_stage >= 2:
		scale_factor = camera_distance_stage2_multiplier
	elif growth_stage >= 1:
		scale_factor = camera_distance_stage1_multiplier

	spring_arm.spring_length = base_camera_distance * scale_factor
	camera_pivot.position.y = base_camera_height * scale_factor

func update_ability_hitbox_scale() -> void:
	var scale_factor := 1.0
	if growth_stage >= 2:
		scale_factor = ability_radius_stage2_multiplier
	elif growth_stage >= 1:
		scale_factor = ability_radius_stage1_multiplier

	shake_area.scale = Vector3.ONE * scale_factor
	roar_area.scale = Vector3.ONE * scale_factor
		
func change_hunger(amount: float) -> void:
	if is_dead:
		return
	
	hunger = clamp(hunger + amount, 0.0, max_hunger)
	hunger_changed.emit(hunger, max_hunger)
	
	if hunger <= 0.0:
		die_from_starvation()
		
func take_damage(amount: float) -> void:
	if is_shaking:
		return

	change_hunger(-amount)
	
func die_from_starvation() -> void:
	if is_dead:
		return
	
	is_dead = true
	movement_audio_player.stop()
	action_audio_player.stop()
	died.emit()

func _should_play_movement_audio() -> bool:
	if is_dead or is_attacking or is_shaking or is_roaring or not is_on_floor():
		return false

	return Vector2(velocity.x, velocity.z).length() > 0.1

func update_movement_audio(should_play: bool) -> void:
	if should_play:
		if not movement_audio_player.playing:
			play_random_movement_clip()
	else:
		if movement_audio_player.playing:
			movement_audio_player.stop()

func play_random_movement_clip() -> void:
	var clips: Array = RUN_FOOTSTEP_SOUNDS
	if growth_stage >= 2:
		clips = WALK_FOOTSTEP_SOUNDS

	if clips.is_empty():
		return

	movement_audio_player.stream = clips[randi_range(0, clips.size() - 1)]
	movement_audio_player.play()

func _on_movement_audio_finished() -> void:
	if _should_play_movement_audio():
		play_random_movement_clip()

func play_action_sound(sound: AudioStream) -> void:
	if sound == null:
		return

	action_audio_player.stream = sound
	action_audio_player.play()
