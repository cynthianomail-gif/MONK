extends Node
## windowed 連拍遊藝場五小遊戲（飛鏢/輪盤/21點/打擊/保齡球）各一張，存專案根目錄。
## 跑法：Godot_console.exe --path D:\monk\MONK res://test/CaptureParlorGames.tscn -- smoke

const GAMES: Array = [
	["res://src/screens/Minigames/Darts.tscn", "res://_darts_shot.png"],
	["res://src/screens/Minigames/Roulette.tscn", "res://_roulette_shot.png"],
	["res://src/screens/Minigames/Blackjack.tscn", "res://_blackjack_shot.png"],
	["res://src/screens/Minigames/Batting.tscn", "res://_batting_shot.png"],
	["res://src/screens/Minigames/Bowling.tscn", "res://_bowling_shot.png"],
]

func _ready() -> void:
	if not OS.get_cmdline_user_args().has("smoke"):
		return
	for entry in GAMES:
		var s: Node = (load(String(entry[0])) as PackedScene).instantiate()
		get_tree().root.add_child.call_deferred(s)
		for i in 45:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png(String(entry[1]))
		print("PARLOR_SHOT_SAVED ", entry[1], " ", img.get_width(), "x", img.get_height())
		s.queue_free()
		await get_tree().process_frame
	get_tree().quit()
