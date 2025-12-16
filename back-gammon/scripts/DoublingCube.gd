## DoublingCube.gd
## Manages the doubling cube state and logic for backgammon.

class_name DoublingCube extends Node

signal cube_offered(offering_player: int)
signal cube_accepted()
signal cube_declined()

enum Owner { NONE = -1, WHITE = 0, BLACK = 1, CENTER = 2 }

var current_value: int = 1  # 1, 2, 4, 8, 16, 32, 64
var cube_owner: int = Owner.CENTER  # Who can offer the cube
var is_offered: bool = false
var offering_player: int = -1

func _ready() -> void:
	reset()

func reset() -> void:
	"""Reset cube to starting state."""
	current_value = 1
	cube_owner = Owner.CENTER
	is_offered = false
	offering_player = -1

func can_offer_cube(player: int) -> bool:
	"""Check if a player can offer to double."""
	# Can offer if cube is in center or you own it
	# Cannot offer if already at max value (64)
	# Cannot offer if cube is already offered
	if is_offered:
		return false
	if current_value >= 64:
		return false
	if cube_owner == Owner.CENTER:
		return true
	return cube_owner == player

func offer_double(player: int) -> bool:
	"""Player offers to double the stakes."""
	if not can_offer_cube(player):
		return false
	
	is_offered = true
	offering_player = player
	cube_offered.emit(player)
	return true

func accept_double(accepting_player: int) -> void:
	"""Opponent accepts the double."""
	if not is_offered:
		return
	
	current_value *= 2
	cube_owner = accepting_player  # Acceptor now owns the cube
	is_offered = false
	offering_player = -1
	cube_accepted.emit()

func decline_double() -> void:
	"""Opponent declines - offering player wins the game."""
	if not is_offered:
		return
	
	is_offered = false
	cube_declined.emit()
	# Note: GameManager should handle ending game when declined

func get_cube_value() -> int:
	return current_value

func get_owner_name() -> String:
	match cube_owner:
		Owner.WHITE:
			return "White"
		Owner.BLACK:
			return "Black"
		Owner.CENTER:
			return "Center"
		_:
			return "None"
