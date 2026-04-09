extends CharacterBody3D

@export var move_speed: float = .5
@export var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
@export var min_wander_time: float = 1.5
@export var max_wander_time: float = 4.0
@export var sight_range: float = 8.0
@export var scared_move_speed: float = 1
@export var aggressive_move_speed: float = 1.4
@export var flee_duration: float = 1.2
@export var attack_range: float = 1.1
@export var attack_cooldown: float = 1.0
@export var attack_damage: float = 3.0
@export var attack_anim_duration: float = 0.45

@onready var wander_timer: Timer = $Timer
@onready var visuals: Node3D = $visuals
@onready var anim_tree: AnimationTree = $AnimationTree

const SKIN_NODE_NAMES: Array[String] = ["redPikminGLB", "yellowPikminGLB", "bluePikminGLB"]

enum Nature {
	NEUTRAL,
	SCARED,
	AGGRESSIVE,
}

@export var nature: Nature = Nature.NEUTRAL

var wander_direction: Vector3 = Vector3.ZERO
var is_frozen := false
var knockback_velocity: Vector3 = Vector3.ZERO
var current_move_speed: float = 0.0
var flee_timer_left: float = 0.0
var attack_cooldown_left: float = 0.0
var attack_anim_timer_left: float = 0.0
var player_target: Node3D

func _ready() -> void:
	randomize()
	apply_skin_by_index(randi_range(0, SKIN_NODE_NAMES.size() - 1))
	current_move_speed = move_speed
	player_target = _find_player()
	pick_new_direction()

func apply_skin_by_index(skin_index: int) -> void:
	if visuals == null:
		return

	var clamped_index := clampi(skin_index, 0, SKIN_NODE_NAMES.size() - 1)
	var selected_skin_name: String = SKIN_NODE_NAMES[clamped_index]
	var selected_skin: Node3D = visuals.get_node_or_null(selected_skin_name)

	if selected_skin == null:
		return

	for skin_name in SKIN_NODE_NAMES:
		var skin_node := visuals.get_node_or_null(skin_name)
		if skin_node is Node3D:
			skin_node.visible = skin_name == selected_skin_name

	anim_tree.root_node = NodePath("../visuals/%s" % selected_skin_name)
	anim_tree.anim_player = NodePath("../visuals/%s/AnimationPlayer" % selected_skin_name)

func _physics_process(delta: float) -> void:
	_update_behavior(delta)

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	velocity.x = wander_direction.x * current_move_speed
	velocity.z = wander_direction.z * current_move_speed
	
	if is_frozen:
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		return

	velocity += knockback_velocity
	knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, 20.0 * delta)

	if attack_anim_timer_left > 0.0:
		anim_tree.set("parameters/conditions/is_attacking", true)
		anim_tree.set("parameters/conditions/is_walking", false)
		anim_tree.set("parameters/conditions/is_idle", false)
	elif wander_direction.length() > 0.01:
		anim_tree.set("parameters/conditions/is_attacking", false)
		visuals.look_at(
			global_position + Vector3(wander_direction.x, 0.0, wander_direction.z),
			Vector3.UP,
		)
		anim_tree.set("parameters/conditions/is_walking", true)
		anim_tree.set("parameters/conditions/is_idle", false)
	else:
		anim_tree.set("parameters/conditions/is_attacking", false)
		anim_tree.set("parameters/conditions/is_walking", false)
		anim_tree.set("parameters/conditions/is_idle", true)

	move_and_slide()

func set_nature(new_nature: int) -> void:
	nature = clampi(new_nature, Nature.NEUTRAL, Nature.AGGRESSIVE)

func set_player_target(target: Node3D) -> void:
	player_target = target

func _find_player() -> Node3D:
	var from_group := get_tree().get_first_node_in_group("player")
	if from_group is Node3D:
		return from_group

	var from_scene := get_tree().current_scene.get_node_or_null("CharacterBody3D")
	if from_scene is Node3D:
		return from_scene

	return null

func _can_see_player() -> bool:
	if player_target == null or not is_instance_valid(player_target):
		player_target = _find_player()

	if player_target == null:
		return false

	return global_position.distance_to(player_target.global_position) <= sight_range

func _update_behavior(delta: float) -> void:
	current_move_speed = move_speed

	if attack_cooldown_left > 0.0:
		attack_cooldown_left = max(0.0, attack_cooldown_left - delta)

	if attack_anim_timer_left > 0.0:
		attack_anim_timer_left = max(0.0, attack_anim_timer_left - delta)

	if nature == Nature.NEUTRAL:
		return

	if player_target == null or not is_instance_valid(player_target):
		player_target = _find_player()

	if player_target == null:
		return

	var to_player: Vector3 = player_target.global_position - global_position
	to_player.y = 0.0
	var distance_to_player := to_player.length()

	if nature == Nature.SCARED:
		current_move_speed = scared_move_speed

		if distance_to_player <= sight_range:
			flee_timer_left = flee_duration

		if flee_timer_left > 0.0:
			flee_timer_left -= delta
			if distance_to_player > 0.01:
				wander_direction = (-to_player).normalized()
		return

	if nature == Nature.AGGRESSIVE:
		current_move_speed = aggressive_move_speed

		if distance_to_player <= sight_range:
			if distance_to_player <= attack_range:
				wander_direction = Vector3.ZERO
				_try_attack_player()
			else:
				wander_direction = to_player.normalized()

func _try_attack_player() -> void:
	if attack_cooldown_left > 0.0 or is_frozen:
		return

	if player_target != null and player_target.has_method("take_damage"):
		player_target.take_damage(attack_damage)
		attack_anim_timer_left = attack_anim_duration

	attack_cooldown_left = attack_cooldown

func pick_new_direction() -> void:
	var angle: float = randf_range(0.0, TAU)
	wander_direction = Vector3(cos(angle), 0.0, sin(angle)).normalized()

	wander_timer.wait_time = randf_range(min_wander_time, max_wander_time)
	wander_timer.start()

func _on_timer_timeout() -> void:
	if nature != Nature.NEUTRAL and _can_see_player():
		wander_timer.wait_time = randf_range(min_wander_time, max_wander_time)
		wander_timer.start()
		return

	# Small chance to pause instead of walking
	if randf() < 0.25:
		wander_direction = Vector3.ZERO
	else:
		var angle: float = randf_range(0.0, TAU)
		wander_direction = Vector3(cos(angle), 0.0, sin(angle)).normalized()

	wander_timer.wait_time = randf_range(min_wander_time, max_wander_time)
	wander_timer.start()
	
func die() -> void:
	queue_free()

func repel_from(source_pos: Vector3) -> void:
	var dir = global_position - source_pos
	dir.y = 0
	dir = dir.normalized()
	knockback_velocity = dir * 16.0
	
func freeze_for(duration: float) -> void:
	if is_frozen:
		return
	
	is_frozen = true
	
	var timer = get_tree().create_timer(duration)
	await timer.timeout
	is_frozen = false
