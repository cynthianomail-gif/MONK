class_name GuardWindow
extends RefCounted

## 完美格擋判定窗（第二期第 2 點）：敵人出招前開一個短時窗，玩家在窗內按 interact(E)
## ＝完美格擋成功。做成可注入假輸入 → headless 測試不靠真鍵盤。
##
## 純邏輯（RefCounted）＝好測；實機由 BattleManager 每 physical frame 餵 real input，
## headless 測試由 test 直接呼叫 press() 注入。
##
## 用法（實機）：
##   var gw := GuardWindow.new(0.5)   # 0.5s 窗
##   gw.open()
##   # 每幀：gw.tick(delta, Input.is_action_pressed("interact"))
##   # 收尾：if gw.succeeded(): ...
## 用法（測試）：
##   var gw := GuardWindow.new(0.5); gw.open()
##   gw.tick(0.2, false)   # 窗內未按
##   gw.tick(0.1, true)    # 窗內按下 → succeeded
##   assert(gw.succeeded())

var window_secs: float = 0.5
var _elapsed: float = 0.0
var _open: bool = false
var _succeeded: bool = false
var _prev_pressed: bool = false   # 邊緣偵測（避免持續按住算多次）

func _init(secs: float = 0.5) -> void:
	window_secs = secs

func open() -> void:
	_elapsed = 0.0
	_open = true
	_succeeded = false
	_prev_pressed = false

func is_open() -> bool:
	return _open

func succeeded() -> bool:
	return _succeeded

## 推進一幀。delta＝經過秒數；pressed＝這一幀 interact 是否按著。
## 回傳「本幀是否剛觸發成功」（供實機立即播格擋演出）。
func tick(delta: float, pressed: bool) -> bool:
	if not _open:
		return false
	_elapsed += delta
	var just_pressed: bool = pressed and not _prev_pressed
	_prev_pressed = pressed
	if _elapsed <= window_secs and just_pressed and not _succeeded:
		_succeeded = true
		_open = false
		return true
	if _elapsed > window_secs:
		_open = false
	return false

## 測試便捷：直接注入「在窗內按下一次」。回傳是否成功。
func press() -> bool:
	return tick(0.0, true)

## 測試便捷：跳過整個窗（不按）。
func expire() -> void:
	tick(window_secs + 0.01, false)
