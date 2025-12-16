## MoveHistory.gd
## Tracks and formats move history for backgammon.

class_name MoveHistory extends Node

var moves: Array = []  # Array of move dictionaries
var turn_number: int = 1
var max_history: int = 20

func _ready() -> void:
	clear()

func clear() -> void:
	moves.clear()
	turn_number = 1

func add_move(from_point: int, to_point: int, player: int, die_used: int) -> void:
	"""Add a move to history."""
	var move_notation = _format_move(from_point, to_point, player, die_used)
	var move_entry = {
		"turn": turn_number,
		"player": player,
		"notation": move_notation,
		"from": from_point,
		"to": to_point,
		"die": die_used
	}
	moves.append(move_entry)
	
	# Keep only recent history
	if moves.size() > max_history:
		moves.pop_front()

func end_turn() -> void:
	"""Increment turn number when turn ends."""
	turn_number += 1


func pop_last_move() -> void:
	"""Remove the most recent move (used for undo)."""
	if moves.size() == 0:
		return
	moves.pop_back()

func _format_move(from_point: int, to_point: int, player: int, die_used: int) -> String:
	"""Format move in backgammon notation."""
	var from_str = ""
	var to_str = ""
	
	# From point
	if from_point == -1:
		from_str = "bar"
	else:
		from_str = str(from_point + 1)  # Display as 1-24 instead of 0-23
	
	# To point
	if to_point == 24:  # Bearing off
		to_str = "off"
	else:
		to_str = str(to_point + 1)
	
	return "%s/%s" % [from_str, to_str]

func get_recent_moves(count: int = 10) -> Array:
	"""Get the most recent moves."""
	var recent = []
	var start_idx = max(0, moves.size() - count)
	for i in range(start_idx, moves.size()):
		recent.append(moves[i])
	return recent

func get_formatted_history() -> String:
	"""Get formatted history as multiline string."""
	var lines = []
	for move in moves:
		var player_str = "White" if move["player"] == 0 else "Black"
		lines.append("Turn %d - %s: %s" % [move["turn"], player_str, move["notation"]])
	return "\n".join(lines)


func set_state(new_moves: Array, new_turn: int) -> void:
	moves = new_moves.duplicate(true)
	turn_number = new_turn
