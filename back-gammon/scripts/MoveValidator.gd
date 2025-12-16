## MoveValidator.gd
## Pure rule helper for backgammon move legality and application.
## Keeps logic stateless so GameManager can stay focused on turn flow.

class_name MoveValidator

const WHITE := 0
const BLACK := 1

static func opponent(player: int) -> int:
	return BLACK if player == WHITE else WHITE

static func direction(player: int) -> int:
	# Convention:
	# WHITE moves counter-clockwise from high toward low (23 -> 0): -1
	# BLACK moves clockwise from low toward high (0 -> 23): +1
	return -1 if player == WHITE else 1

static func entry_point_for_die(player: int, die_value: int) -> int:
	# Bar re-entry: white enters at points 18-23, black enters at points 0-5
	return 24 - die_value if player == WHITE else die_value - 1

static func in_home_board(point: int, player: int) -> bool:
	# Home boards aligned with direction:
	# WHITE bears off at the low end (0..5)
	# BLACK bears off at the high end (18..23)
	if player == WHITE:
		return point >= 0 and point <= 5
	else:
		return point >= 18 and point <= 23

static func all_checkers_in_home(state: Dictionary, player: int) -> bool:
	var points: Array = state["points"]
	for i in range(points.size()):
		if points[i][1] == player and not in_home_board(i, player):
			return false
	return state["bar"][color_key(player)] == 0

static func color_key(player: int) -> String:
	return "white" if player == WHITE else "black"

static func is_blocked(state: Dictionary, target_point: int, player: int) -> bool:
	if target_point < 0 or target_point > 23:
		return false
	var dest = state["points"][target_point]
	return dest[0] >= 2 and dest[1] == opponent(player)

static func distance_for_move(from_point: int, to_point: int, player: int, bear_off: int) -> int:
	# Returns positive pip distance required for the move.
	if from_point == -1:
		# Bar re-entry
		return (24 - to_point) if player == WHITE else (to_point + 1)
	if to_point == bear_off:
		# Bearing off
		return (from_point + 1) if player == WHITE else (24 - from_point)
	return abs(to_point - from_point)

static func has_any_legal_move(state: Dictionary, dice_left: Array, bear_off: int) -> bool:
	return not compute_legal_moves(state, dice_left, bear_off).is_empty()

static func compute_legal_moves(state: Dictionary, dice_left: Array, bear_off: int) -> Array:
	# Returns array of move dictionaries: {"from": int, "to": int, "die": int}
	var moves: Array = []
	if dice_left.is_empty():
		return moves
	var player: int = state["current_player"]
	var color_str := color_key(player)
	var points: Array = state["points"]

	# Bar priority
	if state["bar"][color_str] > 0:
		for die in dice_left:
			var target = entry_point_for_die(player, die)
			if target < 0 or target > 23:
				continue
			if is_blocked(state, target, player):
				continue
			# Extra validation: double-check that target is truly not blocked before adding
			var points_array: Array = state["points"]
			if target >= 0 and target < points_array.size():
				var dest_stack = points_array[target]
				# Only add if point is empty, has own checkers, or has single opponent checker
				if not (dest_stack[0] >= 2 and dest_stack[1] == opponent(player)):
					moves.append({"from": -1, "to": target, "die": die})
			else:
				moves.append({"from": -1, "to": target, "die": die})
		return moves

	# Regular moves
	for from_idx in range(points.size()):
		var stack = points[from_idx]
		if stack[0] <= 0 or stack[1] != player:
			continue
		for die in dice_left:
			var target = _target_for_die(from_idx, die, player, bear_off)
			if target == null:
				continue
			if is_legal_move(state, dice_left, from_idx, target, bear_off) != -1:
				moves.append({"from": from_idx, "to": target, "die": die})
	return moves

static func _target_for_die(from_point: int, die: int, player: int, bear_off: int):
	var dir = direction(player)
	var target = from_point + dir * die
	if target < 0 or target > 23:
		# Beyond board edge means bearing off attempt
		target = bear_off
	return target

static func is_legal_move(state: Dictionary, dice_left: Array, from_point: int, to_point: int, bear_off: int) -> int:
	# Returns the die value used if legal, -1 otherwise.
	var player: int = state["current_player"]
	var color_str := color_key(player)
	var enemy := opponent(player)

	# Bar priority
	if state["bar"][color_str] > 0 and from_point != -1:
		return -1

	# Validate source
	if from_point == -1:
		if state["bar"][color_str] <= 0:
			return -1
	else:
		if from_point < 0 or from_point > 23:
			return -1
		var source = state["points"][from_point]
		if source[0] <= 0 or source[1] != player:
			return -1

	# Validate direction
	if from_point != -1 and to_point != bear_off:
		# WHITE must move to lower indices; BLACK to higher
		if player == WHITE and to_point >= from_point:
			return -1
		if player == BLACK and to_point <= from_point:
			return -1

	# Distance and die selection
	var needed = distance_for_move(from_point, to_point, player, bear_off)
	var die_used = _select_die_for_distance(dice_left, needed, to_point == bear_off, player, from_point, state)
	if die_used == -1:
		return -1

	# Block check
	if to_point != bear_off and is_blocked(state, to_point, player):
		return -1

	# Bearing off eligibility
	if to_point == bear_off and not all_checkers_in_home(state, player):
		return -1

	return die_used

static func _select_die_for_distance(dice_left: Array, distance: int, is_bear_off: bool, player: int, from_point: int, state: Dictionary = {}) -> int:
	# For bearing off with exact match, always prefer exact die
	if is_bear_off and distance in dice_left:
		return distance
	# Exact match for non-bearing-off moves
	if distance in dice_left:
		return distance
	# Bearing off rule: can use a larger die ONLY if no exact match exists and no checkers behind
	if is_bear_off:
		var candidate = _smallest_die_ge(dice_left, distance)
		if candidate != -1 and candidate != distance and not _has_checker_behind(state, player, from_point):
			return candidate
	return -1

static func _smallest_die_ge(dice_left: Array, distance: int) -> int:
	var sorted = dice_left.duplicate()
	sorted.sort()
	for d in sorted:
		if d >= distance:
			return d
	return -1

static func _has_checker_behind(state: Dictionary, player: int, from_point: int) -> bool:
	# Check if any own checker is further from bear-off than the source point (within home board).
	var points: Array = state.get("points", [])
	if points.is_empty():
		return false
	if player == WHITE:
		# WHITE bears off at low end; 'behind' are HIGHER indices
		for i in range(from_point + 1, points.size()):
			if points[i][1] == player and points[i][0] > 0:
				return true
	else:
		# BLACK bears off at high end; 'behind' are LOWER indices
		for i in range(0, from_point):
			if points[i][1] == player and points[i][0] > 0:
				return true
	return false

static func apply_move(state: Dictionary, move: Dictionary) -> Dictionary:
	# Returns {"state": Dictionary, "hit_point": int}
	var new_state: Dictionary = state.duplicate(true)
	var player: int = new_state["current_player"]
	var enemy: int = opponent(player)
	var color_str := color_key(player)
	var enemy_str := color_key(enemy)
	var from_point: int = move.get("from", -1)
	var to_point: int = move.get("to", -1)
	var hit_point: int = -1

	# Remove from source (bar or board)
	if from_point == -1:
		new_state["bar"][color_str] -= 1
	else:
		var src = new_state["points"][from_point]
		src[0] -= 1
		if src[0] <= 0:
			src[1] = -1

	# Destination handling
	if to_point == move.get("bear_off", 24):
		new_state["bear_off"][color_str] += 1
	else:
		var dest = new_state["points"][to_point]
		if dest[0] == 1 and dest[1] == enemy:
			# Hit checker goes to bar
			dest[0] = 0
			dest[1] = -1
			new_state["bar"][enemy_str] += 1
			hit_point = to_point
		# Place mover's checker
		dest[0] += 1
		dest[1] = player

	return {"state": new_state, "hit_point": hit_point}


static func calculate_pip_count(state: Dictionary, player: int) -> int:
	"""
	Calculate pip count (race distance) for a player.
	Sum of (point_distance_to_home * checker_count) for all checkers.
	"""
	var total_pips := 0
	var points: Array = state["points"]
	var bar_count: int = state["bar"][color_key(player)]
	
	# Checkers on bar: 25 pips each (furthest possible)
	total_pips += bar_count * 25
	
	# Checkers on board
	for point_idx in range(24):
		var checker_count: int = points[point_idx][0]
		var checker_color: int = points[point_idx][1]
		
		if checker_count > 0 and checker_color == player:
			var distance_to_bear_off: int
			if player == WHITE:
				# White bears off from point 0, so distance is (point + 1)
				distance_to_bear_off = point_idx + 1
			else:
				# Black bears off from point 23, so distance is (24 - point)
				distance_to_bear_off = 24 - point_idx
			
			total_pips += checker_count * distance_to_bear_off
	
	return total_pips


static func calculate_win_multiplier(state: Dictionary, winner: int) -> int:
	"""
	Calculate point multiplier for the win:
	- Normal win: 1x
	- Gammon (opponent has 0 borne off): 2x
	- Backgammon (opponent has checkers in winner's home or on bar): 3x
	"""
	var loser := opponent(winner)
	var loser_borne_off: int = state["bear_off"][color_key(loser)]
	
	# Normal win
	if loser_borne_off > 0:
		return 1
	
	# Check for backgammon: loser has checkers in winner's home or on bar
	var loser_on_bar: int = state["bar"][color_key(loser)]
	if loser_on_bar > 0:
		return 3  # Backgammon
	
	# Check if loser has checkers in winner's home board
	var points: Array = state["points"]
	var winner_home_range: Array
	if winner == WHITE:
		winner_home_range = range(0, 6)  # Points 0-5
	else:
		winner_home_range = range(18, 24)  # Points 18-23
	
	for point_idx in winner_home_range:
		var checker_count: int = points[point_idx][0]
		var checker_color: int = points[point_idx][1]
		if checker_count > 0 and checker_color == loser:
			return 3  # Backgammon
	
	# Gammon: opponent hasn't borne off any checkers
	return 2
