extends Node
## 對話框顯示層文字加工（純 runtime，不改 .dtl 原文）。
## 目前功能：句末標點（。！？）後自動換行，供 Dialogic text_modifier 掛載呼叫。
## 註冊點：res://addons/dialogic_additions/monk_line_break/index.gd（Dialogic 官方擴充機制，
## project.godot 的 dialogic/extensions_folder 已指向 res://addons/dialogic_additions，
## 不動 addons/dialogic/ 內部檔案）。

## 觸發換行的句末標點。使用者若只要句號，把這裡縮成 "。" 即可。
const SENTENCE_ENDERS := "。！？"

## 句末標點後面若緊跟這些收尾符號（右引號／右括號等），換行要延後到符號之後。
const TRAILING_CLOSERS := "」』）》】’”\")]'"


## Dialogic text_modifier 進入點：text -> text。在 BBCode/Dialogic 標記已解析安全的
## 純文字＋原生 BBCode 混合字串上運作，逐字掃描，遇到 "[...]" 一律整段跳過複製，
## 絕不在標記中間插入換行。
func insert_sentence_breaks(text: String) -> String:
	if text.is_empty():
		return text

	var result := ""
	var i := 0
	var n := text.length()

	while i < n:
		var ch := text[i]

		if ch == "[":
			var close_idx := text.find("]", i)
			if close_idx == -1:
				result += text.substr(i)
				break
			result += text.substr(i, close_idx - i + 1)
			i = close_idx + 1
			continue

		result += ch
		i += 1

		if SENTENCE_ENDERS.find(ch) == -1:
			continue

		# 句末標點後緊跟的收尾符號（」』）等）一併帶過，換行放在它們之後。
		while i < n and TRAILING_CLOSERS.find(text[i]) != -1:
			result += text[i]
			i += 1

		# 已經在（等效）行尾或文末，不重複加換行。
		if i < n and text[i] == "\n":
			continue
		if not _has_more_visible_content(text, i):
			continue

		result += "\n"

	return result


## 從 from_index 起，忽略 "[...]" 標記與空白／換行，判斷後面是否還有實際可顯示內容。
func _has_more_visible_content(text: String, from_index: int) -> bool:
	var i := from_index
	var n := text.length()

	while i < n:
		var ch := text[i]

		if ch == "[":
			var close_idx := text.find("]", i)
			if close_idx == -1:
				return false
			i = close_idx + 1
			continue

		if ch == "\n" or ch == " " or ch == "\t":
			i += 1
			continue

		return true

	return false
