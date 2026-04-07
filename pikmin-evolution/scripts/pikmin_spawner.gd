extends Node3D

@export var enemy_scene: PackedScene
@export var max_enemies: int = 50
@export var max_enemies_stage2: int = 100
@export var max_enemies_stage3: int = 200
@export var spawn_interval: float = .5
@export var spawn_interval3: float = .2
@export var player_block_radius: float = 8.0
@onready var spawn_points_stage1 = $"../spawnPoints".get_children()
@onready var spawn_points_stage2_node = get_node_or_null("../spawnPoints2")
@onready var spawn_points_stage3_node = get_node_or_null("../spawnPoints3")

var current_enemies: int = 0
var spawn_points = []
var base_max_enemies: int = 0
var base_spawn_interval: float = 0.0
var rng = RandomNumberGenerator.new()
var num_spawned: int = 0
var spawn_timer: Timer
var current_stage: int = 0
@onready var player = $"../CharacterBody3D"

func _ready():
	base_max_enemies = max_enemies
	base_spawn_interval = spawn_interval
	spawn_points = spawn_points_stage1
	if player != null and not player.stage_changed.is_connected(_on_player_stage_changed):
		player.stage_changed.connect(_on_player_stage_changed)
	_update_spawn_settings_for_stage(_get_player_stage())

	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.autostart = true
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)
	rng.randomize()

func _on_spawn_timer_timeout():
	if current_enemies >= max_enemies:
		return
	
	if num_spawned >= max_enemies:
		return
	
	if spawn_points.is_empty():
		return

	var available_points: Array[Node3D] = _get_available_spawn_points()
	if available_points.is_empty():
		return

	var point: Node3D = available_points[randi() % available_points.size()]
	var enemy = enemy_scene.instantiate()
	var random_skin_index = rng.randi_range(0, 2)
	if enemy.has_method("apply_skin_by_index"):
		enemy.apply_skin_by_index(random_skin_index)
	get_tree().current_scene.add_child(enemy)
	enemy.global_position = point.global_position

	if enemy.has_method("set_player_target"):
		enemy.set_player_target(player)

	if enemy.has_method("set_nature"):
		enemy.set_nature(_roll_nature_for_stage(current_stage))

	current_enemies += 1
	num_spawned += 1
	enemy.tree_exited.connect(_on_enemy_removed)

func _get_player_stage() -> int:
	if player == null:
		return 0

	return int(player.get("growth_stage"))

func _update_spawn_settings_for_stage(stage: int) -> void:
	current_stage = stage
	if stage >= 2:
		if spawn_points_stage3_node != null:
			spawn_points = spawn_points_stage3_node.get_children()
		max_enemies = max_enemies_stage3
		spawn_interval = spawn_interval3
		num_spawned = 0
		if spawn_timer != null:
			spawn_timer.wait_time = spawn_interval
		return
	if stage >= 1:
		if spawn_points_stage2_node != null:
			spawn_points = spawn_points_stage2_node.get_children()
		max_enemies = max_enemies_stage2
		spawn_interval = base_spawn_interval
		num_spawned = 0
		if spawn_timer != null:
			spawn_timer.wait_time = spawn_interval
		return

	spawn_points = spawn_points_stage1
	max_enemies = base_max_enemies
	spawn_interval = base_spawn_interval
	if spawn_timer != null:
		spawn_timer.wait_time = spawn_interval

func _on_player_stage_changed(stage: int) -> void:
	_update_spawn_settings_for_stage(stage)

func _roll_nature_for_stage(stage: int) -> int:
	var neutral_weight: float = 0.65
	var scared_weight: float = 0.25

	if stage >= 2:
		neutral_weight = 0.10
		scared_weight = 0.20
	elif stage >= 1:
		neutral_weight = 0.35
		scared_weight = 0.35

	var roll := randf()
	if roll < neutral_weight:
		return 0
	if roll < neutral_weight + scared_weight:
		return 1
	return 2

func _get_available_spawn_points() -> Array[Node3D]:
	var points: Array[Node3D] = []
	for point in spawn_points:
		if point is Node3D and not _is_player_near_spawn_point(point):
			points.append(point)
	return points

func _is_player_near_spawn_point(point: Node3D) -> bool:
	if player == null:
		return false

	return player.global_position.distance_to(point.global_position) <= player_block_radius

func _on_enemy_removed():
	current_enemies -= 1
