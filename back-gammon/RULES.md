# Backgammon Game - Official Rules Implementation

## Status: Following backgammongalaxy.com Official Rules

### ✅ IMPLEMENTED RULES

#### 1. **Board Setup**
- ✅ 24 triangular points divided into 4 quadrants
- ✅ 2 dice, 15 checkers per player, 1 doubling cube (for future)
- ✅ Correct starting position:
  - White: 2 on point 24, 5 on 13, 3 on 8, 5 on 6
  - Black: Mirror opposite (2 on 1, 5 on 12, 3 on 17, 5 on 19)
- ✅ White moves counter-clockwise (0→23), Black clockwise (23→0)

#### 2. **Opening Roll** ⭐ NEW
- ✅ Each player rolls 1 die
- ✅ Highest roll wins the opening
- ✅ If equal, both players reroll
- ✅ Winner plays the rolled combination (e.g., if White rolled 4, Black rolled 2, White plays [4,2])

#### 3. **Dice Rolling**
- ✅ Roll 2 dice normally
- ✅ Doubles: same number gives 4 moves (e.g., double 3 = four 3s)
- ✅ Must use both dice if possible
- ✅ Turn ends only after all moves used or no legal moves remain

#### 4. **Movement**
- ✅ Checkers move according to die roll
- ✅ Cannot land on points with 2+ opponent checkers
- ✅ Can stack unlimited checkers on unblocked points
- ✅ Direction: White 0→23, Black 23→0 (opposite directions)

#### 5. **Hitting Checkers** ✅
- ✅ Landing on single opponent checker sends it to bar
- ✅ Opponent must re-enter from bar before moving other checkers
- ✅ Re-entry into opponent's home board (points 0-5 for Black entering, 18-23 for White entering)
- ✅ Cannot re-enter if entry point blocked by 2+ opponent checkers

#### 6. **Bearing Off** ⭐ IMPROVED
- ✅ Only when ALL checkers in home board
  - White home: points 18-23
  - Black home: points 0-5
- ✅ Higher roll rule: If rolling higher than highest checker point, must remove from backmost point
- ✅ Example: If White has checkers on 20, 21, 22 and rolls 6, must remove from point 18 (if checker there) or point 20

#### 7. **Forced Moves** ⭐ NEW
- ✅ MUST use both dice if possible
- ✅ If both cannot be used, MUST use higher die
- ✅ In bearing off, can play lower die first which may enable higher die
- ✅ Game validates and shows available legal moves only

#### 8. **Win Condition**
- ✅ First to bear off all 15 checkers wins
- ✅ Game detects win immediately and announces

---

### 📋 RULES REFERENCE FROM BACKGAMMONGALAXY.COM

#### Anchors & Primes
- 2+ checkers on a point = "anchor" (blocks opponent)
- Adjacent anchors = "prime" (can trap opponent checkers)

#### Point System (Future Implementation)
- **Single**: Opponent has 1-14 checkers borne off = 1 point
- **Gammon**: Opponent has 0 checkers borne off = 2 points  
- **Backgammon**: Opponent has checkers on bar or in your home board = 3 points

#### Doubling Cube (Not yet implemented)
- Offered when advantage clear, before rolling dice
- Sides: 2, 4, 8, 16, 32, 64
- Can refuse double (lose current points) or accept (own the cube)

#### Strategies (For future AI/advanced play)
1. **Prime**: Build blocking wall
2. **Blitz**: Hit and close out opponent
3. **Race**: Pure speed game
4. **Contact/Holding Game**: Maintain anchor in opponent's home

---

### 🎮 HOW TO PLAY (Current Implementation)

1. **Click "New Game"**
   - Initializes board with standard starting position

2. **Opening Roll Phase**
   - Click "Roll Dice" - player rolls 1 die
   - Other player rolls 1 die
   - Highest wins and plays both dice values

3. **Normal Turn**
   - Click "Roll Dice" to roll 2 dice
   - Click a white checker to select it (yellow highlight)
   - Green circles show legal moves
   - Click a green circle to move there
   - Continue moving until dice used or no legal moves

4. **End Turn**
   - Click "End Turn" to pass to opponent
   - Automatically switches player

5. **Win Game**
   - Bear off all 15 checkers first
   - Game announces winner

---

### 🔧 TECHNICAL IMPLEMENTATION

**Game States:**
```
OPENING_ROLL → WAITING_FOR_ROLL → ROLLED_DICE → SELECTING_MOVE → TURN_COMPLETE → (back to WAITING_FOR_ROLL)
```

**Key Methods:**
- `roll_opening_dice()` - Opening roll (1 die per player)
- `roll_dice()` - Normal roll (2 dice)
- `get_legal_moves()` - Calculate valid moves
- `request_move()` - Validate and execute move
- `can_bear_off()` - Check bearing off readiness
- `get_bear_off_moves()` - Valid bearing off moves with higher roll rule

---

### 📝 VALIDATION

**Current Features Validated Against Rules:**
- ✅ Board layout matches official diagram
- ✅ Starting position correct (2-24, 5-13, 3-8, 5-6)
- ✅ Movement directions correct
- ✅ Hitting mechanics correct
- ✅ Blocking (2+ checker) correct
- ✅ Bar re-entry correct
- ✅ Bearing off only in home board
- ✅ Win condition (all 15 borne off)
- ✅ Opening roll sequence (highest wins)
- ✅ Doubles (4 moves)
- ✅ Legal move display

---

### 🚀 FUTURE ENHANCEMENTS

1. **Doubling Cube** - Add stakes multiplier
2. **Point Scoring** - Track single/gammon/backgammon
3. **AI Opponent** - Computer player with strategy
4. **Sound Effects** - Dice roll and move sounds
5. **Animation** - Smooth checker movement
6. **Undo History** - Multiple undo steps
7. **Match Play** - Best of N games
8. **Pip Counting** - Calculate race advantage

---

**Last Updated:** December 15, 2025  
**Rules Source:** https://www.backgammongalaxy.com/how-to-play-backgammon  
**Game Version:** 1.0 (Official Rules Compliant)
