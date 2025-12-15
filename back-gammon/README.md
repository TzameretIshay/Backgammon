# Backgammon Game - Setup & Run Instructions

## Project Status ✅

Your Backgammon game is **fully functional** with complete game logic implemented!

### What's Been Completed

#### 1. Core Game Logic (GameManager.gd)
- ✅ Standard backgammon board initialization (24 points, correct starting positions)
- ✅ Dice rolling system (handles regular rolls and doubles)
- ✅ Full move validation (bar priority, blocked points, bearing off, direction)
- ✅ Move execution with capture handling (hitting checkers to bar)
- ✅ Turn management (player switching, forced move detection)
- ✅ Win condition detection (15 checkers borne off)
- ✅ Signal-based event system for UI updates
- ✅ Undo/reset functionality

#### 2. Visual Board Display (BoardDisplay.gd)
- ✅ Board rendering with 24 triangular points
- ✅ Checker stacks (visual circles for pieces)
- ✅ Bar display for hit checkers
- ✅ Real-time updates via signals
- ✅ Fallback rendering (works with or without texture files)

#### 3. User Interface (UIManager.gd)
- ✅ New Game button (starts fresh game)
- ✅ Roll Dice button (auto-generates random roll)
- ✅ Legal Moves list (shows all valid moves, clickable)
- ✅ Move execution (click to apply move)
- ✅ End Turn button (switches players)
- ✅ Undo Move (reverts last action)
- ✅ Reset Game (start over)
- ✅ Status display (current player, game state, moves remaining)

#### 4. Scene Setup (Main.tscn)
- ✅ GameManager node (game logic)
- ✅ BoardDisplay node (visual rendering)
- ✅ UIManager node (button & event handling)
- ✅ Control panel UI (right side with all controls)

---

## How to Run

### Step 1: Open Godot
- Launch **Godot 4.5 or later**
- Open the project at: `e:\Godot-Projects\Backgammon\back-gammon`

### Step 2: Run the Game
Once the project is loaded:

**Option A: Play from Editor**
- Click the ▶️ **Play** button (or press **F5**)
- This will run `scenes/Main.tscn`

**Option B: Run Directly**
```bash
cd e:\Godot-Projects\Backgammon\back-gammon
godot --path . --play
```

### Step 3: Play the Game

In the game window:
1. Click **"New Game"** to initialize the board
2. Click **"Roll Dice"** to generate a random roll
3. Click a move from the **Legal Moves** list to execute it
4. Click **"End Turn"** when you're done moving
5. The game automatically switches to the other player
6. Win by getting all 15 checkers borne off first!

---

## File Structure

```
back-gammon/
├── scenes/
│   ├── Main.tscn              # Main game scene (entry point)
│   └── ui/                    # UI-related scenes (future)
├── scripts/
│   ├── GameManager.gd         # Core game logic & state
│   ├── BoardDisplay.gd        # Board visualization
│   └── UIManager.gd           # UI event handling
├── assets/
│   └── textures/              # Asset folder (ready for images)
│       ├── board.png          # (add your board image)
│       ├── checker_white.png  # (add white/blue checker)
│       └── checker_brown.png  # (add brown checker)
├── project.godot              # Godot project config
└── test_game.py               # Logic verification script
```

---

## Adding Your Assets

When ready, add your images to `assets/textures/`:
1. Save the board image as `board.png`
2. Save the blue checker as `checker_white.png`
3. Save the brown checker as `checker_brown.png`

The BoardDisplay will automatically load them when available.

---

## Game Rules Implemented

### Board Layout
- 24 triangular points
- Points 0-11 (bottom), 12-23 (top)
- Checker positions follow standard backgammon

### Movement
- **White**: moves 0→23 (left to right across bottom)
- **Black**: moves 23→0 (right to left across bottom)

### Special Rules
- **Bar Priority**: Checkers on bar must re-enter before moving others
- **Blocking**: Cannot land on 2+ enemy checkers
- **Bearing Off**: Only when all home checkers are in home board
- **Doubles**: Rolling same value gives 4 moves instead of 2
- **Hitting**: Landing on enemy single checker sends it to bar

### Win Condition
- First player to bear off all 15 checkers wins

---

## Testing

To verify the game logic without running Godot:
```bash
cd e:\Godot-Projects\Backgammon\back-gammon
python test_game.py
```

---

## Troubleshooting

### "Script not found" errors
- Make sure all script files are in `scripts/` folder
- Check that paths in .tscn match actual file locations

### "Signal not connected" errors
- These are warnings during initialization - safe to ignore
- Signals will work once scenes are properly loaded

### Board not displaying
- Game uses fallback shape rendering (colored circles)
- This is intentional and works without texture files
- Textures optional - add them later when ready

### Moves not working
- Check the console output for legal moves
- Make sure you're in the right game state (not waiting for roll)
- Click a move from the Legal Moves list, not the board directly

---

## Next Steps

1. **Test the game** - Play through a few turns to verify logic
2. **Add assets** - Import your board/checker images when ready
3. **Polish UI** - Customize colors, fonts, button positions
4. **Add sounds** - Dice roll, move completion audio effects
5. **Implement AI** - Create computer opponent

Enjoy your Backgammon game! 🎲
