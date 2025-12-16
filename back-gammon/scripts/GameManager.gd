## GameManager.gd
## Central controller for Backgammon gameplay: state, turn flow, dice, moves, and win checks.
## The logic here is intentionally verbose with comments so Copilot (and humans) can extend it.

extends Node

const WHITE := 0
const BLACK := 1
const BEAR_OFF := 24  # Sentinel index meaning bearing off

const MoveValidator = preload("res://scripts/MoveValidator.gd")
const AI = preload("res://scripts/AI.gd")

signal game_started(state: Dictionary)
signal dice_rolled(values: Array[int])
signal move_applied(from_point: int, to_point: int, color: int, hit_point: int)
signal checker_hit(point: int, color: int)
signal turn_ended(next_player: int)
signal game_won(winner: int)
signal game_reset

enum TurnState { WAITING_FOR_ROLL, ROLLED_DICE, SELECTING_MOVE, GAME_OVER }

@export var board_path: NodePath = NodePath("Board")
@export var dice_path: NodePath = NodePath("DiceUI")
@export var ui_path: NodePath = NodePath("UI")
@export var ai_enabled: bool = false
@export var ai_player: int = BLACK
@export var ai_move_delay: float = 0.35
@export var sfx_move: AudioStream
@export var sfx_roll: AudioStream

var turn_state: TurnState = TurnState.WAITING_FOR_ROLL
var game_state: Dictionary = {}
var game_mode: String = "2-player"  # "1-player" or "2-player"

var _board: Node = null
var _dice_ui: Node = null
var _ui: Node = null
var _sfx_player_move: AudioStreamPlayer
var _sfx_player_roll: AudioStreamPlayer
var _ai_pending := false

func _ready() -> void:
	randomize()
	_resolve_children()
	_setup_sfx()
	new_game()


# ----------------------------------------------------------------------------
# CHILD WIRING
# ----------------------------------------------------------------------------

func _resolve_children() -> void:
	_board = get_node_or_null(board_path)
	_dice_ui = get_node_or_null(dice_path)
	_ui = get_node_or_null(ui_path)

	if _board and _board.has_signal("move_attempted"):
		_board.connect("move_attempted", Callable(self, "_on_board_move_attempt"))
	if _dice_ui and _dice_ui.has_signal("roll_pressed"):
		_dice_ui.connect("roll_pressed", Callable(self, "_on_roll_pressed"))
	if _ui:
		if _ui.has_signal("new_game_pressed"):
			_ui.connect("new_game_pressed", Callable(self, "new_game"))
		if _ui.has_signal("undo_pressed"):
			_ui.connect("undo_pressed", Callable(self, "undo_move"))
		if _ui.has_signal("end_turn_pressed"):
			_ui.connect("end_turn_pressed", Callable(self, "end_turn"))


func _setup_sfx() -> void:
	_sfx_player_move = AudioStreamPlayer.new()
	add_child(_sfx_player_move)
	_sfx_player_move.bus = "Master"
	_sfx_player_roll = AudioStreamPlayer.new()
	add_child(_sfx_player_roll)
	_sfx_player_roll.bus = "Master"


# ----------------------------------------------------------------------------
# GAME INITIALIZATION
# ----------------------------------------------------------------------------

func start_game_with_mode(mode: String) -> void:
	"""Start a new game with the specified mode (1-player or 2-player)."""
	game_mode = mode
	if mode == "1-player":
		ai_enabled = true
		ai_player = BLACK
	else:
		ai_enabled = false
	new_game()


func new_game() -> void:
	"""
	Initialize a fresh game with standard backgammon layout.
	State fields:
	- points: Array[24] of [count, color]
	- bar: {"white": int, "black": int}
	- bear_off: {"white": int, "black": int}
	- current_player: int (WHITE/BLACK)
	- dice_values: Array[int] (rolled dice, already expanded for doubles)
	- remaining_moves: Array[int] (dice not yet used this turn)
	- last_state: Dictionary (deep copy for undo)
	"""
	game_state = {
		"points": _init_standard_board(),
		"bar": {"white": 0, "black": 0},
		"bear_off": {"white": 0, "black": 0},
		"current_player": WHITE,
		"dice_values": [],
		"remaining_moves": [],
		"last_state": {}
	}
	turn_state = TurnState.WAITING_FOR_ROLL
	_emit_state_changed()
	game_started.emit(game_state)
	if _ui and _ui.has_method("set_status"):
		_ui.set_status("New game started. White to roll.")
	_maybe_trigger_ai()


func _init_standard_board() -> Array:
	"""Return 24-point starting layout using 0-indexed points.
	Standard backgammon starting position:
	- Point 0 (bottom-right): 2 White checkers
	- Point 5 (bottom): 5 Black checkers  
	- Point 7 (bottom): 3 Black checkers
	- Point 11 (bottom-left): 5 White checkers
	- Point 12 (top-left): 5 Black checkers
	- Point 16 (top): 3 White checkers
	- Point 18 (top): 5 White checkers
	- Point 23 (top-right): 2 Black checkers
	"""
	var points: Array = []
	for i in range(24):
		points.append([0, -1])

	# White checkers (moves counter-clockwise from 0 toward 23)
	points[23] = [2, WHITE]   # White's 1-point (home)
	points[12] = [5, WHITE]   # White's 12-point
	points[7] = [3, WHITE]    # White's 17-point
	points[5] = [5, WHITE]    # White's 19-point

	# Black checkers (moves clockwise from 23 toward 0)
	points[0] = [2, BLACK]    # Black's 1-point (home)
	points[11] = [5, BLACK]   # Black's 12-point
	points[16] = [3, BLACK]   # Black's 17-point
	points[18] = [5, BLACK]   # Black's 19-point
	return points


func reset() -> void:
	new_game()
	game_reset.emit()


# ----------------------------------------------------------------------------
# DICE FLOW
# ----------------------------------------------------------------------------

func _on_roll_pressed() -> void:
	await roll_dice_auto()


func roll_dice_auto() -> Array:
	return await roll_dice([randi_range(1, 6), randi_range(1, 6)])


func roll_dice(values: Array[int]) -> Array:
	return await _roll_dice_impl(values)


func _roll_dice_impl(values: Array[int]) -> Array:
	if turn_state == TurnState.GAME_OVER:
		push_warning("Game over. Start a new game.")
		return []
	if turn_state != TurnState.WAITING_FOR_ROLL:
		push_warning("Dice already rolled or moves pending.")
		return []

	if values.is_empty():
		values = [randi_range(1, 6), randi_range(1, 6)]

	if values.size() == 2 and values[0] == values[1]:
		game_state["dice_values"] = [values[0], values[0], values[0], values[0]]
	else:
		game_state["dice_values"] = values

	game_state["remaining_moves"] = game_state["dice_values"].duplicate(true)
	turn_state = TurnState.ROLLED_DICE
	dice_rolled.emit(game_state["dice_values"])
	if _dice_ui and _dice_ui.has_method("set_result"):
		_dice_ui.set_result(game_state["dice_values"])
	if _ui and _ui.has_method("set_status"):
		_ui.set_status("%s rolled %s" % [_player_str(game_state["current_player"]), game_state["dice_values"]])
	if _sfx_player_roll and sfx_roll:
		_sfx_player_roll.stream = sfx_roll
		_sfx_player_roll.play()
	# Ensure Board/UI receive updated state so selection/highlights work
	_emit_state_changed()
	_update_legal_moves_display()
	
	# Auto-end turn if no legal moves exist (e.g., blocked on bar)
	if not MoveValidator.has_any_legal_move(game_state, game_state["remaining_moves"], BEAR_OFF):
		if _ui and _ui.has_method("set_status"):
			_ui.set_status("%s has no legal moves. Turn ending." % _player_str(game_state["current_player"]))
		await get_tree().create_timer(1.0).timeout
		end_turn()
	
	return game_state["dice_values"]


# ----------------------------------------------------------------------------
# MOVE FLOW
# ----------------------------------------------------------------------------

func _on_board_move_attempt(from_point: int, to_point: int) -> void:
	request_move(from_point, to_point)


func request_move(from_point: int, to_point: int) -> bool:
	if turn_state not in [TurnState.ROLLED_DICE, TurnState.SELECTING_MOVE]:
		push_warning("Not ready for moves. Roll dice first.")
		return false
	if game_state["remaining_moves"].is_empty():
		push_warning("No remaining moves.")
		return false

	var die_used = MoveValidator.is_legal_move(game_state, game_state["remaining_moves"], from_point, to_point, BEAR_OFF)
	if die_used == -1:
		push_warning("Illegal move: %d -> %d" % [from_point, to_point])
		return false

	game_state["last_state"] = game_state.duplicate(true)
	var apply_result = MoveValidator.apply_move(game_state, {"from": from_point, "to": to_point, "die": die_used, "bear_off": BEAR_OFF})
	game_state = apply_result.state
	game_state["remaining_moves"].erase(die_used)
	turn_state = TurnState.SELECTING_MOVE

	move_applied.emit(from_point, to_point, game_state["current_player"], apply_result.hit_point)
	if apply_result.hit_point != -1:
		checker_hit.emit(apply_result.hit_point, MoveValidator.opponent(game_state["current_player"]))
	if _sfx_player_move and sfx_move:
		_sfx_player_move.stream = sfx_move
		_sfx_player_move.play()
	_update_legal_moves_display()
	if _board and _board.has_method("play_move_animation"):
		_board.play_move_animation(from_point, to_point, game_state["current_player"], apply_result.hit_point, game_state.duplicate(true))
		_emit_state_changed(false)  # UI only; board updates after animation
	else:
		_emit_state_changed()

	if game_state["bear_off"][_player_str(game_state["current_player"])] >= 15:
		_game_won(game_state["current_player"])
		return true

	if game_state["remaining_moves"].is_empty() or not MoveValidator.has_any_legal_move(game_state, game_state["remaining_moves"], BEAR_OFF):
		end_turn()
	return true


func end_turn() -> void:
	game_state["dice_values"] = []
	game_state["remaining_moves"] = []
	turn_state = TurnState.WAITING_FOR_ROLL
	game_state["current_player"] = MoveValidator.opponent(game_state["current_player"])
	_emit_state_changed()
	turn_ended.emit(game_state["current_player"])
	if _ui and _ui.has_method("set_status"):
		_ui.set_status("%s to roll." % _player_str(game_state["current_player"]))
	_maybe_trigger_ai()


func _maybe_trigger_ai() -> void:
	if not ai_enabled:
		return
	if turn_state == TurnState.GAME_OVER:
		return
	if game_state.get("current_player", WHITE) != ai_player:
		return
	if _ai_pending:
		return
	_ai_pending = true
	call_deferred("_run_ai_turn")


func _run_ai_turn() -> void:
	_ai_pending = false
	if turn_state != TurnState.WAITING_FOR_ROLL:
		return
	await _wait_ai_pace()
	await roll_dice_auto()
	await _wait_for_board_animation()
	await _wait_ai_pace()
	while turn_state in [TurnState.ROLLED_DICE, TurnState.SELECTING_MOVE]:
		var mv = AI.choose_move(game_state, game_state.get("remaining_moves", []), BEAR_OFF)
		if mv.is_empty():
			await _wait_ai_pace()
			end_turn()
			break
		request_move(mv["from"], mv["to"])
		await _wait_for_board_animation()
		await _wait_ai_pace()


func undo_move() -> void:
	if game_state.get("last_state", {}).is_empty():
		push_warning("No move to undo.")
		return
	game_state = game_state["last_state"].duplicate(true)
	turn_state = TurnState.ROLLED_DICE if not game_state["remaining_moves"].is_empty() else TurnState.WAITING_FOR_ROLL
	_emit_state_changed()
	_update_legal_moves_display()
	if _ui and _ui.has_method("set_status"):
		_ui.set_status("Move undone. %s to play." % _player_str(game_state["current_player"]))


# ----------------------------------------------------------------------------
# HELPERS
# ----------------------------------------------------------------------------

func _player_str(player: int) -> String:
	return "white" if player == WHITE else "black"


func _emit_state_changed(update_board: bool = true) -> void:
	if update_board and _board and _board.has_method("set_state"):
		_board.set_state(game_state)
	if _ui and _ui.has_method("update_state"):
		_ui.update_state(game_state)


func _update_legal_moves_display() -> void:
	if not _ui or not _ui.has_method("show_legal_moves"):
		return
	var moves = MoveValidator.compute_legal_moves(game_state, game_state["remaining_moves"], BEAR_OFF)
	_ui.show_legal_moves(moves)


func _wait_ai_pace() -> void:
	if ai_move_delay <= 0.0:
		return
	await get_tree().create_timer(ai_move_delay).timeout


func _wait_for_board_animation() -> void:
	if not _board or not _board.has_method("is_animating"):
		return
	var guard := 0
	while _board.is_animating() and guard < 240:
		guard += 1
		await get_tree().create_timer(0.05).timeout


func _game_won(winner: int) -> void:
	turn_state = TurnState.GAME_OVER
	game_state["remaining_moves"] = []
	game_state["dice_values"] = []
	game_won.emit(winner)
	if _ui and _ui.has_method("set_status"):
		_ui.set_status("🏆 %s WINS! 🏆 Click New Game to play again." % _player_str(winner).to_upper())
	# Stop AI chain if running
	ai_enabled = false
	_emit_state_changed()


# Debug helper to print state
func debug_print() -> void:
	print(game_state)
