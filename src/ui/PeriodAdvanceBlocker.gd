extends Control
## 時段推進字卡播放期間的輸入吞噬層（SceneRouter._play_period_advance_card 專用）。
## 全螢幕 Control，MOUSE_FILTER_STOP 擋滑鼠；覆寫 _unhandled_input 吞鍵盤（E/選單鍵等），
## 避免字卡播放中玩家誤觸地圖互動（走近觸發、開選單）。

func _unhandled_input(event: InputEvent) -> void:
	accept_event()
