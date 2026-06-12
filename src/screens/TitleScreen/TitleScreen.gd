extends Control

@onready var start_button: Button    = %StartButton
@onready var continue_button: Button = %ContinueButton
@onready var quit_button: Button     = %QuitButton

func _ready() -> void:
	AudioManager.switch_bgm("title_theme")
	continue_button.visible = SaveManager.has_save()
	start_button.pressed.connect(_on_start_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	start_button.grab_focus()

func _on_start_pressed() -> void:
	SceneRouter.go_to_map()

func _on_continue_pressed() -> void:
	SaveManager.load_game()
	SceneRouter.go_to_map()

func _on_quit_pressed() -> void:
	get_tree().quit()
