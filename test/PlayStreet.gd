extends Node
## 直接進西門街、用正牌 3D 無戒自由走動（方向鍵）。不截圖、不自動關。
## 跑法（視窗）：Godot_..._console.exe --path D:/monk/MONK res://test/PlayStreet.tscn

func _ready() -> void:
	await get_tree().process_frame
	get_tree().current_scene = null
	GameManager.new_game()
	SceneRouter.go_to_map()
	print("PLAY_STREET ready — 方向鍵走動，Esc 關視窗")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit(0)
