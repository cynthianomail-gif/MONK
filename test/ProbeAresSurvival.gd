extends Node
## D-5：Ares 真實生存測試（2026-07-11 新開，不動既有 ProbeAresTTK.gd）。
##
## 背景：ProbeAresTTK.gd:80-85 每回合把玩家補滿血，是刻意設計（只量 TTK/輸出上限，
## 不量生存）。本 probe 另外驗證「真實生存」：不補血、允許死亡、資源（karma/merit）不人為
## 重置（跟真實遊玩一樣只會被技能消耗/回復技能的 side_effect 補回），敵方用 BattleManager
## 本體真實驅動（含 boss 兩階段 war_strike/intimidate/rage_charge → area_crush/divine_judgment/
## divine_rage，非 ProbeAresTTK 的簡化固定值），並讓 One More／全滅 All-Out-Attack 等既有戰鬥
## 機制照真實規則跑（見下方「意外發現」）。
##
## 玩家狀態依據（查證見 _report 開頭列的檔案:行號）：
## - 技能＝「五技能剛達標」：basic_punch/wooden_fish(initial) + arhat_strike(story，c1_intel
##   授予) + broken_bowl_beg(behavior kill_count>=6，易達) + sound_wave(quest ah_zhong，merit，
##   命中 ares 弱點)。與 ProbeAresTTK 情境(b)同一組合，也是 QaGoldenPath D-6 beat 04
##   armory_gate 門檻(skills_unlocked>=5)的最低可行配置——首見 Ares 前最常見的玩家狀態。
## - 修行盤/佛具＝0 投入：armory_gate 只看技能數不看道行點數；佛具商店需 quest_zheng_ma
##   支線完成才解鎖，主線本身不會給，故用 Combatant.from_player() 的原生預設值
##   （max_hp 500／atk 100／def 10／spd 15，CultivationBoard.compute_bonus()+EquipmentSystem
##   .compute_bonus() 在無投入/無裝備時皆回 0）。
## - 金錢＝1000(起始，GameManager.gd:16) + 100(教學戰，enemies.json tutorial_punk.gold_reward)
##   + 250×2(armory_breach/armory_deep 各打一場 pantheon_guard，enemies.json 該欄) = 1600。
## - 補品＝金瘡藥 heal_salve，220金/瓶回200血（items.json）。跑兩種情境見下。
## - 不復活：current_hp<=0 立即判定敗北中止（不像 ProbeAresTTK 補血續打）。
##
## 出招邏輯（模擬「有基本策略但非最優解」的一般玩家）：
## - merit 不足 15（無法出 sound_wave）→ 用 wooden_fish 打底（該技能 side_effect 生 merit+2/次，
##   是唯一會回 merit 的技能，見 skills.json wooden_fish.side_effect）。
## - merit>=15 → 優先送 sound_wave（命中 ares 唯一弱點 merit，見 boss.json ares.weaknesses）。
## - HP<=40% 且還有藥 → 優先吃藥而非出招（求生本能，藥不算一個回合的「出招選擇」，
##   藥吃完才回到上面兩條判斷）。
##
## 兩種補品情境（金額/瓶數推算見上）：
##   A_STRICT_GOLDEN_PATH：zheng_ma_shop_unlocked=false（黃金路線這個時間點商店本來就沒解鎖，
##     shop 系統整個不能用）＝0 瓶，誠實下限情境。
##   B_TYPICAL_PLAYER：假設玩家順手做掉水野支線解鎖商店（常見度高，非硬性支線），
##     1600 金花 3 瓶(660金，回血上限600≈玩家HP 1.2倍)留 940 彈性＝一般玩家較可能的配置。
##
## ⚠ 2026-07-11 重大意外發現（本 probe 用真實 BattleManager 驅動才測得到，ProbeAresTTK
## 因為繞過 BattleManager 直呼 SkillExecutor 完全不會碰到）：
## solo boss（單體敵人，ares 屬此類）只要被打中弱點一次，就會經
## BattleManager._process_result()→_all_downed()（單體時「這隻被打到弱點」＝「全體都倒」，
## 邏輯上對单体永遠成立）→_all_out_attack() 觸發全滅 All-Out-Attack，固定造成
## ALL_OUT_DMG=9999 傷害（BattleManager.gd:7,549-557，無視防禦/抗性，不看 is_boss）。
## ares 上限 2000 血，必定當場秒殺，完全跳過設計好的兩階段機制（war_strike/intimidate/
## rage_charge → area_crush/divine_judgment/divine_rage 全部沒有機會發生）。
## 由於本 probe 的「五技能剛達標」玩家配置裡 sound_wave 正好命中 ares 唯一弱點(merit)，
## 只要撐過「用 wooden_fish 打底攢 15 點 merit」的初期幾回合（本測資約需 8 回合），
## 一旦成功送出 sound_wave，幾乎必勝——這使得下方統計出的「勝率」實質上量的是
## 「能不能撐過初期 8 回合攢資源」，而不是「打贏 ares 完整兩階段戰鬥」的真實難度。
## 這是本 probe 相對 ProbeAresTTK 的核心價值（抓到 TTK 估算完全看不到的真實機制交互），
## 但也代表：即使下方勝率數字很高，並不代表 ares 這場戰鬥「難度合理」——它可能代表
## 「boss 血量池對單體弱點+全滅連段的防禦設計是 0」，是否要修（例如讓 boss 對
## All-Out-Attack 有抗性/減傷，或 All-Out 判定排除 is_boss）由使用者裁定，
## 本 probe 只負責如實測出來、如實報告，不擅自處理。
##
## 跑法：Godot --headless --path D:/monk/MONK res://test/ProbeAresSurvival.tscn

const N_RUNS := 60
const MAX_ROUNDS := 80   # 防呆软死锁上限；正常對局遠遠打不到

const SKILL_PRIORITY: Array = ["sound_wave", "arhat_strike", "broken_bowl_beg", "wooden_fish", "basic_punch"]
const PLAYER_SKILLS: Array = ["basic_punch", "wooden_fish", "arhat_strike", "broken_bowl_beg", "sound_wave"]

var _all_out_trigger_count: int = 0   # 意外發現追蹤：All-Out-Attack 觸發次數（見 _report）

func _ready() -> void:
	await get_tree().process_frame
	get_tree().current_scene = null
	# 用真實 BattleManager 驅動會吃到 guard window/timer 等真實秒數延遲（create_timer 預設吃
	# Engine.time_scale，同遊戲內 Shift 加速機制的原理，見 BattleManager.gd SPEEDUP_SCALE）；
	# 純跑批次統計不需要真實節奏，加大 time_scale 大幅縮短總耗時，不影響模擬邏輯本身。
	Engine.time_scale = 20.0
	print("=== D-5 Ares 真實生存測試（N=%d/情境） ===" % N_RUNS)
	var result_a: Dictionary = await _run_scenario("A_STRICT_GOLDEN_PATH（0瓶金瘡藥）", 0)
	var result_b: Dictionary = await _run_scenario("B_TYPICAL_PLAYER（3瓶金瘡藥）", 3)
	print("")
	print("========== 總結 ==========")
	_print_summary("A_STRICT_GOLDEN_PATH（0瓶金瘡藥）", result_a)
	_print_summary("B_TYPICAL_PLAYER（3瓶金瘡藥）", result_b)
	print("All-Out-Attack 全程觸發次數（兩情境合計 %d 場）：%d" % [N_RUNS * 2, _all_out_trigger_count])
	print("PROBE_ARES_SURVIVAL_DONE")
	get_tree().quit(0)

func _run_scenario(label: String, potion_count: int) -> Dictionary:
	print("--- 情境 [%s] 開始 ---" % label)
	var wins := 0
	var losses := 0
	var total_rounds := 0
	var win_hp_pcts: Array = []
	var death_causes: Dictionary = {}
	for i in N_RUNS:
		var r: Dictionary = await _simulate_one(potion_count)
		if r.win:
			wins += 1
			win_hp_pcts.append(r.hp_pct)
		else:
			death_causes[r.death_cause] = death_causes.get(r.death_cause, 0) + 1
		total_rounds += r.rounds
		print("[%s] run %02d/%d：%s　rounds=%d　hp_end=%d/%d(%.1f%%)　all_out=%s　死因=%s" % [
			label, i + 1, N_RUNS, ("WIN" if r.win else "LOSE"), r.rounds,
			r.hp_end, r.hp_max, r.hp_pct, r.all_out_triggered, r.death_cause])
	var win_rate: float = 100.0 * float(wins) / float(N_RUNS)
	var avg_win_hp := 0.0
	if not win_hp_pcts.is_empty():
		for v in win_hp_pcts:
			avg_win_hp += v
		avg_win_hp /= win_hp_pcts.size()
	return {
		"wins": wins, "losses": losses, "win_rate": win_rate,
		"avg_rounds": float(total_rounds) / float(N_RUNS),
		"avg_win_hp_pct": avg_win_hp,
		"death_causes": death_causes,
	}

func _print_summary(label: String, r: Dictionary) -> void:
	print("[%s] 勝率=%.1f%%（%d/%d）　平均回合數=%.1f　勝場平均剩餘HP=%.1f%%　敗因分佈=%s" % [
		label, r.win_rate, r.wins, N_RUNS, r.avg_rounds, r.avg_win_hp_pct, str(r.death_causes)])

func _make_battle() -> Node:
	var battle_scene: PackedScene = load("res://src/screens/BattleScreen/BattleScreen.tscn")
	var battle = battle_scene.instantiate()
	get_tree().root.add_child(battle)
	return battle

## 模擬一場戰鬥：驅動真實 BattleManager（非簡化敵方行為），玩家用固定優先序真輸入式出招
## （直呼 player_use_skill()，同 QaGoldenPath/ProbeAresTTK 既有慣例），敵方/boss 階段/One More/
## All-Out-Attack 全部照真實規則跑。HOLD_UP（全滅時的問答選單）用「gold」自動代答，避免卡在
## 等真人選擇的 await（見 BattleUI.show_hold_up_menu()：await hold_up_choice 訊號）。
func _simulate_one(potion_count: int) -> Dictionary:
	GameManager.new_game()
	GameManager.player.flags = {}
	GameManager.player.skills_unlocked = PLAYER_SKILLS.duplicate()
	GameManager.player.karma = 0
	GameManager.player.merit = 0
	GameManager.player.gold = 5000  # 金錢不是本測試變因（技能已解鎖、藥另外算），給足避免卡門檻

	var battle := _make_battle()
	await get_tree().process_frame
	battle.setup("ares")
	await get_tree().process_frame

	var boss: Combatant = battle.enemy_combatants[0]
	var player: Combatant = battle.player_combatant
	var exec: Node = battle.executor

	if potion_count > 0:
		GameManager.add_item("heal_salve", potion_count)  # 走真實道具庫存，吃藥經 player_use_item() 真實扣回合
	var rounds := 0
	var all_out_triggered := false
	var guard_iters := 0
	# 防呆上限：真實 BattleManager 驅動（含 UI tween/guard window/傷害飄字等待）比 ProbeAresTTK
	# 的簡化直呼慢很多，即使 Engine.time_scale=20 壓縮時間，「幀數」本身不會被壓縮
	# （create_timer/tween 縮短的是秒數，headless 無畫面限制下每幀仍要跑一次 process_frame）；
	# 實測 20~30 回合的完整對局約需數千幀，故給遠高於單純回合數的幀預算，真正卡死時才會頂到。
	const GUARD_CAP := 40000

	while boss.is_alive() and player.is_alive() and rounds < MAX_ROUNDS and guard_iters < GUARD_CAP:
		guard_iters += 1
		await get_tree().process_frame
		match battle.state:
			battle.State.PLAYER_TURN:
				rounds += 1
				if GameManager.item_count("heal_salve") > 0 and player.current_hp <= player.max_hp * 0.4:
					battle.player_use_item("heal_salve")  # 真實道具路徑：消耗庫存＋回血＋扣掉本回合
				else:
					var skill_id: String = _choose_skill(exec)
					battle.player_use_skill(skill_id, 0)
			battle.State.ALL_OUT:
				# ⚠ 2026-07-11 意外發現（詳見檔頭「重大意外發現」段）：solo boss 只要被打中弱點
				# 進入「全滅」判定（_all_downed()，單體時等於「這隻被打到弱點」）就會觸發
				# All-Out-Attack，固定 9999 傷害——ares 上限 2000 血，必定當場秒殺，
				# 完全跳過 boss 兩階段機制。這裡只做偵測記錄，不介入（All-Out 本身走
				# BattleManager 自己的協程，不需要外部輸入）。
				if not all_out_triggered:
					all_out_triggered = true
					_all_out_trigger_count += 1
			battle.State.HOLD_UP:
				battle.ui.hold_up_choice.emit("gold")
			_:
				pass  # ENEMY_TURN/SKILL_ANIM/END：純等待，讓 BattleManager 自己跑完

	var hp_end: int = player.current_hp
	var hp_max: int = player.max_hp
	var win: bool = not boss.is_alive() and player.is_alive()
	var death_cause := ""
	if not win:
		if not player.is_alive():
			death_cause = "被打死（第%d回合）" % rounds
		elif rounds >= MAX_ROUNDS:
			death_cause = "回合上限(%d)內未擊敗（軟死鎖）" % MAX_ROUNDS
		elif guard_iters >= GUARD_CAP:
			death_cause = "guard_iters 上限（疑似卡在非預期狀態，需人工複查）"
	var result := {
		"win": win, "rounds": rounds, "hp_end": hp_end, "hp_max": hp_max,
		"hp_pct": (100.0 * float(hp_end) / float(hp_max)) if hp_max > 0 else 0.0,
		"death_cause": death_cause, "all_out_triggered": all_out_triggered,
	}
	battle.queue_free()
	await get_tree().process_frame
	return result

## 出招優先序：merit 不足時用 wooden_fish 累積（其 side_effect merit+2 是唯一回 merit 的技能，
## 見 skills.json），merit 足夠優先送 sound_wave（命中 ares 唯一弱點）；karma 足夠時穿插
## arhat_strike；broken_bowl_beg/basic_punch 保底零消耗。
## ⚠ 2026-07-11 實測踩坑：原本用「掃優先序表、第一個負擔得起的就選」的寫法，
## broken_bowl_beg 零消耗排在 wooden_fish 前面，導致資源不足時永遠先選到 broken_bowl_beg
## （零消耗必過關），wooden_fish（唯一會回 merit 的技能，見檔頭說明）永遠選不到，merit 永遠
## 停在 0，sound_wave（cost.merit=15）整場打不出來——「5 招裡有 1 招弱點」的核心設計意圖
## 完全沒被模擬到。改為顯式資源判斷：merit 夠先送 sound_wave；karma 夠送 arhat_strike；
## 都不夠就送 wooden_fish 累積 merit（同時是本命中弱點路線唯一的資源引擎）。
## basic_punch/broken_bowl_beg 兩招在此優先序下實質不會被選到（皆為零消耗物理，對 ares
## 有物理抗性只打一半，且不生資源，嚴格劣於 wooden_fish）——這本身也是一個真實發現：
## 5 招裡的 arhat_strike 需要 karma，但這 5 招沒有任何一招會回 karma（see skills.json，
## 無 side_effect.karma），karma 起始 0 且無法自然累積，等於這套「剛達標」loadout 實際上
## arhat_strike 是打不出來的死技能，只有 sound_wave 弱點路線是唯一可行輸出手段。
func _choose_skill(exec: Node) -> String:
	var sw_cost: Dictionary = exec.get_skill("sound_wave").get("cost", {})
	if int(sw_cost.get("merit", 0)) <= GameManager.player.merit:
		return "sound_wave"
	var as_cost: Dictionary = exec.get_skill("arhat_strike").get("cost", {})
	if int(as_cost.get("karma", 0)) <= GameManager.player.karma:
		return "arhat_strike"
	return "wooden_fish"
