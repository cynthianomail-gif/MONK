extends Node
## 驗證 parlor 貼圖 runtime 載入（headless）。
func _ready() -> void:
	var base := "res://assets/art_direction/new_ink_shrine_style/minigames/parlor/"
	for f in ["darts_board_game_ready.png", "roulette_wheel_top_game_ready.png", "card_back_game_ready.png", "parlor_bg_wide_v2.png"]:
		var p: String = base + f
		var ex := ResourceLoader.exists(p)
		var tex := load(p)
		print("TEXCHECK %s exists=%s loaded=%s" % [f, ex, tex != null])
	get_tree().quit(0)
