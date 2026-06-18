extends Node
## 主線推進引擎：讀 data/main_quests.json（12 章一神，線性），逐章逐 stage 以協程
## await 串接 cutscene / dialogue / battle / boss，通章設 complete_flag ＋發 rewards。
## 成就（十二因緣）由各章 complete_flag 對應（achievements.json），AchievementSystem 待實作。
##
## 入口：地圖「主線」動作 → continue_story()。autoload（見 project.godot）。

signal chapter_started(chapter_id: String)
signal chapter_completed(chapter_id: String)
signal main_quest_all_cleared()

const DATA_PATH := "res://data/main_quests.json"

var _chapters: Dictionary = {}   # id -> chapter data
var _order: Array = []           # chapter ids，依 order 排序
var _running: bool = false
var _demo_last_chapter: String = ""   # DEMO 版最後一章 id（"" = 全本，不設上限）
var _on_cinematic_backdrop: bool = false   # 上一過場 held 住（凍結最後一格當對話背景，未回地圖）

func _ready() -> void:
	var raw: Dictionary = JsonLoader.load_json(DATA_PATH)
	raw.erase("_schema")
	var demo: Dictionary = raw.get("_demo", {})
	_demo_last_chapter = String(demo.get("last_chapter", ""))
	raw.erase("_demo")
	var ids: Array = raw.keys()
	ids.sort_custom(func(a, b): return int(raw[a].get("order", 0)) < int(raw[b].get("order", 0)))
	for cid in ids:
		_chapters[cid] = raw[cid]
		_order.append(cid)

## 目前該推進的章＝第一個「未完成且前置旗標已滿足」的章。
## "" = 全部破關，或被前置擋住（線性流程下後者不該發生）。
func current_chapter_id() -> String:
	for cid in _order:
		var c: Dictionary = _chapters[cid]
		if bool(GameManager.get_flag(c.get("complete_flag", ""))):
			continue
		var req: String = c.get("require_flag", "")
		if req != "" and not bool(GameManager.get_flag(req)):
			return ""
		return cid
	return ""

func is_all_cleared() -> bool:
	if _order.is_empty():
		return false
	var last: Dictionary = _chapters[_order[-1]]
	return bool(GameManager.get_flag(last.get("complete_flag", "")))

## DEMO 版最後一章 id（""＝無上限）。
func demo_last_chapter() -> String:
	return _demo_last_chapter

## DEMO 是否已完成＝demo 最後一章的 complete_flag 已設。完整版(_demo_last_chapter=="")永遠 false。
func is_demo_complete() -> bool:
	if _demo_last_chapter == "":
		return false
	var c: Dictionary = _chapters.get(_demo_last_chapter, {})
	return bool(GameManager.get_flag(c.get("complete_flag", "")))

func get_chapter(cid: String) -> Dictionary:
	return _chapters.get(cid, {})

## 該章目前進行到第幾個 stage（0-based；供任務 app 顯示進度）。
func stage_index(cid: String) -> int:
	return int(GameManager.get_flag(_stage_key(cid), 0))

## 從地圖「主線」動作呼叫：推進目前章（從上次中斷的 stage 續跑整章）。
## DEMO 版：打完最後一章後，不再跑 ch2+，改播 demo 收尾。
func continue_story() -> void:
	if _running:
		return
	if is_demo_complete():
		_running = true
		await _show_demo_end()
		_running = false
		return
	var cid: String = current_chapter_id()
	if cid == "":
		return
	_running = true
	await _run_chapter(cid)
	# 剛通關 demo 最後一章 → 接著播 demo 收尾（取代掉進空的 ch2+）。
	if is_demo_complete():
		await _show_demo_end()
	_running = false

## DEMO 收尾：播「demo 到此結束」旁白（無檔案則靜默返回地圖）。
func _show_demo_end() -> void:
	await _play_dialogue("demo_end")
	await SceneRouter.go_to_map()

func _stage_key(cid: String) -> String:
	return "main_stage_" + cid

func _run_chapter(cid: String) -> void:
	var c: Dictionary = _chapters[cid]
	chapter_started.emit(cid)
	var stages: Array = c.get("stages", [])
	var start_idx: int = int(GameManager.get_flag(_stage_key(cid), 0))
	_on_cinematic_backdrop = false  # 防呆：清掉前一次（可能中止的）held 鏈殘留狀態，避免跨章誤跳回地圖
	for i in range(start_idx, stages.size()):
		GameManager.set_flag(_stage_key(cid), i)
		var stage_ok: bool = await _run_stage(stages[i])
		if not stage_ok:
			return  # 戰敗中止：保留 stage 進度，玩家回古廟後可再選「主線」續推
	_complete_chapter(cid)

## 此 stage 的過場播完是否該回地圖（= _play_cutscene 的 return_to_map 值）。
## held、或同 stage 後面還有 dialogue 要疊在過場上 → 不回地圖。純函式，供測試。
func cutscene_return_to_map(stage: Dictionary) -> bool:
	return not (bool(stage.get("hold", false)) or stage.has("dialogue"))

## 此 stage 收尾是否該回地圖：非 held 且目前正掛在 cinematic 背景上（承接 held 鏈）。
## 純函式，供測試。
func should_return_to_map_after(stage: Dictionary, on_cinematic_backdrop: bool) -> bool:
	return (not bool(stage.get("hold", false))) and on_cinematic_backdrop

## 修練門檻是否通過。type=skills → 已解鎖技能數 >= min。供 gate stage 與測試用。
func gate_passed(gate: Dictionary) -> bool:
	match String(gate.get("type", "")):
		"skills":
			return GameManager.player.skills_unlocked.size() >= int(gate.get("min", 0))
	return true

## 執行單一 stage：依鍵別依序播敘事/場景。回傳 false = 中止本章（保留 stage 進度可續推）。
func _run_stage(stage: Dictionary) -> bool:
	if stage.has("gate"):
		var gate: Dictionary = stage.gate
		if not gate_passed(gate):
			# 未達修練門檻：播「再去歷練」對話，中止本章 → 玩家回地圖歷練/解支線，
			# 之後任務 app「繼續主線」會從本 gate stage 重新檢查。
			if gate.has("fail_dialogue"):
				await _play_dialogue(String(gate.fail_dialogue))
			return false
		if gate.has("pass_dialogue"):
			await _play_dialogue(String(gate.pass_dialogue))
	if stage.has("cutscene"):
		await _play_cutscene(String(stage.cutscene), cutscene_return_to_map(stage))
	if stage.has("dialogue"):
		await _play_dialogue(String(stage.dialogue))
	if stage.has("battle"):
		if not await _play_battle(String(stage.battle)):
			return false
	if stage.has("boss"):
		if not await _play_battle(String(stage.boss)):
			return false
	if stage.has("set_flag"):
		GameManager.set_flag(String(stage.set_flag), true)
	# 整段 cinematic 鏈落幕：第一個非 held 的 stage（如 c1_intel）收尾，把 held 茶攤換回地圖。
	if should_return_to_map_after(stage, _on_cinematic_backdrop):
		await SceneRouter.go_to_map()
		_on_cinematic_backdrop = false
	return true

func _play_cutscene(id: String, return_to_map: bool = true) -> void:
	await SceneRouter.play_story_cutscene(id, "")
	if return_to_map:
		await SceneRouter.go_to_map()  # 結束後回地圖當中性 hub，供下一 stage 的對話/操作
	else:
		_on_cinematic_backdrop = true  # held：凍結最後一格當背景，整段 cinematic 結束才回地圖

func _play_dialogue(timeline: String) -> void:
	if not ResourceLoader.exists("res://dialogue/%s.dtl" % timeline):
		push_warning("MainQuest: 對話 %s 未製作，略過" % timeline)
		return
	# 沉澱輸入 0.35s：上一幕過場的跳過鍵（Enter/空白）＝對話推進鍵，殘留輸入會連跳對話。
	await get_tree().create_timer(0.35).timeout
	Dialogic.start(timeline)
	await Dialogic.timeline_ended

func _play_battle(enemy_id: String) -> bool:
	SceneRouter.go_to_battle(enemy_id)
	var result: Variant = await EventBus.battle_ended
	# 等 BattleManager 自行返回地圖後再續，避免與其 go_to_map 競爭場景切換。
	await get_tree().create_timer(1.3).timeout
	return String(result) == "win"

func _complete_chapter(cid: String) -> void:
	var c: Dictionary = _chapters[cid]
	var cf: String = c.get("complete_flag", "")
	if cf != "":
		GameManager.set_flag(cf, true)  # ＝下一章 require_flag，也＝對應成就 unlock_flag
	_grant_rewards(c.get("rewards", {}))
	GameManager.set_flag(_stage_key(cid), 0)
	chapter_completed.emit(cid)
	if current_chapter_id() == "":
		main_quest_all_cleared.emit()

func _grant_rewards(rewards: Dictionary) -> void:
	if rewards.has("gold"):
		GameManager.add_gold(int(rewards.gold))
	if rewards.has("merit"):
		GameManager.add_merit(int(rewards.merit))
	if rewards.has("karma"):
		GameManager.add_karma(int(rewards.karma))
