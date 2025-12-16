## MainMenu.gd
## Simple menu for selecting 1-player or 2-player mode.

extends Control

signal mode_selected(mode: String)

@export var one_player_button_path: NodePath = NodePath("VBoxContainer/OnePlayerButton")
@export var two_player_button_path: NodePath = NodePath("VBoxContainer/TwoPlayerButton")

var _one_player_button: Button
var _two_player_button: Button

func _ready() -> void:
	_one_player_button = get_node_or_null(one_player_button_path)
	_two_player_button = get_node_or_null(two_player_button_path)
	
	if _one_player_button:
		_one_player_button.pressed.connect(_on_one_player_pressed)
	if _two_player_button:
		_two_player_button.pressed.connect(_on_two_player_pressed)


func _on_one_player_pressed() -> void:
	mode_selected.emit("1-player")


func _on_two_player_pressed() -> void:
	mode_selected.emit("2-player")
