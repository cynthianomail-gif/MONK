extends Control
## 開發預覽（GPU 視窗，非 headless）：直接起 cherry_first_meeting 看 #8 P5 VN 對話框觀感。
## 跑法：Godot_v4.5-stable_win64.exe --path D:\monk\MONK res://test/PreviewDialogueStyle.tscn
## 點擊／空白／Enter 推進對話；無戒(calm/angry)有立繪、警衛/旁白無立繪。結束自動重起方便反覆看。

func _ready() -> void:
	await get_tree().process_frame
	Dialogic.timeline_ended.connect(_restart)
	Dialogic.start("cherry_first_meeting")

func _restart() -> void:
	await get_tree().create_timer(0.6).timeout
	Dialogic.start("cherry_first_meeting")
