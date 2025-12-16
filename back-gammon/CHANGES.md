# Backgammon (Godot 4.5.1) — Project Change Log

This file tracks notable changes, decisions, and file additions to the project. Keep entries concise, dated, and grouped by category. Prefer linking to files by their relative paths.

## Guidelines
- Use ISO date format: YYYY-MM-DD.
- Group changes under "Added", "Changed", "Fixed", "Removed".
- Reference files using workspace-relative paths.
- For generated code, include a brief rationale and any acceptance criteria.

---

## 2025-12-14

### Added
- Initial planning and Copilot generation prompt for a full-featured Backgammon game targeting Godot 4.5.1.
- Created this change log to track all project modifications: [back-gammon/CHANGES.md](back-gammon/CHANGES.md).
- Scaffolded project directories: [back-gammon/scenes/](back-gammon/scenes/) and [back-gammon/scripts/](back-gammon/scripts/).
- Added [back-gammon/scripts/GameManager.gd](back-gammon/scripts/GameManager.gd): core game state machine with signals for dice roll, move apply, turn flow, and win detection. Includes placeholders for full validation and move application logic (Copilot-ready).
- Added [back-gammon/scenes/Main.tscn](back-gammon/scenes/Main.tscn): root scene with GameManager attached; ready to instantiate child scenes (Board, UI, Dice).

## 2025-12-16

### Added
- Added gameplay scaffolding scripts: [back-gammon/scripts/GameManager.gd](back-gammon/scripts/GameManager.gd), [back-gammon/scripts/MoveValidator.gd](back-gammon/scripts/MoveValidator.gd), [back-gammon/scripts/Board.gd](back-gammon/scripts/Board.gd), [back-gammon/scripts/Dice.gd](back-gammon/scripts/Dice.gd), [back-gammon/scripts/UI.gd](back-gammon/scripts/UI.gd), [back-gammon/scripts/Checker.gd](back-gammon/scripts/Checker.gd).
- Added scene scaffolds: [back-gammon/scenes/Board.tscn](back-gammon/scenes/Board.tscn), [back-gammon/scenes/Dice.tscn](back-gammon/scenes/Dice.tscn), [back-gammon/scenes/UI.tscn](back-gammon/scenes/UI.tscn), [back-gammon/scenes/Checker.tscn](back-gammon/scenes/Checker.tscn).
- Updated [back-gammon/scenes/Main.tscn](back-gammon/scenes/Main.tscn) to instantiate Board/Dice/UI and wire exported paths for GameManager.

### Changed
- Rebuilt GameManager to orchestrate turn flow, dice, move application, and integrate MoveValidator with documented signals. Added UI/dice result updates.
- Implemented Board visuals, checker stacking, bar/bear-off targeting, and drag release mapping to move attempts.
- Implemented draggable checkers with hit shapes and drawn discs.
- Enhanced MoveValidator bear-off overshoot handling using state-aware “checker behind” checks.
- UI now shows current player and dice; wired Dice UI result display.
- Added drag-start highlighting of legal destinations (points and bear-off) in Board.
- Added pop-in animation for checkers, dice wobble on roll/update, and optional move/roll SFX hooks.
- Added AI stub (scripts/AI.gd) with simple heuristic; GameManager can auto-play when ai_enabled and ai_player are set.
- Added tweened checker move animation before redraw; board now skips immediate redraw to show movement.
- Improved AI scoring: stronger bear-off/hit priority, bar re-entry bonus, blot avoidance, rewards making points, penalizes advancing into blocks.
- Bar hits/entries now tween via Board when available.
- Added hit flash indicator for captured checkers in [back-gammon/scripts/Board.gd](back-gammon/scripts/Board.gd).
- Added AI turn pacing with configurable delay and waits for board animation in [back-gammon/scripts/GameManager.gd](back-gammon/scripts/GameManager.gd).
- **Added game mode selection:** Created [back-gammon/scenes/MainMenu.tscn](back-gammon/scenes/MainMenu.tscn) and [back-gammon/scripts/MainMenu.gd](back-gammon/scripts/MainMenu.gd) for choosing 1-player (vs AI) or 2-player (local) modes.
- **Comprehensive AI strategy implementation:** Completely rebuilt [back-gammon/scripts/AI.gd](back-gammon/scripts/AI.gd) with proper backgammon strategy including:
  - **Running Game:** Race strategy when ahead (minimizes contact, prioritizes distance).
  - **Blocking Game:** Prime building, anchor establishment, hitting blots.
  - **Phase Detection:** Opening moves (securing 5-point, bar point), mid-game tactics, bearing off optimization.
  - **Strategic Concepts:** Making points, building 6-point primes, establishing anchors (opponent's 20-point, 21-point), blot exposure risk calculation.
  - **Pip counting:** Evaluates race position to determine running vs blocking strategy.
- Created [back-gammon/scenes/Launcher.tscn](back-gammon/scenes/Launcher.tscn) and [back-gammon/scripts/Launcher.gd](back-gammon/scripts/Launcher.gd) as new root scene managing menu/game transitions.
- Updated [back-gammon/project.godot](back-gammon/project.godot) to launch via Launcher scene instead of directly to game.
- **Master-level AI upgrade:** Enhanced [back-gammon/scripts/AI.gd](back-gammon/scripts/AI.gd) to follow complete backgammon strategy guide:
  - **Opening Book:** Optimal plays for all opening rolls (3-1 makes 5-point, 6-1 makes bar-point, etc.) and doubles.
  - **The Golden Points:** Massive priority for 5-point (800 pts) and bar-point (700 pts); heavy penalties (-500) for making 1/2-points early.
  - **The Three Don'ts:** Penalties for unnecessary blots (-150+), breaking key points (-400 for 5-point), and stacking (>4 checkers).
  - **Tactical Patterns:** Detects and executes blitz (aggressive hitting + board closing), priming (4-6 consecutive points), holding games (anchor + wait), and back games (2+ anchors).
  - **Point-Making Priority:** 5-point > bar-point > 4-point > opponent's 5-point anchor > 3-point > 8/9-point for priming.
  - **Best Anchors:** Prioritizes opponent's 5-point (20-point) and bar-point (18-point) for defensive/offensive play.
  - **Builder Strategy:** Rewards positioning checkers in outer board (7-12) for flexibility.
  - **Bearing Off:** Clears high points first, avoids blots when opponent threatens, efficient distribution.
  - **Phase-Specific:** Opening game (first 8 rolls), mid-game tactics, bearing off optimization with distinct priorities.

### Fixed
- Corrected block-counting helper return value in [back-gammon/scripts/AI.gd](back-gammon/scripts/AI.gd) to prevent runtime errors during AI scoring.
- Fixed Godot 4 API compatibility: replaced `update()` with `queue_redraw()` in [back-gammon/scripts/Board.gd](back-gammon/scripts/Board.gd).
- Fixed input handling: replaced `accept_event()` with `get_viewport().set_input_as_handled()` in [back-gammon/scripts/Checker.gd](back-gammon/scripts/Checker.gd).

### Next Steps
- Flesh out Board visuals and checker drag/drop to emit `move_attempted`.
- Enhance MoveValidator overshoot checking for bear-off edge cases.
- Wire sounds/animations and polish UI layout.

### Planned Structure (for traceability)
- Scenes: `scenes/Main.tscn`, `scenes/Board.tscn`, `scenes/Checker.tscn`, `scenes/Dice.tscn`, `scenes/UI.tscn`.
- Scripts: `scripts/GameManager.gd`, `scripts/MoveValidator.gd`, `scripts/Board.gd`, `scripts/Checker.gd`, `scripts/Dice.gd`, `scripts/UI.gd`, optional `scripts/AI.gd`.
- Data Model: `GameState` with points, bar, bear-off, current player, dice, remaining moves.

### Decisions
- Focus first on local 2-player human vs human with complete rules and validation; AI is optional and can be incremental.
- Use Godot 4.5.1 APIs (GDScript 2.0), typed signals and arrays.
- Keep generated code well-documented with comments on key logic and signals.

### Next Steps
- Scaffold `scenes/` and `scripts/` directories.
- Generate minimal `Main.tscn` and `GameManager.gd` to bootstrap Copilot-driven expansion.
- Set `Main.tscn` as the main scene and verify startup.

---

## Template (copy for future entries)

### YYYY-MM-DD

#### Added
- Short bullet per addition with path links.

#### Changed
- Describe behavior or API changes.

#### Fixed
- Describe bug fixes; reference the file and a brief root cause.

#### Removed
- Note removed files or deprecated features.
