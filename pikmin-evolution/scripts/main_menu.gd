extends Control

@onready var play_button: Button = $HBoxContainer/playButton
@onready var level_button: Button = $HBoxContainer/levelButton
@onready var settings_button: Button = $HBoxContainer/settingsButton
@onready var quit_button: Button = $HBoxContainer/quitButton

func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	level_button.pressed.connect(_on_level_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# Ensure controller/keyboard navigation always starts on a focused button.
	for button: Button in [play_button, level_button, settings_button, quit_button]:
		button.focus_mode = Control.FOCUS_ALL

	# Explicit focus chain for reliable left/right navigation.
	play_button.focus_neighbor_right = level_button.get_path()
	level_button.focus_neighbor_left = play_button.get_path()
	level_button.focus_neighbor_right = settings_button.get_path()
	settings_button.focus_neighbor_left = level_button.get_path()
	settings_button.focus_neighbor_right = quit_button.get_path()
	quit_button.focus_neighbor_left = settings_button.get_path()

	play_button.grab_focus()

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/world.tscn")

func _on_level_pressed() -> void:
	# Intentionally no-op for now.
	pass

func _on_settings_pressed() -> void:
	# Intentionally no-op for now.
	pass

func _on_quit_pressed() -> void:
	get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("roar"):
		var viewport: Viewport = get_viewport()
		if viewport == null:
			return

		var focused_button := viewport.gui_get_focus_owner() as BaseButton
		if focused_button != null:
			focused_button.emit_signal("pressed")
		return

	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
