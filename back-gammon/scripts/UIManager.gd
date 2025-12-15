## UIManager.gd
## Manages the UI for the Backgammon game.
## 
## Responsibilities:
## - Handle button clicks (New Game, Roll Dice, End Turn, Undo, Reset)
## - Display legal moves as clickable list items
## - Update status labels with game info
## - Handle move selection from UI list

extends Control

# References
@onready var game_manager: Node = get_tree().root.get_node("Main")
@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var new_game_btn: Button = $VBoxContainer/NewGameBtn
@onready var roll_dice_btn: Button = $VBoxContainer/RollDiceBtn
@onready var end_turn_btn: Button = $VBoxContainer/EndTurnBtn
@onready var undo_btn: Button = $VBoxContainer/UndoBtn
@onready var reset_btn: Button = $VBoxContainer/ResetBtn
@onready var dice_result_label: Label = $VBoxContainer/DiceResultLabel
@onready var legal_moves_label: Label = $VBoxContainer/LegalMovesLabel
@onready var legal_moves_list: ItemList = $VBoxContainer/LegalMovesList

# State
var legal_moves: Array = []
var selected_from_point: int = -1

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	"""Connect UI signals."""
	print("UIManager ready.")
	
	# Connect button signals
	new_game_btn.pressed.connect(_on_new_game_pressed)
	roll_dice_btn.pressed.connect(_on_roll_dice_pressed)
	end_turn_btn.pressed.connect(_on_end_turn_pressed)
	undo_btn.pressed.connect(_on_undo_pressed)
	reset_btn.pressed.connect(_on_reset_pressed)
	legal_moves_list.item_activated.connect(_on_move_selected)
	
	# Connect to GameManager signals
	if game_manager:
		game_manager.game_started.connect(_on_game_started)
		game_manager.dice_rolled.connect(_on_dice_rolled)
		game_manager.move_applied.connect(_on_move_applied)
		game_manager.turn_ended.connect(_on_turn_ended)
		game_manager.game_won.connect(_on_game_won)


# ============================================================================
# BUTTON HANDLERS
# ============================================================================

func _on_new_game_pressed() -> void:
	"""Start a new game."""
	print("New Game button pressed.")
	print("GameManager: ", game_manager)
	print("Calling new_game()...")
	game_manager.new_game()
	print("new_game() returned.")
	_update_ui()


func _on_roll_dice_pressed() -> void:
	"""Roll the dice."""
	print("Roll Dice button pressed.")
	
	# Check if in opening roll phase
	if game_manager.turn_state == game_manager.TurnState.OPENING_ROLL:
		var roll_val = game_manager.roll_opening_dice()
		var player_name = "White" if game_manager.game_state["current_player"] == 0 else "Black"
		dice_result_label.text = "Opening roll (%s): %d" % [player_name, roll_val]
	else:
		game_manager.roll_dice_auto()
	
	_update_legal_moves()
	_update_buttons()


func _on_end_turn_pressed() -> void:
	"""End the current turn."""
	print("End Turn button pressed.")
	game_manager.end_turn()
	_update_ui()


func _on_undo_pressed() -> void:
	"""Undo the last move."""
	print("Undo button pressed.")
	game_manager.undo_move()
	_update_ui()


func _on_reset_pressed() -> void:
	"""Reset the game."""
	print("Reset button pressed.")
	game_manager.reset()
	_update_ui()


# ============================================================================
# MOVE SELECTION
# ============================================================================

func _on_move_selected(index: int) -> void:
	"""Handle move selection from the legal moves list."""
	if index < 0 or index >= legal_moves.size():
		return
	
	var move = legal_moves[index]
	var from_point = move[0]
	var to_point = move[1]
	
	print("Move selected: %d → %d" % [from_point, to_point])
	game_manager.request_move(from_point, to_point)
	_update_ui()


# ============================================================================
# UI UPDATES
# ============================================================================

func _update_ui() -> void:
	"""Update all UI elements."""
	_update_status()
	_update_legal_moves()
	_update_buttons()


func _update_status() -> void:
	"""Update the status label."""
	var state = game_manager.get_game_state()
	if state.is_empty():
		status_label.text = "Game not initialized"
		return
	
	var player_name = "White" if state["current_player"] == 0 else "Black"
	var turn_state_name = game_manager.TurnState.keys()[game_manager.turn_state]
	
	status_label.text = "Player: " + player_name + " | State: " + turn_state_name + " | Moves: " + str(state["remaining_moves"])


func _update_legal_moves() -> void:
	"""Update the legal moves list."""
	legal_moves = game_manager.get_legal_moves()
	
	legal_moves_list.clear()
	
	if legal_moves.is_empty():
		legal_moves_label.text = "Legal moves: (none)"
		return
	
	legal_moves_label.text = "Legal moves: (%d available)" % legal_moves.size()
	
	for move in legal_moves:
		var from_point = move[0]
		var to_point = move[1]
		var die_used = _die_for_move(from_point, to_point)
		
		var from_str = "Bar" if from_point == -1 else "Point %d" % (from_point + 1)
		var to_str = "Point %d" % (to_point + 1) if to_point != 25 else "Bear Off"
		
		legal_moves_list.add_item(from_str + " → " + to_str + "  (die %d)" % die_used)


func _die_for_move(from_point: int, to_point: int) -> int:
	"""Compute which die value this move would consume."""
	var player = game_manager.get_game_state().get("current_player", 0)
	if from_point == -1:
		return 24 - to_point if player == 0 else to_point + 1
	if to_point == 25:
		return from_point + 1 if player == 0 else 24 - from_point
	return from_point - to_point if player == 0 else to_point - from_point


func _update_buttons() -> void:
	"""Enable/disable buttons based on game state."""
	var state = game_manager.get_game_state()
	var turn_state = game_manager.turn_state
	
	if state.is_empty():
		new_game_btn.disabled = false
		roll_dice_btn.disabled = true
		end_turn_btn.disabled = true
		return
	
	# New Game always available
	new_game_btn.disabled = false
	
	# Roll Dice: enabled in OPENING_ROLL and WAITING_FOR_ROLL states
	roll_dice_btn.disabled = (turn_state != game_manager.TurnState.WAITING_FOR_ROLL and 
							   turn_state != game_manager.TurnState.OPENING_ROLL)
	
	# End Turn: available if no more moves or no legal moves remain
	end_turn_btn.disabled = not state["remaining_moves"].is_empty() or turn_state == game_manager.TurnState.WAITING_FOR_ROLL
	
	# Undo always available (GameManager will validate)
	undo_btn.disabled = false
	
	# Reset always available
	reset_btn.disabled = false


# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_game_started(state: Dictionary) -> void:
	"""Update when game starts."""
	print("Game started signal received.")
	# Show opening roll results if available
	if state.has("opening_rolls") and state["opening_rolls"].size() == 2:
		var white_roll = state["opening_rolls"].get("white", 0)
		var black_roll = state["opening_rolls"].get("black", 0)
		var winner_name = "White" if state["current_player"] == 0 else "Black"
		dice_result_label.text = "Opening: W:%d B:%d | %s starts!" % [white_roll, black_roll, winner_name]
	_update_ui()


func _on_dice_rolled(values: Array) -> void:
	"""Update when dice are rolled."""
	var values_str = ", ".join(values.map(func(v): return str(v)))
	dice_result_label.text = "Roll result: [%s]" % values_str
	_update_ui()


func _on_move_applied(from: int, to: int, color: int) -> void:
	"""Update when move is applied."""
	print("Move applied signal received: %d → %d" % [from, to])
	_update_ui()


func _on_turn_ended(next_player: int) -> void:
	"""Update when turn ends."""
	print("Turn ended signal received. Next player: %d" % next_player)
	_update_ui()


func _on_game_won(winner: int) -> void:
	"""Update when game is won."""
	var winner_name = "White" if winner == 0 else "Black"
	status_label.text = "GAME OVER! %s wins!" % winner_name
	print("Game won signal received. Winner: %s" % winner_name)
