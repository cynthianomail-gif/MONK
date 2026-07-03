extends Node
## 第四期總驗收 GPU 截圖：戰鬥新 UI／完美格擋／總攻擊／修行盤／護法／傷害漂浮字。
## ⚠ 只用視窗版 Godot 跑（headless 會卡 frame_post_draw）：
##   tools/godot/Godot_v4.5-stable_win64.exe --path D:/monk/MONK res://test/CaptureOverhaul.tscn

const BATTLE := "res://src/screens/BattleScreen/BattleScreen.tscn"
const BOARD_APP := "res://src/ui/menu/pages/BoardApp.gd"

var _svc: SubViewport

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await get_tree().process_frame  # 避免 first-capture 渲染成黑

	await _capture_battle_overview()
	await _capture_perfect_guard()
	await _capture_all_out()
	await _capture_board()
	await _capture_summon()
	await _capture_damage_floaters()

	print("CAPTURE_OVERHAUL_DONE")
	get_tree().quit(0)

func _new_viewport() -> SubViewport:
	var svc := SubViewport.new()
	svc.size = Vector2i(1920, 1080)
	svc.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_tree().root.add_child.call_deferred(svc)
	return svc

func _save(svc: SubViewport, out_path: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	svc.get_texture().get_image().save_png(out_path)
	print("SAVED ", out_path)

func _free_viewport(svc: SubViewport) -> void:
	svc.queue_free()
	await get_tree().process_frame

# 1) 戰鬥新 UI 全景：順序條＋敵人清單(配對敵)＋斜切指令選單皆入鏡。
func _capture_battle_overview() -> void:
	var svc := _new_viewport()
	await get_tree().process_frame
	var inst: Node = (load(BATTLE) as PackedScene).instantiate()
	svc.add_child(inst)
	await get_tree().process_frame
	inst.setup("pantheon_guard")  # spawn_pair=true → 2 敵面板同時入鏡
	for i in 30:
		await get_tree().process_frame
	await _save(svc, "res://_cap_overhaul_battle_ui.png")
	await _free_viewport(svc)

# 2) 完美格擋瞬間：GuardWindow 觸發視覺狀態（警示閃紅接成功閃白＋「格擋！」字樣）。
func _capture_perfect_guard() -> void:
	var svc := _new_viewport()
	await get_tree().process_frame
	var inst: Node = (load(BATTLE) as PackedScene).instantiate()
	svc.add_child(inst)
	await get_tree().process_frame
	inst.setup("street_punk")
	for i in 24:
		await get_tree().process_frame
	# 直接呼叫 UI API 擺出完美格擋成功瞬間的視覺狀態（不透過真實輸入時序，屬擺拍）。
	inst.ui.show_guard_warning(inst.enemy_combatants[0])
	inst.ui.flash_perfect_guard()
	# flash_perfect_guard() 內部會觸發 _hit_stop()：Engine.time_scale 短暫壓到 0.08，
	# 「格擋！」字樣的淡入 tween(0.08s 遊戲時間) 在 hit-stop 期間幾乎不會推進，
	# 必須用真實時間等待，等 hit-stop 結束+字樣淡入完成後再截圖，否則字樣幾乎全透明。
	await get_tree().create_timer(0.3, true, false, true).timeout  # ignore_time_scale=true
	await _save(svc, "res://_cap_overhaul_perfect_guard.png")
	await _free_viewport(svc)

# 3) 總攻擊演出定格：殘影演出中段（水墨定格「超渡」大字＋背景壓暗）。
func _capture_all_out() -> void:
	var svc := _new_viewport()
	await get_tree().process_frame
	var inst: Node = (load(BATTLE) as PackedScene).instantiate()
	svc.add_child(inst)
	await get_tree().process_frame
	inst.setup("temple_ghost")
	for i in 24:
		await get_tree().process_frame
	inst.ui.play_all_out()  # 不 await：中途截圖抓演出定格
	# 白閃(0.06+0.2s) + 殘影(0.35s) 後進入 0.9s 定格窗，抓定格窗中段。
	await get_tree().create_timer(0.75).timeout
	await _save(svc, "res://_cap_overhaul_all_out.png")
	await _free_viewport(svc)

# 4) 修行盤 BoardApp：已解鎖／可解鎖／鎖定／劇情鎖四態節點入鏡。
# core(已解鎖，恆定) → 解鎖 atk_1(製造更多已解鎖+可解鎖節點) → atk_2 等仍 locked → ring3(master_*) 為 story_locked。
# BoardApp 是為手機選單頁設計（_ready() 內 set_anchors_preset(FULL_RECT)，天生撐滿容器），
# 塞進 1920x1080 SubViewport 會整個被拉伸填滿——這正是手機選單的原生行為，直接沿用即可，
# 不需要另外做縮放置中的截圖專用 hack（先前兩次嘗試 scale/position 都因 _ready() 的錨點覆蓋而失敗）。
func _capture_board() -> void:
	var svc := _new_viewport()
	await get_tree().process_frame
	CultivationBoard.reload()
	GameManager.add_daoxing(10000)  # 確保道行足夠解鎖，四態靠 requires/story_flag 天然分佈
	if CultivationBoard.can_unlock("atk_1"):
		CultivationBoard.unlock_node("atk_1")
	var app: Control = (load(BOARD_APP) as GDScript).new()
	svc.add_child(app)
	await get_tree().process_frame
	app.select_node("atk_2")  # available 態節點，右側資訊面板顯示內容
	for i in 6:
		await get_tree().process_frame
	await _save(svc, "res://_cap_overhaul_board.png")
	await _free_viewport(svc)

# 5) 護法演出定格：立繪滑入＋色閃瞬間（佔位圖入鏡即可）。
func _capture_summon() -> void:
	var svc := _new_viewport()
	await get_tree().process_frame
	var inst: Node = (load(BATTLE) as PackedScene).instantiate()
	svc.add_child(inst)
	await get_tree().process_frame
	inst.setup("corrupt_vendor")
	for i in 24:
		await get_tree().process_frame
	var summon_data: Dictionary = JsonLoader.load_json("res://data/summons.json").get("fuhu_luohan", {})
	inst.ui.play_summon_effect("fuhu_luohan", summon_data)  # 不 await：中途截圖抓滑入/色閃瞬間
	await get_tree().create_timer(0.18).timeout
	await _save(svc, "res://_cap_overhaul_summon.png")
	await _free_viewport(svc)

# 6) 傷害漂浮字入鏡的戰鬥中景：命中/爆擊/弱點/Miss 四態飄字同時可見。
func _capture_damage_floaters() -> void:
	var svc := _new_viewport()
	await get_tree().process_frame
	var inst: Node = (load(BATTLE) as PackedScene).instantiate()
	svc.add_child(inst)
	await get_tree().process_frame
	inst.setup("pantheon_guard")
	for i in 24:
		await get_tree().process_frame
	var ui: Node = inst.ui
	# spawn_pair 敵人 id 為 "pantheon_guard"／"pantheon_guard_2"（Combatant.from_enemy 的 id+suffix 規則），
	# 不是泛用的 "enemy_0"/"enemy_1"——用錯 id 會落到 _floater_pos_for() 的 fallback 座標，三個字疊在一起。
	DamageFloater.spawn(ui.float_layer, ui._floater_pos_for("player"), 42, {})
	DamageFloater.spawn(ui.float_layer, ui._floater_pos_for("pantheon_guard"), 88, {"is_crit": true})
	DamageFloater.spawn(ui.float_layer, ui._floater_pos_for("pantheon_guard_2"), 156, {"hit_weakness": true, "is_crit": true})
	for i in 10:
		await get_tree().process_frame
	await _save(svc, "res://_cap_overhaul_damage_floaters.png")
	await _free_viewport(svc)
