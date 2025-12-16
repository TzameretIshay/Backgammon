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
@export var doubling_cube_path: NodePath = NodePath("DoublingCubeUI")
@export var tutorial_overlay_path: NodePath = NodePath("TutorialOverlay")
@export var settings_popup_path: NodePath = NodePath("SettingsPopup")
@export var ai_enabled: bool = false
@export var ai_player: int = BLACK
@export var ai_difficulty: String = "Medium"
@export var ai_move_delay: float = 0.35
@export var sfx_move: AudioStream
@export var sfx_roll: AudioStream
@export var undo_stack_limit: int = 20

var turn_state: TurnState = TurnState.WAITING_FOR_ROLL
var game_state: Dictionary = {}
var game_mode: String = "2-player"  # "1-player" or "2-player"

# Match play tracking
var match_length: int = 5  # Points to win the match
var match_score: Dictionary = {"white": 0, "black": 0}
var games_played: int = 0
var session_stats := {
	"games": 0,
	"white_wins": 0,
	"black_wins": 0,
	"gammons": 0,
	"backgammons": 0,
	"total_turns": 0,
	"longest_turns": 0
}

var _board: Node = null
var _dice_ui: Node = null
var _ui: Node = null
var _doubling_cube_ui: Node = null
var _doubling_cube: DoublingCube = null
var _move_history: MoveHistory = null
var _tutorial_overlay: Node = null
var _settings_popup: Node = null
var _sfx_player_move: AudioStreamPlayer
var _sfx_player_roll: AudioStreamPlayer
var _ai_pending := false
var _undo_stack: Array = []
var _turns_this_game: int = 0
var _settings := {
	"master_volume": 1.0,
	"sfx_volume": 1.0,
	"anim_speed": 1.0,
	"theme": "Classic"
}
const SAVE_PATH := "user://savegame.save"
const SETTINGS_PATH := "user://config.cfg"

func _ready() -> void:
	randomize()
	_resolve_children()
	_setup_sfx()
	_load_settings_config()
	_apply_settings_to_runtime()
	new_game()


# ----------------------------------------------------------------------------
# CHILD WIRING
# ----------------------------------------------------------------------------

func _resolve_children() -> void:
	_board = get_node_or_null(board_path)
	_dice_ui = get_node_or_null(dice_path)
	_ui = get_node_or_null(ui_path)
	_doubling_cube_ui = get_node_or_null(doubling_cube_path)
	_tutorial_overlay = get_node_or_null(tutorial_overlay_path)
	_settings_popup = get_node_or_null(settings_popup_path)

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
		if _ui.has_signal("tutorial_pressed"):
			_ui.connect("tutorial_pressed", Callable(self, "_start_tutorial"))
		if _ui.has_signal("save_pressed"):
			_ui.connect("save_pressed", Callable(self, "_on_save_pressed"))
		if _ui.has_signal("load_pressed"):
			_ui.connect("load_pressed", Callable(self, "_on_load_pressed"))
		if _ui.has_signal("settings_pressed"):
			_ui.connect("settings_pressed", Callable(self, "_show_settings"))
	if _doubling_cube_ui:
		if _doubling_cube_ui.has_signal("double_offered"):
			_doubling_cube_ui.connect("double_offered", Callable(self, "_on_double_offered"))
		if _doubling_cube_ui.has_signal("double_accepted"):
			_doubling_cube_ui.connect("double_accepted", Callable(self, "_on_double_accepted"))
		if _doubling_cube_ui.has_signal("double_declined"):
			_doubling_cube_ui.connect("double_declined", Callable(self, "_on_double_declined"))
	if _tutorial_overlay and _tutorial_overlay.has_signal("tutorial_closed"):
		_tutorial_overlay.connect("tutorial_closed", Callable(self, "_on_tutorial_closed"))
	if _settings_popup:
		if _settings_popup.has_signal("settings_applied"):
			_settings_popup.connect("settings_applied", Callable(self, "_on_settings_applied"))
		if _settings_popup.has_signal("settings_closed"):
			_settings_popup.connect("settings_closed", Callable(self, "_on_settings_closed"))
	
	# Create doubling cube
	_doubling_cube = DoublingCube.new()
	add_child(_doubling_cube)
	
	# Create move history
	_move_history = MoveHistory.new()
	add_child(_move_history)


func _setup_sfx() -> void:
	_sfx_player_move = AudioStreamPlayer.new()
	add_child(_sfx_player_move)
	_sfx_player_move.bus = "Master"
	_sfx_player_roll = AudioStreamPlayer.new()
	add_child(_sfx_player_roll)
	_sfx_player_roll.bus = "Master"


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		_save_game(false)


# ----------------------------------------------------------------------------
# GAME INITIALIZATION
# ----------------------------------------------------------------------------

func start_game_with_mode(mode: String, p_match_length: int = 5, p_ai_difficulty: String = "Medium") -> void:
	"""Start a new match with the specified mode and length."""
	game_mode = mode
	match_length = p_match_length
	ai_difficulty = p_ai_difficulty
	match_score = {"white": 0, "black": 0}
	games_played = 0
	
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
	_reset_undo_stack()
	_turns_this_game = 0
	
	# Reset doubling cube
	if _doubling_cube:
		_doubling_cube.reset()
		_update_cube_ui()
	
	# Reset move history
	if _move_history:
		_move_history.clear()
		_update_move_history()
	
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

	_reset_undo_stack()

	if values.size() == 2 and values[0] == values[1]:
		game_state["dice_values"] = [values[0], values[0], values[0], values[0]]
	else:
		game_state["dice_values"] = values

	game_state["remaining_moves"] = game_state["dice_values"].duplicate(true)
	_push_undo_state()
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

	_push_undo_state()
	var apply_result = MoveValidator.apply_move(game_state, {"from": from_point, "to": to_point, "die": die_used, "bear_off": BEAR_OFF})
	game_state = apply_result.state
	game_state["remaining_moves"].erase(die_used)
	turn_state = TurnState.SELECTING_MOVE

	move_applied.emit(from_point, to_point, game_state["current_player"], apply_result.hit_point)
	if apply_result.hit_point != -1:
		checker_hit.emit(apply_result.hit_point, MoveValidator.opponent(game_state["current_player"]))
	
	# Add move to history
	if _move_history:
		_move_history.add_move(from_point, to_point, game_state["current_player"], die_used)
		_update_move_history()
	
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
	_turns_this_game += 1
	game_state["dice_values"] = []
	game_state["remaining_moves"] = []
	_reset_undo_stack()
	turn_state = TurnState.WAITING_FOR_ROLL
	game_state["current_player"] = MoveValidator.opponent(game_state["current_player"])
	
	# Increment turn number in move history
	if _move_history:
		_move_history.end_turn()
	
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
		var mv = AI.choose_move(game_state, game_state.get("remaining_moves", []), BEAR_OFF, ai_difficulty)
		if mv.is_empty():
			await _wait_ai_pace()
			end_turn()
			break
		request_move(mv["from"], mv["to"])
		await _wait_for_board_animation()
		await _wait_ai_pace()


func undo_move() -> void:
	if _undo_stack.is_empty():
		push_warning("No move to undo.")
		return
	var prev_state: Dictionary = _undo_stack.pop_back()
	game_state = prev_state.duplicate(true)
	game_state["last_state"] = {}
	turn_state = TurnState.ROLLED_DICE if not game_state.get("remaining_moves", []).is_empty() else TurnState.WAITING_FOR_ROLL
	if _move_history:
		_move_history.pop_last_move()
		_update_move_history()
	_emit_state_changed()
	_update_legal_moves_display()
	if _ui and _ui.has_method("set_status"):
		_ui.set_status("Move undone. %s to play. Remaining dice: %s" % [_player_str(game_state["current_player"]), game_state.get("remaining_moves", [])])


# ----------------------------------------------------------------------------
# HELPERS
# ----------------------------------------------------------------------------

func _player_str(player: int) -> String:
	return "white" if player == WHITE else "black"


func _reset_undo_stack() -> void:
	_undo_stack.clear()
	game_state["last_state"] = {}


func _push_undo_state() -> void:
	var snapshot := game_state.duplicate(true)
	snapshot["last_state"] = {}
	_undo_stack.append(snapshot)
	if _undo_stack.size() > undo_stack_limit:
		_undo_stack.pop_front()
	game_state["last_state"] = snapshot


func _emit_state_changed(update_board: bool = true) -> void:
	if update_board and _board and _board.has_method("set_state"):
		_board.set_state(game_state)
	if _ui and _ui.has_method("update_state"):
		_ui.update_state(game_state)
	if _ui and _ui.has_method("update_match_score"):
		_ui.update_match_score(match_score["white"], match_score["black"], match_length)
	_update_stats_ui()
	_update_cube_ui()


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
	
	# Calculate points with cube multiplier and gammon/backgammon
	var base_multiplier = MoveValidator.calculate_win_multiplier(game_state, winner)
	var cube_value = _doubling_cube.get_cube_value() if _doubling_cube else 1
	var total_points = cube_value * base_multiplier
	var turns_used = max(1, _turns_this_game + 1)  # Include the winning turn
	
	var win_type = "Normal"
	if base_multiplier == 2:
		win_type = "Gammon"
	elif base_multiplier == 3:
		win_type = "Backgammon"
	
	# Add points to match score
	var winner_key = "white" if winner == WHITE else "black"
	match_score[winner_key] += total_points
	games_played += 1
	# Session stats
	session_stats["games"] += 1
	session_stats[winner_key + "_wins"] += 1
	session_stats["total_turns"] += turns_used
	session_stats["longest_turns"] = max(session_stats["longest_turns"], turns_used)
	if base_multiplier == 2:
		session_stats["gammons"] += 1
	elif base_multiplier == 3:
		session_stats["backgammons"] += 1
	
	game_won.emit(winner)
	
	# Check for match winner
	if match_score[winner_key] >= match_length:
		_match_won(winner)
	else:
		# Game won but match continues
		var white_score = match_score["white"]
		var black_score = match_score["black"]
		if _ui and _ui.has_method("set_status"):
			_ui.set_status("🏆 %s WINS %s! 🏆 (+%d pts) | Match: W:%d B:%d (to %d) | Click New Game" % [
				_player_str(winner).to_upper(), win_type, total_points,
				white_score, black_score, match_length
			])
	
	# Stop AI chain if running
	ai_enabled = false
	_emit_state_changed()


func _match_won(winner: int) -> void:
	"""Called when a player wins the entire match."""
	var white_score = match_score["white"]
	var black_score = match_score["black"]
	if _ui and _ui.has_method("set_status"):
		_ui.set_status("🎉🏆 %s WINS THE MATCH! 🏆🎉 | Final Score: W:%d B:%d | Games: %d" % [
			_player_str(winner).to_upper(),
			white_score, black_score, games_played
		])


# ----------------------------------------------------------------------------
# DOUBLING CUBE
# ----------------------------------------------------------------------------

func _update_cube_ui() -> void:
	if not _doubling_cube_ui:
		return
	var value = _doubling_cube.get_cube_value()
	var owner = _doubling_cube.get_owner_name()
	_doubling_cube_ui.update_display(value, owner)
	
	# Enable/disable double button based on current player and cube state
	var can_double = _doubling_cube.can_offer_cube(game_state["current_player"])
	_doubling_cube_ui.set_double_enabled(can_double, game_state["current_player"])


func _update_move_history() -> void:
	if not _ui or not _move_history:
		return
	if _ui.has_method("update_move_history"):
		var recent_moves = _move_history.get_recent_moves(10)
		_ui.update_move_history(recent_moves)


func _start_tutorial() -> void:
	if not _tutorial_overlay:
		return
	if _tutorial_overlay.has_method("restart"):
		_tutorial_overlay.call("restart")
		_tutorial_overlay.show()
	if _ui and _ui.has_method("set_status"):
		_ui.set_status("Tutorial: follow the steps or Skip/Replay.")


func _on_tutorial_closed() -> void:
	if _ui and _ui.has_method("set_status"):
		_ui.set_status("Tutorial closed. Continue playing.")


func _update_stats_ui() -> void:
	if not _ui or not _ui.has_method("update_stats"):
		return
	_ui.update_stats(session_stats)


# ----------------------------------------------------------------------------
# SETTINGS
# ----------------------------------------------------------------------------

func _show_settings() -> void:
	if _settings_popup and _settings_popup.has_method("show_with"):
		_settings_popup.call("show_with", _settings)


func _on_settings_applied(payload: Dictionary) -> void:
	_settings = payload.duplicate()
	_apply_settings_to_runtime()
	_save_settings_config()
	if _ui and _ui.has_method("set_status"):
		_ui.set_status("Settings applied.")


func _on_settings_closed() -> void:
	if _ui and _ui.has_method("set_status"):
		_ui.set_status("Settings closed.")


func _apply_settings_to_runtime() -> void:
	_apply_audio_settings()
	if _board and _board.has_method("set_animation_speed"):
		_board.call("set_animation_speed", _settings.get("anim_speed", 1.0))
	if _board and _board.has_method("apply_theme"):
		_board.call("apply_theme", _build_theme(_settings.get("theme", "Classic")))


func _apply_audio_settings() -> void:
	var master_v: float = clamp(_settings.get("master_volume", 1.0), 0.0, 1.0)
	var sfx_v: float = clamp(_settings.get("sfx_volume", 1.0), 0.0, 1.0)
	var combined = max(master_v * sfx_v, 0.001)
	var db = linear_to_db(combined)
	if _sfx_player_move:
		_sfx_player_move.volume_db = db
	if _sfx_player_roll:
		_sfx_player_roll.volume_db = db


func _load_settings_config() -> void:
	var cfg = ConfigFile.new()
	var err = cfg.load(SETTINGS_PATH)
	if err == OK:
		_settings["master_volume"] = cfg.get_value("audio", "master_volume", 1.0)
		_settings["sfx_volume"] = cfg.get_value("audio", "sfx_volume", 1.0)
		_settings["anim_speed"] = cfg.get_value("display", "anim_speed", 1.0)
		_settings["theme"] = cfg.get_value("display", "theme", "Classic")


func _save_settings_config() -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("audio", "master_volume", _settings.get("master_volume", 1.0))
	cfg.set_value("audio", "sfx_volume", _settings.get("sfx_volume", 1.0))
	cfg.set_value("display", "anim_speed", _settings.get("anim_speed", 1.0))
	cfg.set_value("display", "theme", _settings.get("theme", "Classic"))
	cfg.save(SETTINGS_PATH)


func _build_theme(name: String) -> Dictionary:
	match name:
		"Dark":
			return {
				"board_bg": Color(0.12, 0.12, 0.14),
				"play_area": Color(0.25, 0.3, 0.35),
				"point_a": Color(0.6, 0.35, 0.2),
				"point_b": Color(0.85, 0.7, 0.4),
				"bar": Color(0.3, 0.3, 0.32, 0.4),
				"bearoff": Color(0.18, 0.45, 0.2, 0.3),
				"highlight": Color(0.15, 0.9, 0.9, 0.85)
			}
		"Ocean":
			return {
				"board_bg": Color(0.15, 0.2, 0.3),
				"play_area": Color(0.35, 0.5, 0.7),
				"point_a": Color(0.9, 0.6, 0.25),
				"point_b": Color(0.95, 0.85, 0.55),
				"bar": Color(0.2, 0.25, 0.35, 0.35),
				"bearoff": Color(0.25, 0.7, 0.35, 0.3),
				"highlight": Color(0.05, 0.95, 0.85, 0.9)
			}
		_:
			return {
				"board_bg": Color(0.2, 0.25, 0.35),
				"play_area": Color(0.5, 0.6, 0.75),
				"point_a": Color(0.72, 0.48, 0.28),
				"point_b": Color(0.9, 0.7, 0.45),
				"bar": Color(0.25, 0.25, 0.3, 0.3),
				"bearoff": Color(0.2, 0.6, 0.2, 0.25),
				"highlight": Color(0.0, 1.0, 1.0, 0.8)
			}


func _on_double_offered(player: int) -> void:
	if _doubling_cube.offer_double(player):
		var new_value = _doubling_cube.get_cube_value() * 2
		var opponent_player = BLACK if player == WHITE else WHITE
		
		# If opponent is AI, auto-decide based on pip count (simplified)
		if ai_enabled and opponent_player == ai_player:
			await get_tree().create_timer(0.5).timeout
			var white_pips = MoveValidator.calculate_pip_count(game_state, WHITE)
			var black_pips = MoveValidator.calculate_pip_count(game_state, BLACK)
			var pip_diff = white_pips - black_pips
			
			# AI accepts if ahead by 20+ pips or within 30 pips
			var should_accept = false
			if opponent_player == WHITE:
				should_accept = pip_diff < 30  # White accepts if not too far behind
			else:
				should_accept = -pip_diff < 30  # Black accepts if not too far behind
			
			if should_accept:
				_on_double_accepted()
			else:
				_on_double_declined()
		else:
			# Show dialog for human player
			_doubling_cube_ui.show_offer_dialog(_player_str(player), new_value)


func _on_double_accepted() -> void:
	var opponent = BLACK if game_state["current_player"] == WHITE else WHITE
	_doubling_cube.accept_double(opponent)
	_update_cube_ui()
	if _ui and _ui.has_method("set_status"):
		_ui.set_status("%s accepted the double. Stakes now: %d" % [_player_str(opponent), _doubling_cube.get_cube_value()])


func _on_double_declined() -> void:
	_doubling_cube.decline_double()
	# Offering player wins by forfeit
	var winner = game_state["current_player"]
	var cube_value = _doubling_cube.get_cube_value()
	_game_won(winner)
	if _ui and _ui.has_method("set_status"):
		_ui.set_status("🏆 %s WINS by forfeit! 🏆 (%d points)" % [_player_str(winner).to_upper(), cube_value])


# ----------------------------------------------------------------------------
# SAVE / LOAD
# ----------------------------------------------------------------------------

func _on_save_pressed() -> void:
	_save_game(true)


func _on_load_pressed() -> void:
	_load_game(true)


func _save_game(manual: bool) -> void:
	var data = {
		"game_state": game_state,
		"turn_state": turn_state,
		"match_score": match_score,
		"match_length": match_length,
		"games_played": games_played,
		"session_stats": session_stats,
		"cube": {
			"value": _doubling_cube.get_cube_value() if _doubling_cube else 1,
			"owner": _doubling_cube.cube_owner if _doubling_cube else 2,
			"is_offered": _doubling_cube.is_offered if _doubling_cube else false,
			"offering_player": _doubling_cube.offering_player if _doubling_cube else -1
		},
		"move_history": {
			"moves": _move_history.moves if _move_history else [],
			"turn_number": _move_history.turn_number if _move_history else 1
		},
		"ai": {
			"enabled": ai_enabled,
			"player": ai_player,
			"difficulty": ai_difficulty
		},
		"settings": _settings
	}
	var fa = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if fa:
		fa.store_string(JSON.stringify(data))
		fa.close()
		if manual and _ui and _ui.has_method("set_status"):
			_ui.set_status("Game saved.")
	elif manual:
		push_warning("Could not save game to %s" % SAVE_PATH)


func _load_game(manual: bool) -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		if manual and _ui and _ui.has_method("set_status"):
			_ui.set_status("No save file found.")
		return
	var fa = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if fa == null:
		push_warning("Failed to open save file.")
		return
	var txt = fa.get_as_text()
	fa.close()
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Invalid save data.")
		return
	var data: Dictionary = parsed
	# Restore primitives
	game_state = data.get("game_state", game_state)
	turn_state = data.get("turn_state", turn_state)
	match_score = data.get("match_score", match_score)
	match_length = data.get("match_length", match_length)
	games_played = data.get("games_played", games_played)
	session_stats = data.get("session_stats", session_stats)
	var cube_data: Dictionary = data.get("cube", {})
	if _doubling_cube:
		_doubling_cube.current_value = cube_data.get("value", 1)
		_doubling_cube.cube_owner = cube_data.get("owner", 2)
		_doubling_cube.is_offered = cube_data.get("is_offered", false)
		_doubling_cube.offering_player = cube_data.get("offering_player", -1)
	var mh: Dictionary = data.get("move_history", {})
	if _move_history:
		_move_history.set_state(mh.get("moves", []), mh.get("turn_number", 1))
	var ai_data: Dictionary = data.get("ai", {})
	ai_enabled = ai_data.get("enabled", ai_enabled)
	ai_player = ai_data.get("player", ai_player)
	ai_difficulty = ai_data.get("difficulty", ai_difficulty)
	_settings = data.get("settings", _settings)
	_apply_settings_to_runtime()
	_reset_undo_stack()
	_update_move_history()
	_update_cube_ui()
	_emit_state_changed()
	_update_legal_moves_display()
	if manual and _ui and _ui.has_method("set_status"):
		_ui.set_status("Game loaded.")


# Debug helper to print state
func debug_print() -> void:
	print(game_state)
