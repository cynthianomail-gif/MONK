extends Node
## 十二因緣成就系統。錨定主線 12 章：每章 complete_flag ＝ 對應成就 unlock_flag
## （見 data/achievements.json 與 main_quests.json，兩者一字不差、章序一致）。
##
## 狀態純推導：is_unlocked(id) ⟺ GameManager.get_flag(unlock_flag) 為真。
## 旗標已隨 SaveManager 整包存讀，故不另存。單一真相源。
##
## 解鎖彈窗：監聽 GameManager.flag_changed（僅真變動時發），命中某成就 unlock_flag
## 即 EventBus.achievement_unlocked(id) ＋ 推進 pending_toasts，由 MapScreen 取播。
## autoload（見 project.godot，排在 GameManager 之後）。

const DATA_PATH := "res://data/achievements.json"

var _list: Array = []                # 依 chapter 排序的成就資料（含 id）
var pending_toasts: Array = []       # 尚未播彈窗的成就 id（MapScreen 取走）

func _ready() -> void:
	var raw: Dictionary = JsonLoader.load_json(DATA_PATH)
	var ids: Array = []
	for id in raw.keys():
		if String(id).begins_with("_"):
			continue
		ids.append(id)
	ids.sort_custom(func(a, b): return int(raw[a].get("chapter", 0)) < int(raw[b].get("chapter", 0)))
	for id in ids:
		var d: Dictionary = raw[id]
		_list.append({
			"id": id,
			"name": d.get("name", id),
			"chapter": int(d.get("chapter", 0)),
			"desc": d.get("desc", ""),
			"unlock_flag": d.get("unlock_flag", ""),
		})
	GameManager.flag_changed.connect(_on_flag_changed)

func total() -> int:
	return _list.size()

func is_unlocked(id: String) -> bool:
	for it in _list:
		if it.id == id:
			return it.unlock_flag != "" and bool(GameManager.get_flag(it.unlock_flag))
	return false

func unlocked_count() -> int:
	var n := 0
	for it in _list:
		if it.unlock_flag != "" and bool(GameManager.get_flag(it.unlock_flag)):
			n += 1
	return n

## 依章序回傳成就清單；每項 {id, name, chapter, desc, unlock_flag, unlocked}。
func get_all() -> Array:
	var out: Array = []
	for it in _list:
		var e: Dictionary = it.duplicate()
		e["unlocked"] = it.unlock_flag != "" and bool(GameManager.get_flag(it.unlock_flag))
		out.append(e)
	return out

func _on_flag_changed(key: String, value: Variant) -> void:
	if not bool(value):
		return
	for it in _list:
		if it.unlock_flag == key:
			EventBus.achievement_unlocked.emit(it.id)
			pending_toasts.append(it.id)
			return
