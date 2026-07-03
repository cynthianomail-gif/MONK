extends Node

## 修行盤（第三期）：讀 data/cultivation_board.json＋GameManager.player.board_unlocked
## 算出成長加成 bonus{hp,atk,def,spd,passives[]}，供 Combatant.from_player() 套用。
## 節點解鎖／灌注道行的判定與扣款也集中在這裡，UI（BoardScreen/BoardApp）只管畫面。
##
## 資料格式見 data/cultivation_board.json；node.type：
##   stat    — effect.stat(hp/atk/def/spd) + effect.add：累加到 bonus。
##   skill   — effect.learn_skill：解鎖當下直接 grant_skill()（避開 SkillUnlockManager 雙重門檻）。
##   passive — effect.passive：旗標式，戰鬥端用 has_passive() 查。

signal node_unlocked(node_id: String)

const BOARD_PATH := "res://data/cultivation_board.json"

var _board: Dictionary = {}
var _nodes_by_id: Dictionary = {}

func _ready() -> void:
	_load()

func _load() -> void:
	_board = JsonLoader.load_json(BOARD_PATH)
	_nodes_by_id.clear()
	for n in _board.get("nodes", []):
		_nodes_by_id[String(n.id)] = n

## 供測試/UI 重新載入（例如切換測試資料）。
func reload() -> void:
	_load()

func get_board() -> Dictionary:
	return _board

func get_rings() -> Array:
	return _board.get("rings", [])

func get_nodes() -> Array:
	return _board.get("nodes", [])

func get_node_def(node_id: String) -> Dictionary:
	return _nodes_by_id.get(node_id, {})

## 舊存檔缺鍵防呆：確保 board_unlocked 存在且含 "core"。
func _ensure_unlocked() -> void:
	if not GameManager.player.has("board_unlocked") or typeof(GameManager.player.board_unlocked) != TYPE_ARRAY:
		GameManager.player["board_unlocked"] = ["core"]
	elif "core" not in GameManager.player.board_unlocked:
		GameManager.player.board_unlocked.append("core")

func is_unlocked(node_id: String) -> bool:
	_ensure_unlocked()
	return node_id in GameManager.player.board_unlocked

## 前置是否全數已解鎖（core 的 requires 為空恆 true）。
func requires_met(node_id: String) -> bool:
	var n: Dictionary = get_node_def(node_id)
	if n.is_empty():
		return false
	for req in n.get("requires", []):
		if not is_unlocked(String(req)):
			return false
	return true

## 節點是否已被劇情鎖擋下（節點所在環有 unlock_flag 且旗標未達成）。
func is_story_locked(node_id: String) -> bool:
	var n: Dictionary = get_node_def(node_id)
	if n.is_empty():
		return false
	var ring: Dictionary = _ring_def(int(n.get("ring", 0)))
	var flag: String = String(ring.get("unlock_flag", ""))
	if flag == "":
		return false
	return not bool(GameManager.get_flag(flag))

func _ring_def(ring_idx: int) -> Dictionary:
	for r in get_rings():
		if int(r.get("ring", -1)) == ring_idx:
			return r
	return {}

## 節點四態，供 UI 判斷視覺樣式：
## "unlocked" | "available"（可解鎖，前置達成＋未被劇情鎖）| "locked"（前置未達）| "story_locked"（劇情鎖）
func node_state(node_id: String) -> String:
	if is_unlocked(node_id):
		return "unlocked"
	if is_story_locked(node_id):
		return "story_locked"
	if requires_met(node_id):
		return "available"
	return "locked"

## 是否可解鎖（前置達成＋未劇情鎖＋道行足夠＋尚未解鎖）。
func can_unlock(node_id: String) -> bool:
	if is_unlocked(node_id):
		return false
	if is_story_locked(node_id):
		return false
	if not requires_met(node_id):
		return false
	var n: Dictionary = get_node_def(node_id)
	var cost: int = int(n.get("cost", 0))
	return int(GameManager.player.get("daoxing", 0)) >= cost

## 實際解鎖：扣款＋加入 board_unlocked＋套用 effect（skill 節點直接習得）。回傳是否成功。
func unlock_node(node_id: String) -> bool:
	if not can_unlock(node_id):
		return false
	var n: Dictionary = get_node_def(node_id)
	var cost: int = int(n.get("cost", 0))
	GameManager.add_daoxing(-cost)
	_ensure_unlocked()
	GameManager.player.board_unlocked.append(node_id)
	var effect: Dictionary = n.get("effect", {})
	if String(n.get("type", "")) == "skill" and effect.has("learn_skill"):
		SkillUnlockManager.grant_skill(String(effect.learn_skill))
	node_unlocked.emit(node_id)
	return true

## 算出目前 board_unlocked 帶來的總加成。
func compute_bonus() -> Dictionary:
	_ensure_unlocked()
	var bonus: Dictionary = {"hp": 0, "atk": 0, "def": 0, "spd": 0, "passives": []}
	for node_id in GameManager.player.board_unlocked:
		var n: Dictionary = get_node_def(String(node_id))
		if n.is_empty():
			continue
		var effect: Dictionary = n.get("effect", {})
		match String(n.get("type", "")):
			"stat":
				var stat: String = String(effect.get("stat", ""))
				if stat in bonus and stat != "passives":
					bonus[stat] += int(effect.get("add", 0))
			"passive":
				var p: String = String(effect.get("passive", ""))
				if p != "" and p not in bonus.passives:
					bonus.passives.append(p)
			"skill":
				pass  # skill 節點效果＝習得技能，不貢獻數值 bonus
	return bonus

## 戰鬥端查是否具備某被動旗標（例："guard_boost"）。
func has_passive(passive_id: String) -> bool:
	return passive_id in compute_bonus().passives
