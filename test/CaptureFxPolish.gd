extends Node
## 戰鬥體感打磨 QC 截圖：三系技能特效峰值 + 玩家受擊紅閃瞬間 + 左上無回合 chip 佐證。
## 用有視窗的 Godot 跑（非 headless，需 GPU 渲染），存 PNG 到專案根 D:/monk/MONK/_cap_fx_*.png。
## 抓幀時機：CPUParticles2D explosiveness=1.0 的噴發峰值在 emit 後 1-2 幀；
## 淨系 ripple 的 alpha 峰值在 tween 0.06s 後（約 3 幀）；物理系斬痕 0.04s 淡入後持續較久，6 幀穩定。

const BATTLE := "res://src/screens/BattleScreen/BattleScreen.tscn"

func _ready() -> void:
	await get_tree().process_frame  # 避免 first-capture 黑幀
	await _capture_skill_fx("basic_punch", "res://_cap_fx_physical.png", 6)   # 物理系：白色斜斬
	await _capture_skill_fx("arhat_strike", "res://_cap_fx_karma.png", 2)     # 業系：黑紫迸散（粒子峰值幀）
	await _capture_skill_fx("sound_wave", "res://_cap_fx_merit.png", 3)      # 淨系：金色音波環（漣漪峰值幀）
	await _capture_player_hit("res://_cap_fx_player_hit_red.png")
	await _capture_plain("res://_cap_fx_no_turnchip.png")
	print("FX_CAPTURE_DONE")
	get_tree().quit(0)

func _make_battle(svc: SubViewport) -> Node:
	var inst: Node = (load(BATTLE) as PackedScene).instantiate()
	svc.add_child(inst)
	await get_tree().process_frame
	inst.setup("street_punk")
	for i in 12:
		await get_tree().process_frame
	return inst

func _new_viewport() -> SubViewport:
	var svc := SubViewport.new()
	svc.size = Vector2i(1920, 1080)
	svc.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_tree().root.add_child.call_deferred(svc)
	await get_tree().process_frame
	return svc

func _snap(svc: SubViewport, out_path: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	svc.get_texture().get_image().save_png(out_path)

## 直接呼叫 SkillFx.play_for_skill 在敵陣中央位置播特效，peak_frames＝起手後抓幀的等待幀數（依基元峰值調）。
func _capture_skill_fx(skill_id: String, out_path: String, peak_frames: int) -> void:
	var svc := await _new_viewport()
	var inst := await _make_battle(svc)
	var sk: Dictionary = inst.executor.get_skill(skill_id)
	var ui = inst.ui
	var pos: Vector2 = ui._floater_pos_for("")  # 敵陣中央位置，特效可見不擋在立繪後
	SkillFx.play_for_skill(sk, ui.float_layer, pos)
	for i in peak_frames:
		await get_tree().process_frame
	await _snap(svc, out_path)
	print("SAVED ", out_path, " (skill=", skill_id, " fx=", sk.get("fx", ""), " frames=", peak_frames, ")")
	svc.queue_free()
	await get_tree().process_frame

## 玩家受擊紅閃：直接呼叫 BattleUI._shake_player_figure()（hp_changed 連動的同一函式）。
func _capture_player_hit(out_path: String) -> void:
	var svc := await _new_viewport()
	var inst := await _make_battle(svc)
	inst.ui._shake_player_figure()
	await get_tree().process_frame  # 紅閃剛套用的第一幀最明顯
	await _snap(svc, out_path)
	print("SAVED ", out_path, " (player hit red-flash)")
	svc.queue_free()
	await get_tree().process_frame

## 素面戰鬥畫面：佐證左上角無回合 chip（TurnOrderBar 視覺已移除）。
func _capture_plain(out_path: String) -> void:
	var svc := await _new_viewport()
	var _inst := await _make_battle(svc)
	await _snap(svc, out_path)
	print("SAVED ", out_path, " (plain battle, top-left clean)")
	svc.queue_free()
	await get_tree().process_frame
