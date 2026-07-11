extends Node
## headless 測試：存檔多槽（J3，2026-07-08；備份/還原機制於 2026-07-10 QC P0 重寫）。
## 跑法：Godot --headless res://test/TestSaveSlots.tscn
##
## ⚠ headless 的 user:// 是「真的」使用者存檔目錄（不是沙盒）。本測試會：
## 1) 開跑前把使用者現有的 save_slot_*.json / save_meta.json / save.json(.bak) 搬到
##    使用者存檔目錄之外的獨立暫存目錄（OS.get_cache_dir() 下的隨機子目錄，不與
##    user:// 同層），且逐檔驗證「複製成功＋大小一致」後才刪除原始檔——任一檔案
##    驗證失敗就整批中止，不刪任何原始檔，也不跑任何子測試。
## 2) 測試全程只操作乾淨狀態
## 3) 結束時（無論成敗）把備份還原、逐檔驗證還原成功後才清掉備份目錄；
##    還原失敗會大聲印出備份路徑並保留備份目錄，讓人工介入。
##
## 2026-07-10 之前的舊版只用 DirAccess.copy_absolute 複製到 user:// 底下的子目錄，
## 且不檢查回傳值——備份失敗照樣往下刪除原始檔，曾經真的毀過 Cynthia 的真實存檔。
## 這版改為「先驗證、後刪除」的兩階段流程，且備份目錄搬出 user:// 之外。

var ok := true

const SLOT_FILES := ["save_slot_1.json", "save_slot_2.json", "save_slot_3.json", "save_meta.json"]
const LEGACY_FILES := ["save.json", "save.json.bak"]

var _backup_dir: String = ""       # 本次執行使用的備份目錄（絕對路徑，跑在 user:// 之外）
var _backed_up_files: Array[String] = []  # 已成功備份＋已刪除原始檔的檔名，收尾只還原這些

func _ready() -> void:
	await get_tree().process_frame

	if not _backup_real_saves():
		# 備份失敗＝真實存檔安全紅線。不跑任何子測試，直接中止。
		ok = false
		print("SAVE_SLOTS_TEST: ABORTED — 備份未通過驗證，為保護真實存檔已中止，未執行任何子測試。")
		print("SAVE_SLOTS_TEST: ", "HAS FAILURES")
		get_tree().quit(1)
		return

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
	_reset_save_manager_state()
	_test_has_unsaved_changes()

	_cleanup_test_artifacts()
	_restore_real_saves()

	print("SAVE_SLOTS_TEST: ", "ALL PASS" if ok else "HAS FAILURES")
	get_tree().quit(0 if ok else 1)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		ok = false
		print("FAIL: ", msg)

# ─── user:// 備份／還原機制 ───────────────────────────────

## 備份目錄：OS 的快取目錄（與 user:// 存檔目錄不同層）下的隨機子目錄。
## 支援用環境變數 MONK_TEST_FORCE_BAD_BACKUP_DIR 覆寫（負向實驗用：指向不存在的
## 磁碟機或唯讀路徑，驗證「備份失敗→中止→真實存檔完好」）。
func _get_backup_root() -> String:
	var override_dir := OS.get_environment("MONK_TEST_FORCE_BAD_BACKUP_DIR")
	if override_dir != "":
		return override_dir
	var unique := "monk_test_save_backup_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	return OS.get_cache_dir().path_join(unique)

func _file_size(abs_path: String) -> int:
	if not FileAccess.file_exists(abs_path):
		return -1
	var f := FileAccess.open(abs_path, FileAccess.READ)
	if f == null:
		return -1
	var len := f.get_length()
	f.close()
	return len

## 兩階段備份：
##   phase 1：把每個存在的真實檔複製到備份目錄，逐檔驗證「複製回傳 OK 且大小與來源一致」；
##            任一檔案驗證失敗＝整批中止，回傳 false，此時所有原始檔都還沒被動過。
##   phase 2：phase 1 全過才刪除原始檔（同樣檢查刪除回傳值）；刪除失敗也視為中止。
## 回傳 true 才代表安全可以繼續跑子測試。
func _backup_real_saves() -> bool:
	_backup_dir = _get_backup_root()
	var make_err := DirAccess.make_dir_recursive_absolute(_backup_dir)
	if make_err != OK and not DirAccess.dir_exists_absolute(_backup_dir):
		print("SAVE_SLOTS_TEST: 無法建立備份目錄 %s（錯誤碼 %d）。真實存檔完全未被觸碰。" % [_backup_dir, make_err])
		return false

	var to_backup: Array[String] = []
	for f in SLOT_FILES + LEGACY_FILES:
		if FileAccess.file_exists("user://%s" % f):
			to_backup.append(f)

	if to_backup.is_empty():
		print("SAVE_SLOTS_TEST: 使用者目前沒有真實存檔檔案，無需備份。")
		return true

	# phase 1：複製＋驗證，全部通過才進 phase 2。
	for f in to_backup:
		var src_abs := ProjectSettings.globalize_path("user://%s" % f)
		var dst_abs := _backup_dir.path_join(f)
		var src_size := _file_size(src_abs)
		var copy_err := DirAccess.copy_absolute(src_abs, dst_abs)
		var dst_size := _file_size(dst_abs)
		if copy_err != OK or src_size < 0 or dst_size != src_size:
			print("SAVE_SLOTS_TEST: 備份 %s 失敗或大小不符（copy_err=%d, 來源大小=%d, 備份大小=%d）。備份目錄=%s。真實存檔尚未被刪除，安全。" % [f, copy_err, src_size, dst_size, _backup_dir])
			return false

	# phase 2：驗證全數通過，才刪除原始檔（讓測試在乾淨的 user:// 上跑）。
	for f in to_backup:
		var src_abs := ProjectSettings.globalize_path("user://%s" % f)
		var rm_err := DirAccess.remove_absolute(src_abs)
		if rm_err != OK:
			print("SAVE_SLOTS_TEST: 已驗證備份，但刪除原始檔 %s 失敗（錯誤碼 %d）。真實檔仍在原位，備份留在 %s 供核對。" % [f, rm_err, _backup_dir])
			return false
		_backed_up_files.append(f)

	print("SAVE_SLOTS_TEST: 已備份並驗證 %d 個真實存檔檔案至 %s" % [_backed_up_files.size(), _backup_dir])
	return true

## 還原：逐檔複製回 user:// 並驗證大小一致才刪除備份副本；有任何一個還原失敗，
## 大聲印出來並保留備份目錄（含未成功還原的那些檔案），不強行清掉。
func _restore_real_saves() -> void:
	if _backed_up_files.is_empty():
		if _backup_dir != "" and DirAccess.dir_exists_absolute(_backup_dir):
			DirAccess.remove_absolute(_backup_dir)  # 空備份目錄，直接清掉
		return

	var restore_failed: Array[String] = []
	for f in _backed_up_files:
		var src_abs := _backup_dir.path_join(f)
		var dst_abs := ProjectSettings.globalize_path("user://%s" % f)
		var src_size := _file_size(src_abs)
		var copy_err := DirAccess.copy_absolute(src_abs, dst_abs)
		var dst_size := _file_size(dst_abs)
		if copy_err != OK or src_size < 0 or dst_size != src_size:
			restore_failed.append(f)
			ok = false
			print("SAVE_SLOTS_TEST: !!! 還原 %s 失敗（copy_err=%d, 來源大小=%d, 目的大小=%d）——備份仍保留在 %s，需要人工核對！" % [f, copy_err, src_size, dst_size, _backup_dir])
			continue
		DirAccess.remove_absolute(src_abs)

	if restore_failed.is_empty():
		DirAccess.remove_absolute(_backup_dir)
	else:
		print("SAVE_SLOTS_TEST: !!! 備份目錄保留於 %s（含 %d 個未成功還原的檔案），需要人工介入，勿刪除此目錄。" % [_backup_dir, restore_failed.size()])

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
	SaveManager._last_saved_snapshot = ""  # 「未儲存進度」快照歸零，避免跨子測試互相污染

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

# ─── h) has_unsaved_changes()：設定頁「回主選單」守門用的全量快照比對 ───────────
func _test_has_unsaved_changes() -> void:
	GameManager.new_game()
	# 開局尚未存讀過（快照已被 _reset_save_manager_state 歸零）：刻意保守，視為「有未儲存」。
	_check(SaveManager.has_unsaved_changes(), "new_game 後、首次存檔前＝有未儲存變更（刻意保守）")

	SaveManager.save_to_slot(1)
	_check(not SaveManager.has_unsaved_changes(), "save_to_slot 後＝無未儲存變更")

	GameManager.player.gold = 12345
	_check(SaveManager.has_unsaved_changes(), "存檔後修改 gold＝偵測到未儲存變更")

	SaveManager.save_to_slot(1)
	_check(not SaveManager.has_unsaved_changes(), "再次存檔後＝變更已清除")

	GameManager.player.day = 99
	_check(SaveManager.has_unsaved_changes(), "存檔後修改 day＝偵測到未儲存變更")
	var loaded := SaveManager.load_from_slot(1)
	_check(loaded, "load_from_slot(1) 成功")
	_check(not SaveManager.has_unsaved_changes(), "load_from_slot 後＝視為已與存檔一致，無未儲存變更")
	_check(int(GameManager.player.day) != 99, "load_from_slot 覆蓋了 day 的未存變更 (got %d)" % int(GameManager.player.day))

	# 巢狀欄位（flags/inventory 等 Dictionary）變更也要偵測到——全量序列化比對不看欄位種類。
	GameManager.set_flag("test_unsaved_flag", true)
	_check(SaveManager.has_unsaved_changes(), "巢狀 flags 變更也被偵測到")
	GameManager.player.flags.erase("test_unsaved_flag")
	_check(not SaveManager.has_unsaved_changes(), "還原巢狀變更後＝無未儲存變更")
