extends Control

const SAVE_SLOT_PICKER := preload("res://src/ui/SaveSlotPicker.gd")

@onready var start_button: Button    = %StartButton
@onready var continue_button: Button = %ContinueButton
@onready var quit_button: Button     = %QuitButton

func _ready() -> void:
	AudioManager.switch_bgm("title_theme")
	continue_button.visible = _any_slot_has_save()
	start_button.pressed.connect(_on_start_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	start_button.grab_focus()

func _any_slot_has_save() -> bool:
	for n in range(1, SaveManager.SLOT_COUNT + 1):
		if SaveManager.slot_exists(n):
			return true
	return false

func _filled_slot_count() -> int:
	var count := 0
	for n in range(1, SaveManager.SLOT_COUNT + 1):
		if SaveManager.slot_exists(n):
			count += 1
	return count

func _on_start_pressed() -> void:
	# 新遊戲：重置狀態（出生點＝古廟），直接由主線引擎跑第一章。
	# ch1 第一幕就是開場過場（神廟倒塌），故不需另外播，避免雙播。
	# 先把 active_slot 指到空槽，之後的自動存檔才不會蓋掉既有進度。
	SaveManager.select_slot_for_new_game()
	GameManager.new_game()
	MainQuestManager.continue_story()

func _on_continue_pressed() -> void:
	# 只有一個槽有資料就直接載（不打斷老玩家；可能不是 active_slot，故找出那一槽直接載）；
	# 多個槽有資料才開選擇 UI。
	if _filled_slot_count() <= 1:
		for n in range(1, SaveManager.SLOT_COUNT + 1):
			if SaveManager.slot_exists(n):
				SaveManager.load_from_slot(n)
				break
		SceneRouter.go_to_map()
		return
	var picker := SAVE_SLOT_PICKER.new()
	get_tree().root.add_child(picker)
	picker.slot_chosen.connect(func(_n: int):
		SceneRouter.go_to_map()
	)
	picker.closed.connect(func():
		if is_instance_valid(picker):
			picker.queue_free()
	)
	picker.open("load")

func _on_quit_pressed() -> void:
	get_tree().quit()
