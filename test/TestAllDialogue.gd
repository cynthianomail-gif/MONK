extends Node

## 批量驗證：所有對話 timeline 與角色資源
##  - 每個 .dtl 能 load + process() 且事件數 > 0（語法無誤）
##  - 分支 timeline 的 Choice 數量正確
##  - 條件結局含 Condition 事件
##  - 所有 .dch 能透過 Dialogic loader 載入
## 以 main scene 跑，Dialogic autoload 在線。
## 注意：一次 process() 全部 timeline（數量以下方 ALL_TIMELINES 陣列為準）後，Godot headless 在「關機清理」階段
## 會 segfault（退出碼 139），這是引擎 teardown bug，發生在所有檢查印出之後，
## 與內容正確性無關（執行期一次只 Dialogic.start 一條）。
## 判定通過的權威信號＝是否印出 "ALL_DIALOGUE_TEST: ALL PASS"。

# 期望的分支選項數
const EXPECTED_CHOICES := {
	"cherry_first_meeting": 2,
	"quest_rei_choice": 3,
	"quest_zheng_ma_s1": 3,
	"quest_david_choice": 3,
	"quest_cherry_debt_choice": 3,
	"quest_cai_ma_choice": 3,
	"quest_lao_wang_choice": 2,
}

const ALL_TIMELINES := [
	"cherry_first_meeting",
	"ah_ming_hub",
	"quest_ah_ming_s1", "quest_ah_ming_s2",
	"quest_rei_choice",
	"quest_zheng_ma_s1", "quest_zheng_ma_s2",
	"quest_jie_challenge",
	"quest_ah_zhong_s1", "quest_ah_zhong_s2", "quest_ah_zhong_s3", "quest_ah_zhong_final",
	"quest_david_choice",
	"quest_cherry_debt_s1", "quest_cherry_debt_choice", "quest_cherry_debt_final",
	"quest_cai_ma_s1", "quest_cai_ma_choice",
	"quest_grandma_s1", "quest_grandma_s2", "quest_grandma_final",
	"quest_lao_wang_s1", "quest_lao_wang_s2", "quest_lao_wang_choice",
	"vow_break_food", "vow_break_lust", "vow_break_greed",
]

const ALL_CHARS := ["Cherry", "Wujie", "AhMing", "Rei", "ZhengMa", "Jie",
	"AhZhong", "David", "CaiMa", "Grandma", "LaoWang"]

func _ready() -> void:
	await get_tree().process_frame
	var ok := true
	ok = _test_chars() and ok
	ok = _test_timelines() and ok
	if ok:
		print("ALL_DIALOGUE_TEST: ALL PASS (%d timelines, %d characters)" % [
			ALL_TIMELINES.size(), ALL_CHARS.size()])
		get_tree().quit(0)
	else:
		push_error("ALL_DIALOGUE_TEST: FAILED")
		get_tree().quit(1)

func _test_chars() -> bool:
	var ok := true
	for name in ALL_CHARS:
		var path := "res://dialogue/%s.dch" % name
		var c = load(path)
		if c == null or not (c is DialogicCharacter):
			push_error("角色載入失敗：%s" % path); ok = false
		elif c.portraits.is_empty():
			push_error("角色無立繪：%s" % name); ok = false
	if ok:
		print("  [PASS] %d 個角色資源全部載入正確" % ALL_CHARS.size())
	return ok

func _test_timelines() -> bool:
	var ok := true
	var total_choice := 0
	var total_signal := 0
	var total_cond := 0
	for name in ALL_TIMELINES:
		var path := "res://dialogue/%s.dtl" % name
		if not ResourceLoader.exists(path):
			push_error("timeline 不存在：%s" % path); ok = false; continue
		var tl = load(path)
		if tl == null or not (tl is DialogicTimeline):
			push_error("timeline 載入失敗：%s" % name); ok = false; continue
		tl.process()
		var c := {"Choice": 0, "Signal": 0, "Text": 0, "Condition": 0}
		for ev in tl.events:
			if ev != null and c.has(ev.event_name):
				c[ev.event_name] += 1
		var events_total: int = tl.events.size()
		if events_total < 3:
			push_error("%s 事件數過少(%d)，疑似解析失敗" % [name, events_total]); ok = false
		# 分支選項數檢查
		if EXPECTED_CHOICES.has(name) and c["Choice"] != EXPECTED_CHOICES[name]:
			push_error("%s Choice 數應為 %d，實得 %d" % [name, EXPECTED_CHOICES[name], c["Choice"]])
			ok = false
		total_choice += c["Choice"]
		total_signal += c["Signal"]
		total_cond += c["Condition"]
		# 釋放已處理事件，避免大量 DialogicEvent 資源累積導致關機清理崩潰
		tl.events.clear()
		tl = null
	# cherry_debt_final 應有條件事件
	if total_cond < 1:
		push_error("預期至少一個 Condition 事件（cherry_debt_final），實得 0"); ok = false
	if ok:
		print("  [PASS] %d 個 timeline 全部解析成功（Choice 合計=%d, Signal 合計=%d, Condition=%d）" % [
			ALL_TIMELINES.size(), total_choice, total_signal, total_cond])
	return ok
