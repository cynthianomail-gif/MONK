extends Node

## 佛具裝備位（2026-07-08，規格見 docs/superpowers/specs/2026-07-08-equipment-design.md）：
## 讀 data/equipment.json＋GameManager.player.equipment / equipment_owned，
## 算出裝備加成 bonus{atk,def,hp,gold_pct,merit_per_win}，供 Combatant.from_player()
## 與 BattleManager._victory() 套用。仿 CultivationBoard 的組織方式（class 靜態資料+autoload）。
##
## 三欄：beads（念珠，攻）／kasaya（袈裟，防+HP）／bowl（缽，經濟被動）。
## 一次購買永久持有、免費換裝、無耐久度。

const EQUIPMENT_PATH := "res://data/equipment.json"
const SLOTS := ["beads", "kasaya", "bowl"]

var _items: Dictionary = {}

func _ready() -> void:
	_load()

func _load() -> void:
	_items = JsonLoader.load_json(EQUIPMENT_PATH)

## 供測試重新載入。
func reload() -> void:
	_load()

func get_items() -> Dictionary:
	return _items

func get_item_def(item_id: String) -> Dictionary:
	return _items.get(item_id, {})

## 舊存檔缺鍵防呆：確保 equipment / equipment_owned 存在且型別正確（同 _ensure_inventory 模式）。
func _ensure_equipment() -> void:
	if not GameManager.player.has("equipment") or typeof(GameManager.player.equipment) != TYPE_DICTIONARY:
		GameManager.player["equipment"] = {"beads": "", "kasaya": "", "bowl": ""}
	else:
		for slot in SLOTS:
			if not GameManager.player.equipment.has(slot):
				GameManager.player.equipment[slot] = ""
	if not GameManager.player.has("equipment_owned") or typeof(GameManager.player.equipment_owned) != TYPE_ARRAY:
		GameManager.player["equipment_owned"] = []

## 是否已持有（購買過）。
func is_owned(item_id: String) -> bool:
	_ensure_equipment()
	return item_id in GameManager.player.equipment_owned

## 該欄目前裝的 item_id（空字串＝未裝）。
func get_equipped(slot: String) -> String:
	_ensure_equipment()
	return String(GameManager.player.equipment.get(slot, ""))

## 是否達到進貨門檻（unlock_flag 為空＝開店即有）。
func is_unlocked(item_id: String) -> bool:
	var d: Dictionary = get_item_def(item_id)
	if d.is_empty():
		return false
	var flag: String = String(d.get("unlock_flag", ""))
	if flag == "":
		return true
	return bool(GameManager.get_flag(flag))

## 該欄已持有的道具清單（供 EquipPage 列出可裝清單）。
func owned_in_slot(slot: String) -> Array:
	_ensure_equipment()
	var result: Array = []
	for item_id in GameManager.player.equipment_owned:
		var d: Dictionary = get_item_def(String(item_id))
		if String(d.get("slot", "")) == slot:
			result.append(String(item_id))
	return result

## 購買：扣款＋入 equipment_owned（每件限購一次）。回傳是否成功。
func purchase(item_id: String) -> bool:
	if is_owned(item_id):
		return false
	var d: Dictionary = get_item_def(item_id)
	if d.is_empty():
		return false
	var price: int = int(d.get("price", 0))
	if not GameManager.spend_gold(price):
		return false
	_ensure_equipment()
	GameManager.player.equipment_owned.append(item_id)
	return true

## 裝上（同欄自動換掉舊的）。未持有則失敗。
func equip(item_id: String) -> bool:
	if not is_owned(item_id):
		return false
	var d: Dictionary = get_item_def(item_id)
	if d.is_empty():
		return false
	var slot: String = String(d.get("slot", ""))
	if slot == "":
		return false
	_ensure_equipment()
	GameManager.player.equipment[slot] = item_id
	return true

## 卸下該欄。
func unequip(slot: String) -> void:
	_ensure_equipment()
	if slot in SLOTS:
		GameManager.player.equipment[slot] = ""

## 算出目前三欄已裝備帶來的總加成。
func compute_bonus() -> Dictionary:
	_ensure_equipment()
	var bonus: Dictionary = {"atk": 0, "def": 0, "hp": 0, "gold_pct": 0.0, "merit_per_win": 0}
	for slot in SLOTS:
		var item_id: String = String(GameManager.player.equipment.get(slot, ""))
		if item_id == "":
			continue
		var d: Dictionary = get_item_def(item_id)
		if d.is_empty():
			continue
		var b: Dictionary = d.get("bonus", {})
		bonus.atk += int(b.get("atk", 0))
		bonus.def += int(b.get("def", 0))
		bonus.hp += int(b.get("hp", 0))
		var p: Dictionary = d.get("passive", {})
		bonus.gold_pct += float(p.get("gold_pct", 0.0))
		bonus.merit_per_win += int(p.get("merit_per_win", 0))
	return bonus
