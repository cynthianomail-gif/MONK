extends Node
## 多槽存檔（2026-07-08 由單槽升級）：三槽獨立檔 user://save_slot_{1,2,3}.json，
## 目前使用中的槽位記在 user://save_meta.json（{"active_slot": n}）。
## save_game()/load_game() 保持零參數簽名（全專案既有呼叫點不用改）：
## 內部一律讀寫 active_slot；跨日自動存檔、地圖存檔動作都自然落在使用中的槽。
## 舊版單槽存檔（user://save.json）在第一次存取時遷移進 slot1，並改名 .bak 保留備份。

const SLOT_COUNT: int = 3
const SLOT_PATH_FMT: String = "user://save_slot_%d.json"
const META_PATH: String = "user://save_meta.json"
const LEGACY_SAVE_PATH: String = "user://save.json"

var active_slot: int = 1
var _migrated: bool = false

func _slot_path(n: int) -> String:
	return SLOT_PATH_FMT % n

## 舊檔遷移：若 user://save.json 存在且 slot1 尚無檔案 → 搬到 slot1，舊檔改名 .bak 保留備份。
## 冪等：已遷移過（或本來就沒有舊檔）就不重複動作。
func _ensure_migrated() -> void:
	if _migrated:
		return
	_migrated = true
	_load_meta()
	if not FileAccess.file_exists(LEGACY_SAVE_PATH):
		return
	if FileAccess.file_exists(_slot_path(1)):
		return  # slot1 已有資料，不覆蓋
	var legacy_abs := ProjectSettings.globalize_path(LEGACY_SAVE_PATH)
	var slot1_abs := ProjectSettings.globalize_path(_slot_path(1))
	var dir := DirAccess.open("user://")
	if dir:
		dir.copy(legacy_abs, slot1_abs)
		dir.rename(legacy_abs, legacy_abs + ".bak")
	# 注意：這裡不強制 active_slot=1——meta 若已指向別槽（例如舊檔玩家開新遊戲時
	# select_slot_for_new_game() 挑了空槽），強制切回 1 會讓下一次自動存檔
	# 蓋掉剛遷移進 slot1 的舊進度。沒有 meta 時 _load_meta() 本來就預設 1。

func _load_meta() -> void:
	if not FileAccess.file_exists(META_PATH):
		active_slot = 1
		return
	var file := FileAccess.open(META_PATH, FileAccess.READ)
	if file == null:
		active_slot = 1
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("active_slot"):
		active_slot = clampi(int(parsed["active_slot"]), 1, SLOT_COUNT)
	else:
		active_slot = 1

func _save_meta() -> void:
	var file := FileAccess.open(META_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: 無法寫入 meta %s" % META_PATH)
		return
	file.store_string(JSON.stringify({"active_slot": active_slot}))
	file.close()

## ── 舊介面（零參數，全專案既有呼叫點不用改）：一律作用於 active_slot ──
func has_save() -> bool:
	_ensure_migrated()
	return FileAccess.file_exists(_slot_path(active_slot))

func save_game() -> void:
	_ensure_migrated()
	save_to_slot(active_slot)

func load_game() -> bool:
	_ensure_migrated()
	return load_from_slot(active_slot)

func delete_save() -> void:
	_ensure_migrated()
	var path := _slot_path(active_slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

## ── 新介面：多槽 ──
## 新遊戲開跑前呼叫（TitleScreen「開始」）：把 active_slot 指到第一個空槽，
## 讓之後的自動存檔不會蓋掉既有進度（含尚未遷移的舊版 save.json——
## slot_exists 已把它視為 slot1）。三槽全滿時**不動 active_slot、不寫 meta**，
## 呼叫端（TitleScreen）要自行判斷「全滿」並改走 SaveSlotPicker(new_game 模式)
## 讓玩家明確選槽＋二次確認覆蓋，再呼叫 set_active_slot_for_new_game()——
## 2026-07-10 QC P0 前的舊行為是「三槽全滿時沿用 active_slot 無聲覆蓋」，
## 屬於資料安全缺陷，已改掉。
func select_slot_for_new_game() -> void:
	_load_meta()
	for n in range(1, SLOT_COUNT + 1):
		if not slot_exists(n):
			if active_slot != n:
				active_slot = n
				_save_meta()
			return

## 三槽全滿時，玩家已在 SaveSlotPicker(new_game 模式) 明確選定＋二次確認覆蓋某槽後，
## TitleScreen 呼叫這個把 active_slot 指過去（不管該槽有沒有資料）。之後
## GameManager.new_game() + 首次自動存檔（save_to_slot 內建 _ensure_migrated）
## 會自然覆蓋該槽——若該槽其實是「未遷移的舊版 save.json」，_ensure_migrated
## 會先把舊檔搬成 slot1 + .bak 備份，新進度才落地，舊資料仍留一份 .bak。
func set_active_slot_for_new_game(n: int) -> void:
	if n < 1 or n > SLOT_COUNT:
		push_error("SaveManager: 槽位超出範圍 %d" % n)
		return
	_load_meta()
	if active_slot != n:
		active_slot = n
		_save_meta()

func save_to_slot(n: int) -> void:
	_ensure_migrated()
	if n < 1 or n > SLOT_COUNT:
		push_error("SaveManager: 槽位超出範圍 %d" % n)
		return
	var path := _slot_path(n)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: 無法寫入存檔 %s" % path)
		return
	var data: Dictionary = GameManager.player.duplicate(true)
	data["_saved_at"] = Time.get_datetime_string_from_system()
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	active_slot = n
	_save_meta()

func load_from_slot(n: int) -> bool:
	_ensure_migrated()
	if n < 1 or n > SLOT_COUNT:
		push_error("SaveManager: 槽位超出範圍 %d" % n)
		return false
	var path := _slot_path(n)
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveManager: 存檔格式錯誤")
		return false
	# 以預設值為底合併，避免舊存檔缺欄位
	for key in parsed:
		if key == "_saved_at":
			continue
		GameManager.player[key] = parsed[key]
	active_slot = n
	_save_meta()
	return true

func slot_exists(n: int) -> bool:
	if n < 1 or n > SLOT_COUNT:
		return false
	if FileAccess.file_exists(_slot_path(n)):
		return true
	# 尚未遷移的舊版單槽檔視為 slot1 有資料。純檔案存在檢查、不觸發搬檔——
	# 開機畫面/headless 測試會走到這裡，不得動使用者真實 save.json；
	# 真正的遷移留給 save/load 路徑的 _ensure_migrated()。
	return n == 1 and FileAccess.file_exists(LEGACY_SAVE_PATH)

## 槽位摘要：{exists, day, period_name, gold, area_name, saved_at}。
## 不存在的槽只回 {exists:false}，不動記憶體中的 GameManager.player。
## 未遷移的舊版單槽檔一律當 slot1 顯示（只讀，不搬檔，理由同 slot_exists）。
func slot_summary(n: int) -> Dictionary:
	if n < 1 or n > SLOT_COUNT:
		return {"exists": false}
	var path := _slot_path(n)
	if not FileAccess.file_exists(path):
		if n == 1 and FileAccess.file_exists(LEGACY_SAVE_PATH):
			path = LEGACY_SAVE_PATH
		else:
			return {"exists": false}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"exists": false}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"exists": false}
	var period_idx: int = int(parsed.get("period", 0))
	var period_names: Array = GameManager.TIME_PERIODS
	var period_name: String = period_names[period_idx] if period_idx >= 0 and period_idx < period_names.size() else "?"
	var area_id: String = String(parsed.get("current_area", ""))
	return {
		"exists": true,
		"day": int(parsed.get("day", 1)),
		"period_name": period_name,
		"gold": int(parsed.get("gold", 0)),
		"area_name": _area_display_name(area_id),
		"saved_at": String(parsed.get("_saved_at", "")),
	}

## 區域顯示名：沿用 areas.json（有就用顯示名，沒有就回傳原始 id）。
func _area_display_name(area_id: String) -> String:
	if area_id == "":
		return "?"
	var areas: Dictionary = JsonLoader.load_json("res://data/areas.json")
	if areas.has(area_id) and typeof(areas[area_id]) == TYPE_DICTIONARY and areas[area_id].has("name"):
		return String(areas[area_id]["name"])
	return area_id
