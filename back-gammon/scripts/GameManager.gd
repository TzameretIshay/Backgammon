
## GameManager.gd
## Manages the overall game state, turn flow, and validation for a Backgammon game.
##
## This script is the central hub for game logic:
## - Maintains the current game board state (points, bar, bear-off counts).
## - Orchestrates turn flow: dice roll → legal move computation → move validation → turn end.
## - Emits signals for UI and board updates.
## - Provides undo/reset functionality.
##
## State Flow:
##   WaitingForRoll → RolledDice → SelectingMove → MovingChecker → TurnComplete → next player
##
## TODO: This is a scaffold. Full implementation will be generated with Copilot.

extends Node

# ============================================================================
# SIGNALS
# ============================================================================

## Emitted when a new game starts; passes the starting board state.
signal game_started(state: Dictionary)

## Emitted when the current player rolls the dice.
## Values: [d1, d2] or [d1, d1, d1, d1] if double.
signal dice_rolled(values: Array)

## Emitted when a move is successfully applied to the board.
signal move_applied(from: int, to: int, color: int)

## Emitted when a checker is hit (sent to bar).
signal checker_hit(point: int, color: int)

## Emitted when a turn ends; passes the next player (0=white, 1=black).
signal turn_ended(next_player: int)

## Emitted when a player wins; passes winner color (0=white, 1=black).
signal game_won(winner: int)

## Emitted when game state is reset.
signal game_reset

# ============================================================================
# STATE & DATA STRUCTURES
# ============================================================================

## Enum for turn states
enum TurnState { OPENING_ROLL, WAITING_FOR_ROLL, ROLLED_DICE, SELECTING_MOVE, ANIMATING_MOVE, TURN_COMPLETE }

## Current game state dictionary structure:
## {
##   "points": Array[Array[int]],  # 24 points; each point: [count, color] or list of colors
##   "bar": {"white": int, "black": int},  # Checkers on bar
##   "bear_off": {"white": int, "black": int},  # Checkers born off
##   "current_player": int,  # 0=white, 1=black
##   "dice_values": Array[int],  # [d1, d2] or [d1, d1, d1, d1] if double
##   "remaining_moves": Array[int],  # Die values not yet used
##   "last_state": Dictionary  # For undo functionality
## }
var game_state: Dictionary = {}

## Turn state machine
var turn_state: TurnState = TurnState.WAITING_FOR_ROLL

## Player colors (enum or int)
## 0 = White (moves 1 → 24)
## 1 = Black (moves 24 → 1)
var white_player: int = 0
var black_player: int = 1

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	"""Initialize game on scene load."""
	print("GameManager ready. Call new_game() to start.")


# ============================================================================
# GAME INITIALIZATION
# ============================================================================

## Creates a new game with standard backgammon starting position.
## Board layout (per Wikipedia backgammon rules):
##   White checkers (2): point 24
##   White checkers (5): point 13
##   White checkers (3): point 8
##   White checkers (5): point 6
##   (symmetric for Black, reversed points)
func new_game() -> void:
	"""Initialize a new backgammon game with standard starting position."""
	print("Starting new backgammon game...")
	
	# Initialize board: 24 points, each initially empty
	game_state = {
		"points": _init_standard_board(),
		"bar": {"white": 0, "black": 0},
		"bear_off": {"white": 0, "black": 0},
		"current_player": white_player,  # White goes first
		"dice_values": [],
		"remaining_moves": [],
		"last_state": {},
		"opening_rolls": {}  # Track opening roll for each player
	}
	
	turn_state = TurnState.OPENING_ROLL
	game_started.emit(game_state)
	print("Game initialized. Both players must roll for opening.")


## Initializes the standard backgammon starting position.
## Returns: Array[Array[int]] of 24 points, each with [count, color]
## where color: 0=white, 1=black, -1=empty.
func _init_standard_board() -> Array:
	"""Initialize standard backgammon board layout."""
	var points = []
	for i in range(24):
		points.append([0, -1])  # All points start empty: [count, color]
	
	# Place starting checkers per standard rules
	# White (0): 2 on point 23, 5 on point 12, 3 on point 7, 5 on point 5
	# Black (1): 2 on point 0, 5 on point 11, 3 on point 16, 5 on point 18
	# (Using 0-indexed points)
	
	# White starting position
	points[23] = [2, white_player]  # 2 on point 24
	points[12] = [5, white_player]  # 5 on point 13
	points[7] = [3, white_player]   # 3 on point 8
	points[5] = [5, white_player]   # 5 on point 6
	
	# Black starting position (mirrored)
	points[0] = [2, black_player]   # 2 on point 1
	points[11] = [5, black_player]  # 5 on point 12
	points[16] = [3, black_player]  # 3 on point 17
	points[18] = [5, black_player]  # 5 on point 19
	
	return points


## Resets game state and turn.
func reset() -> void:
	"""Reset the game to initial state."""
	print("Resetting game...")
	new_game()
	game_reset.emit()


# ============================================================================
# TURN FLOW: ROLL DICE
# ============================================================================

## Handles opening roll sequence (each player rolls 1 die).
## Returns the die value rolled (1-6).
func roll_opening_dice() -> int:
	"""Roll a single die during opening roll phase."""
	if turn_state != TurnState.OPENING_ROLL:
		push_warning("Not in opening roll phase")
		return 0
	
	var roll = randi_range(1, 6)
	var player_color = _player_color(game_state["current_player"])
	
	if not game_state.has("opening_rolls"):
		game_state["opening_rolls"] = {}
	
	game_state["opening_rolls"][player_color] = roll
	print("Opening roll - ", player_color, ": ", roll)
	
	# Check if both players have rolled
	if game_state["opening_rolls"].size() == 2:
		var white_roll = game_state["opening_rolls"].get("white", 0)
		var black_roll = game_state["opening_rolls"].get("black", 0)
		
		if white_roll == black_roll:
			# Reroll - reset and have same player roll again
			print("Opening rolls tied! Both players must reroll.")
			game_state["opening_rolls"] = {}
		else:
			# Determine winner and start game
			var winner = white_player if white_roll > black_roll else black_player
			game_state["current_player"] = winner
			print("Opening roll winner: ", _player_color(winner), " with ", max(white_roll, black_roll))
			# Transition to normal play: winner now rolls their two dice to start
			game_state["dice_values"] = []
			game_state["remaining_moves"] = []
			turn_state = TurnState.WAITING_FOR_ROLL
	else:
		# Switch to other player for their opening roll
		game_state["current_player"] = black_player if game_state["current_player"] == white_player else white_player
		turn_state = TurnState.OPENING_ROLL
	
	return roll


# ============================================================================
# TURN FLOW: ROLL DICE
# ============================================================================

## Generates and rolls the dice for the current player.
## Returns the array of die values rolled.
func roll_dice_auto() -> Array:
	"""
	Generate a random dice roll.
	Returns [d1, d2] normally, or [value, value, value, value] if double.
	"""
	return roll_dice([randi_range(1, 6), randi_range(1, 6)])


## Called when the current player rolls the dice.
## Computes legal moves and transitions to move selection.
func roll_dice(values: Array) -> Array:
	"""
	Handle a dice roll event. Triggers legal move computation.
	
	Args:
		values: Array of die values, e.g., [3, 5] or pass empty array to auto-generate.
	
	Returns:
		The actual die values rolled.
	"""
	if turn_state != TurnState.WAITING_FOR_ROLL:
		push_warning("Dice already rolled; cannot roll again this turn.")
		return []
	
	# Auto-generate if no values provided
	if values.is_empty():
		values = [randi_range(1, 6), randi_range(1, 6)]
	
	print("Dice rolled: ", values, " by player ", game_state["current_player"])
	
	# Check for double: same value on both dice
	if values.size() == 2 and values[0] == values[1]:
		# Double: player gets four moves of that value
		game_state["dice_values"] = [values[0], values[0], values[0], values[0]]
		print("Double rolled! Player gets 4 moves of ", values[0])
	else:
		game_state["dice_values"] = values
	
	game_state["remaining_moves"] = game_state["dice_values"].duplicate()
	turn_state = TurnState.ROLLED_DICE
	
	dice_rolled.emit(game_state["dice_values"])
	print("Remaining moves: ", game_state["remaining_moves"])
	
	return game_state["dice_values"]


# ============================================================================
# TURN FLOW: MOVE SELECTION & APPLICATION
# ============================================================================

## Called when a checker is dragged and dropped on a destination point.
## Validates the move, applies it, and updates remaining moves.
func request_move(from_point: int, to_point: int) -> bool:
	"""
	Request to move a checker from one point to another.
	Validates legality, applies the move, and emits signals.
	
	Args:
		from_point: Source point index (0-23) or -1 for bar.
		to_point: Destination point index (0-23) or 25 for bear-off.
	
	Returns:
		True if move was legal and applied; False otherwise.
	"""
	if turn_state not in [TurnState.ROLLED_DICE, TurnState.SELECTING_MOVE]:
		push_warning("Not in a state to make moves.")
		return false
	
	if game_state["remaining_moves"].is_empty():
		push_warning("No remaining moves available.")
		return false
	
	# TODO: Call MoveValidator.validate_move(game_state, from_point, to_point, remaining_moves)
	# For now, placeholder validation
	var is_valid = _validate_move_placeholder(from_point, to_point)
	
	if not is_valid:
		push_warning("Move from %d to %d is not legal." % [from_point, to_point])
		return false
	
	# Save state for undo
	game_state["last_state"] = game_state.duplicate(true)
	
	# Apply move: update board, bar, bear-off
	_apply_move(from_point, to_point)
	
	move_applied.emit(from_point, to_point, game_state["current_player"])
	print("Move applied: ", from_point, " → ", to_point)
	
	turn_state = TurnState.SELECTING_MOVE
	
	# Check for win condition
	if game_state["bear_off"][_player_color(game_state["current_player"])] == 15:
		_end_game(game_state["current_player"])
		return true
	
	# If no more moves, end turn
	if game_state["remaining_moves"].is_empty():
		end_turn()
	
	return true


## Placeholder validation. Will be replaced by MoveValidator.gd.
func _validate_move_placeholder(from_point: int, to_point: int) -> bool:
	"""
	Validate a move according to backgammon rules.
	
	Rules:
	1. Must re-enter from bar before moving other checkers
	2. Cannot land on point with 2+ enemy checkers
	3. Can only bear off when all home checkers are in home board
	4. Movement direction depends on color
	5. Distance moved must match an unused die value
	"""
	var player = game_state["current_player"]
	var player_color_str = _player_color(player)
	var enemy_color = black_player if player == white_player else white_player
	
	# Rule 1: Bar priority - if checkers on bar, must re-enter first
	if game_state["bar"][player_color_str] > 0:
		# Can only move from bar (-1)
		if from_point != -1:
			return false
		# Re-entry points depend on color
		if player == white_player:
			# White re-enters from opponent's home (points 18-23)
			return to_point >= 18 and to_point <= 23
		else:
			# Black re-enters from opponent's home (points 0-5)
			return to_point >= 0 and to_point <= 5

	# Special handling for bar re-entry distance/direction
	if from_point == -1:
		var distance_from_bar = (24 - to_point) if player == white_player else (to_point + 1)
		if distance_from_bar not in game_state["remaining_moves"]:
			return false
		# Rule 2: Cannot land on point with 2+ enemy checkers
		if to_point >= 0 and to_point < 24:
			var dest_point = game_state["points"][to_point]
			if dest_point[0] >= 2 and dest_point[1] == enemy_color:
				return false
		return true
	
	# Cannot move from bar if no checkers on bar
	if from_point == -1:
		return false
	
	# Check valid point index for regular moves
	if from_point < 0 or from_point >= 24:
		return false
	
	# Check if player has checkers on source point
	var source_point = game_state["points"][from_point]
	if source_point[0] == 0 or source_point[1] != player:
		return false
	
	# Calculate distance based on player color and direction
	var distance = 0
	if player == white_player:
		# White moves from 24 -> 1 (indices 23 down to 0)
		if to_point == 25:  # Bearing off from home board (0-5)
			distance = from_point + 1
		elif to_point >= 0 and to_point < 24:
			if to_point >= from_point:
				return false  # Wrong direction (must move toward lower indices)
			distance = from_point - to_point
		else:
			return false
	else:
		# Black moves from 1 -> 24 (indices 0 up to 23)
		if to_point == 25:  # Bearing off from home board (18-23)
			distance = 24 - from_point
		elif to_point >= 0 and to_point < 24:
			if to_point <= from_point:
				return false  # Wrong direction (must move toward higher indices)
			distance = to_point - from_point
		else:
			return false
	
	# Check if distance matches a remaining die value
	if distance not in game_state["remaining_moves"]:
		return false
	
	# Rule 2: Cannot land on point with 2+ enemy checkers
	if to_point >= 0 and to_point < 24:
		var dest_point = game_state["points"][to_point]
		if dest_point[0] >= 2 and dest_point[1] == enemy_color:
			return false
	
	# Rule 3: Bearing off - check if all home checkers are in home board
	if to_point == 25:
		if player == white_player:
			# White home board: points 0-5
			for i in range(6, 24):
				if game_state["points"][i][1] == player:
					return false
		else:
			# Black home board: points 18-23
			for i in range(18):
				if game_state["points"][i][1] == player:
					return false
	
	return true


## Applies a move to the game board.
## Updates points, bar, and bear-off counts; removes used die value.
func _apply_move(from_point: int, to_point: int) -> void:
	"""
	Apply a move to the board state.
	Handles removing checker from source, placing on destination,
	hitting enemy checkers, and updating bear-off.
	"""
	var player = game_state["current_player"]
	var player_color_str = _player_color(player)
	var enemy_color = black_player if player == white_player else white_player
	var enemy_color_str = _player_color(enemy_color)
	
	# Calculate distance to find matching die value
	var distance = 0
	if from_point == -1:
		distance = (24 - to_point) if player == white_player else (to_point + 1)
	elif player == white_player:
		if to_point == 25:
			distance = from_point + 1
		else:
			distance = from_point - to_point
	else:
		if to_point == 25:
			distance = 24 - from_point
		else:
			distance = to_point - from_point
	
	# Remove the used die value from remaining moves
	if distance in game_state["remaining_moves"]:
		game_state["remaining_moves"].erase(distance)
	
	# Remove checker from source
	if from_point == -1:
		# Re-entering from bar
		game_state["bar"][player_color_str] -= 1
	else:
		# Moving from a point
		var source = game_state["points"][from_point]
		source[0] -= 1
		if source[0] == 0:
			source[1] = -1  # Mark as empty
	
	# Place checker on destination
	if to_point == 25:
		# Bearing off
		game_state["bear_off"][player_color_str] += 1
	else:
		# Check if we're hitting an enemy checker
		var dest = game_state["points"][to_point]
		if dest[0] == 1 and dest[1] == enemy_color:
			# Hit! Send enemy checker to bar
			dest[0] = 0
			dest[1] = -1
			game_state["bar"][enemy_color_str] += 1
			checker_hit.emit(to_point, enemy_color)
		# Place mover's checker on destination
		dest[0] += 1
		dest[1] = player


## Converts player int to color string for key lookups.
func _player_color(player: int) -> String:
	"""Convert player int (0/1) to color string ('white'/'black')."""
	return "white" if player == white_player else "black"


# ============================================================================
# TURN MANAGEMENT
# ============================================================================

## Ends the current player's turn and switches to the opponent.
func end_turn() -> void:
	"""
	End the current turn and pass to the next player.
	In backgammon, a turn ends when:
	- All moves are used, or
	- No legal moves remain (forced end of turn)
	"""
	if not game_state["remaining_moves"].is_empty():
		if has_legal_moves():
			push_warning("Cannot end turn; legal moves remaining.")
			return
		else:
			# No legal moves left - forced end (acceptable)
			print("No legal moves available - ending turn.")
	
	print("Ending turn for player ", game_state["current_player"])
	
	# Switch player
	game_state["current_player"] = black_player if game_state["current_player"] == white_player else white_player
	game_state["dice_values"] = []
	game_state["remaining_moves"] = []
	turn_state = TurnState.WAITING_FOR_ROLL
	
	turn_ended.emit(game_state["current_player"])
	print("Turn passed to player ", game_state["current_player"], ". Waiting for roll.")


## Undoes the last move (reverts to saved game state).
func undo_move() -> void:
	"""Undo the last move if a saved state exists."""
	if game_state.has("last_state") and not game_state["last_state"].is_empty():
		game_state = game_state["last_state"]
		print("Move undone.")
		game_started.emit(game_state)  # Refresh UI
	else:
		push_warning("No move to undo.")


# ============================================================================
# WIN CONDITIONS & END GAME
# ============================================================================

## Detects and handles a player winning (all 15 checkers born off).
func _end_game(winner: int) -> void:
	"""End the game and declare a winner."""
	print("Player ", winner, " wins!")
	turn_state = TurnState.WAITING_FOR_ROLL  # Prevent further moves
	game_won.emit(winner)


# ============================================================================
# HELPERS & DEBUGGING
# ============================================================================

## Returns the count of checkers on a specific point.
func get_checkers_on_point(point: int) -> int:
	"""Get the number of checkers on a point. Returns 0 if empty."""
	if point < 0 or point >= 24:
		return 0
	return game_state["points"][point][0]


## Returns the owner color of a point (0=white, 1=black, -1=empty).
func get_point_color(point: int) -> int:
	"""Get the color occupying a point. Returns -1 if empty."""
	if point < 0 or point >= 24:
		return -1
	return game_state["points"][point][1]


## Returns all legal moves available from current position given remaining dice.
func get_legal_moves() -> Array:
	"""
	Compute all legal moves for the current player.
	Returns array of [from_point, to_point] pairs.
	"""
	var legal_moves = []
	var player = game_state["current_player"]
	var player_color_str = _player_color(player)
	
	# If checkers on bar, can only move from bar
	if game_state["bar"][player_color_str] > 0:
		for die_val in game_state["remaining_moves"]:
			var to_point = 0
			if player == white_player:
				to_point = 24 - die_val  # 23 -> 18
				to_point = clampi(to_point, 18, 23)
			else:
				to_point = die_val - 1   # 0 -> 5
				to_point = clampi(to_point, 0, 5)
			
			if _validate_move_placeholder(-1, to_point):
				legal_moves.append([-1, to_point])
		return legal_moves
	
	# Check all points for possible moves
	for from_point in range(24):
		if get_point_color(from_point) != player:
			continue  # Not our checker
		
		# Try each remaining die value
		for die_val in game_state["remaining_moves"]:
			var to_point = 0
			if player == white_player:
				to_point = from_point - die_val
				if to_point < 0:
					to_point = 25  # Bearing off
			else:
				to_point = from_point + die_val
				if to_point > 23:
					to_point = 25  # Bearing off
			
			if _validate_move_placeholder(from_point, to_point):
				legal_moves.append([from_point, to_point])
	
	return legal_moves


## Returns true if the current player has any legal moves available.
func has_legal_moves() -> bool:
	"""Check if current player has any valid moves."""
	return not get_legal_moves().is_empty()


## Counts total checkers for a player on the board (not in bear-off).
func count_active_checkers(player_color: int) -> int:
	"""Count active checkers for a player (excludes bear-off)."""
	var player_color_str = _player_color(player_color)
	var count = game_state["bar"][player_color_str]
	
	for point in game_state["points"]:
		if point[1] == player_color:
			count += point[0]
	
	return count


## Returns the current game state (for debugging and UI updates).
func get_game_state() -> Dictionary:
	"""Return the current game state."""
	return game_state


## Prints the current board state (debugging).
func debug_print_board() -> void:
	"""Print the current board to console for debugging."""
	print("=== BOARD STATE ===")
	print("Points: ", game_state["points"])
	print("Bar: ", game_state["bar"])
	print("Bear-off: ", game_state["bear_off"])
	print("Current player: ", game_state["current_player"])
	print("Remaining moves: ", game_state["remaining_moves"])
	print("===================")
