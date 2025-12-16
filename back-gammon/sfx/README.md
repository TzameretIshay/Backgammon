# Sound Effects for Backgammon

This folder should contain the following sound effect files:

1. **dice_roll.wav** - Sound of dice being rolled
2. **checker_move.wav** - Sound of a checker sliding across the board  
3. **checker_hit.wav** - Sound when a checker is captured/hit
4. **game_win.wav** - Victory sound when a game is won

## Where to get sounds:

You can create or find these sounds from:
- **Freesound.org** (CC0/public domain sounds)
- **OpenGameArt.org** (free game audio)
- **Audacity** (create simple sounds)
- **BFXR** / **SFXR** (procedural sound generators)

## Format:

- Format: WAV or OGG
- Sample rate: 22050Hz or 44100Hz
- Mono or Stereo
- Keep files small (< 100KB each)

## Integration:

Once you add the sound files here, they will automatically be imported by Godot and can be assigned to the GameManager's sfx_move and sfx_roll properties in the Inspector.
