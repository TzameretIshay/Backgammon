## Launcher.gd
## Root scene that manages menu and game transitions.

extends Node

@export var menu_path: NodePath = NodePath("MainMenu")
@export var game_path: NodePath = NodePath("Game")

var _menu: Control
var _game: Node

func _ready() -> void:
	_menu = get_node_or_null(menu_path)
	_game = get_node_or_null(game_path)
	
	if _menu:
		_menu.visible = true
		_menu.connect("mode_selected", Callable(self, "_on_mode_selected"))
	
	if _game:
		_set_game_visibility(false)


func _on_mode_selected(mode: String, match_length: int = 5, difficulty: String = "Medium") -> void:
	if _menu:
		_menu.visible = false
	
	if _game:
		_set_game_visibility(true)
		if _game.has_method("start_game_with_mode"):
			_game.start_game_with_mode(mode, match_length, difficulty)


func show_menu() -> void:
	if _menu:
		_menu.visible = true
	if _game:
		_set_game_visibility(false)
		# Reset game state by calling new_game on GameManager
		var game_manager = _game.get_child(0) if _game.get_child_count() > 0 else null
		if game_manager and game_manager.has_method("new_game"):
			game_manager.call("new_game")
		# Update UI status
		var ui = _game.get_node_or_null("UI")
		if ui and ui.has_method("set_status"):
			ui.call("set_status", "Returned to menu. Select a game mode to continue.")


func _set_game_visibility(is_visible: bool) -> void:
	if not _game:
		return
	# Game node is a Node, not CanvasItem, so we hide/show its children
	for child in _game.get_children():
		if child is CanvasItem:
			child.visible = is_visible
	# Also control processing
	_game.process_mode = Node.PROCESS_MODE_INHERIT if is_visible else Node.PROCESS_MODE_DISABLED
