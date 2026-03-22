extends CharacterBody3D

@export var move_speed: float = .5
@export var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
@export var min_wander_time: float = 1.5
@export var max_wander_time: float = 4.0

@onready var wander_timer: Timer = $Timer
@onready var visuals: Node3D = $visuals
@onready var anim_tree: AnimationTree = $AnimationTree

var wander_direction: Vector3 = Vector3.ZERO
var is_frozen := false
var knockback_velocity: Vector3 = Vector3.ZERO

func _ready() -> void:
	randomize()
	pick_new_direction()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	velocity.x = wander_direction.x * move_speed
	velocity.z = wander_direction.z * move_speed
	
	if is_frozen:
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		return

	velocity += knockback_velocity
	knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, 20.0 * delta)

	if wander_direction.length() > 0.01:
		visuals.look_at(
			global_position + Vector3(wander_direction.x, 0.0, wander_direction.z),
			Vector3.UP,
		)
		anim_tree.set("parameters/conditions/is_walking", true)
		anim_tree.set("parameters/conditions/is_idle", false)
	else:
		anim_tree.set("parameters/conditions/is_walking", false)
		anim_tree.set("parameters/conditions/is_idle", true)

	move_and_slide()

func pick_new_direction() -> void:
	var angle: float = randf_range(0.0, TAU)
	wander_direction = Vector3(cos(angle), 0.0, sin(angle)).normalized()

	wander_timer.wait_time = randf_range(min_wander_time, max_wander_time)
	wander_timer.start()

func _on_timer_timeout() -> void:
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
	knockback_velocity = dir * 8.0
	
func freeze_for(duration: float) -> void:
	if is_frozen:
		return
	
	is_frozen = true
	
	var timer = get_tree().create_timer(duration)
	await timer.timeout
	is_frozen = false
