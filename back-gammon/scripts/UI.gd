## UI.gd
## Basic HUD: status text, buttons, legal moves list.

extends Control

signal new_game_pressed
signal end_turn_pressed
signal undo_pressed
signal tutorial_pressed
signal save_pressed
signal load_pressed
signal settings_pressed
signal return_to_menu_pressed
signal return_to_menu_confirmed

@onready var status_label: Label = $ScrollContainer/VBox/StatusLabel
@onready var player_label: Label = $ScrollContainer/VBox/PlayerLabel
@onready var roll_label: Label = $ScrollContainer/VBox/RollLabel
@onready var pip_count_label: Label = $ScrollContainer/VBox/PipCountLabel
@onready var match_score_label: Label = $ScrollContainer/VBox/MatchScoreLabel
@onready var history_list: ItemList = $ScrollContainer/VBox/MoveHistoryList
@onready var moves_list: ItemList = $ScrollContainer/VBox/LegalMoves
@onready var new_game_btn: Button = $ScrollContainer/VBox/NewGameBtn
@onready var end_turn_btn: Button = $ScrollContainer/VBox/EndTurnBtn
@onready var undo_btn: Button = $ScrollContainer/VBox/UndoBtn
@onready var tutorial_btn: Button = $ScrollContainer/VBox/TutorialBtn
@onready var save_btn: Button = $ScrollContainer/VBox/SaveBtn
@onready var load_btn: Button = $ScrollContainer/VBox/LoadBtn
@onready var settings_btn: Button = $ScrollContainer/VBox/SettingsBtn
@onready var return_to_menu_btn: Button = $ScrollContainer/VBox/ReturnToMenuBtn
@onready var forfeit_confirmation: ConfirmationDialog = $ForfeitConfirmation
@onready var stats_label: Label = $ScrollContainer/VBox/StatsLabel
@onready var stats_value: Label = $ScrollContainer/VBox/StatsValue

func _ready() -> void:
	if new_game_btn:
		new_game_btn.pressed.connect(func(): new_game_pressed.emit())
	if end_turn_btn:
		end_turn_btn.pressed.connect(func(): end_turn_pressed.emit())
	if undo_btn:
		undo_btn.pressed.connect(func(): undo_pressed.emit())
	if tutorial_btn:
		tutorial_btn.pressed.connect(func(): tutorial_pressed.emit())
	if save_btn:
		save_btn.pressed.connect(func(): save_pressed.emit())
	if load_btn:
		load_btn.pressed.connect(func(): load_pressed.emit())
	if settings_btn:
		settings_btn.pressed.connect(func(): settings_pressed.emit())
	if return_to_menu_btn:
		return_to_menu_btn.pressed.connect(_on_return_to_menu_pressed)
	if forfeit_confirmation:
		forfeit_confirmation.confirmed.connect(func(): return_to_menu_confirmed.emit())
	set_status("Welcome. Press New Game.")
	show_legal_moves([])
	update_stats({})


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
	
	# Update pip count
	if pip_count_label:
		var white_pips = MoveValidator.calculate_pip_count(state, MoveValidator.WHITE)
		var black_pips = MoveValidator.calculate_pip_count(state, MoveValidator.BLACK)
		var leader = ""
		if white_pips < black_pips:
			leader = " ✓"
		elif black_pips < white_pips:
			leader = ""
		pip_count_label.text = "Pip Count: White %d%s | Black %d%s" % [white_pips, " ✓" if white_pips < black_pips else "", black_pips, " ✓" if black_pips < white_pips else ""]


func update_match_score(white_score: int, black_score: int, match_length: int) -> void:
	if match_score_label:
		match_score_label.text = "Match: White %d | Black %d (to %d)" % [white_score, black_score, match_length]


func show_legal_moves(moves: Array) -> void:
	if moves_list == null:
		return
	moves_list.clear()
	for move in moves:
		var from_str = "bar" if move.get("from", -2) == -1 else str(move.get("from", "-"))
		var to_str = "off" if move.get("to", -2) == 24 else str(move.get("to", "-"))
		moves_list.add_item("%s -> %s (die %s)" % [from_str, to_str, move.get("die", "-")])


func update_move_history(moves: Array) -> void:
	"""Update move history display with recent moves."""
	if history_list == null:
		return
	history_list.clear()
	for move in moves:
		var player_str = "W" if move["player"] == 0 else "B"
		var turn_str = "T%d" % move["turn"]
		history_list.add_item("%s %s: %s" % [turn_str, player_str, move["notation"]])
	# Scroll to bottom
	if history_list.item_count > 0:
		history_list.ensure_current_is_visible()


func update_stats(stats: Dictionary) -> void:
	if stats_value == null:
		return
	var games: int = int(stats.get("games", 0))
	var white_wins: int = int(stats.get("white_wins", 0))
	var black_wins: int = int(stats.get("black_wins", 0))
	var gammons: int = int(stats.get("gammons", 0))
	var backgammons: int = int(stats.get("backgammons", 0))
	var total_turns: int = int(stats.get("total_turns", 0))
	var longest: int = int(stats.get("longest_turns", 0))
	var avg_turns: int = 0
	if games > 0:
		avg_turns = int(round(float(total_turns) / float(games)))
	stats_value.text = "Games %d | W %d / B %d | Gammon %d | Backgammon %d | Avg turns %d | Longest %d" % [
		games, white_wins, black_wins, gammons, backgammons, avg_turns, longest
	]


func _on_return_to_menu_pressed() -> void:
	"""Show forfeit confirmation dialog when return to menu is clicked."""
	if forfeit_confirmation:
		forfeit_confirmation.popup_centered_ratio(0.4)
