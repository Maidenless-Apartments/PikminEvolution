extends Control

@onready var hunger_bar: ProgressBar = $HungerBar
@onready var time_label: Label = $TimeLabel
@onready var score_label: Label = $ScoreLabel
@onready var stage_label: Label = $StageLabel
@onready var fps_label: Label = $FPSLabel
@onready var message_label: Label = $MessageLabel
@onready var eat_icon: TextureRect = $iconsContainer/eatIcon
@onready var shake_icon: TextureRect = $iconsContainer/shakeIcon
@onready var roar_icon: TextureRect = $iconsContainer/roarIcon
@onready var end_game_backdrop: ColorRect = $EndGameBackdrop
@onready var end_game_panel: PanelContainer = $EndGamePanel
@onready var end_game_title: Label = $EndGamePanel/MarginContainer/VBoxContainer/TitleLabel
@onready var end_game_reason: Label = $EndGamePanel/MarginContainer/VBoxContainer/ReasonLabel
@onready var end_game_score: Label = $EndGamePanel/MarginContainer/VBoxContainer/ScoreLabel
@onready var play_again_button: Button = $EndGamePanel/MarginContainer/VBoxContainer/ButtonRow/PlayAgainButton
@onready var next_level_button: Button = $EndGamePanel/MarginContainer/VBoxContainer/ButtonRow/NextLevelButton
@onready var main_menu_button: Button = $EndGamePanel/MarginContainer/VBoxContainer/ButtonRow/MainMenuButton

@onready var player = $"../../CharacterBody3D"
@onready var game_manager = $"../../gameManager"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player.hunger_changed.connect(_on_hunger_changed)
	player.pikmin_eaten_changed.connect(_on_pikmin_eaten_changed)
	player.stage_changed.connect(_on_stage_changed)
	player.eating.connect(_on_eating_changed)
	player.shaking.connect(_on_shaking_changed)
	player.roaring.connect(_on_roaring_changed)
	game_manager.time_changed.connect(_on_time_changed)
	game_manager.game_over.connect(_on_game_over)
	SettingsManager.debugger_changed.connect(_on_debugger_changed)
	play_again_button.pressed.connect(_on_play_again_pressed)
	next_level_button.pressed.connect(_on_next_level_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	
	eat_icon.self_modulate = Color(1,1,1,1)
	shake_icon.self_modulate = Color(0.45, 0.45, 0.45, 1.0)
	roar_icon.self_modulate = Color(0.45, 0.45, 0.45, 1.0)
	end_game_backdrop.visible = false
	end_game_panel.visible = false
	fps_label.visible = false

	for button: Button in [play_again_button, next_level_button, main_menu_button]:
		button.focus_mode = Control.FOCUS_ALL

	play_again_button.focus_neighbor_right = next_level_button.get_path()
	next_level_button.focus_neighbor_left = play_again_button.get_path()
	next_level_button.focus_neighbor_right = main_menu_button.get_path()
	main_menu_button.focus_neighbor_left = next_level_button.get_path()
	
	_on_hunger_changed(player.hunger, player.max_hunger)
	_on_pikmin_eaten_changed(player.pikmin_eaten)
	_on_stage_changed(player.growth_stage)
	_on_time_changed(game_manager.time_left)
	_on_debugger_changed(SettingsManager.debugger_enabled)

func _process(_delta: float) -> void:
	if fps_label.visible:
		fps_label.text = "FPS: %d" % Engine.get_frames_per_second()

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
	end_game_title.text = "You Win!" if won else "You Lose"
	end_game_reason.text = reason
	end_game_score.text = "Pikmin Eaten: " + str(player.pikmin_eaten)
	next_level_button.visible = won
	end_game_backdrop.visible = true
	end_game_panel.visible = true
	get_tree().paused = true
	if won:
		next_level_button.grab_focus()
	else:
		play_again_button.grab_focus()
	
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

func _on_debugger_changed(enabled: bool) -> void:
	fps_label.visible = enabled
	if enabled:
		fps_label.text = "FPS: %d" % Engine.get_frames_per_second()

func _on_play_again_pressed() -> void:
	get_tree().paused = false
	LevelManager.restart_current_level()

func _on_next_level_pressed() -> void:
	get_tree().paused = false
	LevelManager.load_next_level()

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	LevelManager.go_to_main_menu()

func _unhandled_input(event: InputEvent) -> void:
	if not end_game_panel.visible:
		return

	if event.is_action_pressed("roar"):
		var viewport: Viewport = get_viewport()
		if viewport == null:
			return

		var focused_button := viewport.gui_get_focus_owner() as BaseButton
		if focused_button != null:
			focused_button.emit_signal("pressed")
