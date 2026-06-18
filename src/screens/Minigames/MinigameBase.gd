extends Node2D
class_name MinigameBase
## 所有小遊戲的共用基底。
## 子類負責玩法與計分，結束時呼叫 finish(result)；
## 由 SceneRouter.finish_minigame 統一套用獎勵、回報結果、返回地圖。
##
## result 契約：
##   { "id": String, "score": int, "win": bool,
##     "gold": int, "merit": int, "karma": int }
## 小遊戲本身不直接改 GameManager 狀態（保持純邏輯、好測試）。

const RESULT_TEMPLATE := {
	"id": "", "score": 0, "win": false,
	"gold": 0, "merit": 0, "karma": 0,
}

var _finished: bool = false

## 子類覆寫，回傳本小遊戲的 id（與場景檔名 to_snake_case 對應）。
func minigame_id() -> String:
	return ""

## 把 result 補齊預設欄位後回傳（子類組 result 時可用）。
func make_result(fields: Dictionary) -> Dictionary:
	var r := RESULT_TEMPLATE.duplicate(true)
	for k in fields:
		r[k] = fields[k]
	if r.id == "":
		r.id = minigame_id()
	return r

## 結束小遊戲：交給 SceneRouter 套用獎勵並返回地圖。重複呼叫只生效一次。
func finish(result: Dictionary) -> void:
	if _finished:
		return
	_finished = true
	var r := make_result(result)
	if Engine.has_singleton("SceneRouter") or get_node_or_null("/root/SceneRouter") != null:
		SceneRouter.finish_minigame(r)
	else:
		# 測試情境下沒有 autoload：直接發訊號讓測試接住。
		minigame_finished.emit(r)

signal minigame_finished(result: Dictionary)
