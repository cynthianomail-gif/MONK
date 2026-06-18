extends Node
## 進戰鬥 → 截圖，看戰鬥畫面美術（背景／敵Boss立繪／玩家立繪／暗金霓虹框）。
## 用有視窗的 Godot 跑（非 headless，需 GPU 渲染），存 PNG 到專案根。

const BATTLE := "res://src/screens/BattleScreen/BattleScreen.tscn"

func _ready() -> void:
	await get_tree().process_frame  # 第一張 capture 前先過一幀，避免 first-capture 渲染成黑
	await _capture("ares", "res://_cap_battle_ares.png", false)
	await _capture("ares", "res://_cap_battle_ares_phase2.png", true)
	await _capture("pantheon_guard", "res://_cap_battle_guard.png", false)
	print("BATTLE_CAPTURE_DONE")
	get_tree().quit(0)

func _capture(enemy_id: String, out_path: String, phase2: bool) -> void:
	var svc := SubViewport.new()
	svc.size = Vector2i(1920, 1080)
	svc.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_tree().root.add_child.call_deferred(svc)
	await get_tree().process_frame
	var inst: Node = (load(BATTLE) as PackedScene).instantiate()
	svc.add_child(inst)
	await get_tree().process_frame
	inst.setup(enemy_id)
	for i in 24:
		await get_tree().process_frame
	if phase2 and inst._boss != null:
		# 與遊戲一致：phase2 走 cut/ 去背站姿（資料裡是原 jpg bust）
		var ph2 := BattleArt.resolve_figure_path(BattleArt.BOSS_DIR, String(inst._boss.portrait_moods.get("phase2", "")).get_file())
		inst.ui.set_enemy_base(inst._boss, ph2)
		for i in 8:
			await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	svc.get_texture().get_image().save_png(out_path)
	print("SAVED ", out_path)
	svc.queue_free()
	await get_tree().process_frame
