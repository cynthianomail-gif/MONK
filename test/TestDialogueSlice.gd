extends Node

## 垂直切片驗證：Cherry 初遇對話
##  1. Cherry.dch / Wujie.dch 透過 Dialogic loader 正確載入（格式正確、立繪存在）
##  2. cherry_first_meeting.dtl 語法正確（process() 後含 Choice 2 選項 + Signal 事件）
##  3. GameManager 對話橋接：affection 累加、flag 設定
## 以 main scene 跑，autoload（Dialogic / GameManager）皆在線。

func _ready() -> void:
	await get_tree().process_frame
	var ok := true
	ok = _test_characters() and ok
	ok = _test_timeline() and ok
	ok = _test_bridge() and ok
	if ok:
		print("DIALOGUE_SLICE_TEST: ALL PASS")
		get_tree().quit(0)
	else:
		push_error("DIALOGUE_SLICE_TEST: FAILED")
		get_tree().quit(1)

func _test_characters() -> bool:
	var ok := true
	var cherry = load("res://dialogue/Cherry.dch")
	if cherry == null or not (cherry is DialogicCharacter):
		push_error("Cherry.dch 載入失敗或型別錯誤")
		return false
	if cherry.display_name != "櫻":
		push_error("Cherry display_name 錯：%s" % cherry.display_name); ok = false
	for p in ["neutral", "smile", "sorrow", "angry"]:
		if not cherry.portraits.has(p):
			push_error("Cherry 缺立繪 %s" % p); ok = false
	if cherry.default_portrait != "neutral":
		push_error("Cherry default_portrait 錯"); ok = false

	var wujie = load("res://dialogue/Wujie.dch")
	if wujie == null or not (wujie is DialogicCharacter):
		push_error("Wujie.dch 載入失敗或型別錯誤"); return false
	for p in ["calm", "angry", "happy", "surprised"]:
		if not wujie.portraits.has(p):
			push_error("Wujie 缺立繪 %s" % p); ok = false

	# 驗立繪圖檔實際存在（image override 為 var_to_str 後的帶引號字串）
	for c in [cherry, wujie]:
		for name in c.portraits:
			var raw: String = c.portraits[name].get("export_overrides", {}).get("image", "")
			var img_path: String = str_to_var(raw) if raw else ""
			if img_path == "" or not ResourceLoader.exists(img_path):
				push_error("立繪檔不存在：%s (%s/%s)" % [img_path, c.display_name, name]); ok = false
	if ok:
		print("  [PASS] 角色資源 Cherry/Wujie 載入正確，立繪齊全且圖檔存在")
	return ok

func _test_timeline() -> bool:
	var tl = load("res://dialogue/cherry_first_meeting.dtl")
	if tl == null or not (tl is DialogicTimeline):
		push_error("cherry_first_meeting.dtl 載入失敗"); return false
	tl.process()
	var counts := {"Choice": 0, "Signal": 0, "Text": 0}
	for ev in tl.events:
		if ev != null and counts.has(ev.event_name):
			counts[ev.event_name] += 1
	var ok := true
	if counts["Choice"] != 2:
		push_error("Choice 事件數應為 2，實得 %d" % counts["Choice"]); ok = false
	if counts["Signal"] < 3:
		push_error("Signal 事件數應 >=3，實得 %d" % counts["Signal"]); ok = false
	if counts["Text"] < 8:
		push_error("Text 事件偏少（%d），疑似解析失敗" % counts["Text"]); ok = false
	if ok:
		print("  [PASS] timeline 解析正確：Choice=%d Signal=%d Text=%d" % [
			counts["Choice"], counts["Signal"], counts["Text"]])
	return ok

func _test_bridge() -> bool:
	var ok := true
	GameManager.set_flag("cherry_affection", 0)
	GameManager.set_flag("cherry_met", false)
	GameManager._on_dialogic_signal("affection:+10")
	GameManager._on_dialogic_signal("affection:+2")
	GameManager._on_dialogic_signal("flag:cherry_met")
	if int(GameManager.get_flag("cherry_affection", 0)) != 12:
		push_error("affection 累加錯：%s" % str(GameManager.get_flag("cherry_affection"))); ok = false
	if GameManager.get_flag("cherry_met", false) != true:
		push_error("flag:cherry_met 未設定"); ok = false
	if ok:
		print("  [PASS] 對話橋接：affection=12, cherry_met=true")
	return ok
