extends Node

const MAIN_MENU_SCENE := "res://scenes/MainMenu.tscn"
const LEVEL_SCENES: Array[String] = [
	"res://scenes/levels/level_01.tscn",
	"res://scenes/levels/level_02.tscn"
]

var selected_level_index: int = 0
var current_level_index: int = -1

func get_level_count() -> int:
	return LEVEL_SCENES.size()

func get_selected_level_index() -> int:
	return selected_level_index

func cycle_selected_level() -> int:
	if LEVEL_SCENES.is_empty():
		selected_level_index = 0
		return selected_level_index

	selected_level_index = (selected_level_index + 1) % LEVEL_SCENES.size()
	return selected_level_index

func load_level(index: int) -> void:
	if not _is_valid_level_index(index):
		push_warning("LevelManager: Invalid level index %d" % index)
		return

	selected_level_index = index
	current_level_index = index
	get_tree().change_scene_to_file(LEVEL_SCENES[index])

func load_selected_level() -> void:
	load_level(selected_level_index)

func load_next_level() -> bool:
	if current_level_index < 0:
		load_selected_level()
		return true

	var next_index := current_level_index + 1
	if not _is_valid_level_index(next_index):
		go_to_main_menu()
		return false

	load_level(next_index)
	return true

func restart_current_level() -> void:
	if _is_valid_level_index(current_level_index):
		load_level(current_level_index)
		return

	load_selected_level()

func go_to_main_menu() -> void:
	current_level_index = -1
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

func _is_valid_level_index(index: int) -> bool:
	return index >= 0 and index < LEVEL_SCENES.size()
