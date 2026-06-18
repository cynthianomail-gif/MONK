extends Node
## 神祇情報圖鑑系統。讀 data/god_intel.json（萬神殿總覽＋12 神）。
## 每位神有多塊情報碎片（pieces），各帶 unlock 條件；蒐集進度＝已解碎片 / 總碎片。
## 開場了塵只給第 1 塊（teaser），進度條不滿；其餘碎片要透過其他人/支線/章節補齊。
##
## 碎片 unlock 條件（piece.flag）支援兩種：
##   "intel_xxx" 等一般旗標  → GameManager.get_flag()
##   "quest:<id>"           → <id> 已在 completed_quests（完成該支線）
## 狀態純推導、不另存（隨 flags/completed_quests 走）。autoload（見 project.godot）。

const DATA_PATH := "res://data/god_intel.json"

var _list: Array = []   # 依 order 排序的神（含 id 與 pieces）

func _ready() -> void:
	var raw: Dictionary = JsonLoader.load_json(DATA_PATH)
	var ids: Array = []
	for id in raw.keys():
		if String(id).begins_with("_"):
			continue
		ids.append(id)
	ids.sort_custom(func(a, b): return int(raw[a].get("order", 0)) < int(raw[b].get("order", 0)))
	for id in ids:
		var d: Dictionary = raw[id]
		_list.append({
			"id": id,
			"god": d.get("god", id),
			"domain": d.get("domain", ""),
			"pieces": d.get("pieces", []),
		})

func _piece_unlocked(flag: String) -> bool:
	if flag.begins_with("quest:"):
		return flag.substr(6) in GameManager.player.completed_quests
	return bool(GameManager.get_flag(flag))

func _entry(id: String) -> Dictionary:
	for it in _list:
		if it.id == id:
			return it
	return {}

func total() -> int:
	return _list.size()

## 已「發現」＝第一塊碎片已解（在圖鑑現身、不再是 ？？？）。
func is_discovered(id: String) -> bool:
	var it := _entry(id)
	var pieces: Array = it.get("pieces", [])
	if pieces.is_empty():
		return false
	return _piece_unlocked(String(pieces[0].get("flag", "")))

func discovered_count() -> int:
	var n := 0
	for it in _list:
		if is_discovered(it.id):
			n += 1
	return n

## 該神的蒐集進度 {got, total}。
func progress(id: String) -> Dictionary:
	var it := _entry(id)
	var pieces: Array = it.get("pieces", [])
	var got := 0
	for pc in pieces:
		if _piece_unlocked(String(pc.get("flag", ""))):
			got += 1
	return {"got": got, "total": pieces.size()}

## 依 order 回傳；每項 {id, god, domain, discovered, got, total, pieces:[{text, unlocked}]}。
## 鎖住碎片仍含 text 原文，UI 端須依 unlocked 決定顯示（？？？）。
func get_all() -> Array:
	var out: Array = []
	for it in _list:
		var pcs: Array = []
		var got := 0
		for pc in it.pieces:
			var u := _piece_unlocked(String(pc.get("flag", "")))
			if u:
				got += 1
			pcs.append({"text": pc.get("text", ""), "unlocked": u})
		out.append({
			"id": it.id, "god": it.god, "domain": it.domain,
			"discovered": is_discovered(it.id),
			"got": got, "total": it.pieces.size(), "pieces": pcs,
		})
	return out
