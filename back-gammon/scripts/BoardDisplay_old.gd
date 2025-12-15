## BoardDisplay.gd
## Renders the backgammon board visually with checkers on points.
##
## This script:
## - Displays the board image as background
## - Draws point positions (triangular points at standard positions)
## - Renders checkers (brown/blue pieces) on their current board positions
## - Handles click detection on points for move selection
## - Updates visually when game state changes

extends Node2D

# References
@onready var game_manager: Node = get_parent().get_parent()
var board_image: Texture2D
var checker_white: Texture2D
var checker_brown: Texture2D

# Display settings
var board_position: Vector2 = Vector2(420, 100)
var board_size: Vector2 = Vector2(700, 500)
var point_width: float = 40.0
var checker_radius: float = 15.0

# Point layout - visual positions on screen for each of 24 points
# Points 0-11 on bottom row, 12-23 on top row (standard backgammon layout)
var point_positions: Array[Vector2] = []

# Game state cache
var game_state: Dictionary = {}

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	"""Initialize board display."""
	print("BoardDisplay ready.")
	_init_textures()
	_calculate_point_positions()
	
	# Connect to GameManager signals
	if game_manager:
		game_manager.game_started.connect(_on_game_started)
		game_manager.move_applied.connect(_on_move_applied)
		game_manager.dice_rolled.connect(_on_dice_rolled)
		game_manager.turn_ended.connect(_on_turn_ended)
		game_manager.game_won.connect(_on_game_won)


func _draw() -> void:
	"""Render board and checkers."""
	if not game_state.is_empty():
		_draw_board()
		_draw_points()
		_draw_checkers()
		_draw_status()


# ============================================================================
# TEXTURE LOADING
# ============================================================================

func _init_textures() -> void:
	"""Load board and checker textures (safe even if files are missing)."""
	# Use load() instead of preload() so missing files do not crash parsing.
	if ResourceLoader.exists("res://assets/textures/board.png"):
		board_image = load("res://assets/textures/board.png")
	if ResourceLoader.exists("res://assets/textures/checker_white.png"):
		checker_white = load("res://assets/textures/checker_white.png")
	if ResourceLoader.exists("res://assets/textures/checker_brown.png"):
		checker_brown = load("res://assets/textures/checker_brown.png")

	print("Textures loaded (using shapes if not found).")


# ============================================================================
# POINT POSITION CALCULATION
# ============================================================================

func _calculate_point_positions() -> void:
	"""
	Calculate visual positions for all 24 backgammon points.
	Standard layout: points 0-11 on bottom, 12-23 on top.
	Points arranged in two rows of 12.
	"""
	point_positions.clear()
	
	var spacing = board_size.x / 12.0
	var bottom_y = board_position.y + board_size.y - 30
	var top_y = board_position.y + 30
	
	# Bottom row: points 0-11 (left to right)
	for i in range(12):
		var x = board_position.x + (i + 0.5) * spacing
		point_positions.append(Vector2(x, bottom_y))
	
	# Top row: points 12-23 (left to right)
	for i in range(12):
		var x = board_position.x + (i + 0.5) * spacing
		point_positions.append(Vector2(x, top_y))


# ============================================================================
# DRAWING
# ============================================================================

func _draw_board() -> void:
	"""Draw the board background."""
	# Fill with green for now (board color)
	draw_rect(Rect2(board_position, board_size), Color.DARK_GREEN)
	draw_rect(Rect2(board_position, board_size), Color.BLACK, false, 2.0)
	
	# Draw bar in middle
	var bar_x = board_position.x + board_size.x / 2.0
	draw_line(Vector2(bar_x, board_position.y), Vector2(bar_x, board_position.y + board_size.y), Color.BLACK, 3.0)


func _draw_points() -> void:
	"""Draw visual point indicators on the board."""
	for i in range(24):
		var pos = point_positions[i]
		var is_top = i >= 12
		
		# Draw triangular point shape
		var height = 20.0
		var width = point_width
		
		var p1 = pos
		var p2 = pos + Vector2(-width / 2.0, height if is_top else -height)
		var p3 = pos + Vector2(width / 2.0, height if is_top else -height)
		
		# Alternate point colors for clarity
		var color = Color(0.7, 0.5, 0.3) if i % 2 == 0 else Color(0.6, 0.4, 0.2)
		
		# Draw filled triangle
		draw_colored_polygon([p1, p2, p3], color)
		
		# Draw point label (for debugging)
		draw_string(ThemeDB.fallback_font, pos - Vector2(10, 0), str(i), HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color.WHITE)


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
		
		# Draw stack of checkers
		for i in range(count):
			var offset = Vector2(0, i * (checker_radius * 1.5))
			var checker_color = Color.BROWN if color == 1 else Color.LIGHT_BLUE
			draw_circle(base_pos + offset, checker_radius, checker_color)
			draw_circle(base_pos + offset, checker_radius, Color.WHITE, false, 2.0)
	
	# Draw checkers on bar
	var bar_x = board_position.x + board_size.x / 2.0
	var bar_y = board_position.y + board_size.y / 2.0
	
	if game_state["bar"]["white"] > 0:
		var white_bar_pos = Vector2(bar_x - 30, bar_y)
		for i in range(game_state["bar"]["white"]):
			draw_circle(white_bar_pos + Vector2(0, i * 40), checker_radius, Color.LIGHT_BLUE)
			draw_circle(white_bar_pos + Vector2(0, i * 40), checker_radius, Color.WHITE, false, 2.0)
	
	if game_state["bar"]["black"] > 0:
		var black_bar_pos = Vector2(bar_x + 30, bar_y)
		for i in range(game_state["bar"]["black"]):
			draw_circle(black_bar_pos + Vector2(0, i * 40), checker_radius, Color.BROWN)
			draw_circle(black_bar_pos + Vector2(0, i * 40), checker_radius, Color.WHITE, false, 2.0)


func _draw_status() -> void:
	"""Draw game status text."""
	if game_state.is_empty():
		return
	
	var status_y = board_position.y - 40
	var player_name = "White" if game_state["current_player"] == 0 else "Black"
	var status_text = "Player: %s | Remaining moves: %s | White off: %d | Black off: %d" % [
		player_name,
		game_state["remaining_moves"],
		game_state["bear_off"]["white"],
		game_state["bear_off"]["black"]
	]
	
	draw_string(ThemeDB.fallback_font, Vector2(board_position.x, status_y), status_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)


# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_game_started(state: Dictionary) -> void:
	"""Update when game starts."""
	game_state = state.duplicate(true)
	queue_redraw()
	print("Game display updated.")


func _on_move_applied(from: int, to: int, color: int) -> void:
	"""Update when move is applied."""
	game_state = game_manager.get_game_state().duplicate(true)
	queue_redraw()


func _on_dice_rolled(values: Array[int]) -> void:
	"""Update when dice are rolled."""
	print("Dice rolled: %s" % values)
	queue_redraw()


func _on_turn_ended(next_player: int) -> void:
	"""Update when turn ends."""
	game_state = game_manager.get_game_state().duplicate(true)
	queue_redraw()


func _on_game_won(winner: int) -> void:
	"""Update when game is won."""
	print("Player %d wins!" % winner)
	queue_redraw()


# ============================================================================
# INPUT HANDLING
# ============================================================================

func _input_event(viewport: Viewport, event: InputEvent, shape_idx: int) -> void:
	"""Handle clicks on board to select moves."""
	if event is InputEventMouseButton and event.pressed:
		var click_pos = event.position
		_handle_point_click(click_pos)


func _handle_point_click(click_pos: Vector2) -> void:
	"""
	Detect which point was clicked and attempt a move.
	For now, just for testing - full drag-and-drop would be better.
	"""
	# Find closest point to click
	var closest_point = -1
	var closest_dist = 100.0
	
	for i in range(24):
		var dist = click_pos.distance_to(point_positions[i])
		if dist < closest_dist:
			closest_dist = dist
			closest_point = i
	
	if closest_point >= 0 and closest_dist < 40:
		print("Clicked point %d" % closest_point)
		# UI will handle move selection through proper interface


# ============================================================================
# DEBUGGING
# ============================================================================

func get_point_position(point_idx: int) -> Vector2:
	"""Get visual position of a point (for testing/debugging)."""
	if point_idx < 0 or point_idx >= point_positions.size():
		return Vector2.ZERO
	return point_positions[point_idx]
