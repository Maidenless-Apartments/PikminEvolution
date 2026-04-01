extends Node

@export var level_time: float = 240.0

@onready var player = $"../CharacterBody3D"

signal time_changed(time_left)
signal game_over(won, reason)

var time_left: float
var game_is_over := false

func _ready() -> void:
	time_left = level_time
	player.died.connect(_on_player_died)
	player.stage_changed.connect(_on_stage_changed)
	
func _process(delta: float) -> void:
	if game_is_over:
		return
	
	time_left -= delta
	time_left = max(time_left, 0.0)
	time_changed.emit(time_left)
	
	if time_left <= 0.0:
		end_level()
		
func _on_player_died() -> void:
	if game_is_over:
		return
	
	game_is_over = true
	game_over.emit(false, "You starved.")
	
func _on_stage_changed() -> void:
	time_left += 20
	
func end_level() -> void:
	if game_is_over:
		return
	
	game_is_over = true
	
	var won = player.growth_stage >= 2
	var reason = ""
	
	if won:
		reason = "Time's up. You reached the final stage!"
	else:
		reason = "Time's up. You did not fully evolve."
	
	game_over.emit(won, reason)
