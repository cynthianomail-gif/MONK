extends Node
## 佈局工具 v2（P1）：資料 + 套用 + 存讀。規格：
## docs/superpowers/specs/2026-07-07-layout-tuner-v2-design.md 第 1 節。
##
## 職責：持有「識別鍵 → 已存位置」的持久資料，遊戲內登記時即時套用（若已有存檔覆寫），
## 並負責存讀 JSON（res://_layout_overrides.json，人可讀、進版控，可 commit＝正式版也會套用）。
##
## autoload 順序：必須排在 LayoutTuner 之前（project.godot [autoload]），LayoutTuner 會用它。

const OVERRIDES_PATH := "res://_layout_overrides.json"

## 持久：layout_key(String) -> entry(Dictionary)。載入自 JSON，save() 存檔寫回。
## Control entry: {"kind":"control","offsets":[l,t,r,b],"group":"..."}
## Node2D  entry: {"kind":"node2d","pos":[x,y],"group":"..."}
var _overrides: Dictionary = {}

## 暫態：layout_key -> {"node":CanvasItem, "group":String}。每次 register 覆蓋(重建)；
## 節點離開樹時由 tree_exited 訊號自動清掉。供 LayoutTuner 列舉「現在畫面上有哪些可調節點」用。
var _live: Dictionary = {}

func _ready() -> void:
	_load()

## 場景在 _ready/build 時對每個可調節點呼叫一次。key 要全域唯一且穩定
## （例："battle/player_figure"）；group 同類共用（例多個同型自由元件），沒有填 ""。
## 登記後：記進 _live、掛 meta("layout_key")、加入 group "layout_tunable"，
## 若 _overrides 有這個 key 就 deferred 套用（等版面/anchor 定位後）。
func register(node: CanvasItem, key: String, group: String = "") -> void:
	if node == null:
		return
	_live[key] = {"node": node, "group": group}
	node.set_meta("layout_key", key)
	if not node.is_in_group("layout_tunable"):
		node.add_to_group("layout_tunable")
	if not node.tree_exited.is_connected(_on_node_tree_exited):
		node.tree_exited.connect(_on_node_tree_exited.bind(key))
	if _overrides.has(key):
		# 用 WeakRef 包住節點再排入 call_deferred：若節點在佇列排到前就被釋放，
		# 直接把 Node 當強型別參數傳給 call_deferred 會在執行時噴
		# "Error calling deferred method ... Cannot convert argument 1 from Object to Object"
		# （已釋放的 Node 無法轉型成 CanvasItem，is_instance_valid 守衛救不了，因為
		# 錯誤發生在參數轉換階段，函式本體根本沒被呼叫到）。WeakRef.get_ref() 在節點
		# 已釋放時安全回傳 null，於 _apply_override_deferred 消化時判斷即可。
		call_deferred("_apply_override_deferred", weakref(node), key)

## call_deferred 的安全轉接層，見 register() 內註解。
func _apply_override_deferred(node_ref: WeakRef, key: String) -> void:
	var node = node_ref.get_ref()
	if node == null or not is_instance_valid(node):
		return
	apply_override(node, key)

func _on_node_tree_exited(key: String) -> void:
	unregister(key)

## 反登記（節點離開樹時自動呼叫，把 _live[key] 清掉）。
func unregister(key: String) -> void:
	_live.erase(key)

## 把 _overrides[key] 的位置套到 node 上（Control 設 offsets、Node2D 設 position）。
## 沒有該 key 就不動。用 call_deferred 呼叫以確保容器/anchor 已完成一次 layout。
func apply_override(node: CanvasItem, key: String) -> void:
	if node == null or not is_instance_valid(node):
		return
	var entry: Dictionary = _overrides.get(key, {})
	if entry.is_empty():
		return
	if node is Control and entry.get("kind", "") == "control":
		var offsets: Array = entry.get("offsets", [])
		if offsets.size() == 4:
			var c := node as Control
			c.offset_left = offsets[0]
			c.offset_top = offsets[1]
			c.offset_right = offsets[2]
			c.offset_bottom = offsets[3]
	elif node is Node2D and entry.get("kind", "") == "node2d":
		var pos: Array = entry.get("pos", [])
		if pos.size() == 2:
			(node as Node2D).position = Vector2(pos[0], pos[1])

## 讀目前 node 的位置寫進 _overrides[key]（含 group）。tuner 拖曳/微調後呼叫。
func capture(key: String, group: String = "") -> void:
	if not _live.has(key):
		return
	var node: CanvasItem = _live[key].get("node")
	if node == null or not is_instance_valid(node):
		return
	if node is Control:
		var c := node as Control
		_overrides[key] = {
			"kind": "control",
			"offsets": [c.offset_left, c.offset_top, c.offset_right, c.offset_bottom],
			"group": group,
		}
	elif node is Node2D:
		var n2d := node as Node2D
		_overrides[key] = {
			"kind": "node2d",
			"pos": [n2d.position.x, n2d.position.y],
			"group": group,
		}

## 同群組套用：把 key 這個節點目前的「相對位置」套到所有同 group 的 live 節點
## （全部設成同一個 local position＝使用者說的「全部變成我更新後的位置」）。
## P1 戰鬥的自由塊都是唯一的，暫時用不到；先實作備用。
func apply_group(group: String) -> void:
	if group == "":
		return
	var ref_pos = null
	var ref_kind := ""
	for k in _live:
		var entry: Dictionary = _live[k]
		if entry.get("group", "") != group:
			continue
		var node: CanvasItem = entry.get("node")
		if node == null or not is_instance_valid(node):
			continue
		if ref_pos == null:
			if node is Control:
				ref_pos = (node as Control).position
				ref_kind = "control"
			elif node is Node2D:
				ref_pos = (node as Node2D).position
				ref_kind = "node2d"
			continue
		if ref_kind == "control" and node is Control:
			(node as Control).position = ref_pos
		elif ref_kind == "node2d" and node is Node2D:
			(node as Node2D).position = ref_pos

## 判斷節點是不是自由定位（父節點不是 Container）。
func is_free(node: CanvasItem) -> bool:
	if node == null:
		return false
	var parent := node.get_parent()
	return parent != null and not (parent is Container)

## 列出目前活著的登記節點：[{key, node, group, free:bool}]，供 tuner 畫框。
func live_entries() -> Array:
	var out: Array = []
	for k in _live:
		var entry: Dictionary = _live[k]
		var node: CanvasItem = entry.get("node")
		if node == null or not is_instance_valid(node):
			continue
		out.append({
			"key": k,
			"node": node,
			"group": entry.get("group", ""),
			"free": is_free(node),
		})
	return out

## 寫 _overrides 進 JSON（人可讀、進版控）。
func save() -> void:
	save_to_path(OVERRIDES_PATH)

## 測試用：存到自訂路徑（例如 user:// 暫存），避免留檔在 repo（驗收條件 6）。
func save_to_path(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_overrides, "\t"))
		f.close()

func _load() -> void:
	load_from_path(OVERRIDES_PATH)

## 測試用：從自訂路徑讀（例如 user:// 暫存，模擬「重開遊戲重新載入」而不動 repo 內的
## 正式 _layout_overrides.json）。找不到檔案就保持 _overrides 現狀不動（不清空）。
func load_from_path(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if parsed is Dictionary:
		_overrides = parsed
