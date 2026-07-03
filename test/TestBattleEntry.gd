extends Node
## headless 驗證：進戰全鏈路（SceneRouter.go_to_battle → 換場 → BattleManager.setup）。
## 對應 bug：實機戰鬥畫面全黑、只剩 PlayerPanel 預設文字 → 懷疑 setup 未被呼叫。
## 跑法：Godot --headless res://test/TestBattleEntry.tscn

class Runner extends Node:
	func _ready() -> void:
		_run()

	func _run() -> void:
		await get_tree().process_frame
		await SceneRouter.go_to_battle("street_punk")
		for i in 5:
			await get_tree().process_frame
		var ok := true
		var cs := get_tree().current_scene
		if cs == null or not cs.is_in_group("battle_manager"):
			print("FAIL: current_scene 不是 BattleScreen，而是 ", cs)
			ok = false
		else:
			if cs.get("enemy_combatants") == null or (cs.enemy_combatants as Array).is_empty():
				print("FAIL: setup 未生效（enemy_combatants 空）")
				ok = false
			var bg := cs.get_node_or_null("BattleUI/BattleBg") as TextureRect
			if bg == null or bg.texture == null:
				print("FAIL: BattleBg 無貼圖（黑畫面重現）")
				ok = false
			var ea := cs.get_node_or_null("BattleUI/EnemyArea")
			if ea == null or ea.get_child_count() == 0:
				print("FAIL: EnemyArea 沒有敵人面板")
				ok = false
			var pf := cs.get_node_or_null("BattleUI/PlayerFigure") as TextureRect
			if pf == null or pf.texture == null:
				print("FAIL: PlayerFigure 無立繪")
				ok = false
		print("BATTLE_ENTRY_TEST: ", "ALL PASS" if ok else "HAS FAILURES")
		get_tree().quit(0 if ok else 1)

func _ready() -> void:
	# 測試場景自己會被 change_scene_to_file 釋放，邏輯要掛在 root 下的獨立節點才能活過換場。
	var r := Runner.new()
	get_tree().root.add_child.call_deferred(r)
