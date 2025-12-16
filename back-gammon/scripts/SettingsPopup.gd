## SettingsPopup.gd
## Simple settings dialog for volumes, animation speed, and theme selection.

extends Control

signal settings_applied(settings: Dictionary)
signal settings_closed

@onready var master_slider: HSlider = $Panel/VBox/MasterRow/MasterSlider
@onready var sfx_slider: HSlider = $Panel/VBox/SfxRow/SfxSlider
@onready var anim_slider: HSlider = $Panel/VBox/AnimRow/AnimSlider
@onready var theme_option: OptionButton = $Panel/VBox/ThemeRow/ThemeOption
@onready var apply_btn: Button = $Panel/VBox/Buttons/ApplyBtn
@onready var cancel_btn: Button = $Panel/VBox/Buttons/CancelBtn

var _themes := ["Classic", "Dark", "Ocean"]

func _ready() -> void:
	if theme_option:
		theme_option.clear()
		for i in range(_themes.size()):
			theme_option.add_item(_themes[i], i)
	if apply_btn:
		apply_btn.pressed.connect(_on_apply)
	if cancel_btn:
		cancel_btn.pressed.connect(_on_cancel)
	visible = false


func show_with(settings: Dictionary) -> void:
	master_slider.value = float(settings.get("master_volume", 1.0)) if master_slider else 1.0
	sfx_slider.value = float(settings.get("sfx_volume", 1.0)) if sfx_slider else 1.0
	anim_slider.value = float(settings.get("anim_speed", 1.0)) if anim_slider else 1.0
	var theme_name: String = settings.get("theme", "Classic")
	if theme_option:
		var idx = _themes.find(theme_name)
		theme_option.select(idx if idx != -1 else 0)
	show()


func _on_apply() -> void:
	var theme_name = _themes[theme_option.get_selected_id()] if theme_option else "Classic"
	var payload = {
		"master_volume": master_slider.value if master_slider else 1.0,
		"sfx_volume": sfx_slider.value if sfx_slider else 1.0,
		"anim_speed": anim_slider.value if anim_slider else 1.0,
		"theme": theme_name
	}
	hide()
	settings_applied.emit(payload)


func _on_cancel() -> void:
	hide()
	settings_closed.emit()
