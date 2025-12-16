## Dice.gd
## Simple UI wrapper for rolling dice; emits when the player clicks roll.

extends Control

signal roll_pressed

@onready var roll_button: Button = $RollButton
@onready var result_label: Label = $ResultLabel
@onready var _anim_target: Control = self

func _ready() -> void:
	if roll_button:
		roll_button.pressed.connect(_on_roll_button)
	set_result([])


func _on_roll_button() -> void:
	roll_pressed.emit()
	_play_wobble()


func set_result(values: Array) -> void:
	if result_label == null:
		return
	if values.is_empty():
		result_label.text = "Roll: --"
	else:
		result_label.text = "Roll: %s" % str(values)
	_play_wobble()


func _play_wobble() -> void:
	var tw = create_tween()
	tw.tween_property(_anim_target, "scale", Vector2(1.08, 1.08), 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_anim_target, "scale", Vector2.ONE, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
