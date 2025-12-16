## UI.gd
## Basic HUD: status text, buttons, legal moves list.

extends Control

signal new_game_pressed
signal end_turn_pressed
signal undo_pressed

@onready var status_label: Label = $VBox/StatusLabel
@onready var player_label: Label = $VBox/PlayerLabel
@onready var roll_label: Label = $VBox/RollLabel
@onready var moves_list: ItemList = $VBox/LegalMoves
@onready var new_game_btn: Button = $VBox/NewGameBtn
@onready var end_turn_btn: Button = $VBox/EndTurnBtn
@onready var undo_btn: Button = $VBox/UndoBtn

func _ready() -> void:
	if new_game_btn:
		new_game_btn.pressed.connect(func(): new_game_pressed.emit())
	if end_turn_btn:
		end_turn_btn.pressed.connect(func(): end_turn_pressed.emit())
	if undo_btn:
		undo_btn.pressed.connect(func(): undo_pressed.emit())
	set_status("Welcome. Press New Game.")
	show_legal_moves([])


func set_status(text: String) -> void:
	if status_label:
		status_label.text = text


func update_state(state: Dictionary) -> void:
	# Optionally reflect dice/current player.
	if roll_label:
		roll_label.text = "Dice: %s" % str(state.get("dice_values", []))
	if player_label:
		var p = state.get("current_player", 0)
		player_label.text = "Player: %s" % ("White" if p == 0 else "Black")


func show_legal_moves(moves: Array) -> void:
	if moves_list == null:
		return
	moves_list.clear()
	for move in moves:
		moves_list.add_item("%s -> %s (die %s)" % [move.get("from", "-"), move.get("to", "-"), move.get("die", "-")])
