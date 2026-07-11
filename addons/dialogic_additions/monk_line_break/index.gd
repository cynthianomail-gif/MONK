@tool
extends DialogicIndexer
## 註冊「句末標點自動換行」text_modifier。
## 掛在 res://addons/dialogic_additions/（Dialogic 官方擴充機制，project.godot 的
## dialogic/extensions_folder 已指向這裡），不觸碰 addons/dialogic/ 內部檔案。
## 實際邏輯在 res://src/autoloads/DialogueTextFx.gd（autoload），順序設在最後
## （order 100，晚於變數代換 30／文字特效剝除 50／自動上色 90／詞彙表 95），
## 讓其他管線先把文字處理成最終樣子，我們只做最後一道「插入換行」的收尾工。


func _get_text_modifiers() -> Array[Dictionary]:
	return [
		{
			"node_path": ^"/root/DialogueTextFx",
			"method": "insert_sentence_breaks",
			"mode": 0, # DialogicSubsystemText.ParserModes.TEXT_ONLY —— 只套對話正文，不動選項文字
			"order": 100,
		}
	]
