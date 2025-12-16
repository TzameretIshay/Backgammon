## MainMenu.gd
## Simple menu for selecting 1-player or 2-player mode and match length.

extends Control

signal mode_selected(mode: String, match_length: int, difficulty: String)

@export var one_player_button_path: NodePath = NodePath("VBoxContainer/OnePlayerButton")
@export var two_player_button_path: NodePath = NodePath("VBoxContainer/TwoPlayerButton")
@export var match_length_option_path: NodePath = NodePath("VBoxContainer/MatchLengthOption")
@export var difficulty_option_path: NodePath = NodePath("VBoxContainer/DifficultyOption")

var _one_player_button: Button
var _two_player_button: Button
var _match_length_option: OptionButton
var _difficulty_option: OptionButton

const MATCH_LENGTHS = [3, 5, 7, 11, 15, 21]
const DIFFICULTIES = ["Easy", "Medium", "Hard"]

func _ready() -> void:
	_one_player_button = get_node_or_null(one_player_button_path)
	_two_player_button = get_node_or_null(two_player_button_path)
	_match_length_option = get_node_or_null(match_length_option_path)
	_difficulty_option = get_node_or_null(difficulty_option_path)
	
	if _one_player_button:
		_one_player_button.pressed.connect(_on_one_player_pressed)
	if _two_player_button:
		_two_player_button.pressed.connect(_on_two_player_pressed)


func _get_selected_match_length() -> int:
	if _match_length_option:
		var idx = _match_length_option.selected
		return MATCH_LENGTHS[idx] if idx < MATCH_LENGTHS.size() else 5
	return 5  # Default to 5 points


func _get_selected_difficulty() -> String:
	if _difficulty_option:
		var idx = _difficulty_option.selected
		return DIFFICULTIES[idx] if idx < DIFFICULTIES.size() else "Medium"
	return "Medium"


func _on_one_player_pressed() -> void:
	mode_selected.emit("1-player", _get_selected_match_length(), _get_selected_difficulty())


func _on_two_player_pressed() -> void:
	mode_selected.emit("2-player", _get_selected_match_length(), _get_selected_difficulty())
