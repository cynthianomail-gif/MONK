extends Node
## windowed 連拍 21點 Yakuza UI 三階段（下注籌碼/動作選單/結算面板），存專案根目錄。
## 跑法：Godot_console.exe --path D:\monk\MONK res://test/CaptureBlackjackUI.tscn -- smoke

func _ready() -> void:
	if not OS.get_cmdline_user_args().has("smoke"):
		return
	var g: Node = (load("res://src/screens/Minigames/Blackjack.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(g)
	for i in 10:
		await get_tree().process_frame
	# 下注 3 枚（籌碼淡入下注圈）
	for i in 3:
		g._add_bet_chip()
		for f in 10:
			await get_tree().process_frame
	await _shot("res://_blackjack_bet_shot.png")
	# 發牌動畫 → 等進玩家回合（左側動作選單）
	g._try_deal()
	var dealt: int = 0
	while g._phase in ["dealing", "bet"] and dealt < 600:
		await get_tree().process_frame
		dealt += 1
	for f in 10:
		await get_tree().process_frame
	await _shot("res://_blackjack_action_shot.png")
	# 停牌 → 莊家補牌 → RESULT 結算面板
	if g._phase == "player":
		g._menu_do("stand")
	var waited: int = 0
	while not g._panel.visible and waited < 600:
		await get_tree().process_frame
		waited += 1
	for f in 25:
		await get_tree().process_frame
	await _shot("res://_blackjack_result_shot.png")
	get_tree().quit()

func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(path)
	print("BJ_UI_SHOT_SAVED ", path, " ", img.get_width(), "x", img.get_height())
