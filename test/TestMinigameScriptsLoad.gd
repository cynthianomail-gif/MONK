extends Node
## 全小遊戲場景載入回歸：逐一 load+instantiate 每款小遊戲 .tscn，
## 抓「腳本 parse/compile 失敗」這類整檔炸掉的問題（2026-07-08 發現
## Bowling/Roulette/OfferingToss 從未被任何測試載入過的覆蓋缺口而補）。
## 只驗證「載得起來」，不跑玩法——玩法各自有專屬測試。

const SCENES := [
	"res://src/screens/Minigames/Batting.tscn",
	"res://src/screens/Minigames/BeggarChallenge.tscn",
	"res://src/screens/Minigames/Blackjack.tscn",
	"res://src/screens/Minigames/Bowling.tscn",
	"res://src/screens/Minigames/Darts.tscn",
	"res://src/screens/Minigames/OfferingToss.tscn",
	"res://src/screens/Minigames/Roulette.tscn",
	"res://src/screens/Minigames/SoupCarry.tscn",
	"res://src/screens/Minigames/WoodenFishRhythm.tscn",
]

func _ready() -> void:
	GameManager.new_game()
	var failed: Array = []
	for path in SCENES:
		var ps := load(path) as PackedScene
		if ps == null:
			failed.append("%s：載入失敗" % path)
			continue
		var node := ps.instantiate()
		if node == null:
			failed.append("%s：instantiate 失敗" % path)
			continue
		if node.get_script() == null:
			failed.append("%s：腳本掛載失敗（可能 parse error 被剝除）" % path)
		add_child(node)
		await get_tree().process_frame
		node.queue_free()
		await get_tree().process_frame
	if failed.is_empty():
		print("TEST PASS: 9 款小遊戲場景全部載入+instantiate OK")
		get_tree().quit(0)
	else:
		for f in failed:
			push_error("TEST FAIL: %s" % f)
		get_tree().quit(1)
