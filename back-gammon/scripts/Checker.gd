extends Node2D

@export var point_index: int = -1
@export var color_id: int = 0  # 0=white, 1=black

var is_selected := false

func _draw() -> void:
	# Draw a simple checker disc; colors are high-contrast for clarity.
	var fill = Color(0.92, 0.92, 0.92) if color_id == 0 else Color(0.1, 0.1, 0.1)
	var outline = Color(0.2, 0.2, 0.2) if color_id == 0 else Color(0.8, 0.8, 0.8)
	draw_circle(Vector2.ZERO, 28, outline)
	draw_circle(Vector2.ZERO, 24, fill)
	
	# Draw selection ring if selected
	if is_selected:
		draw_circle(Vector2.ZERO, 30, Color(0, 1, 1, 0.8))


func set_selected(selected: bool) -> void:
	is_selected = selected
	queue_redraw()
