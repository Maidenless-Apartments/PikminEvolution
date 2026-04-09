extends Control

@onready var hunger_bar: ProgressBar = $HungerBar
@onready var time_label: Label = $TimeLabel
@onready var score_label: Label = $ScoreLabel
@onready var stage_label: Label = $StageLabel
@onready var message_label: Label = $MessageLabel
@onready var eat_icon: TextureRect = $iconsContainer/eatIcon
@onready var shake_icon: TextureRect = $iconsContainer/shakeIcon
@onready var roar_icon: TextureRect = $iconsContainer/roarIcon

@onready var player = $"../../CharacterBody3D"
@onready var game_manager = $"../../gameManager"

func _ready() -> void:
	player.hunger_changed.connect(_on_hunger_changed)
	player.pikmin_eaten_changed.connect(_on_pikmin_eaten_changed)
	player.stage_changed.connect(_on_stage_changed)
	player.eating.connect(_on_eating_changed)
	player.shaking.connect(_on_shaking_changed)
	player.roaring.connect(_on_roaring_changed)
	game_manager.time_changed.connect(_on_time_changed)
	game_manager.game_over.connect(_on_game_over)
	
	eat_icon.self_modulate = Color(1,1,1,1)
	shake_icon.self_modulate = Color(0.45, 0.45, 0.45, 1.0)
	roar_icon.self_modulate = Color(0.45, 0.45, 0.45, 1.0)
	
	_on_hunger_changed(player.hunger, player.max_hunger)
	_on_pikmin_eaten_changed(player.pikmin_eaten)
	_on_stage_changed(player.growth_stage)
	_on_time_changed(game_manager.time_left)

func _on_hunger_changed(current: float, max_value: float) -> void:
	hunger_bar.max_value = max_value
	hunger_bar.value = current
	
func _on_pikmin_eaten_changed(value: int) -> void:
	score_label.text = "Eaten: " + str(value)
	
func _on_stage_changed(stage: int) -> void:
	if stage == 1:
		shake_icon.self_modulate = Color(1,1,1,1)
	if stage == 2:
		roar_icon.self_modulate = Color(1,1,1,1)
	stage_label.text = "Stage: " + str(stage + 1)
	
func _on_time_changed(time_left: float) -> void:
	var seconds = int(ceil(time_left))
	time_label.text = "Time: " + str(seconds)
	
func _on_game_over(won: bool, reason: String) -> void:
	message_label.text = reason
	message_label.visible = true
	
func _on_eating_changed(value: int) -> void:
	if value == 1:
		eat_icon.self_modulate = Color(0.45, 0.45, 0.45, 1.0)
	else:
		eat_icon.self_modulate = Color(1,1,1,1)
		
func _on_shaking_changed(value: int) -> void:
	if value == 1:
		shake_icon.self_modulate = Color(0.45, 0.45, 0.45, 1.0)
	else:
		shake_icon.self_modulate = Color(1,1,1,1)
		
func _on_roaring_changed(value: int) -> void:
	if value == 1:
		roar_icon.self_modulate = Color(0.45, 0.45, 0.45, 1.0)
	else:
		roar_icon.self_modulate = Color(1,1,1,1)
