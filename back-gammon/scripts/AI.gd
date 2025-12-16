## AI.gd
## Master-level backgammon AI implementing complete strategy guide:
## - Opening theory (optimal plays for each roll)
## - Golden points (5-point, bar-point priority)
## - Tactical patterns (blitz, priming, holding, back games)
## - Pip counting and race evaluation
## - Checker distribution and timing
## - Point-making priorities and anchor strategy

class_name AI

const MoveValidator = preload("res://scripts/MoveValidator.gd")

const RUNNING_GAME := "running"
const BLOCKING_GAME := "blocking"
const BEARING_OFF := "bearing_off"
const OPENING_GAME := "opening"
const BLITZ_GAME := "blitz"
const PRIMING_GAME := "priming"
const HOLDING_GAME := "holding"
const BACK_GAME := "back_game"

static func choose_move(state: Dictionary, dice_left: Array, bear_off: int) -> Dictionary:
	var moves = MoveValidator.compute_legal_moves(state, dice_left, bear_off)
	if moves.is_empty():
		return {}
	
	# Check if this is opening (first few moves)
	var roll_number = _estimate_roll_number(state)
	
	# For opening moves (first 1-3 rolls), use opening book if available
	if roll_number <= 2 and dice_left.size() >= 2:
		var opening_move = _get_opening_book_move(state, dice_left, moves)
		if not opening_move.is_empty():
			return opening_move
	
	# Determine current game phase and strategy
	var phase = _determine_game_phase(state, roll_number)
	var tactical_pattern = _detect_tactical_pattern(state)
	var strategy = _determine_strategy(state, phase, tactical_pattern)
	
	# Score moves: higher is better
	var best = moves[0]
	var best_score = -1e9
	for m in moves:
		var score = _score_move(state, m, bear_off, phase, strategy, tactical_pattern)
		if score > best_score:
			best_score = score
			best = m
	return best

static func _estimate_roll_number(state: Dictionary) -> int:
	# Estimate what roll number this is based on checker positions
	var player = state["current_player"]
	var points = state["points"]
	var moved_checkers = 0
	
	# Count how many checkers have moved from starting positions
	if player == MoveValidator.WHITE:
		# White starts with checkers on 0, 11, 16, 18
		var start_0 = 2 - (points[0][0] if points[0][1] == player else 0)
		var start_11 = 5 - (points[11][0] if points[11][1] == player else 0)
		var start_16 = 3 - (points[16][0] if points[16][1] == player else 0)
		var start_18 = 5 - (points[18][0] if points[18][1] == player else 0)
		moved_checkers = start_0 + start_11 + start_16 + start_18
	else:
		# Black starts on 23, 12, 7, 5
		var start_23 = 2 - (points[23][0] if points[23][1] == player else 0)
		var start_12 = 5 - (points[12][0] if points[12][1] == player else 0)
		var start_7 = 3 - (points[7][0] if points[7][1] == player else 0)
		var start_5 = 5 - (points[5][0] if points[5][1] == player else 0)
		moved_checkers = start_23 + start_12 + start_7 + start_5
	
	# Estimate roll number (each roll moves ~2 checkers)
	return max(1, moved_checkers / 2)


static func _determine_game_phase(state: Dictionary, roll_number: int) -> String:
	var player = state["current_player"]
	
	# Opening game: first 5-10 rolls
	if roll_number <= 8:
		return OPENING_GAME
	
	# Check if in bearing off phase (all checkers in home board)
	if MoveValidator.all_checkers_in_home(state, player):
		return BEARING_OFF
	
	# Count checkers in various zones
	var total_checkers = _count_total_checkers(state, player)
	var home_checkers = _count_checkers_in_home(state, player)
	
	# If most checkers are home, transitioning to bearing off
	if home_checkers >= total_checkers - 3:
		return BEARING_OFF
	
	return BLOCKING_GAME  # Mid-game default


static func _detect_tactical_pattern(state: Dictionary) -> String:
	var player = state["current_player"]
	var enemy = MoveValidator.opponent(player)
	var points = state["points"]
	var bar = state.get("bar", {})
	
	# Blitz: opponent has 2+ on bar or in our home with weak board
	var enemy_on_bar = bar.get("white" if enemy == MoveValidator.WHITE else "black", 0)
	var enemy_in_our_home = _count_checkers_in_zone(state, enemy, 0 if player == MoveValidator.WHITE else 18, 6 if player == MoveValidator.WHITE else 24)
	var our_home_points = _count_made_points_in_zone(state, player, 0 if player == MoveValidator.WHITE else 18, 6 if player == MoveValidator.WHITE else 24)
	
	if enemy_on_bar >= 1 or (enemy_in_our_home >= 2 and our_home_points >= 3):
		return BLITZ_GAME
	
	# Back game: we hold 2+ anchors in enemy home
	var our_anchors_in_enemy_home = _count_anchors_in_zone(state, player, 18 if player == MoveValidator.WHITE else 0, 24 if player == MoveValidator.WHITE else 6)
	if our_anchors_in_enemy_home >= 2:
		return BACK_GAME
	
	# Holding game: we hold 1 anchor in enemy home, most checkers advanced
	if our_anchors_in_enemy_home == 1:
		var our_checkers_advanced = _count_checkers_past_point(state, player, 12)
		if our_checkers_advanced >= 10:
			return HOLDING_GAME
	
	# Priming game: we have 4+ consecutive points
	var longest_prime = _count_longest_prime(state, player)
	if longest_prime >= 4:
		return PRIMING_GAME
	
	return BLOCKING_GAME


static func _determine_strategy(state: Dictionary, phase: String, tactical_pattern: String) -> String:
	var player = state["current_player"]
	var enemy = MoveValidator.opponent(player)
	
	# Tactical patterns override general strategy
	if tactical_pattern in [BLITZ_GAME, PRIMING_GAME, HOLDING_GAME, BACK_GAME]:
		return tactical_pattern
	
	# Always use running game when bearing off
	if phase == BEARING_OFF:
		return RUNNING_GAME
	
	# Calculate pip count (distance to home) for both players
	var my_pips = _calculate_pip_count(state, player)
	var enemy_pips = _calculate_pip_count(state, enemy)
	
	# If significantly ahead in the race (10%+ lead), run
	if my_pips > 0 and float(my_pips) / float(enemy_pips) <= 0.90:
		return RUNNING_GAME
	
	# Otherwise, use blocking strategy
	return BLOCKING_GAME


static func _get_opening_book_move(state: Dictionary, dice: Array, moves: Array) -> Dictionary:
	# Opening book based on comprehensive strategy guide
	# Returns best move for opening rolls
	var player = state["current_player"]
	var d1 = dice[0] if dice.size() > 0 else 0
	var d2 = dice[1] if dice.size() > 1 else 0
	var roll_key = str(min(d1, d2)) + "-" + str(max(d1, d2))
	
	# Define target moves for each opening roll
	var opening_plays = {
		"1-3": {"priority": ["make_5_point"]},  # Best: 8/5, 6/5
		"1-6": {"priority": ["make_bar_point"]},  # 13/7, 8/7
		"2-4": {"priority": ["make_4_point"]},  # 8/4, 6/4
		"3-5": {"priority": ["make_3_point"]},  # 8/3, 6/3
		"5-6": {"priority": ["run_one"]},  # 24/13 (for white) or 1/12 (for black)
		"4-6": {"priority": ["run_one"]},  # 24/14
		"3-6": {"priority": ["run_bar"]},  # 24/18 or split options
		"2-6": {"priority": ["run_18", "slot_5"]},
		"4-5": {"priority": ["split_deep"]},  # 24/20, 24/19
		"3-4": {"priority": ["split_back"]},  # 24/20, 24/21
		"2-3": {"priority": ["split_back"]},  # 24/21, 13/11
		"2-5": {"priority": ["builders"]},  # 13/11, 13/8
		"1-4": {"priority": ["builders"]},  # 13/9, 13/12
		"1-2": {"priority": ["slot_5"]},  # 13/11, 6/5
	}
	
	# For doubles, handle specially
	if d1 == d2:
		return _handle_opening_doubles(state, d1, moves, player)
	
	var play_info = opening_plays.get(roll_key, {})
	if play_info.is_empty():
		return {}
	
	# Find the move that best matches the opening book
	return _find_best_opening_move(moves, play_info, player)


static func _handle_opening_doubles(state: Dictionary, die: int, moves: Array, player: int) -> Dictionary:
	# Optimal plays for opening doubles
	match die:
		1:  # Make 7-point and 5-point: 8/7(2), 6/5(2)
			return _find_move_making_points(moves, [7, 5] if player == MoveValidator.WHITE else [16, 18], player)
		2:  # Make 4-point and 11-point: 6/4(2), 13/11(2)
			return _find_move_making_points(moves, [4, 11] if player == MoveValidator.WHITE else [19, 12], player)
		3:  # Make both 5-points: 8/5(2), 6/3(2)
			return _find_move_making_points(moves, [5, 3] if player == MoveValidator.WHITE else [18, 20], player)
		4:  # Make both 9-points: 13/9(2), 24/20(2)
			return _find_move_making_points(moves, [9, 20] if player == MoveValidator.WHITE else [14, 3], player)
		5:  # Bring down to 3-point: 13/3(2)
			return _find_move_to_point(moves, 3 if player == MoveValidator.WHITE else 20)
		6:  # Run both back: 24/18(2)
			return _find_move_to_point(moves, 18 if player == MoveValidator.WHITE else 5)
	return {}


static func _find_best_opening_move(moves: Array, play_info: Dictionary, player: int) -> Dictionary:
	# Simple heuristic to match opening book intentions
	var priorities = play_info.get("priority", [])
	for priority in priorities:
		for move in moves:
			if _move_matches_intent(move, priority, player):
				return move
	return {}


static func _move_matches_intent(move: Dictionary, intent: String, player: int) -> bool:
	var to_p = move.get("to", -1)
	match intent:
		"make_5_point":
			return to_p == (5 if player == MoveValidator.WHITE else 18)
		"make_bar_point":
			return to_p == (7 if player == MoveValidator.WHITE else 16)
		"make_4_point":
			return to_p == (4 if player == MoveValidator.WHITE else 19)
		"make_3_point":
			return to_p == (3 if player == MoveValidator.WHITE else 20)
		"run_one", "run_bar", "run_18":
			return to_p >= 12 and to_p <= 18
		"slot_5":
			return to_p == (5 if player == MoveValidator.WHITE else 18)
		"split_deep", "split_back":
			return to_p >= 18 or to_p <= 5
		"builders":
			return to_p >= 7 and to_p <= 12
	return false


static func _find_move_making_points(moves: Array, target_points: Array, player: int) -> Dictionary:
	for move in moves:
		if move.get("to", -1) in target_points:
			return move
	return {}


static func _find_move_to_point(moves: Array, target: int) -> Dictionary:
	for move in moves:
		if move.get("to", -1) == target:
			return move
	return {}


static func _score_move(state: Dictionary, move: Dictionary, bear_off: int, phase: String, strategy: String, tactical_pattern: String) -> float:
	var player = state["current_player"]
	var enemy = MoveValidator.opponent(player)
	var from_p = move.get("from", -1)
	var to_p = move.get("to", -1)
	var score = 0.0
	var points = state["points"]

	# === BEARING OFF PHASE ===
	if phase == BEARING_OFF:
		if to_p == bear_off:
			score += 2500  # Highest priority: remove checkers
		# Clear highest points first (strategy guide principle)
		if _is_in_home_board(to_p, player):
			var point_height = _get_home_point_number(to_p, player)
			score -= point_height * 10  # Prefer bearing off from high points
		# Don't break critical points unless necessary
		if from_p >= 0 and from_p < 24 and _is_in_home_board(from_p, player):
			var src = points[from_p]
			if src[0] == 2:  # Breaking a point
				score -= 50
		# Don't leave blots when opponent still has checkers
		var enemy_threats = _count_enemy_threats(state, enemy)
		if enemy_threats > 0 and to_p >= 0 and to_p < 24:
			var dest = points[to_p]
			if dest[0] == 0:  # Would leave blot
				score -= 200
		return score

	# === BAR RE-ENTRY (ALWAYS CRITICAL) ===
	if from_p == -1:
		score += 600  # Must re-enter from bar (highest priority outside bearing off)
		# Strongly prefer entering on anchor points (20-point, 18-point)
		if _is_best_anchor(to_p, player):
			score += 350
		elif _is_anchor_point(to_p, player):
			score += 200

	# === THE GOLDEN POINTS (OPENING GAME PRIORITY) ===
	if phase == OPENING_GAME and to_p >= 0 and to_p < 24:
		var dest = points[to_p]
		if dest[0] == 1 and dest[1] == player:
			# Making 5-point is THE best (single most important point)
			if to_p == (5 if player == MoveValidator.WHITE else 18):
				score += 800  # Golden point bonus
			# Making bar-point (7-point) is second best
			elif to_p == (7 if player == MoveValidator.WHITE else 16):
				score += 700  # Bar point bonus
			# Making 4-point is good
			elif to_p == (4 if player == MoveValidator.WHITE else 19):
				score += 400
			# Making 3-point is acceptable
			elif to_p == (3 if player == MoveValidator.WHITE else 20):
				score += 300

	# === NEVER MAKE 1-POINT OR 2-POINT EARLY ===
	if phase == OPENING_GAME and to_p >= 0 and to_p < 24:
		var dest = points[to_p]
		if dest[0] == 1 and dest[1] == player:
			# Heavy penalty for making 1-point or 2-point early
			if to_p == (0 if player == MoveValidator.WHITE else 23) or to_p == (1 if player == MoveValidator.WHITE else 22):
				score -= 500  # Strategy guide: DON'T make these early

	# === HITTING BLOTS (CONTEXT-DEPENDENT) ===
	if to_p >= 0 and to_p < 24:
		var dest = points[to_p]
		if dest[0] == 1 and dest[1] == enemy:
			if tactical_pattern == BLITZ_GAME:
				score += 700  # Extremely high in blitz
				if _is_in_home_board(to_p, player):
					score += 200  # Even better in our home during blitz
			elif strategy == PRIMING_GAME:
				score += 500  # High priority for priming
			elif strategy == HOLDING_GAME or strategy == BACK_GAME:
				score += 350  # Good for timing
			elif strategy == RUNNING_GAME:
				score += 150  # Lower priority when running
			else:
				score += 400  # Default: hitting is good

	# === MAKING POINTS (POINT-MAKING PRIORITY) ===
	if to_p >= 0 and to_p < 24:
		var dest = points[to_p]
		if dest[0] == 1 and dest[1] == player:
			# Base value for making any point
			score += 300
			
			# Strategic point values (priority from guide)
			if to_p == (5 if player == MoveValidator.WHITE else 18):
				score += 500  # 5-point: most important
			elif to_p == (7 if player == MoveValidator.WHITE else 16):
				score += 450  # Bar-point: second most important
			elif to_p == (4 if player == MoveValidator.WHITE else 19):
				score += 300  # 4-point: third priority
			elif _is_best_anchor(to_p, player):
				score += 400  # Opponent's 5-point anchor
			elif to_p == (3 if player == MoveValidator.WHITE else 20):
				score += 200  # 3-point: acceptable
			elif to_p == (8 if player == MoveValidator.WHITE else 15) or to_p == (9 if player == MoveValidator.WHITE else 14):
				score += 250  # 8-point, 9-point: for priming
			
			# Prime building value
			var prime_value = _evaluate_prime_building(state, to_p, player)
			score += prime_value
			
			# In priming game, point-making is extra valuable
			if tactical_pattern == PRIMING_GAME:
				score += 200

	# === ANCHOR ESTABLISHMENT (DEFENSIVE/OFFENSIVE) ===
	if _is_anchor_point(to_p, player) and to_p >= 0 and to_p < 24:
		var dest = points[to_p]
		if dest[0] >= 1 and dest[1] == player:
			# Best anchors (strategy guide priorities)
			if _is_best_anchor(to_p, player):  # 20-point or 18-point
				score += 300
			else:
				score += 150
			# Extra value in holding and back games
			if tactical_pattern in [HOLDING_GAME, BACK_GAME]:
				score += 200

	# === BUILDERS (MAINTAIN FLEXIBILITY) ===
	if to_p >= 0 and to_p < 24:
		# Reward having builders in outer board (7-12 for WHITE, 12-16 for BLACK)
		if (player == MoveValidator.WHITE and to_p >= 7 and to_p <= 12) or (player == MoveValidator.BLACK and to_p >= 12 and to_p <= 16):
			score += 80  # Good positioning for making points

	# === DISTANCE ADVANCEMENT ===
	var dist = abs(to_p - from_p) if to_p != bear_off else MoveValidator.distance_for_move(from_p, to_p, player, bear_off)
	if strategy == RUNNING_GAME:
		score += dist * 10  # Prioritize distance in running game
	elif tactical_pattern == BACK_GAME:
		score -= dist * 2  # In back game, want to slow down
	else:
		score += dist * 4  # Default: advancement is good

	# === SAFETY: AVOID BLOTS (THE THREE DON'TS - #1) ===
	if from_p >= 0 and from_p < 24:
		var src = points[from_p]
		if src[0] == 1:  # Would leave blot
			var exposure = _calculate_exposure_risk(state, from_p, player)
			score -= exposure
			# Heavy penalty in opponent's home board
			if _is_in_home_board(from_p, enemy):
				score -= 150
			# Less severe if it's a strategic slot (like slotting 5-point)
			if from_p == (5 if player == MoveValidator.WHITE else 18) and phase == OPENING_GAME:
				score += 100  # Acceptable strategic risk

	# === AVOID BREAKING POINTS (THE THREE DON'TS - #3) ===
	if from_p >= 0 and from_p < 24:
		var src = points[from_p]
		if src[0] == 2:  # Breaking a made point
			# Heavy penalty for breaking golden points
			if from_p == (5 if player == MoveValidator.WHITE else 18):
				score -= 400  # Don't break 5-point!
			elif from_p == (7 if player == MoveValidator.WHITE else 16):
				score -= 350  # Don't break bar-point!
			elif _is_key_point(from_p, player):
				score -= 250
			elif tactical_pattern == PRIMING_GAME:
				score -= 200  # Don't break prime
			else:
				score -= 100

	# === AVOID STACKING (THE THREE DON'TS - #2) ===
	if to_p >= 0 and to_p < 24:
		var dest = points[to_p]
		if dest[1] == player:
			# Penalty for excessive stacking (more than 4 is wasteful)
			if dest[0] >= 4:
				score -= 70
			if dest[0] >= 5:
				score -= 100
			# Don't pile up on 6-point
			if to_p == (6 if player == MoveValidator.WHITE else 17) and dest[0] >= 5:
				score -= 150

	# === TACTICAL PATTERN BONUSES ===
	if tactical_pattern == BLITZ_GAME:
		# In blitz: make home board points aggressively
		if _is_in_home_board(to_p, player) and to_p >= 0 and to_p < 24:
			var dest = points[to_p]
			if dest[0] >= 1 and dest[1] == player:
				score += 250
	
	elif tactical_pattern == PRIMING_GAME:
		# Maintain and extend the prime
		var prime_length = _count_longest_prime(state, player)
		if prime_length >= 4:
			score += prime_length * 30
	
	elif tactical_pattern == BACK_GAME:
		# Maintain anchors and timing
		var anchor_count = _count_anchors_in_zone(state, player, 18 if player == MoveValidator.WHITE else 0, 24 if player == MoveValidator.WHITE else 6)
		if anchor_count >= 2:
			score += 200

	return score


static func _is_key_point(point: int, player: int) -> bool:
	# 5-point and bar point (7-point) are most valuable
	if player == MoveValidator.WHITE:
		return point == 5 or point == 7
	else:
		return point == 18 or point == 16


static func _is_anchor_point(point: int, player: int) -> bool:
	# Anchor is a made point in opponent's home board
	if player == MoveValidator.WHITE:
		return point >= 18 and point < 24
	else:
		return point >= 0 and point < 6


static func _is_in_home_board(point: int, player: int) -> bool:
	if player == MoveValidator.WHITE:
		return point >= 0 and point < 6
	else:
		return point >= 18 and point < 24


static func _evaluate_prime_building(state: Dictionary, point: int, player: int) -> float:
	# Check if making this point extends a prime (consecutive made points)
	var points = state["points"]
	var consecutive_before = 0
	var consecutive_after = 0
	
	# Count consecutive points before
	var check_point = point - 1 if player == MoveValidator.WHITE else point + 1
	while check_point >= 0 and check_point < 24:
		if points[check_point][0] >= 2 and points[check_point][1] == player:
			consecutive_before += 1
			check_point = check_point - 1 if player == MoveValidator.WHITE else check_point + 1
		else:
			break
	
	# Count consecutive points after
	check_point = point + 1 if player == MoveValidator.WHITE else point - 1
	while check_point >= 0 and check_point < 24:
		if points[check_point][0] >= 2 and points[check_point][1] == player:
			consecutive_after += 1
			check_point = check_point + 1 if player == MoveValidator.WHITE else check_point - 1
		else:
			break
	
	var prime_length = consecutive_before + consecutive_after + 1
	# Reward based on prime length (6-point prime is ideal)
	return prime_length * prime_length * 20.0


static func _calculate_exposure_risk(state: Dictionary, point: int, player: int) -> float:
	# Calculate risk of leaving a blot at this point
	var enemy = MoveValidator.opponent(player)
	var risk = 0.0
	
	# Higher risk in opponent's home board
	if _is_in_home_board(point, enemy):
		risk += 120
	# Medium risk in outer boards
	elif point >= 6 and point < 18:
		risk += 70
	# Lower risk in own home board
	else:
		risk += 40
	
	# Check if enemy has pieces that can hit (simplified)
	var enemy_presence = _count_enemy_checkers_nearby(state, point, enemy)
	risk += enemy_presence * 15
	
	return risk


static func _count_enemy_checkers_nearby(state: Dictionary, point: int, enemy: int) -> int:
	# Count enemy checkers within hitting distance (1-6 points away)
	var points = state["points"]
	var count = 0
	for dist in range(1, 7):
		var check_point = point + dist if enemy == MoveValidator.BLACK else point - dist
		if check_point >= 0 and check_point < 24:
			if points[check_point][1] == enemy and points[check_point][0] > 0:
				count += 1
	return count


static func _calculate_pip_count(state: Dictionary, player: int) -> int:
	# Calculate total distance all checkers must travel
	var points = state["points"]
	var pip_count = 0
	
	for i in range(24):
		if points[i][1] == player:
			var checkers = points[i][0]
			var distance = 0
			if player == MoveValidator.WHITE:
				distance = i + 1
			else:
				distance = 24 - i
			pip_count += checkers * distance
	
	# Add bar checkers (25 pips each)
	var bar = state.get("bar", {})
	if player == MoveValidator.WHITE:
		pip_count += bar.get("white", 0) * 25
	else:
		pip_count += bar.get("black", 0) * 25
	
	return pip_count


static func _count_total_checkers(state: Dictionary, player: int) -> int:
	var points = state["points"]
	var total = 0
	for i in range(24):
		if points[i][1] == player:
			total += points[i][0]
	return total


static func _count_checkers_in_home(state: Dictionary, player: int) -> int:
	var points = state["points"]
	var home_count = 0
	if player == MoveValidator.WHITE:
		for i in range(0, 6):
			if points[i][1] == player:
				home_count += points[i][0]
	else:
		for i in range(18, 24):
			if points[i][1] == player:
				home_count += points[i][0]
	return home_count


static func _count_blocks_ahead(state: Dictionary, player: int, from_or_to: int) -> int:
	var points = state.get("points", [])
	var count = 0
	if from_or_to < 0 or from_or_to >= points.size():
		return 0
	if player == MoveValidator.WHITE:
		for i in range(0, from_or_to):
			if points[i][1] == MoveValidator.BLACK and points[i][0] >= 2:
				count += 1
	else:
		for i in range(from_or_to + 1, points.size()):
			if points[i][1] == MoveValidator.WHITE and points[i][0] >= 2:
				count += 1
	return count


# === ADDITIONAL HELPER FUNCTIONS FOR COMPLETE STRATEGY ===

static func _is_best_anchor(point: int, player: int) -> bool:
	# Best anchors: opponent's 5-point (20-point) or bar-point (18-point)
	if player == MoveValidator.WHITE:
		return point == 20 or point == 18  # Enemy 5-point or bar-point
	else:
		return point == 3 or point == 5  # Enemy 5-point or bar-point


static func _get_home_point_number(point: int, player: int) -> int:
	# Return 1-6 for home board point number
	if player == MoveValidator.WHITE:
		return point + 1 if point >= 0 and point < 6 else 0
	else:
		return 24 - point if point >= 18 and point < 24 else 0


static func _count_enemy_threats(state: Dictionary, enemy: int) -> int:
	# Count enemy checkers that could threaten us
	var points = state["points"]
	var threats = 0
	for i in range(24):
		if points[i][1] == enemy and points[i][0] > 0:
			threats += points[i][0]
	var bar = state.get("bar", {})
	threats += bar.get("white" if enemy == MoveValidator.WHITE else "black", 0)
	return threats


static func _count_checkers_in_zone(state: Dictionary, player: int, start: int, end: int) -> int:
	var points = state["points"]
	var count = 0
	for i in range(start, end):
		if i >= 0 and i < 24 and points[i][1] == player:
			count += points[i][0]
	return count


static func _count_made_points_in_zone(state: Dictionary, player: int, start: int, end: int) -> int:
	var points = state["points"]
	var count = 0
	for i in range(start, end):
		if i >= 0 and i < 24 and points[i][1] == player and points[i][0] >= 2:
			count += 1
	return count


static func _count_anchors_in_zone(state: Dictionary, player: int, start: int, end: int) -> int:
	# Anchors are made points (2+) in the zone
	return _count_made_points_in_zone(state, player, start, end)


static func _count_checkers_past_point(state: Dictionary, player: int, threshold: int) -> int:
	# Count checkers that have passed a certain point
	var points = state["points"]
	var count = 0
	if player == MoveValidator.WHITE:
		# WHITE moves toward 0, so "past" means < threshold
		for i in range(0, threshold):
			if points[i][1] == player:
				count += points[i][0]
	else:
		# BLACK moves toward 23, so "past" means > threshold
		for i in range(threshold + 1, 24):
			if points[i][1] == player:
				count += points[i][0]
	return count


static func _count_longest_prime(state: Dictionary, player: int) -> int:
	# Count the longest consecutive run of made points
	var points = state["points"]
	var longest = 0
	var current = 0
	
	for i in range(24):
		if points[i][1] == player and points[i][0] >= 2:
			current += 1
			longest = max(longest, current)
		else:
			current = 0
	
	return longest
