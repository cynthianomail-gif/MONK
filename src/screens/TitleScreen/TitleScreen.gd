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
	# 新遊戲：重置狀態（出生點＝古廟），直接由主線引擎跑第一章。
	# ch1 第一幕就是開場過場（神廟倒塌），故不需另外播，避免雙播。
	GameManager.new_game()
	MainQuestManager.continue_story()

func _on_continue_pressed() -> void:
	SaveManager.load_game()
	SceneRouter.go_to_map()

func _on_quit_pressed() -> void:
	get_tree().quit()
