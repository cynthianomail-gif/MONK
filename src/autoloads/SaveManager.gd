extends Node

const SAVE_PATH: String = "user://save.json"

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: 無法寫入存檔 %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(GameManager.player, "\t"))
	file.close()

func load_game() -> bool:
	if not has_save():
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveManager: 存檔格式錯誤")
		return false
	# 以預設值為底合併，避免舊存檔缺欄位
	for key in parsed:
		GameManager.player[key] = parsed[key]
	return true

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
