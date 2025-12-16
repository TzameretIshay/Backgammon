## Board.gd (Rebuilt)
## Renders board points, stacks checkers, and converts drag releases into move attempts.

extends Node2D

signal move_attempted(from_point: int, to_point: int)

@export var checker_scene: PackedScene

const WHITE := 0
const BLACK := 1
const BEAR_OFF := 24
const HIT_FLASH_DURATION := 0.35

const MoveValidator = preload("res://scripts/MoveValidator.gd")

var game_state: Dictionary = {}
var _point_positions: Array = []  # Array[Vector2] length 24
var _bearoff_rect: Rect2
var _bar_rect: Rect2
var _checkers_root: Node2D
var _highlight_points: Array = []
var _highlight_bearoff := false
var _checker_nodes := {}  # point_index -> Array[Node2D]
var _animating := false
var _bar_white := []
var _bar_black := []
var _hit_flash_point := -1
var _hit_flash_time := 0.0
var _selected_point := -1  # Track which point's checker is selected
var _has_selection := false  # True when a checker is selected (board or bar)
var _anim_speed: float = 1.0

# Theme colors (mutable via settings)
var _col_board_bg := Color(0.2, 0.25, 0.35)
var _col_play_area := Color(0.5, 0.6, 0.75)
var _col_point_a := Color(0.72, 0.48, 0.28)
var _col_point_b := Color(0.9, 0.7, 0.45)
var _col_bar := Color(0.25, 0.25, 0.3, 0.3)
var _col_bearoff := Color(0.2, 0.6, 0.2, 0.25)
var _col_highlight := Color(0.0, 1.0, 1.0, 0.8)

func _ready() -> void:
	_checkers_root = Node2D.new()
	add_child(_checkers_root)
	_build_layout()
	queue_redraw()


func _process(delta: float) -> void:
	if _hit_flash_time > 0.0:
		_hit_flash_time -= delta
		if _hit_flash_time <= 0.0:
			_hit_flash_point = -1
		queue_redraw()


func _build_layout() -> void:
	# Backgammon board: points 0-23
	# Visual layout (left to right):
	#   BOTTOM: 11 10 9 8 7 6 | BAR | 5 4 3 2 1 0
	#   TOP:    12 13 14 15 16 17 | BAR | 18 19 20 21 22 23
	
	_point_positions.clear()
	for i in range(24):
		_point_positions.append(Vector2.ZERO)
	
	# Board dimensions (scaled down by half)
	var margin = 20.0
	var board_w = 600.0
	var board_h = 400.0
	var bar_w = 40.0
	var side_w = (board_w - bar_w) / 2.0  # 280 per side
	var point_w = side_w / 6.0  # ~46.67 per point
	var triangle_h = 160.0  # Height of triangles
	
	# Y coordinates - triangle base positions
	var bottom_y = margin + board_h  # Bottom edge
	var top_y = margin  # Top edge
	
	# X boundaries
	var left_start = margin
	var right_start = margin + side_w + bar_w
	
	# BOTTOM ROW - Display order: 11,10,9,8,7,6 | BAR | 5,4,3,2,1,0
	# Left side: points 11 down to 6
	for i in range(6):
		var point_idx = 11 - i
		var x = left_start + point_w * (i + 0.5)
		_point_positions[point_idx] = Vector2(x, bottom_y)
	
	# Right side: points 5 down to 0
	for i in range(6):
		var point_idx = 5 - i
		var x = right_start + point_w * (i + 0.5)
		_point_positions[point_idx] = Vector2(x, bottom_y)
	
	# TOP ROW - Display order: 12,13,14,15,16,17 | BAR | 18,19,20,21,22,23
	# Left side: points 12 to 17
	for i in range(6):
		var point_idx = 12 + i
		var x = left_start + point_w * (i + 0.5)
		_point_positions[point_idx] = Vector2(x, top_y)
	
	# Right side: points 18 to 23
	for i in range(6):
		var point_idx = 18 + i
		var x = right_start + point_w * (i + 0.5)
		_point_positions[point_idx] = Vector2(x, top_y)
	
	# Bar and bear-off areas
	_bar_rect = Rect2(margin + side_w, margin + 50.0, bar_w, board_h - 100.0)
	_bearoff_rect = Rect2(margin + board_w + 10.0, margin + 50.0, 50.0, board_h - 100.0)


func set_state(state: Dictionary) -> void:
	# Shallow duplicate to avoid circular reference from last_state
	game_state = {}
	for key in state.keys():
		if key != "last_state":
			game_state[key] = state[key]
	_draw_checkers()
	queue_redraw()


func _draw_checkers() -> void:
	# Clear old checker nodes
	for c in _checkers_root.get_children():
		c.queue_free()
	_checker_nodes.clear()
	_bar_white.clear()
	_bar_black.clear()

	if checker_scene == null:
		push_warning("Checker scene not assigned.")
		return

	var stack_spacing = 9.0  # Scaled down by half
	for idx in range(24):
		var count = game_state.get("points", [])[idx][0]
		var color = game_state.get("points", [])[idx][1]
		if count <= 0:
			continue
		for n in range(count):
			var checker = checker_scene.instantiate()
			checker.point_index = idx
			checker.color_id = color
			# Stack upward for bottom row, downward for top row
			var offset = Vector2(0, -stack_spacing * n) if idx < 12 else Vector2(0, stack_spacing * n)
			var target_pos = _point_positions[idx] + offset
			checker.position = target_pos
			_checkers_root.add_child(checker)
			if not _checker_nodes.has(idx):
				_checker_nodes[idx] = []
			_checker_nodes[idx].append(checker)
			checker.scale = Vector2(0.425, 0.425)  # Half size (0.85/2)
			var tw = create_tween()
			tw.tween_property(checker, "scale", Vector2(0.5, 0.5), 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Bar checkers
	var bar = game_state.get("bar", {})
	var bar_spacing = 8.0  # Scaled down by half
	if bar.get("white", 0) > 0:
		for n in range(bar["white"]):
			var cw = checker_scene.instantiate()
			cw.point_index = -1
			cw.color_id = WHITE
			cw.position = _bar_rect.get_center() + Vector2(0, -bar_spacing * n)
			_checkers_root.add_child(cw)
			_bar_white.append(cw)
	if bar.get("black", 0) > 0:
		for n in range(bar["black"]):
			var cb = checker_scene.instantiate()
			cb.point_index = -1
			cb.color_id = BLACK
			cb.position = _bar_rect.get_center() + Vector2(0, bar_spacing * n)
			_checkers_root.add_child(cb)
			_bar_black.append(cb)


func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if not event.pressed:
		return
	
	# Get both coordinate spaces for accurate hit-testing
	var mouse_global = get_global_mouse_position()
	var mouse_local = to_local(mouse_global)
	
	# Check if clicked on a checker (compare in GLOBAL space)
	var clicked_checker_point = _get_checker_at_position(mouse_global)
	
	if clicked_checker_point != -99:
		# Clicked on a checker
		if game_state.is_empty():
			return
		
		var current_player = game_state.get("current_player", -1)
		
		# Special case: selecting from BAR (clicked_checker_point == -1)
		if clicked_checker_point == -1:
			var ck = "white" if current_player == WHITE else "black"
			if game_state.get("bar", {}).get(ck, 0) <= 0:
				return
			_selected_point = -1
			_has_selection = true
			_on_checker_started(-1)
			get_viewport().set_input_as_handled()
			return
		
		# Regular board point: validate color
		var color_at_point = game_state.get("points", [])[clicked_checker_point][1]
		if color_at_point != current_player:
			return
		
		# Select this checker and show highlights
		_selected_point = clicked_checker_point
		_has_selection = true
		_on_checker_started(clicked_checker_point)
		get_viewport().set_input_as_handled()
		return
	
	# Not on a checker, check if on a highlight
	if not _has_selection:
		return  # No checker selected
	
	# Check if player clicked on a highlighted destination (LOCAL space)
	# Use highlight-aware locator for more reliable selection
	var target = _locate_target_from_highlights(mouse_local)
	
	# Only process clicks on highlighted points or bear-off
	var is_valid_destination = (target in _highlight_points) or (target == BEAR_OFF and _highlight_bearoff)
	
	if not is_valid_destination:
		return  # Not a valid destination
	
	# Valid move destination clicked
	print("Moving from %d to %d" % [_selected_point, target])
	move_attempted.emit(_selected_point, target)
	_selected_point = -1
	_has_selection = false
	_highlight_points.clear()
	_highlight_bearoff = false
	
	# Clear selection from all checkers
	for idx in _checker_nodes.keys():
		for checker in _checker_nodes[idx]:
			checker.set_selected(false)
	
	queue_redraw()
	get_viewport().set_input_as_handled()


func _get_checker_at_position(pos: Vector2) -> int:
	# Prefer bar checkers so re-entry is easy to select
	var bar_radius := 24.0
	for checker in _bar_white:
		if pos.distance_to(checker.global_position) <= bar_radius:
			return -1  # Bar selection
	for checker in _bar_black:
		if pos.distance_to(checker.global_position) <= bar_radius:
			return -1  # Bar selection

	# Then check board checkers
	var board_radius := 20.0
	for idx in _checker_nodes.keys():
		var checkers = _checker_nodes[idx]
		for checker in checkers:
			if pos.distance_to(checker.global_position) <= board_radius:
				return idx

	return -99  # No checker found


func play_move_animation(from_point: int, to_point: int, color: int, hit_point: int, new_state: Dictionary) -> void:
	_animating = true
	_highlight_points.clear()
	_highlight_bearoff = false
	var checker := _pop_top_checker(from_point, color)
	if checker == null:
		set_state(new_state)
		_animating = false
		return

	var start_pos := checker.global_position
	var dest_pos := _target_position_for_point(to_point, color, new_state)
	
	# Create arc path for checker movement
	var distance = start_pos.distance_to(dest_pos)
	var mid_point = (start_pos + dest_pos) / 2.0
	var arc_height = min(distance * 0.3, 100.0)  # Arc proportional to distance
	mid_point.y -= arc_height  # Lift checker up in an arc
	
	var tw = create_tween()
	tw.set_parallel(false)
	
	# Move up in an arc (2-step bezier-like path)
	var dur_arc: float = 0.15 / max(_anim_speed, 0.01)
	tw.tween_property(checker, "global_position", mid_point, dur_arc).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(checker, "global_position", dest_pos, dur_arc).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# Small bounce/settle effect
	var dur_bounce: float = 0.05 / max(_anim_speed, 0.01)
	tw.tween_property(checker, "scale", Vector2(1.1, 0.9), dur_bounce)
	tw.tween_property(checker, "scale", Vector2.ONE, dur_bounce)
	
	tw.chain().tween_callback(Callable(self, "_apply_post_animation_state").bind(new_state))

	if hit_point != -1:
		_hit_flash_point = hit_point
		_hit_flash_time = HIT_FLASH_DURATION
		queue_redraw()


func _apply_post_animation_state(new_state: Dictionary) -> void:
	set_state(new_state)
	_animating = false


func _pop_top_checker(point_idx: int, color: int) -> Node2D:
	if point_idx == -1:
		if color == WHITE and not _bar_white.is_empty():
			return _bar_white.pop_back()
		if color == BLACK and not _bar_black.is_empty():
			return _bar_black.pop_back()
		return null
	if not _checker_nodes.has(point_idx):
		return null
	var arr: Array = _checker_nodes[point_idx]
	if arr.is_empty():
		return null
	return arr.pop_back()


func _target_position_for_point(point_idx: int, color: int, state: Dictionary) -> Vector2:
	var stack_spacing = 9.0  # Scaled down by half
	if point_idx == BEAR_OFF:
		return _bearoff_rect.get_center()
	if point_idx == -1:
		return _bar_rect.get_center()
	if point_idx < 0 or point_idx >= _point_positions.size():
		return _point_positions[clampi(point_idx, 0, _point_positions.size() - 1)]
	
	var points: Array = state.get("points", [])
	var count_here = points[point_idx][0]
	var offset_index = count_here - 1
	var base = _point_positions[point_idx]
	if point_idx >= 12:
		return base + Vector2(0, stack_spacing * offset_index)
	else:
		return base + Vector2(0, -stack_spacing * offset_index)


func is_animating() -> bool:
	return _animating


func _on_checker_started(from_point: int) -> void:
	# Clear previous selection
	for idx in _checker_nodes.keys():
		var checkers = _checker_nodes[idx]
		for checker in checkers:
			checker.set_selected(false)
	
	# Highlight legal destinations and mark checker as selected
	_highlight_points.clear()
	_highlight_bearoff = false
	if game_state.is_empty():
		return
	
	# Mark the clicked checker as selected
	if from_point in _checker_nodes and not _checker_nodes[from_point].is_empty():
		_checker_nodes[from_point][-1].set_selected(true)
	elif from_point == -1:
		var cp = game_state.get("current_player", WHITE)
		if cp == WHITE and not _bar_white.is_empty():
			_bar_white[-1].set_selected(true)
		elif cp == BLACK and not _bar_black.is_empty():
			_bar_black[-1].set_selected(true)
	
	var moves = MoveValidator.compute_legal_moves(game_state, game_state.get("remaining_moves", []), BEAR_OFF)
	for m in moves:
		if m.get("from", -99) != from_point:
			continue
		var dest = m.get("to", -1)
		if dest == BEAR_OFF:
			_highlight_bearoff = true
		else:
			_highlight_points.append(dest)
	
	queue_redraw()


func _locate_target(world_pos: Vector2) -> int:
	if _bearoff_rect.has_point(world_pos):
		return BEAR_OFF
	var best_idx = -1
	var best_dist = 1e12
	for i in range(_point_positions.size()):
		var d = world_pos.distance_to(_point_positions[i])
		if d < best_dist:
			best_dist = d
			best_idx = i
	return best_idx


func _locate_target_from_highlights(world_pos: Vector2) -> int:
	# Prefer the closest highlighted destination to make clicking reliable
	if _highlight_points.is_empty():
		return _locate_target(world_pos)
	var best_idx = -1
	var best_dist = 1e12
	for i in _highlight_points:
		if i < 0 or i >= _point_positions.size():
			continue
		var d = world_pos.distance_to(_point_positions[i])
		if d < best_dist:
			best_dist = d
			best_idx = i
	return best_idx


func set_animation_speed(speed: float) -> void:
	_anim_speed = max(speed, 0.1)


func apply_theme(theme: Dictionary) -> void:
	# Expected keys: board_bg, play_area, point_a, point_b, bar, bearoff, highlight
	_col_board_bg = theme.get("board_bg", _col_board_bg)
	_col_play_area = theme.get("play_area", _col_play_area)
	_col_point_a = theme.get("point_a", _col_point_a)
	_col_point_b = theme.get("point_b", _col_point_b)
	_col_bar = theme.get("bar", _col_bar)
	_col_bearoff = theme.get("bearoff", _col_bearoff)
	_col_highlight = theme.get("highlight", _col_highlight)
	queue_redraw()


func _draw() -> void:
	# Background
	draw_rect(Rect2(Vector2.ZERO, Vector2(1600, 1000)), _col_board_bg)
	
	# Board play area
	var margin = 20.0
	var board_w = 600.0
	var board_h = 400.0
	draw_rect(Rect2(margin, margin, board_w, board_h), _col_play_area)
	
	# Draw triangles
	var triangle_width = 23.0  # Half-width of triangle base
	var triangle_height = 160.0
	
	for i in range(_point_positions.size()):
		var p = _point_positions[i]
		# Alternate colors
		var col = _col_point_a if i % 2 == 0 else _col_point_b
		
		# Bottom triangles (0-11) have base at bottom edge, point UP toward center
		# Top triangles (12-23) have base at top edge, point DOWN toward center
		if i < 12:
			# Bottom row - base at bottom edge, tip points up toward center
			var left_base = p + Vector2(-triangle_width, 0)
			var right_base = p + Vector2(triangle_width, 0)
			var tip = p + Vector2(0, -triangle_height)
			var tri = PackedVector2Array([left_base, right_base, tip])
			draw_polygon(tri, [col, col, col])
		else:
			# Top row - base at top edge, tip points down toward center
			var left_base = p + Vector2(-triangle_width, 0)
			var right_base = p + Vector2(triangle_width, 0)
			var tip = p + Vector2(0, triangle_height)
			var tri = PackedVector2Array([left_base, right_base, tip])
			draw_polygon(tri, [col, col, col])
	
	draw_rect(_bar_rect, _col_bar, false, 2)
	draw_rect(_bearoff_rect, _col_bearoff, false, 2)

	for h in _highlight_points:
		if h < 0 or h >= _point_positions.size():
			continue
		var hp = _point_positions[h]
		draw_circle(hp, 25, _col_highlight)
		draw_circle(hp, 23, Color(_col_highlight.r, _col_highlight.g, _col_highlight.b, _col_highlight.a * 0.5))
	if _highlight_bearoff:
		draw_rect(_bearoff_rect, Color(0.2, 0.8, 0.2, 0.35), true)

	if _hit_flash_point != -1 and _hit_flash_time > 0.0:
		if _hit_flash_point >= 0 and _hit_flash_point < _point_positions.size():
			var hp_flash = _point_positions[_hit_flash_point]
			var t = clamp(_hit_flash_time / HIT_FLASH_DURATION, 0.0, 1.0)
			# Pulsing effect with multiple rings
			var alpha1 = 0.8 * t
			var alpha2 = 0.5 * t
			draw_circle(hp_flash, 35, Color(1, 0.1, 0.1, alpha1))
			draw_circle(hp_flash, 30, Color(1, 0.3, 0.1, alpha2))
			draw_circle(hp_flash, 25, Color(1, 0.5, 0.2, alpha1 * 0.7))
