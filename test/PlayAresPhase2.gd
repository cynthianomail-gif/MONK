extends Node
## 實機視窗 demo：進阿瑞斯戰鬥當背景 → 循環重播二階變身過場（疊在戰鬥上、含畫面＋audio.ogg 聲音）。
## 給人反覆觀看播放節奏/運鏡/聲音用，非自動測試。看夠了直接關視窗即可（不會自動關閉）。
## 跑法（有視窗，需 GPU）：
##   tools/godot/Godot_v4.5-stable_win64.exe --path D:/monk/MONK res://test/PlayAresPhase2.tscn

const BATTLE := "res://src/screens/BattleScreen/BattleScreen.tscn"

func _ready() -> void:
	await get_tree().process_frame
	var inst: Node = (load(BATTLE) as PackedScene).instantiate()
	add_child(inst)
	await get_tree().process_frame
	inst.setup("ares")
	# 先看一下黑西裝阿瑞斯站在熔鑄爐戰場
	await get_tree().create_timer(2.0).timeout
	print("DEMO: 開始循環播放二階變身過場（有聲音）。看夠了關視窗即可。")
	while true:
		await SceneRouter.play_battle_cutscene("ares_phase2")
		# 兩次播放之間留 1.5 秒間隔
		await get_tree().create_timer(1.5).timeout
