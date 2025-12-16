## TutorialOverlay.gd
## Simple guided overlay that highlights key actions: roll, enter from bar, hit, bear off.

extends Control

signal tutorial_closed

@export var roll_button_path: NodePath
@export var board_highlight_rect: Rect2 = Rect2(Vector2(20, 20), Vector2(680, 420))
@export var bearoff_highlight_rect: Rect2 = Rect2(Vector2(640, 70), Vector2(70, 320))

@onready var _title_label: Label = $Panel/VBox/TitleLabel
@onready var _body_label: Label = $Panel/VBox/BodyLabel
@onready var _step_label: Label = $Panel/VBox/StepLabel
@onready var _next_btn: Button = $Panel/VBox/Buttons/NextButton
@onready var _back_btn: Button = $Panel/VBox/Buttons/BackButton
@onready var _skip_btn: Button = $Panel/VBox/Buttons/SkipButton
@onready var _replay_btn: Button = $Panel/VBox/Buttons/ReplayButton
@onready var _highlight: ColorRect = $HighlightRect

var _steps: Array = []
var _current_step: int = 0

func _ready() -> void:
	_build_steps()
	_bind_buttons()
	restart()


func _build_steps() -> void:
	_steps = [
		{
			"title": "Roll the dice",
			"body": "Tap Roll to start your turn. Roll before moving any checker.",
			"target_path": roll_button_path
		},
		{
			"title": "Enter from the bar",
			"body": "If hit, re-enter from the bar first. Legal targets will glow; use the board area shown here.",
			"target_rect": board_highlight_rect
		},
		{
			"title": "Hit blots",
			"body": "Landing on a lone opposing checker sends it to the bar. They must re-enter before other moves.",
			"target_rect": board_highlight_rect
		},
		{
			"title": "Bear off",
			"body": "When all checkers are home, move them off using the bear-off lane on the right.",
			"target_rect": bearoff_highlight_rect
		}
	]


func _bind_buttons() -> void:
	if _next_btn:
		_next_btn.pressed.connect(_on_next)
	if _back_btn:
		_back_btn.pressed.connect(_on_back)
	if _skip_btn:
		_skip_btn.pressed.connect(_on_skip)
	if _replay_btn:
		_replay_btn.pressed.connect(restart)


func restart() -> void:
	_current_step = 0
	show()
	_update_step()


func _on_next() -> void:
	if _current_step < _steps.size() - 1:
		_current_step += 1
		_update_step()
	else:
		hide()
		tutorial_closed.emit()


func _on_back() -> void:
	if _current_step <= 0:
		return
	_current_step -= 1
	_update_step()


func _on_skip() -> void:
	hide()
	tutorial_closed.emit()


func _update_step() -> void:
	if _steps.is_empty():
		return
	var step = _steps[_current_step]
	if _title_label:
		_title_label.text = step.get("title", "Tutorial")
	if _body_label:
		_body_label.text = step.get("body", "")
	if _step_label:
		_step_label.text = "Step %d/%d" % [_current_step + 1, _steps.size()]
	if _back_btn:
		_back_btn.disabled = _current_step == 0
	if _next_btn:
		_next_btn.text = "Done" if _current_step == _steps.size() - 1 else "Next"
	_update_highlight(step)


func _update_highlight(step: Dictionary) -> void:
	var rect := Rect2()
	if step.has("target_path"):
		var target = get_node_or_null(step["target_path"])
		if target and target is Control:
			var ctrl := target as Control
			rect = Rect2(ctrl.get_global_rect())
	elif step.has("target_rect"):
		rect = Rect2(step["target_rect"])
	if rect.size == Vector2.ZERO:
		_highlight.hide()
		return
	_highlight.show()
	var local_pos = get_global_transform().affine_inverse() * rect.position
	_highlight.position = local_pos
	_highlight.size = rect.size
