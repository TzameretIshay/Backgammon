## BoardDisplay.gd
## Renders the backgammon board visually with proper layout and interactive move selection.
##
## Features:
## - Correct backgammon board layout (home/outer boards, bar in middle)
## - Click to select a checker and see available moves highlighted
## - Click a highlighted move to execute it
## - Real-time updates from GameManager signals

extends Node2D

# References
@onready var game_manager: Node = get_parent().get_parent()

# Display settings
var board_position: Vector2 = Vector2(420, 80)
var board_size: Vector2 = Vector2(700, 550)
var point_width: float = 30.0
var checker_radius: float = 12.0

# Point layout - standard backgammon layout
# Points 0-5: White's home board (right side, bottom)
# Points 6-11: White's outer board (middle-right, bottom)
# Points 12-17: Black's outer board (middle-left, top)
# Points 18-23: Black's home board (left side, top)
var point_positions: Array[Vector2] = []
var bar_position: Vector2 = Vector2.ZERO

# Game state cache
var game_state: Dictionary = {}
var bar_selected: bool = false  # Whether bar is the active selection

# Move selection state
var selected_point: int = -1  # Currently selected point (-1 = none)
var available_moves: Array = []  # Available destination points from selection

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	"""Initialize board display."""
	print("BoardDisplay ready.")
	print("Parent: ", get_parent())
	print("Parent's parent: ", get_parent().get_parent())
	_calculate_point_positions()
	
	# Connect to GameManager signals
	if game_manager:
		print("GameManager found, connecting signals...")
		game_manager.game_started.connect(_on_game_started)
		game_manager.move_applied.connect(_on_move_applied)
		game_manager.dice_rolled.connect(_on_dice_rolled)
		game_manager.turn_ended.connect(_on_turn_ended)
		game_manager.game_won.connect(_on_game_won)
	else:
		print("ERROR: GameManager not found!")


func _draw() -> void:
	"""Render board and checkers."""
	_draw_board()  # Always draw board
	_draw_points()  # Always draw points
	
	if not game_state.is_empty():
		_draw_available_moves()
		_draw_checkers()
		_draw_status()


func _input(event: InputEvent) -> void:
	"""Handle mouse clicks for move selection."""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Only consume clicks that land inside the board area so UI buttons keep working
		if _is_within_board(event.position):
			_handle_click(event.position)
			get_viewport().set_input_as_handled()


func _is_within_board(pos: Vector2) -> bool:
	"""Return true if the click is inside the board rectangle."""
	return Rect2(board_position, board_size).has_point(pos)


# ============================================================================
# POINT POSITION CALCULATION
# ============================================================================

func _calculate_point_positions() -> void:
	"""
	Calculate visual positions for all 24 backgammon points.
	
	Layout (proper backgammon):
	Top side (Black):
		Points 18-23: Black's home (top right)
		Points 12-17: Black's outer (top left)
	Bar in middle
	Bottom side (White):
		Points 6-11: White's outer (bottom left)
		Points 0-5: White's home (bottom right)
	"""
	point_positions.clear()
	
	var pt_width = point_width
	var spacing_x = board_size.x / 12.0

	# Bar position (middle of board)
	bar_position = board_position + Vector2(board_size.x / 2.0, board_size.y / 2.0)

	# Place bases near board edges so triangles/checkers live at top and bottom, not midline
	var edge_margin = 22.0
	var bottom_y = board_position.y + board_size.y - edge_margin
	var top_y = board_position.y + edge_margin
	
	# BOTTOM SIDE (White)
	# Points 0-5: White's home board (bottom right)
	for i in range(6):
		var x = board_position.x + board_size.x - (i + 0.5) * spacing_x
		point_positions.append(Vector2(x, bottom_y))
	
	# Points 6-11: White's outer board (bottom left)
	for i in range(6):
		var x = board_position.x + board_size.x * 0.5 - (i + 0.5) * spacing_x
		point_positions.append(Vector2(x, bottom_y))
	
	# TOP SIDE (Black) - mirrored
	# Points 12-17: Black's outer board (top left)
	for i in range(6):
		var x = board_position.x + (i + 0.5) * spacing_x
		point_positions.append(Vector2(x, top_y))
	
	# Points 18-23: Black's home board (top right)
	for i in range(6):
		var x = board_position.x + board_size.x * 0.5 + (i + 0.5) * spacing_x
		point_positions.append(Vector2(x, top_y))


# ============================================================================
# DRAWING
# ============================================================================

func _draw_board() -> void:
	"""Draw the board background."""
	# Fill with backgammon green
	draw_rect(Rect2(board_position, board_size), Color(0.2, 0.4, 0.2))
	draw_rect(Rect2(board_position, board_size), Color.BLACK, false, 3.0)
	
	# Draw bar in middle (divides left/right)
	var bar_x = board_position.x + board_size.x / 2.0
	draw_line(Vector2(bar_x, board_position.y), Vector2(bar_x, board_position.y + board_size.y), 
			  Color(0.8, 0.2, 0.2), 4.0)
	
	# Draw horizontal divider (home/outer board separator)
	var bar_y = board_position.y + board_size.y / 2.0
	draw_line(Vector2(board_position.x, bar_y), Vector2(board_position.x + board_size.x, bar_y),
			  Color.DARK_GRAY, 2.0)


func _draw_points() -> void:
	"""Draw visual point indicators on the board."""
	for i in range(24):
		if point_positions.size() <= i:
			continue
		
		var pos = point_positions[i]
		
		# Determine if point is in home (0-5, 18-23) or outer (6-11, 12-17)
		var is_home = (i < 6 or i >= 18)
		var is_top = i >= 12
		
		# Draw triangular point
		var height = 25.0 if is_home else 20.0
		var width = point_width
		
		# Base sits on the board edge; tip points toward board center
		var base_y = pos.y
		var tip_y = pos.y + (height if is_top else -height)
		var p1 = Vector2(pos.x - width / 2.0, base_y)
		var p2 = Vector2(pos.x + width / 2.0, base_y)
		var p3 = Vector2(pos.x, tip_y)
		
		# Alternate colors for clarity
		var color = Color(0.7, 0.5, 0.3) if i % 2 == 0 else Color(0.6, 0.4, 0.2)
		draw_colored_polygon([p1, p2, p3], color)
		
		# Draw point number for reference
		var num_str = str((i + 1) % 25)  # 1-24 numbering
		draw_string(ThemeDB.fallback_font, pos - Vector2(8, 4), num_str, 
			   HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color.WHITE)


func _draw_available_moves() -> void:
	"""Highlight available destination points for selected checker."""
	if selected_point == -1 or available_moves.is_empty():
		return
	
	# Highlight the source point
	if selected_point == -1:
		# Bar highlight
		var current = game_manager.get_game_state().get("current_player", 0)
		var bar_pos = bar_position - Vector2(40, 0) if current == 0 else bar_position + Vector2(40, 0)
		draw_circle(bar_pos, checker_radius + 6, Color.YELLOW, false, 3.0)
	elif selected_point >= 0 and selected_point < point_positions.size():
		draw_circle(point_positions[selected_point], checker_radius + 5, Color.YELLOW, false, 3.0)
	
	# Highlight available destination points
	for dest_point in available_moves:
		if dest_point == 25:  # Bear off
			# Draw indicator near top right
			draw_circle(board_position + Vector2(board_size.x - 30, 15), checker_radius + 3, 
					   Color(0.0, 1.0, 0.0), false, 2.0)
		elif dest_point >= 0 and dest_point < point_positions.size():
			draw_circle(point_positions[dest_point], checker_radius + 5, Color.GREEN, false, 2.0)


func _draw_checkers() -> void:
	"""Draw checkers on the board at correct positions."""
	if game_state.is_empty() or not game_state.has("points"):
		return
	
	# Draw checkers on points
	for point_idx in range(24):
		var point_data = game_state["points"][point_idx]
		var count = point_data[0]
		var color = point_data[1]
		
		if count == 0:
			continue
		
		var base_pos = point_positions[point_idx]
		var is_top = point_idx >= 12
		var stack_dir = 1 if is_top else -1  # Top stacks downward; bottom stacks upward into board
		
		# Draw stack of checkers
		for i in range(min(count, 6)):  # Limit stack display to 6
			var offset = Vector2(0, stack_dir * i * (checker_radius * 2.2))
			var checker_color = Color(0.5, 0.3, 0.1) if color == 1 else Color(0.7, 0.8, 0.9)
			draw_circle(base_pos + offset, checker_radius, checker_color)
			draw_circle(base_pos + offset, checker_radius, Color.WHITE, false, 1.5)
		
		# Show count if > 6
		if count > 6:
			draw_string(ThemeDB.fallback_font, base_pos + Vector2(-8, stack_dir * 30), "+" + str(count - 6),
				   HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color.WHITE)
	
	# Draw checkers on bar
	if game_state["bar"]["white"] > 0:
		var white_bar_pos = bar_position - Vector2(40, 0)
		for i in range(game_state["bar"]["white"]):
			draw_circle(white_bar_pos + Vector2(0, i * 30), checker_radius, Color(0.7, 0.8, 0.9))
			draw_circle(white_bar_pos + Vector2(0, i * 30), checker_radius, Color.WHITE, false, 1.5)
	
	if game_state["bar"]["black"] > 0:
		var black_bar_pos = bar_position + Vector2(40, 0)
		for i in range(game_state["bar"]["black"]):
			draw_circle(black_bar_pos + Vector2(0, i * 30), checker_radius, Color(0.5, 0.3, 0.1))
			draw_circle(black_bar_pos + Vector2(0, i * 30), checker_radius, Color.WHITE, false, 1.5)


func _draw_status() -> void:
	"""Draw game status text."""
	if game_state.is_empty():
		return
	
	var status_y = board_position.y - 50
	var player_name = "White" if game_state["current_player"] == 0 else "Black"
	
	draw_string(ThemeDB.fallback_font, Vector2(board_position.x, status_y), 
			   "Player: " + player_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	
	if selected_point >= 0 and selected_point < 24:
		var msg = "Selected: Point " + str(selected_point + 1) + " | Available moves: " + str(available_moves.size())
		draw_string(ThemeDB.fallback_font, Vector2(board_position.x, status_y + 25), 
				   msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.YELLOW)
	elif bar_selected:
		# Show dice available for re-entry when bar is selected
		var dice_vals = game_manager.get_game_state().get("remaining_moves", [])
		var dice_str = ", ".join(dice_vals.map(func(v): return str(v)))
		var msg2 = "Bar selected: re-enter using dice [" + dice_str + "]"
		draw_string(ThemeDB.fallback_font, Vector2(board_position.x, status_y + 25), 
			   msg2, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.YELLOW)


# ============================================================================
# INPUT HANDLING
# ============================================================================

func _handle_click(click_pos: Vector2) -> void:
	"""Handle mouse clicks for selecting checkers and making moves."""
	# Block selection until dice are rolled for the active player
	if game_manager.turn_state in [game_manager.TurnState.OPENING_ROLL, game_manager.TurnState.WAITING_FOR_ROLL]:
		print("Cannot move yet; roll dice first.")
		return

	# Find closest point to click
	var closest_point = -1
	var closest_dist = 100.0

	# Check bar hit zones first (white on left, black on right of bar)
	var white_bar_pos = bar_position - Vector2(40, 0)
	var black_bar_pos = bar_position + Vector2(40, 0)
	var bar_threshold = 70.0
	var current_player = game_manager.game_state["current_player"]
	if current_player == 0 and click_pos.distance_to(white_bar_pos) < bar_threshold and game_manager.game_state["bar"]["white"] > 0:
		print("Selecting from bar (white)")
		_select_point(-1)
		bar_selected = true
		return
	if current_player == 1 and click_pos.distance_to(black_bar_pos) < bar_threshold and game_manager.game_state["bar"]["black"] > 0:
		print("Selecting from bar (black)")
		_select_point(-1)
		bar_selected = true
		return
	
	for i in range(24):
		if point_positions.size() <= i:
			continue
		var dist = click_pos.distance_to(point_positions[i])
		if dist < closest_dist:
			closest_dist = dist
			closest_point = i
	
	# Check if clicked on a point
	if closest_point >= 0 and closest_dist < 40:
		if bar_selected and selected_point == -1:
			# Bar is selected; only allow moves to highlighted legal destinations
			if closest_point in available_moves:
				_try_move(-1, closest_point)
			else:
				print("Cannot move to that point from bar")
			return
		elif selected_point == -1:
			# No selection yet - try to select this point
			_select_point(closest_point)
		elif selected_point == closest_point:
			# Deselect
			_deselect_point()
		else:
			# Try to move from selected to this point
			_try_move(selected_point, closest_point)


func _select_point(point: int) -> void:
	"""Select a point to see available moves."""
	# Refresh local state to stay in sync
	game_state = game_manager.get_game_state().duplicate(true)
	var current_player = game_state["current_player"]
	var point_color = game_manager.get_point_color(point) if point >= 0 else current_player

	# Bar selection: ensure current player has pieces on bar
	if point == -1:
		var bar_key = "white" if current_player == 0 else "black"
		if game_manager.game_state["bar"][bar_key] <= 0:
			print("No checkers on bar")
			return
	else:
		# Can only select own checkers
		if point_color != current_player:
			print("Cannot select opponent's checkers")
			return
	
	selected_point = point
	available_moves = game_manager.get_legal_moves().filter(func(m): return m[0] == point)

	# Extract just the destination points
	available_moves = available_moves.map(func(m): return m[1])
	print("Selected point ", point, " with ", available_moves.size(), " available moves")
	queue_redraw()
	
	print("Selected point ", point, " with ", available_moves.size(), " available moves")
	queue_redraw()


func _deselect_point() -> void:
	"""Deselect current point."""
	selected_point = -1
	available_moves = []
	bar_selected = false
	queue_redraw()


func _auto_select_bar_if_needed() -> void:
	"""If current player has checkers on bar, auto-select bar and highlight legal re-entries."""
	if not game_manager:
		return
	var state = game_manager.get_game_state()
	if state.is_empty():
		return
	var current = state.get("current_player", 0)
	var bar_key = "white" if current == 0 else "black"
	if state["bar"].get(bar_key, 0) <= 0:
		return

	selected_point = -1
	bar_selected = true
	available_moves = game_manager.get_legal_moves().filter(func(m): return m[0] == -1)
	available_moves = available_moves.map(func(m): return m[1])
	queue_redraw()


func _try_move(from_point: int, to_point: int) -> void:
	"""Attempt to move from one point to another."""
	if to_point not in available_moves:
		print("Cannot move to that point")
		return
	
	print("Moving from ", from_point, " to ", to_point)
	game_manager.request_move(from_point, to_point)
	_deselect_point()


# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_game_started(state: Dictionary) -> void:
	"""Update when game starts."""
	print("_on_game_started called with state keys: ", state.keys())
	game_state = state.duplicate(true)
	_deselect_point()
	_auto_select_bar_if_needed()
	queue_redraw()


func _on_move_applied(from: int, to: int, color: int) -> void:
	"""Update when move is applied."""
	game_state = game_manager.get_game_state().duplicate(true)
	_deselect_point()
	queue_redraw()


func _on_dice_rolled(values: Array) -> void:
	"""Update when dice are rolled."""
	game_state = game_manager.get_game_state().duplicate(true)
	_auto_select_bar_if_needed()
	queue_redraw()


func _on_turn_ended(next_player: int) -> void:
	"""Update when turn ends."""
	game_state = game_manager.get_game_state().duplicate(true)
	_deselect_point()
	_auto_select_bar_if_needed()
	queue_redraw()


func _on_game_won(winner: int) -> void:
	"""Update when game is won."""
	_deselect_point()
	queue_redraw()
