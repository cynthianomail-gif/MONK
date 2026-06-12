class_name JsonLoader
extends RefCounted

## 共用 JSON 讀取工具：檔案不存在或格式錯誤時回傳空 Dictionary

static func load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("JsonLoader: 找不到 %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("JsonLoader: 無法開啟 %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("JsonLoader: %s 不是有效的 JSON 物件" % path)
		return {}
	return parsed
