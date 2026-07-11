extends Node
## headless 測試：第一章阿瑞斯劇情擴充（8 stage＋了塵＋神祇情報圖鑑）。
## 跑法：Godot --headless res://test/TestCh1Expansion.tscn（需 Dialogic autoload 在線→當 main scene 跑）。

var ok := true

## 2026-07-06 新增 c1_tutorial_brawl（茶攤小混混亂入教學戰，介於 aftermath/intel 之間）：
## 見 main_quests.json、BattleTutorial.gd。stage 數 9→10。
const EXPECT_STAGE_IDS := ["c1_demolition", "c1_aftermath", "c1_tutorial_brawl", "c1_intel", "c1_armory_gate",
	"c1_confront", "c1_armory_breach", "c1_armory_deep", "c1_ares_intro", "c1_ares"]
const INTEL_FLAGS := ["intel_pantheon", "intel_ares", "intel_hermes", "intel_poseidon",
	"intel_demeter", "intel_hephaestus", "intel_aphrodite", "intel_apollo", "intel_dionysus",
	"intel_artemis", "intel_athena", "intel_hera", "intel_zeus"]
const NEW_DTLS := ["main_ch1_aftermath", "main_ch1_intel", "main_ch1_armory_breach",
	"main_ch1_gate_ready", "main_ch1_not_ready"]

func _ready() -> void:
	await get_tree().process_frame
	_test_ch1_stages()
	_test_gate_logic()
	_test_god_intel()
	_test_new_dialogues()
	_test_opening_wakeup()
	_test_skill_learning()
	_test_gate_side_quest_orange_dots()
	await _test_gate_side_quest_dialogue_hints()
	await _smoke_intel_app()
	await _smoke_phone_menu()
	print("CH1_EXPANSION_TEST: ", "ALL PASS" if ok else "HAS FAILURES")
	get_tree().quit(0 if ok else 1)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		ok = false
		print("FAIL: ", msg)

func _test_ch1_stages() -> void:
	var raw: Dictionary = JsonLoader.load_json("res://data/main_quests.json")
	var c: Dictionary = raw.get("ch01_ares", {})
	_check(not c.is_empty(), "ch01_ares 存在")
	var stages: Array = c.get("stages", [])
	_check(stages.size() == 10, "ch1 有 10 stage (got %d)" % stages.size())
	var ids: Array = []
	for s in stages:
		ids.append(String(s.get("id", "")))
	_check(ids == EXPECT_STAGE_IDS, "stage id 順序正確 (got %s)" % str(ids))
	_check(String(c.get("complete_flag", "")) == "ares_purified", "complete_flag 仍 ares_purified")
	# 關鍵鍵別仍在
	var has_boss := false
	var has_opening := false
	for s in stages:
		if String(s.get("boss", "")) == "ares":
			has_boss = true
		if String(s.get("cutscene", "")) == "opening_temple_falls":
			has_opening = true
	_check(has_boss, "仍有 ares boss stage")
	_check(has_opening, "仍有 opening_temple_falls")
	# 修練門檻 stage
	var gate_stage: Dictionary = {}
	for s in stages:
		if s.has("gate"):
			gate_stage = s
	_check(not gate_stage.is_empty(), "有修練門檻 gate stage")
	if not gate_stage.is_empty():
		var g: Dictionary = gate_stage.gate
		_check(String(g.get("type", "")) == "skills", "gate type=skills")
		_check(int(g.get("min", 0)) >= 4, "gate min 門檻 >=4 (got %d)" % int(g.get("min", 0)))
		_check(g.has("fail_dialogue"), "gate 有 fail_dialogue")

func _test_gate_logic() -> void:
	var g := {"type": "skills", "min": 5}
	var saved: Array = GameManager.player.skills_unlocked.duplicate()
	GameManager.player.skills_unlocked = ["basic_punch", "wooden_fish", "arhat_strike"]
	_check(not MainQuestManager.gate_passed(g), "技能 3<5 門檻擋住")
	GameManager.player.skills_unlocked = ["a", "b", "c", "d", "e"]
	_check(MainQuestManager.gate_passed(g), "技能 5>=5 門檻放行")
	GameManager.player.skills_unlocked = saved

func _test_god_intel() -> void:
	var g := GodIntel
	_check(g.total() == 13, "god_intel total==13 (12神+總覽) (got %d)" % g.total())
	for f in INTEL_FLAGS:
		GameManager.player.flags.erase(f)
	GameManager.player.completed_quests = []
	_check(g.discovered_count() == 0, "情報清空後 discovered==0 (got %d)" % g.discovered_count())
	_check(not g.is_discovered("ares"), "ares 未發現")
	# 開場簡介只給第一塊碎片（進度條不滿）
	GameManager.set_flag("intel_ares", true)
	_check(g.is_discovered("ares"), "set intel_ares → ares 已發現")
	var p := g.progress("ares")
	_check(int(p.got) == 1 and int(p.total) == 4, "ares 進度 1/4（got %d/%d）" % [int(p.got), int(p.total)])
	# 透過其他人（完成支線）補齊碎片
	GameManager.player.completed_quests.append("ah_zhong")
	_check(int(g.progress("ares").got) == 2, "完成阿忠支線 → ares 進度補到 2（got %d）" % int(g.progress("ares").got))
	var all := g.get_all()
	_check(all.size() == 13, "get_all size 13 (got %d)" % all.size())
	# 未發現的神不外洩（discovered=false）
	var hermes_undisc := false
	for e in all:
		if e.id == "hermes":
			hermes_undisc = not e.discovered
	_check(hermes_undisc, "hermes 未發現（briefing 未跑）")

func _test_new_dialogues() -> void:
	for name in NEW_DTLS:
		var path := "res://dialogue/%s.dtl" % name
		_check(ResourceLoader.exists(path), "對話存在：%s" % name)
		if not ResourceLoader.exists(path):
			continue
		var tl = load(path)
		_check(tl != null and tl is DialogicTimeline, "load timeline %s" % name)
		if tl == null:
			continue
		tl.process()
		var sig := 0
		for ev in tl.events:
			if ev != null and ev.event_name == "Signal":
				sig += 1
		_check(tl.events.size() >= 3, "%s 事件數 >=3 (got %d)" % [name, tl.events.size()])
		match name:
			"main_ch1_aftermath":
				_check(sig >= 12, "aftermath 12 神簡介解鎖 >=12 情報 signal (got %d)" % sig)
			"main_ch1_intel":
				_check(sig >= 2, "intel 含傳藝+旗標 >=2 signal (got %d)" % sig)
		tl.events.clear()
		tl = null

func _smoke_intel_app() -> void:
	var gs := load("res://src/ui/menu/pages/IntelApp.gd")
	_check(gs != null, "load IntelApp.gd")
	if gs:
		var page = gs.new()
		get_tree().root.add_child(page)
		for i in 3:
			await get_tree().process_frame
		_check(is_instance_valid(page), "IntelApp alive")
		page.queue_free()
		await get_tree().process_frame

func _smoke_phone_menu() -> void:
	var ps := load("res://src/ui/menu/MenuShell.tscn")
	_check(ps != null, "load MenuShell.tscn")
	if ps:
		var shell = ps.instantiate()
		shell.set("pause_game", false)
		get_tree().root.add_child(shell)
		for i in 4:
			await get_tree().process_frame
		if shell.has_method("_show_device"):
			shell._show_device("phone")
			await get_tree().process_frame
		_check(is_instance_valid(shell), "phone menu alive")
		shell.queue_free()
		await get_tree().process_frame

func _test_opening_wakeup() -> void:
	# --- 醒來過場資料存在 ---
	var cuts: Dictionary = JsonLoader.load_json("res://data/cutscenes.json")
	var wake: Dictionary = cuts.get("ch1_aftermath_wake", {})
	_check(not wake.is_empty(), "ch1_aftermath_wake 過場存在")
	_check((wake.get("shots", []) as Array).size() > 0, "ch1_aftermath_wake shots 非空")
	# --- main_quests hold 接線 ---
	var raw: Dictionary = JsonLoader.load_json("res://data/main_quests.json")
	var stages: Array = raw.get("ch01_ares", {}).get("stages", [])
	var by_id: Dictionary = {}
	for s in stages:
		by_id[String(s.get("id", ""))] = s
	_check(bool(by_id.get("c1_demolition", {}).get("hold", false)), "c1_demolition 帶 hold")
	var aft: Dictionary = by_id.get("c1_aftermath", {})
	_check(bool(aft.get("hold", false)), "c1_aftermath 帶 hold")
	# 2026-07-06 設計變更：移除 c1_aftermath 的純字幕過場 ch1_aftermath_wake（與後面 main_ch1_aftermath
	# 對話框的開頭旁白重覆＝使用者反映「有對話框了就不用沒立繪的純文字」，且該段字幕會卡跳過）。
	# 茶攤背景改由 main_ch1_aftermath.dtl 的 [background] 承載，故 c1_aftermath 不再帶 cutscene 欄。
	_check(not aft.has("cutscene"), "c1_aftermath 已移除純字幕過場（改由對話框背景承載）")
	_check(String(aft.get("dialogue", "")) == "main_ch1_aftermath", "c1_aftermath 仍有 main_ch1_aftermath 對話")
	_check(not by_id.get("c1_intel", {}).has("hold"), "c1_intel 無 hold")
	# --- 回地圖決策表（純函式，無副作用） ---
	var m := MainQuestManager
	# cutscene-only 未 held：過場後回地圖、收尾不回（同現行）
	var cs_only := {"id": "x", "cutscene": "foo"}
	_check(m.cutscene_return_to_map(cs_only) == true, "cutscene-only 未 held → 過場後回地圖")
	_check(m.should_return_to_map_after(cs_only, false) == false, "cutscene-only 未 held → 收尾不回")
	# c1_demolition(hold)：過場不回、收尾仍 held
	_check(m.cutscene_return_to_map(by_id["c1_demolition"]) == false, "c1_demolition 過場不回地圖")
	_check(m.should_return_to_map_after(by_id["c1_demolition"], true) == false, "c1_demolition 收尾仍 held")
	# c1_aftermath(hold+dialogue)：過場不回、收尾仍 held
	_check(m.cutscene_return_to_map(aft) == false, "c1_aftermath 過場不回地圖")
	_check(m.should_return_to_map_after(aft, true) == false, "c1_aftermath 收尾仍 held")
	# cutscene+dialogue 未 held：過場後不回（隔離測 has("dialogue") 分支，防 or 被刪仍綠）
	var cs_dlg_noheld := {"id": "z", "cutscene": "foo", "dialogue": "bar"}
	_check(m.cutscene_return_to_map(cs_dlg_noheld) == false, "cutscene+dialogue 未 held → 過場後不回地圖")
	# c1_intel(無 hold，承 held)：收尾回地圖
	_check(m.should_return_to_map_after(by_id["c1_intel"], true) == true, "c1_intel 收尾回地圖")
	# dialogue-only 未 held 未承 cinematic：收尾不回（不會每段對話重載地圖）
	var dlg_only := {"id": "y", "dialogue": "bar"}
	_check(m.should_return_to_map_after(dlg_only, false) == false, "dialogue-only 未承 cinematic 收尾不回")

func _test_skill_learning() -> void:
	# 鬼招防呆：grant_skill 不該把不存在於 skills.json 的招灌進池
	GameManager.player.skills_unlocked = ["basic_punch", "wooden_fish"]
	SkillUnlockManager.grant_skill("brahma_resonance")
	_check("brahma_resonance" not in GameManager.player.skills_unlocked, "junk brahma_resonance not granted")
	SkillUnlockManager.grant_skill("wooden_fish_fury")
	_check("wooden_fish_fury" not in GameManager.player.skills_unlocked, "junk wooden_fish_fury not granted")
	# ch1 門檻流：開局 2 招
	GameManager.player.skills_unlocked = ["basic_punch", "wooden_fish"]
	GameManager.player.completed_quests = []
	GameManager.player.flags.erase("kill_count")
	GameManager.player.flags.erase("weakness_hit_count")
	SkillUnlockManager._announced_learnable.clear()
	var gate := {"type": "skills", "min": 5}
	_check(not MainQuestManager.gate_passed(gate), "gate blocked at 2 skills")
	# 了塵 c1_intel 親授羅漢拳（story 直給）→ 3 招
	SkillUnlockManager.grant_skill("arhat_strike")
	_check(GameManager.player.skills_unlocked.size() == 3, "3 skills after arhat granted")
	_check(not MainQuestManager.gate_passed(gate), "gate still blocked at 3")
	# 保底純刷：打 6 場 + 弱點 5 次 → 破碗乞討 / 苦肉計「可學」（不自動學）
	GameManager.set_flag("kill_count", 6)
	GameManager.set_flag("weakness_hit_count", 5)
	SkillUnlockManager.check_unlocks(false)
	_check("broken_bowl_beg" not in GameManager.player.skills_unlocked, "broken_bowl_beg not auto-learned")
	_check(SkillUnlockManager.get_unlock_state("broken_bowl_beg").learnable, "broken_bowl_beg learnable via grind")
	_check(SkillUnlockManager.get_unlock_state("self_harm").learnable, "self_harm learnable via grind")
	_check(not MainQuestManager.gate_passed(gate), "gate still blocked before learning (learnable≠learned)")
	# 去經書習得兩招 → 5 招 → gate 開（純刷即可，無 softlock）
	_check(SkillUnlockManager.learn_skill("broken_bowl_beg"), "learn broken_bowl_beg")
	_check(SkillUnlockManager.learn_skill("self_harm"), "learn self_harm")
	_check(GameManager.player.skills_unlocked.size() == 5, "5 skills after learning 2")
	_check(MainQuestManager.gate_passed(gate), "gate passes at 5 (grind-only path, no softlock)")

## 2026-07-11：主線卡 c1_armory_gate 期間，前置支線（大村 ah_zhong／水野 zheng_ma／源造 lao_wang）
## 地點視為主線目標（橘點）。驗證三態：0 完成→三位全橘；完成 1 個→該點恢復、其餘仍橘；
## 完成 2 個（湊滿門檻）→ 全部恢復，橘點回了塵本人承接的「下一目標」。亦驗未卡在 gate／
## 已通關時 fail-open，不誤標。
func _test_gate_side_quest_orange_dots() -> void:
	var qm := QuestManager
	var saved_flags: Dictionary = GameManager.player.flags.duplicate()
	var saved_quests: Array = GameManager.player.completed_quests.duplicate()
	var npc_ah_zhong: Dictionary = qm._npcs.get("npc_ah_zhong", {})
	var npc_zheng_ma: Dictionary = qm._npcs.get("npc_zheng_ma", {})
	var npc_lao_wang: Dictionary = qm._npcs.get("npc_lao_wang", {})
	_check(not npc_ah_zhong.is_empty() and not npc_zheng_ma.is_empty() and not npc_lao_wang.is_empty(),
		"三位前置支線 NPC 都在 map_npcs.json")

	# 卡在 c1_armory_gate（stage index 對上）
	GameManager.player.flags.erase("ares_purified")
	GameManager.set_flag("main_stage_ch01_ares", 4)
	_check(MainQuestManager.is_blocked_at_gate("ch01_ares", "c1_armory_gate"), "stage index 4 → 判定卡在 gate")

	# 0 完成：三位全橘
	GameManager.player.completed_quests = []
	var pending0: Array = qm.c1_armory_gate_pending_quests()
	_check(pending0.size() == 3, "0 完成 → pending 3 位 (got %d)" % pending0.size())
	_check(qm.location_has_main_quest(npc_ah_zhong), "0 完成 → 大村(ah_zhong)橘")
	_check(qm.location_has_main_quest(npc_zheng_ma), "0 完成 → 水野(zheng_ma)橘")
	_check(qm.location_has_main_quest(npc_lao_wang), "0 完成 → 源造(lao_wang)橘")

	# 完成 1 個（大村）→ 該點恢復、其餘仍橘
	GameManager.player.completed_quests = ["ah_zhong"]
	var pending1: Array = qm.c1_armory_gate_pending_quests()
	_check(pending1.size() == 2 and "ah_zhong" not in pending1,
		"完成 1 個 → pending 剩 2 位且不含已完成者 (got %s)" % str(pending1))
	_check(not qm.location_has_main_quest(npc_ah_zhong), "完成大村 → 該點恢復（不再橘）")
	_check(qm.location_has_main_quest(npc_zheng_ma), "完成大村 → 水野仍橘")
	_check(qm.location_has_main_quest(npc_lao_wang), "完成大村 → 源造仍橘")

	# 完成 2 個（大村+水野）→ 全部恢復（即使源造仍未完成，也不再追著跑第三位）
	GameManager.player.completed_quests = ["ah_zhong", "zheng_ma"]
	var pending2: Array = qm.c1_armory_gate_pending_quests()
	_check(pending2.is_empty(), "完成 2 個 → pending 清空 (got %s)" % str(pending2))
	_check(not qm.location_has_main_quest(npc_ah_zhong), "完成 2 個 → 大村恢復")
	_check(not qm.location_has_main_quest(npc_zheng_ma), "完成 2 個 → 水野恢復")
	_check(not qm.location_has_main_quest(npc_lao_wang), "完成 2 個 → 源造也恢復（湊滿即回主線本身）")
	# 了塵本人的 main_quest 點不受影響，全程恆橘（demo 未完成）
	_check(qm.location_has_main_quest(qm._npcs.get("npc_liaochen", {})), "了塵本人 main_quest 點恆橘，承接『下一目標』")

	# 未卡在 gate（stage 已推進過去）→ fail-open，不誤標，即使 0 完成
	GameManager.player.completed_quests = []
	GameManager.set_flag("main_stage_ch01_ares", 5)
	_check(not MainQuestManager.is_blocked_at_gate("ch01_ares", "c1_armory_gate"), "stage index 5 → 已不卡在 gate")
	_check(qm.c1_armory_gate_pending_quests().is_empty(), "未卡在 gate → pending 空（fail-open）")
	_check(not qm.location_has_main_quest(npc_ah_zhong), "未卡在 gate → 大村不誤標橘")

	# 已通關（ares_purified）→ fail-open
	GameManager.set_flag("main_stage_ch01_ares", 4)
	GameManager.set_flag("ares_purified", true)
	_check(not MainQuestManager.is_blocked_at_gate("ch01_ares", "c1_armory_gate"), "章已完成 → 不算卡在 gate")
	_check(qm.c1_armory_gate_pending_quests().is_empty(), "章已完成 → pending 空")

	GameManager.player.flags = saved_flags
	GameManager.player.completed_quests = saved_quests

## 了塵重複對話（main_ch1_not_ready）在卡 gate 期間要點名還沒去見的前置支線 NPC。
## 實跑 Dialogic 兩態：0 完成→點名大村+源造；完成 2 個(大村+水野)→改點名剩下的源造。
## 用 Dialogic.History 的 simple_history 撈實際播出的文字比對，不只是「解析成功」的靜態檢查。
func _test_gate_side_quest_dialogue_hints() -> void:
	if not ResourceLoader.exists("res://dialogue/main_ch1_not_ready.dtl"):
		_check(false, "main_ch1_not_ready.dtl 存在")
		return
	var saved_quests: Array = GameManager.player.completed_quests.duplicate()

	# 結構鐵則：if/elif/else 分支數對得上（8 態＝1 if+6 elif+1 else，Dialogic 的 Condition
	# 事件涵蓋 if/elif/else 三種 condition_type，故節點數=8），且仍無『- 選項』（Choice）
	# ——原檔本就 0 個選項，改動不准新增。
	var tl = load("res://dialogue/main_ch1_not_ready.dtl")
	tl.process()
	var cond_count := 0
	var choice_count := 0
	for ev in tl.events:
		if ev == null:
			continue
		if ev.event_name == "Condition":
			cond_count += 1
		elif ev.event_name == "Choice":
			choice_count += 1
	_check(cond_count == 8, "main_ch1_not_ready 有 8 個 Condition 節點(if+6 elif+else) (got %d)" % cond_count)
	_check(choice_count == 0, "main_ch1_not_ready 仍無『- 選項』分支，選項數不變 (got %d)" % choice_count)
	tl.events.clear()
	tl = null

	GameManager.player.completed_quests = []
	var text0: String = await _play_and_collect("main_ch1_not_ready")
	_check(text0.find("大村") != -1, "0 完成 → 台詞點名大村 (got: %s)" % text0)
	_check(text0.find("源造") != -1, "0 完成 → 台詞點名源造 (got: %s)" % text0)

	GameManager.player.completed_quests = ["ah_zhong", "zheng_ma"]
	var text2: String = await _play_and_collect("main_ch1_not_ready")
	_check(text2.find("源造") != -1, "完成大村+水野 → 台詞改點名剩下的源造 (got: %s)" % text2)
	_check(not text2.is_empty(), "完成大村+水野 → 有實際播出文字（Dialogic 真的跑完 timeline）")

	GameManager.player.completed_quests = saved_quests

## 播放一條 timeline 到底，回傳 Dialogic.History 收到的全部文字串接（供比對台詞內容）。
func _play_and_collect(timeline: String) -> String:
	Dialogic.History.simple_history_content = []
	Dialogic.start(timeline)
	await get_tree().process_frame
	var guard := 0
	# skip_text_reveal() 讓 typewriter 立即顯示完整文字，才能可靠推進到下一事件——純
	# process_frame/短 timer 在字數多時等不到 text_finished，handle_next_event() 會對著
	# 還卡在 reveal 中的事件空打（同 CaptureDialogueFont.gd 慣例）。
	while Dialogic.current_timeline != null and guard < 40:
		await get_tree().create_timer(0.15).timeout
		if Dialogic.has_subsystem("Text"):
			Dialogic.Text.skip_text_reveal()
		await get_tree().create_timer(0.15).timeout
		if Dialogic.current_timeline != null:
			Dialogic.handle_next_event()
		await get_tree().process_frame
		guard += 1
	await get_tree().process_frame
	var out := ""
	for e in Dialogic.History.get_simple_history():
		out += String(e.get("text", "")) + "\n"
	return out
