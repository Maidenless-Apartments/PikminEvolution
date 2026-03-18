extends Node3D

@export var enemy_scene: PackedScene
@export var max_enemies: int = 60
@export var spawn_interval: float = .5
@onready var spawn_points = $"../spawnPoints".get_children()

var current_enemies: int = 0

func _ready():
	var timer = Timer.new()
	timer.wait_time = spawn_interval
	timer.autostart = true
	timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(timer)

func _on_spawn_timer_timeout():
	if current_enemies >= max_enemies:
		return
	
	if spawn_points.is_empty():
		return
	
	var point = spawn_points[randi() % spawn_points.size()]
	var enemy = enemy_scene.instantiate()
	get_tree().current_scene.add_child(enemy)
	enemy.global_position = point.global_position
	current_enemies += 1
	enemy.tree_exited.connect(_on_enemy_removed)

func _on_enemy_removed():
	current_enemies -= 1
