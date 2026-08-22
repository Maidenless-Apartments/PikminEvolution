extends Control

@onready var play_button: Button = $HBoxContainer/playButton
@onready var level_button: Button = $HBoxContainer/levelButton
@onready var settings_button: Button = $HBoxContainer/settingsButton
@onready var quit_button: Button = $HBoxContainer/quitButton
@onready var settings_backdrop: ColorRect = $SettingsBackdrop
@onready var settings_panel: PanelContainer = $SettingsPanel
@onready var debugger_checkbox: CheckBox = $SettingsPanel/MarginContainer/VBoxContainer/DebuggerCheckBox
@onready var settings_close_button: Button = $SettingsPanel/MarginContainer/VBoxContainer/CloseButton

func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	level_button.pressed.connect(_on_level_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	debugger_checkbox.toggled.connect(_on_debugger_toggled)
	settings_close_button.pressed.connect(_hide_settings_popup)

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

	settings_backdrop.visible = false
	settings_panel.visible = false
	debugger_checkbox.button_pressed = SettingsManager.debugger_enabled
	_update_level_button_text()
	play_button.grab_focus()

func _on_play_pressed() -> void:
	LevelManager.load_selected_level()

func _on_level_pressed() -> void:
	LevelManager.cycle_selected_level()
	_update_level_button_text()

func _on_settings_pressed() -> void:
	var show_settings := not settings_panel.visible
	settings_backdrop.visible = show_settings
	settings_panel.visible = show_settings
	if show_settings:
		debugger_checkbox.grab_focus()
	else:
		play_button.grab_focus()

func _hide_settings_popup() -> void:
	settings_backdrop.visible = false
	settings_panel.visible = false
	settings_button.grab_focus()

func _on_debugger_toggled(pressed: bool) -> void:
	SettingsManager.set_debugger_enabled(pressed)

func _on_quit_pressed() -> void:
	get_tree().quit()

func _update_level_button_text() -> void:
	var level_index := LevelManager.get_selected_level_index() + 1
	var level_count := LevelManager.get_level_count()
	level_button.text = "Level: %d / %d" % [level_index, level_count]

func _unhandled_input(event: InputEvent) -> void:
	if settings_panel.visible and event.is_action_pressed("ui_cancel"):
		_hide_settings_popup()
		get_viewport().set_input_as_handled()
		return

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
