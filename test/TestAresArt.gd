extends Node
## headless 驗證：第 1 章 Ares 過場/對話的正式美術接線。
##  - okami 現身圖 (ok_ares_reveal.png) 已匯入、可載入為 Texture2D
##  - HQ 外觀圖 (hq_exterior.jpg) 已匯入、可載入為 Texture2D
##  - cutscenes.json 的 ares_intro 指向 ok_ares_reveal.png（不再借 gods/ares.jpg，也不再是洗字前的 ares_reveal.jpg）
##  - main_ares_lead.dtl 解析正常，含開頭 HQ 背景事件 + 結尾清空事件
## 跑法：Godot --headless res://test/TestAresArt.tscn
## 註：2026-06-24 okami 水墨整合（commit 2eb4bec）把 ares_intro 的現身圖從 ares_reveal.jpg
## 換成 ok_ares_reveal.png；本測試於 2026-07-06 同步更新斷言以反映此事實。

var ok: bool = true

const ARES_REVEAL := "res://assets/cutscenes/ch1_ares/ok_ares_reveal.png"
const HQ_EXTERIOR := "res://assets/cutscenes/ch1_ares/hq_exterior.jpg"
const OLD_BORROW := "res://assets/2d/gods/ares.jpg"

func _ready() -> void:
	await get_tree().process_frame
	_test_images()
	_test_cutscene_wiring()
	_test_dialogue_background()
	print("ARES_ART_TEST: ", "ALL PASS" if ok else "HAS FAILURES")
	get_tree().quit(0 if ok else 1)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		ok = false
		print("FAIL: ", msg)

func _test_images() -> void:
	for path in [ARES_REVEAL, HQ_EXTERIOR]:
		_check(ResourceLoader.exists(path), "圖已匯入存在：%s" % path)
		var tex = load(path)
		_check(tex is Texture2D, "圖可載入為 Texture2D：%s" % path)

func _test_cutscene_wiring() -> void:
	var cuts: Dictionary = JsonLoader.load_json("res://data/cutscenes.json")
	var shots: Array = cuts.get("ares_intro", {}).get("shots", [])
	var images: Array = []
	for s in shots:
		images.append(String(s.get("image", "")))
	_check(images.has(ARES_REVEAL), "ares_intro 指向 okami 現身圖 (ok_ares_reveal.png)")
	_check(not images.has(OLD_BORROW), "ares_intro 不再借 gods/ares.jpg")

func _test_dialogue_background() -> void:
	var path := "res://dialogue/main_ares_lead.dtl"
	_check(ResourceLoader.exists(path), "main_ares_lead.dtl 存在")
	var tl = load(path)
	_check(tl is DialogicTimeline, "main_ares_lead 載入為 DialogicTimeline")
	if not (tl is DialogicTimeline):
		return
	tl.process()
	var bg_args: Array = []
	for ev in tl.events:
		if ev != null and ev.event_name == "Background":
			bg_args.append(String(ev.argument))
	_check(bg_args.size() >= 2, "含 >=2 個 Background 事件 (got %d)" % bg_args.size())
	_check(bg_args.has(HQ_EXTERIOR), "開頭背景指向 HQ 外觀圖 (got %s)" % str(bg_args))
	_check(bg_args.has(""), "結尾有清空背景事件")
