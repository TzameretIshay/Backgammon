## SoundGenerator.gd
## Generates simple procedural sound effects for the game.

class_name SoundGenerator extends Node

static func create_dice_roll_sound() -> AudioStreamGenerator:
	"""Create a rattling dice sound."""
	var stream = AudioStreamGenerator.new()
	stream.mix_rate = 22050.0
	stream.buffer_length = 0.3
	return stream

static func create_checker_move_sound() -> AudioStreamGenerator:
	"""Create a sliding/clicking checker sound."""
	var stream = AudioStreamGenerator.new()
	stream.mix_rate = 22050.0
	stream.buffer_length = 0.15
	return stream

static func create_checker_hit_sound() -> AudioStreamGenerator:
	"""Create an impact/hit sound."""
	var stream = AudioStreamGenerator.new()
	stream.mix_rate = 22050.0
	stream.buffer_length = 0.2
	return stream

static func create_win_sound() -> AudioStreamGenerator:
	"""Create a victory fanfare sound."""
	var stream = AudioStreamGenerator.new()
	stream.mix_rate = 22050.0
	stream.buffer_length = 0.5
	return stream

# Note: AudioStreamGenerator requires manual playback buffer filling
# For simple placeholder sounds, we'll use a simpler approach with RandomNumberGenerator
