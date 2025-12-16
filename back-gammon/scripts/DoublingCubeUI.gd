## DoublingCubeUI.gd
## UI for the doubling cube control.

extends Control

signal double_offered(player: int)
signal double_accepted()
signal double_declined()

@onready var cube_label: Label = $VBox/CubeLabel
@onready var owner_label: Label = $VBox/OwnerLabel
@onready var double_btn: Button = $VBox/DoubleBtn
@onready var offer_dialog: AcceptDialog = $CubeOfferDialog
@onready var offer_label: Label = $CubeOfferDialog/VBox/OfferLabel
@onready var accept_btn: Button = $CubeOfferDialog/VBox/HBox/AcceptBtn
@onready var decline_btn: Button = $CubeOfferDialog/VBox/HBox/DeclineBtn

var current_player: int = 0

func _ready() -> void:
	if double_btn:
		double_btn.pressed.connect(_on_double_pressed)
	if accept_btn:
		accept_btn.pressed.connect(_on_accept_pressed)
	if decline_btn:
		decline_btn.pressed.connect(_on_decline_pressed)
	update_display(1, "Center")
	double_btn.disabled = true

func update_display(value: int, owner: String) -> void:
	if cube_label:
		cube_label.text = "Cube: %d" % value
	if owner_label:
		owner_label.text = "Owner: %s" % owner

func set_double_enabled(enabled: bool, player: int) -> void:
	current_player = player
	if double_btn:
		double_btn.disabled = not enabled

func show_offer_dialog(offering_player: String, new_value: int) -> void:
	if offer_label:
		offer_label.text = "%s offers to double the stakes to %d!" % [offering_player, new_value]
	if offer_dialog:
		offer_dialog.popup_centered()

func _on_double_pressed() -> void:
	double_offered.emit(current_player)

func _on_accept_pressed() -> void:
	if offer_dialog:
		offer_dialog.hide()
	double_accepted.emit()

func _on_decline_pressed() -> void:
	if offer_dialog:
		offer_dialog.hide()
	double_declined.emit()
