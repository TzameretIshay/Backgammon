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
