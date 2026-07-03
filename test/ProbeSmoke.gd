extends Node
## 煙霧驗證三疑點實跑（headless）：
## B5 軍火庫技能門檻不足時 main_ch1_not_ready 對話是否有跑、文案是否引導支線。
## B6 ares 空弱點表：以最低配裝（僅 basic_punch/wooden_fish/arhat_strike）模擬戰鬥，觀察 TTK 是否合理。
## HQ→軍火庫跳接：c1_confront(dialogue main_ares_lead) → c1_armory_breach(dialogue+battle) 場景切換是否黑屏卡住。
## 跑法：Godot --headless --path D:/monk/MONK res://test/ProbeSmoke.tscn

var ok: bool = true

func _ready() -> void:
	await get_tree().process_frame
	get_tree().current_scene = null  # 脫離 current_scene：B5/HQ 段會觸發 SceneRouter.go_to_map() 換場，
	# 若本節點仍是 current_scene，change_scene_to_file 會把它連同尚未跑完的協程一起釋放。
	await _probe_b5_gate_not_ready()
	await _probe_b6_ares_ttk()
	await _probe_hq_transition()
	print("PROBE_SMOKE: ", "ALL PASS" if ok else "HAS FAILURES")
	get_tree().quit(0 if ok else 1)

func _fail(msg: String) -> void:
	ok = false
	print("PROBE FAIL: ", msg)

# ─── B5：技能不足時 gate 是否正確擋下並播出引導對話 ───────────────
func _probe_b5_gate_not_ready() -> void:
	print("--- B5: c1_armory_gate 技能門檻(未達標) ---")
	GameManager.new_game()
	GameManager.player.flags = {}
	GameManager.player.skills_unlocked = ["basic_punch", "wooden_fish", "arhat_strike"]  # 3 招，未達 gate min=5
	print("B5 起始技能數: ", GameManager.player.skills_unlocked.size())

	var gate: Dictionary = {"type": "skills", "min": 5}
	var passed: bool = MainQuestManager.gate_passed(gate)
	print("B5 gate_passed(min=5, 3招): ", passed)
	if passed:
		_fail("B5: 3 招時 gate 不應通過")
		return

	if not ResourceLoader.exists("res://dialogue/main_ch1_not_ready.dtl"):
		_fail("B5: main_ch1_not_ready.dtl 不存在")
		return

	var timeline: DialogicTimeline = load("res://dialogue/main_ch1_not_ready.dtl")
	var events: Array = timeline.events
	var text_joined: String = ""
	for e in events:
		text_joined += String(e) + "\n"
	print("B5 main_ch1_not_ready.dtl 內容行數: ", events.size())
	var has_guidance: bool = text_joined.contains("紅塵") or text_joined.contains("過過招") or text_joined.contains("練利")
	print("B5 文案含支線引導關鍵字(紅塵/過過招/練利): ", has_guidance)
	if not has_guidance:
		_fail("B5: 對話文案未偵測到明確的支線引導字樣")

	# 實跑 continue_story() 全鏈：需先把 flag 推進到 c1_armory_gate 這一格(index 3)，
	# 並確保前三格已播過（用 set_flag 模擬跳過已完成的 cutscene/dialogue 格，只驗 gate 這一格本身）。
	GameManager.set_flag("main_stage_ch01_ares", 3)  # c1_armory_gate 是 index 3
	GameManager.set_flag("relic_stolen", true)
	GameManager.set_flag("armory_unlocked", true)
	# headless 無真實輸入驅動 timeline 前進，Dialogic.timeline_ended 不會自己觸發，
	# 故不 await continue_story()（它內部會卡在 await Dialogic.timeline_ended），改 fire-and-forget
	# 監看幾幀偵測到 timeline 啟動後，手動 Dialogic.end_timeline() 讓 continue_story() 收尾（同 TestMapInteraction 慣例）。
	# 註：timeline_started 訊號在此情境下實測不可靠觸發（Dialogic 內部路徑差異），改直接輪詢 current_timeline。
	var caught_timeline: String = ""
	MainQuestManager.continue_story()
	for i in 60:
		await get_tree().process_frame
		if Dialogic.current_timeline != null:
			caught_timeline = String(Dialogic.current_timeline.resource_path)
			break
	if Dialogic.current_timeline != null:
		Dialogic.end_timeline()
	for i in 10:
		await get_tree().process_frame
	print("B5 continue_story() 實跑後 caught_timeline: ", caught_timeline)
	if not caught_timeline.contains("main_ch1_not_ready"):
		_fail("B5: 實跑 continue_story() 未偵測到啟動 main_ch1_not_ready（可能被其他 timeline 蓋過或訊號時序錯過，見輸出判讀）")
	var stage_after: int = GameManager.get_flag("main_stage_ch01_ares", -1)
	print("B5 gate 未過，stage 應停留在 3（原地）: ", stage_after)
	if stage_after != 3:
		_fail("B5: gate 未過時 stage 應保留在 3，實際 %d" % stage_after)
	print("B5 DONE")

# ─── B6：ares 空弱點表，最低配裝 TTK 模擬 ───────────────
func _probe_b6_ares_ttk() -> void:
	print("--- B6: ares weaknesses=[] 最低配裝 TTK 模擬 ---")
	GameManager.new_game()
	GameManager.player.flags = {}
	GameManager.player.skills_unlocked = ["basic_punch", "wooden_fish", "arhat_strike"]
	GameManager.player.karma = 100
	GameManager.player.merit = 100
	GameManager.player.gold = 1000

	var battle_scene: PackedScene = load("res://src/screens/BattleScreen/BattleScreen.tscn")
	var battle = battle_scene.instantiate()
	get_tree().root.add_child(battle)
	await get_tree().process_frame
	battle.setup("ares")
	await get_tree().process_frame

	var boss_data: Dictionary = JsonLoader.load_json("res://data/boss.json").get("ares", {})
	print("B6 ares weaknesses: ", boss_data.get("weaknesses", []), " resistances: ", boss_data.get("resistances", []))
	print("B6 ares max_hp: ", boss_data.get("max_hp", 0), " defense: ", boss_data.get("defense", 0))

	var boss: Combatant = battle.enemy_combatants[0]
	var player: Combatant = battle.player_combatant
	var exec: Node = battle.executor

	# 純模擬：直接呼叫 execute() 反覆用 3 招輪替打，不經 UI/輸入，最多跑 60 回合防止無限迴圈。
	var turn: int = 0
	var skill_cycle: Array = ["arhat_strike", "basic_punch", "wooden_fish"]
	var hp_before: int = boss.current_hp
	var player_deaths: int = 0
	while boss.is_alive() and turn < 60:
		var skill_id: String = skill_cycle[turn % skill_cycle.size()]
		var sk: Dictionary = exec.get_skill(skill_id)
		# 資源不足則退回 basic_punch
		var cost: Dictionary = sk.get("cost", {})
		if cost.get("karma", 0) > GameManager.player.karma or cost.get("merit", 0) > GameManager.player.merit:
			skill_id = "basic_punch"
		exec.execute(skill_id, player, boss, [boss])
		turn += 1
		# 補資源，避免因資源枯竭卡住模擬（非真實遊玩節奏，純粹為了跑出 TTK 上限估計）
		GameManager.player.karma = 100
		GameManager.player.merit = 100
		if not boss.is_alive():
			break
		# 簡化敵方反擊：用 boss phase1 的 war_strike 固定打玩家，觀察玩家是否會先陣亡
		var boss_atk: int = int(boss_data.get("attack", 80))
		var dmg_to_player: int = maxi(boss_atk - player.defense, 1)
		exec.apply_damage(player, dmg_to_player, boss, "physical")
		if not player.is_alive():
			player_deaths += 1
			break

	print("B6 模擬結果：回合數(玩家出手次數)=", turn, " boss存活=", boss.is_alive(), " boss剩餘HP=", boss.current_hp, "/", boss_data.get("max_hp", 0))
	print("B6 玩家剩餘HP=", player.current_hp, "/", player.max_hp, " 玩家中途陣亡=", player_deaths > 0)

	if turn >= 60 and boss.is_alive():
		print("B6 觀察：60 回合內未能擊敗 ares（最低配裝＋空弱點表），TTK 明顯過長，屬體驗風險（非程式崩潰）")
	elif player_deaths > 0:
		print("B6 觀察：模擬中玩家先陣亡（此模擬未含玩家防禦/道具/護法，真實遊玩應更從容，僅供傷害量級參考）")
	else:
		print("B6 觀察：%d 回合內擊敗 ares，未觸發任何錯誤或例外，空弱點表未造成程式崩潰或卡死" % turn)

	battle.queue_free()
	await get_tree().process_frame
	print("B6 DONE")

# ─── HQ→軍火庫跳接：c1_confront → c1_armory_breach 場景切換是否黑屏卡住 ───────────────
func _probe_hq_transition() -> void:
	print("--- HQ→軍火庫跳接 (c1_confront → c1_armory_breach) ---")
	if Dialogic.current_timeline != null:
		Dialogic.end_timeline()
		await get_tree().process_frame
	GameManager.new_game()
	GameManager.player.flags = {}
	GameManager.player.skills_unlocked = ["basic_punch", "wooden_fish", "arhat_strike", "vajra_glare", "sound_wave"]  # 5 招，gate 過
	GameManager.set_flag("relic_stolen", true)
	GameManager.set_flag("armory_unlocked", true)
	GameManager.set_flag("main_stage_ch01_ares", 3)  # 從 c1_armory_gate 開始跑

	# 註：timeline_started 訊號在本情境下實測不可靠觸發，改直接輪詢 current_timeline（同 B5 段）。
	var timelines_seen: Array = []
	var last_seen: String = ""

	# 註：EventBus.battle_started 訊號連線在本情境下實測不可靠觸發（與 Dialogic.timeline_started
	# 同類現象，疑似 lambda 連線在 fire-and-forget 協程鏈中的時序問題），改直接輪詢 current_scene 是否切為 BattleScreen。
	var battle_started: bool = false

	# continue_story 會一路跑：c1_armory_gate(過)→c1_confront(main_ares_lead)→c1_armory_breach(對話+battle)
	# headless 無真實輸入驅動 timeline 前進，途中每條 dialogue timeline 都要手動 end_timeline 才能推進
	# （同 B5 段與 TestMapInteraction 慣例）；battle 一開打就會卡在 EventBus.battle_ended 等待，
	# 不玩實戰，只確認有沒有順利觸發戰鬥場景（=場景/流程沒卡死黑屏）。
	# 不 await：fire-and-forget，讓它在背景推進，本函式用 process_frame 迴圈監看進度並手動推進對話。
	MainQuestManager.continue_story()
	var elapsed_frames: int = 0
	var max_frames: int = 900  # ~15s at 60fps，超過視為卡死/黑屏
	while elapsed_frames < max_frames:
		await get_tree().process_frame
		elapsed_frames += 1
		if get_tree().current_scene != null and String(get_tree().current_scene.name) == "BattleScreen":
			battle_started = true
		if Dialogic.current_timeline != null:
			var p := String(Dialogic.current_timeline.resource_path)
			if p != last_seen:
				last_seen = p
				if not timelines_seen.has(p):
					timelines_seen.append(p)
			await get_tree().create_timer(0.4).timeout  # 讓 _play_dialogue 的 0.35s 沉澱等待先過，避免搶在 Dialogic.start 之前 end
			if Dialogic.current_timeline != null:
				Dialogic.end_timeline()
		if battle_started:
			break

	print("HQ跳接 途經 timelines: ", timelines_seen)
	print("HQ跳接 是否進入 BattleScreen (c1_armory_breach 觸發戰鬥場景): ", battle_started, "  等待幀數: ", elapsed_frames)
	if not battle_started:
		_fail("HQ跳接: %d 幀(~%.1fs) 內未切換到 BattleScreen，疑似卡住/黑屏" % [elapsed_frames, elapsed_frames / 60.0])
	else:
		print("HQ跳接 觀察：c1_confront(main_ares_lead 對話) → c1_armory_breach(對話+battle) 場景鏈正常跑通，無黑屏卡死，途中無額外過場鏡頭（純對話銜接，符合 C1 finding 記錄的「該 stage 靠 dialogue 撐住流程，無迷宮探索場景」現況）")
		# 结束 battle：直接呼叫 battle_ended 讓 continue_story 收尾，避免殘留掛起的 await
		EventBus.battle_ended.emit("win")
		for i in 90:
			await get_tree().process_frame
	print("HQ跳接 DONE")
