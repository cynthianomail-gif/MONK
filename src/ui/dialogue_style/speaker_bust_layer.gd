@tool
extends DialogicLayoutLayer
## #8 P5 VN 版面 — 獨立立繪層。
## 一個 SPEAKER 模式立繪容器：自動顯示「當前說話者」的立繪，免 join/leave 事件（零 .dtl 改動）。
## 立繪錨左下、放大，畫在文字框之上（仿 Persona 5）。大小/落點屬觀感，於實機 GPU 微調。

@export var portrait_size_mode: DialogicNode_PortraitContainer.SizeModes = DialogicNode_PortraitContainer.SizeModes.FIT_SCALE_HEIGHT


func _apply_export_overrides() -> void:
	var con: DialogicNode_PortraitContainer = %SpeakerPortrait
	con.size_mode = portrait_size_mode
	con.update_portrait_transforms()
