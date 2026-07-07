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
	# 佈局工具 v2（P3）：這是本專案唯一自己掌控的 Dialogic layout layer 腳本，
	# 藉這個既有掛鉤點順便登記本層立繪＋標註 Dialogic 自己那層(VN_TextboxLayer)
	# 的對話框/名牌。不能改 addons/dialogic 內的 .tscn/.gd，改用 get_parent()
	# （DialogicLayoutBase）掃兄弟層取節點參照，純登記不改 Dialogic 行為。
	# 見 docs/superpowers/specs/2026-07-07-layout-tuner-v2-design.md（P3 擴充）。
	call_deferred("_register_layout_tunables", con)


func _register_layout_tunables(portrait_con: DialogicNode_PortraitContainer) -> void:
	if not is_instance_valid(portrait_con):
		return
	# 立繪本身：SpeakerPortrait 的父節點是 SpeakerBustLayer(Control，非 Container)，
	# is_free() 為 true，可自由拖曳＋永久存檔。
	LayoutStore.register(portrait_con, "dialogue/portrait")

	var base := get_parent()
	if base == null or not base.has_method("get_layers"):
		return
	for layer in base.get_layers():
		# VN_TextboxLayer：Dialogic 自己的內建 addon 場景，本專案不能改它的 .tscn/.gd，
		# 但可以從外部用 %unique_name 取節點參照做「純登記」（不影響 Dialogic 行為）。
		# 用 has_node 探測而非比對類別/名字——只有 VN_TextboxLayer 這個場景同時有
		# %Sizer 與 %NameLabelPanel 這兩個 unique name，探測到就是它。
		if not (layer is Node):
			continue
		if layer.has_node("%Sizer") and layer.has_node("%NameLabelPanel"):
			var sizer: Control = layer.get_node("%Sizer")
			var nameplate: Control = layer.get_node("%NameLabelPanel")
			# Sizer＝對話框本體實際定位/尺寸節點(_apply_box_settings 設 position/size，
			# offsets 換算後與 LayoutStore 的 Control offsets 套用相容)；父節點
			# AnimationParent 是 Control 非 Container，is_free() 為 true。
			LayoutStore.register(sizer, "dialogue/textbox")
			# NameLabelPanel：父節點 NameLabelHolder 是 Control 非 Container，
			# is_free() 為 true，可自由拖曳。
			LayoutStore.register(nameplate, "dialogue/nameplate")
			break
