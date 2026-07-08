extends Node
## headless 測試：存檔多槽（J3，2026-07-08）。
## 跑法：Godot --headless res://test/TestSaveSlots.tscn
##
## ⚠ headless 的 user:// 是「真的」使用者存檔目錄（不是沙盒）。本測試會：
## 1) 開跑前把使用者現有的 save_slot_*.json / save_meta.json / save.json(.bak) 搬到暫存備份目錄
## 2) 測試全程只操作乾淨狀態
## 3) 結束時（無論成敗）把備份還原、清掉測試自己造的檔案
## 不这样做的話，這支測試會直接改到 Cynthia 電腦上的真實存檔。

var ok := true

const SLOT_FILES := ["save_slot_1.json", "save_slot_2.json", "save_slot_3.json", "save_meta.json"]
const LEGACY_FILES := ["save.json", "save.json.bak"]
const BACKUP_DIR := "user://_test_save_backup"

func _ready() -> void:
	await get_tree().process_frame
	_backup_real_saves()
	_reset_save_manager_state()

	_test_save_load_roundtrip()
	_reset_save_manager_state()
	_test_slots_independent()
	_reset_save_manager_state()
	_test_legacy_migration()
	_reset_save_manager_state()
	_test_slot_summary_fields()
	_reset_save_manager_state()
	_test_save_game_writes_active_slot()
	_reset_save_manager_state()
	_test_legacy_visible_readonly()
	_reset_save_manager_state()
	_test_new_game_does_not_clobber_legacy()

	_cleanup_test_artifacts()
	_restore_real_saves()

	print("SAVE_SLOTS_TEST: ", "ALL PASS" if ok else "HAS FAILURES")
	get_tree().quit(0 if ok else 1)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		ok = false
		print("FAIL: ", msg)

# ─── user:// 備份／還原機制 ───────────────────────────────
func _backup_real_saves() -> void:
	var dir := DirAccess.open("user://")
	if dir and not dir.dir_exists("_test_save_backup"):
		dir.make_dir("_test_save_backup")
	for f in SLOT_FILES + LEGACY_FILES:
		var src := "user://%s" % f
		if FileAccess.file_exists(src):
			var dst := "%s/%s" % [BACKUP_DIR, f]
			DirAccess.copy_absolute(ProjectSettings.globalize_path(src), ProjectSettings.globalize_path(dst))
			DirAccess.remove_absolute(ProjectSettings.globalize_path(src))

func _restore_real_saves() -> void:
	var dir := DirAccess.open(BACKUP_DIR)
	if dir == null:
		return
	for f in SLOT_FILES + LEGACY_FILES:
		var src := "%s/%s" % [BACKUP_DIR, f]
		if FileAccess.file_exists(src):
			var dst := "user://%s" % f
			DirAccess.copy_absolute(ProjectSettings.globalize_path(src), ProjectSettings.globalize_path(dst))
			DirAccess.remove_absolute(ProjectSettings.globalize_path(src))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP_DIR))

## 測試造的檔案，前後都清一次（每個子測試之間也重置，避免互相污染）。
func _cleanup_test_artifacts() -> void:
	for f in SLOT_FILES + LEGACY_FILES:
		var p := "user://%s" % f
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

## 重置 SaveManager 記憶體狀態＋清乾淨檔案，讓每個子測試從相同起點開始。
func _reset_save_manager_state() -> void:
	_cleanup_test_artifacts()
	SaveManager.active_slot = 1
	SaveManager._migrated = false  # 強迫下次呼叫重新跑一次遷移檢查（此時應該是 no-op，因為沒有舊檔）

# ─── a) save_to_slot(2) → load_from_slot(2) 資料一致且 active_slot=2 ───
func _test_save_load_roundtrip() -> void:
	GameManager.new_game()
	GameManager.player.day = 7
	GameManager.player.gold = 4242
	GameManager.player.current_area = "armory"
	SaveManager.save_to_slot(2)
	_check(SaveManager.active_slot == 2, "save_to_slot(2) 後 active_slot==2 (got %d)" % SaveManager.active_slot)
	_check(FileAccess.file_exists("user://save_slot_2.json"), "slot2 檔案存在")

	# 模擬重載：清掉記憶體再 load
	GameManager.player.day = 1
	GameManager.player.gold = 0
	GameManager.player.current_area = "shrine"
	var loaded := SaveManager.load_from_slot(2)
	_check(loaded, "load_from_slot(2) 成功")
	_check(GameManager.player.day == 7, "day 還原 (got %d)" % int(GameManager.player.day))
	_check(GameManager.player.gold == 4242, "gold 還原 (got %d)" % int(GameManager.player.gold))
	_check(String(GameManager.player.current_area) == "armory", "current_area 還原 (got %s)" % GameManager.player.current_area)
	_check(SaveManager.active_slot == 2, "load_from_slot(2) 後 active_slot==2 (got %d)" % SaveManager.active_slot)

# ─── b) 三槽獨立不互污 ───────────────────────────
func _test_slots_independent() -> void:
	GameManager.new_game()
	GameManager.player.gold = 111
	SaveManager.save_to_slot(1)
	GameManager.player.gold = 222
	SaveManager.save_to_slot(2)
	GameManager.player.gold = 333
	SaveManager.save_to_slot(3)

	var s1 := SaveManager.slot_summary(1)
	var s2 := SaveManager.slot_summary(2)
	var s3 := SaveManager.slot_summary(3)
	_check(int(s1.get("gold", -1)) == 111, "slot1 gold==111 (got %s)" % s1.get("gold"))
	_check(int(s2.get("gold", -1)) == 222, "slot2 gold==222 (got %s)" % s2.get("gold"))
	_check(int(s3.get("gold", -1)) == 333, "slot3 gold==333 (got %s)" % s3.get("gold"))

	# load slot1 不應把 slot2/slot3 的檔案內容改掉
	SaveManager.load_from_slot(1)
	_check(int(GameManager.player.gold) == 111, "load slot1 拿回 111 (got %d)" % int(GameManager.player.gold))
	var s2_after := SaveManager.slot_summary(2)
	var s3_after := SaveManager.slot_summary(3)
	_check(int(s2_after.get("gold", -1)) == 222, "slot2 仍是 222，未被互污 (got %s)" % s2_after.get("gold"))
	_check(int(s3_after.get("gold", -1)) == 333, "slot3 仍是 333，未被互污 (got %s)" % s3_after.get("gold"))

# ─── c) 舊檔遷移：造 user://save.json → 初始化 → slot1 有資料且舊檔不在原位 ───
func _test_legacy_migration() -> void:
	# 手工造一份舊版單槽存檔（模擬升級前的玩家）。
	GameManager.new_game()
	GameManager.player.day = 9
	GameManager.player.gold = 999
	var legacy_file := FileAccess.open("user://save.json", FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(GameManager.player, "\t"))
	legacy_file.close()
	_check(FileAccess.file_exists("user://save.json"), "前置：舊檔造好")
	_check(not FileAccess.file_exists("user://save_slot_1.json"), "前置：slot1 尚無檔案")

	# 重置記憶體狀態，強迫 SaveManager 下次存取時重跑遷移邏輯。
	SaveManager._migrated = false
	SaveManager.active_slot = 1
	var migrated := SaveManager.has_save()  # 呼叫任一公開 API 即觸發 _ensure_migrated()
	_check(migrated, "遷移後 has_save()==true")
	_check(FileAccess.file_exists("user://save_slot_1.json"), "slot1 有資料")
	_check(not FileAccess.file_exists("user://save.json"), "舊檔 save.json 已不在原位")
	_check(FileAccess.file_exists("user://save.json.bak"), "舊檔改名為 .bak 保留備份")

	GameManager.new_game()
	var loaded := SaveManager.load_from_slot(1)
	_check(loaded, "遷移後 slot1 可正常載入")
	_check(int(GameManager.player.day) == 9, "遷移資料 day==9 (got %d)" % int(GameManager.player.day))
	_check(int(GameManager.player.gold) == 999, "遷移資料 gold==999 (got %d)" % int(GameManager.player.gold))

# ─── d) slot_summary 欄位正確 ───────────────────────────
func _test_slot_summary_fields() -> void:
	var empty := SaveManager.slot_summary(1)
	_check(not bool(empty.get("exists", true)), "空槽 slot_summary.exists==false")

	GameManager.new_game()
	GameManager.player.day = 3
	GameManager.player.period = 2  # "傍晚"
	GameManager.player.gold = 555
	GameManager.player.current_area = "shrine"
	SaveManager.save_to_slot(1)
	var s := SaveManager.slot_summary(1)
	_check(bool(s.get("exists", false)), "有資料 slot_summary.exists==true")
	_check(int(s.get("day", -1)) == 3, "slot_summary.day==3 (got %s)" % s.get("day"))
	_check(String(s.get("period_name", "")) == "傍晚", "slot_summary.period_name==傍晚 (got %s)" % s.get("period_name"))
	_check(int(s.get("gold", -1)) == 555, "slot_summary.gold==555 (got %s)" % s.get("gold"))
	_check(String(s.get("area_name", "")) == "神社區", "slot_summary.area_name==神社區 (got %s)" % s.get("area_name"))
	_check(String(s.get("saved_at", "")) != "", "slot_summary.saved_at 非空")

# ─── e) save_game() 寫的是 active_slot ───────────────────────────
func _test_save_game_writes_active_slot() -> void:
	GameManager.new_game()
	GameManager.player.gold = 1
	SaveManager.save_to_slot(3)  # 設定 active_slot=3（比照真實流程：SlotPicker 存哪槽就切到哪槽）
	GameManager.player.gold = 777
	SaveManager.save_game()  # 零參數舊介面，應寫進目前的 active_slot(3)，不建立新檔
	_check(FileAccess.file_exists("user://save_slot_3.json"), "save_game() 寫進 slot3（active_slot）")
	_check(not FileAccess.file_exists("user://save_slot_1.json"), "save_game() 不應動到 slot1")
	var s3 := SaveManager.slot_summary(3)
	_check(int(s3.get("gold", -1)) == 777, "slot3 內容正確 (got %s)" % s3.get("gold"))

	# load_game() 零參數也應作用於 active_slot
	GameManager.player.gold = 0
	var loaded := SaveManager.load_game()
	_check(loaded, "load_game() 成功")
	_check(int(GameManager.player.gold) == 777, "load_game() 拿回 slot3 內容 (got %d)" % int(GameManager.player.gold))

	# delete_save() 也應只刪 active_slot
	SaveManager.delete_save()
	_check(not FileAccess.file_exists("user://save_slot_3.json"), "delete_save() 刪掉 active_slot(3)")

# ─── f) 舊檔未遷移時：查詢 API 看得到（當 slot1），且純只讀不搬檔（review B-1a）───
func _test_legacy_visible_readonly() -> void:
	GameManager.new_game()
	GameManager.player.day = 50
	GameManager.player.gold = 99999
	var legacy_file := FileAccess.open("user://save.json", FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(GameManager.player, "\t"))
	legacy_file.close()
	SaveManager._migrated = false

	# TitleScreen._ready() 只用這兩個 API 決定「繼續」可視性——必須看得到舊檔
	_check(SaveManager.slot_exists(1), "未遷移舊檔：slot_exists(1)==true（繼續按鈕看得到）")
	var s := SaveManager.slot_summary(1)
	_check(bool(s.get("exists", false)), "未遷移舊檔：slot_summary(1).exists==true")
	_check(int(s.get("day", -1)) == 50, "未遷移舊檔：summary 讀到舊檔內容 day==50 (got %s)" % s.get("day"))

	# 只讀鐵則：查詢不得搬檔（開機/測試路徑不動真實 save.json）
	_check(FileAccess.file_exists("user://save.json"), "查詢後舊檔仍在原位（未被搬走）")
	_check(not FileAccess.file_exists("user://save_slot_1.json"), "查詢不產生 slot1 檔案")
	_check(not FileAccess.file_exists("user://save.json.bak"), "查詢不產生 .bak")

# ─── g) 舊檔玩家按「開始新遊戲」：自動存檔落到空槽，舊進度遷入 slot1 不被蓋（review B-1b）───
func _test_new_game_does_not_clobber_legacy() -> void:
	GameManager.new_game()
	GameManager.player.day = 50
	GameManager.player.gold = 99999
	var legacy_file := FileAccess.open("user://save.json", FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(GameManager.player, "\t"))
	legacy_file.close()
	SaveManager._migrated = false

	# 比照 TitleScreen._on_start_pressed()：先挑空槽再開新遊戲
	SaveManager.select_slot_for_new_game()
	_check(SaveManager.active_slot == 2, "有舊檔（虛擬 slot1）時新遊戲挑 slot2 (got %d)" % SaveManager.active_slot)
	GameManager.new_game()  # day=1
	SaveManager.save_game()  # 模擬跨日自動存檔（同時觸發遷移）

	var s1 := SaveManager.slot_summary(1)
	var s2 := SaveManager.slot_summary(2)
	_check(int(s1.get("day", -1)) == 50, "舊進度遷入 slot1 未被蓋 day==50 (got %s)" % s1.get("day"))
	_check(int(s2.get("day", -1)) == 1, "新遊戲存進 slot2 day==1 (got %s)" % s2.get("day"))
	_check(FileAccess.file_exists("user://save.json.bak"), "遷移後 .bak 備份存在")
	_check(not FileAccess.file_exists("user://save.json"), "遷移後舊檔不在原位")

	# 全新玩家（零存檔）對照：挑 slot1，行為與單槽時代一致
	_reset_save_manager_state()
	SaveManager.select_slot_for_new_game()
	_check(SaveManager.active_slot == 1, "零存檔新遊戲挑 slot1 (got %d)" % SaveManager.active_slot)
