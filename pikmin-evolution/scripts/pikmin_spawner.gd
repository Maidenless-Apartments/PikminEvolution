extends Node3D

@export var enemy_scene: PackedScene
@export var max_enemies: int = 100
@export var spawn_interval: float = .5
@onready var spawn_points = $"../spawnPoints".get_children()

var current_enemies: int = 0
var rng = RandomNumberGenerator.new()
@onready var player = $"../CharacterBody3D"

func _ready():
	var timer = Timer.new()
	timer.wait_time = spawn_interval
	timer.autostart = true
	timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(timer)
	rng.randomize()

func _on_spawn_timer_timeout():
	if current_enemies >= max_enemies:
		return
	
	if spawn_points.is_empty():
		return
	
	var point = spawn_points[randi() % spawn_points.size()]
	var enemy = enemy_scene.instantiate()
	var random_int = rng.randi_range(1, 2)
	if random_int == 1:
		enemy.get_node("visuals/redPikminGLB").show()
	elif random_int == 2:
		enemy.get_node("visuals/yellowPikminGLB").show()
	get_tree().current_scene.add_child(enemy)
	enemy.global_position = point.global_position

	if enemy.has_method("set_player_target"):
		enemy.set_player_target(player)

	if enemy.has_method("set_nature"):
		enemy.set_nature(_roll_nature_for_stage(_get_player_stage()))

	current_enemies += 1
	enemy.tree_exited.connect(_on_enemy_removed)

func _get_player_stage() -> int:
	if player == null:
		return 0

	return int(player.get("growth_stage"))

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

func _on_enemy_removed():
	current_enemies -= 1
