# P5 風對話框 · VN 版面（立繪在框外）設計 spec

日期：2026-06-17
關聯：[[project-build-status]]（「胸像化」舊決定＝本案有意識翻案）、[[project-monk-game]]、[[project-art-direction]]（暗金×黑 UI 色系）。
既有：`project.godot` `layout/default_style="res://src/ui/dialogue_style/monk_dialogue_style.tres"`。
缺口來源：PROJECT_STATUS #8「對話 UI 美化：P5 斜切邊框/霓虹未做」。

## 願景與範圍

把對話呈現從「立繪內嵌在文字框裡」升級成 **Persona 5 式 VN 版面**：立繪是螢幕**左下角一張獨立大胸像**（壓在場景上、不在框內），對話框是右側**斜切（skew）＋金色霓虹**的純文字框，左上掛一塊**斜切金色名牌**。配色沿用既有暗金×黑（金 `#C9A861`、近黑 `#0B0B0B`、暖奶白 `#F0E9D8`）。

使用者以 P5 截圖定調（立繪在框外）。本案＝視覺/版面升級，**不改劇情、不改對話內容**。

**範圍邊界（拍板）：**
- **零 `.dtl` 改動**：立繪靠 `SPEAKER` 模式容器自動顯示「當前說話者」，不需 join/leave 事件。
- **不動 Dialogic addon**：只在專案內新增資源/場景＋改 `monk_dialogue_style.tres` 的 overrides。
- **不寫 shader**：斜切＝`StyleBoxFlat.skew`；金邊＝`border`；霓虹光暈＝`shadow_color/shadow_size`；名牌＝獨立 `StyleBox`。皆 StyleBoxFlat 內建能力。
- **選項層（vn_choice_layer）＝同日追加完成**：2 新 StyleBox `monk_choice_normal.tres`（斜切暗金底＋細暗金邊）/`monk_choice_hover.tres`（亮金邊＋金光暈），套 vn_choice 層 overrides（`boxes_stylebox_normal/hovered/focused`＋`text_color_*` 奶白→亮金）；位置維持**置中**（試過右上角 `boxes_offset` 後使用者決定回中央）。TestDialogueStyle 加選項斷言＝ALL PASS。
- 立繪精確大小/落點＝觀感參數，**最終於實機 GPU 微調**；headless 只保證「樣式載入＋對話跑完不報錯」。

## 現況（已探查確認）

- `monk_dialogue_style.tres`：`layer_list=["10".."16"]`，其中 **`12`=Resource_speaker → `Layer_SpeakerPortraitTextbox`（textbox_with_speaker_portrait.tscn，立繪內嵌框內）**，目前 overrides 只設暗金×黑配色（box 近黑 0.94、名字金、文字奶白、box_size 960×210、portrait_bg 透明）。其餘層：`10`全背景／`11`輸入／`13`glossary／`14`選項／`15`text input／`16`歷史。
- `Layer_SpeakerPortraitTextbox`：立繪容器在 box 的 HBox 內（`mode=1`SPEAKER、`debug_character_portrait="speaker"`），所以立繪**內嵌**且**自動跟說話者**。
- `Layer_VN_Textbox`（`vn_textbox_layer.gd`）：**純文字框，無內嵌立繪**，且**名稱有獨立 panel**。可 override：`box_panel`(StyleBox)、`box_color_use_global/box_color_custom`(self_modulate)、`box_size`/`box_margin_bottom`、`name_label_box_panel`(StyleBox)、`name_label_box_modulate`、`name_label_box_offset`、`name_label_alignment`、文字色/字型/大小、`next_indicator_*`、進場動畫、打字音。`_apply_box_settings` 把 `box_panel` 套到 `%DialogTextPanel`，`self_modulate=box_color_custom`（注意：會**乘**在 StyleBox 顏色上）。
- `Layer_VN_Portraits`：5 個 **POSITION 模式**容器（`container_ids="leftmost/left/center/right/rightmost"`）＝**需 join 事件**才顯示 → 不適用（會逼改 26 個 .dtl）。
- `DialogicNode_PortraitContainer`（`node_portrait_container.gd`）：`mode` 有 `POSITION`（需 join）與 **`SPEAKER`（自動跟說話者，加入 group `dialogic_portrait_con_speaker`，免 join）**。`size_mode` 建議 `FIT_SCALE_HEIGHT`（依容器高縮放、保比例，scale 100%＝容器高 100%）。`origin_anchor` 控制落點錨（如 `BOTTOM_LEFT`）。
- 立繪資產：`assets/2d/portraits/<char>/bust/*.png` 為**透明去背 RGBA**（color type 6；無戒 850×884，四角 alpha=0），適合放大當 VN 胸像。`.dch` 角色檔 `scale=1.0`、各 portrait `offset/scale` 可調。
- `.dtl` 語法：`Wujie (calm): …`，**無 join 事件**；非角色說話者（如「警衛：」「旁白」）無立繪 → 維持無立繪（符合 P5 旁白無頭像）。

## 架構（3 元件＋1 樣式改寫，各自獨立、介面清楚）

### ① 立繪層 `src/ui/dialogue_style/speaker_bust_layer.tscn` ＋ `.gd`（新）
- 腳本 `speaker_bust_layer.gd`：`@tool extends DialogicLayoutLayer`（與 `vn_portrait_layer.gd` 同基類，才會被 Dialogic 當成 style 層載入並套 overrides）。`@export var portrait_size_mode := DialogicNode_PortraitContainer.SizeModes.FIT_SCALE_HEIGHT`；`_apply_export_overrides()` 把該值套到子容器（仿 vn_portrait_layer 的最小寫法）。
- 場景：根 `Control`（全螢幕 anchors_preset=15、`mouse_filter=2`、掛上述腳本），其下**一個** `DialogicNode_PortraitContainer`：
  - `mode = SPEAKER`（1）→ 自動顯示當前說話者、免 join。
  - `size_mode = FIT_SCALE_HEIGHT`、`origin_anchor = BOTTOM_LEFT`。
  - 容器 anchor 落在畫面左下：`anchor_left=0`、`anchor_top=0.38`、`anchor_right=0.42`、`anchor_bottom=1.0`（容器高 = 62% 畫面 → 胸像約 6 成畫面高；**GPU 調定 2026-06-17**）。`origin_offset = Vector2(320, -20)`（左/下邊距，實機微調定案）。
- **z-order**：此層排在文字框層**之後**（layer_list 較後＝畫在上層），讓胸像壓在框的左緣前方（仿 P5）；胸像靠左、文字靠右，避免蓋到文字。

### ② 文字框 StyleBox `src/ui/dialogue_style/monk_textbox_panel.tres`（新）
`StyleBoxFlat`：
- `bg_color = Color(0.043,0.043,0.043,0.95)`（近黑，**直接烤進 StyleBox**）。
- `skew = Vector2(0.12, 0)`（右傾斜切；P5 感，過大會切到字 → 0.10~0.14 區間實機調）。
- `border_*` 全邊 `2`、`border_color = Color(0.957,0.851,0.541,1)`（亮金 `#F4D98A`）。
- 霓虹光暈：`shadow_color = Color(0.788,0.659,0.38,0.45)`、`shadow_size = 10`、`shadow_offset = Vector2(0,0)`。
- 圓角全 `2`（接近銳角，配斜切）；`content_margin_*`：**left 大**（補 skew 偏移＋騰出左側立繪空間，讓文字落在立繪右邊不被壓），**GPU 調定 left 295 / right 30 / top 18 / bottom 18**。

### ③ 名牌 StyleBox `src/ui/dialogue_style/monk_nametag_panel.tres`（新）
`StyleBoxFlat`：`bg_color = Color(0.788,0.659,0.38,1)`（金，烤進）、`skew = Vector2(0.18,0)`（比框更斜，名牌更尖）、`border` 1.5 亮金、圓角 1、`content_margin` left 22/right 18/top 4/bottom 4。名字文字色＝近黑（靠 override 設 `name_label_*_color`）。

### ④ 改寫 `monk_dialogue_style.tres`
- `layer_list`：把 `"12"` 的 scene 由 `textbox_with_speaker_portrait.tscn` 換成 `vn_textbox_layer.tscn`；**新增一層**（如 `"17"`）指向 `speaker_bust_layer.tscn`，排在 `"12"` 之後。最終次序（後者畫在上）：…背景→文字框(12)→立繪(17)→輸入…（輸入/選項/歷史維持其原 id 與相對次序；確保立繪不蓋輸入提示與選項）。
- `12`(VN textbox) overrides：
  - `box_panel = "res://src/ui/dialogue_style/monk_textbox_panel.tres"`
  - `box_color_use_global = false`、`box_color_custom = Color(1,1,1,1)`（self_modulate 白＝不染色，讓 StyleBox 顏色如實顯示）
  - `box_size = Vector2(1180, 230)`、`box_margin_bottom = 40`
  - `text_use_global_color = false`、`text_custom_color = Color(0.941,0.913,0.847,1)`（奶白）
  - `name_label_box_panel = "res://src/ui/dialogue_style/monk_nametag_panel.tres"`
  - `name_label_box_use_global_color = false`、`name_label_box_modulate = Color(1,1,1,1)`
  - **`name_label_box_offset = Vector2(295, 0)`**（GPU 調定，把名牌右移到文字正上方、左緣與內文切齊；公式 `name_panel.x = offset - content_margin_left`，故名牌與文字邊距同值 295 時對齊）
  - `name_label_use_global_color = false`、`name_label_use_character_color = false`、`name_label_custom_color = Color(0.043,0.043,0.043,1)`（名牌上近黑字）
  - `name_label_alignment = LEFT`、`name_label_box_offset` 視名牌落點微調
  - `next_indicator_*` 用既有預設（金色 ▼ 感）；文字仍走全域字型/大小/速度（沿用 SettingsManager text_speed）。
- `17`(bust) overrides：（若 bust 層腳本提供 size_mode override 則設 `FIT_SCALE_HEIGHT`，否則 .tscn 內已設）。

## 版面/z-order 與「胸像化」翻案

- 舊決定（記憶 `project-build-status`）：為了排版把立繪做成胸像並**內嵌框內**。本案依使用者 P5 參考圖**有意識翻案**為「胸像在框外、VN 式」。胸像資產（去背）沿用，不需重生。
- 落點：立繪左下、文字框右側偏下、名牌貼文字框左上緣。胸像 z 在框之上、文字之左，互不遮蔽。

## 驗證計畫

- **headless（可驗）** `test/TestDialogueStyle.gd`（新，或併入既有 dialogue 測）：
  1. `monk_dialogue_style.tres` 能 `load()` 不報錯；`layer_list` 含 VN textbox 與 bust 兩層、**不含** speaker-portrait-textbox。
  2. 兩個新 StyleBox `.tres` 能 load 且為 `StyleBoxFlat`，關鍵值（skew/border/ shadow/ bg）符規格。
  3. `speaker_bust_layer.tscn` 能 instantiate，內含 `DialogicNode_PortraitContainer` 且 `mode==SPEAKER`。
  4. 跑一段含角色說話的 timeline（如 `main_ares_lead`）`Dialogic.start`→直到 `timeline_ended`，全程無 SCRIPT ERROR（沿用既有 `TestAllDialogue`/`TestDialogueSlice` 模式）。
  5. 全專案 `--editor --quit` 無 parse error。
- **GPU（✅ 已實機調定 2026-06-17）**：用 `test/PreviewDialogueStyle.tscn`（直接起 main_ares_lead 的開發預覽，點擊推進、結束自動重起）反覆微調。定案＝立繪 `origin_offset=(320,-20)`/`anchor_top=0.38`（左下、~62% 高、留白舒適、不吃字）、文字 `content_margin_left=295`、名牌 `name_label_box_offset=(295,0)`（左緣切齊內文）。斜切 0.12／光暈 shadow_size 10／近黑底 0.95 觀感 OK。旁白/警衛無立繪情形正常。

## 風險與緩解

- **self_modulate 乘色**：VN textbox 把 `box_color_custom` 當 self_modulate **乘**在 StyleBox 上 → 故 box/nametag modulate 都設**白 (1,1,1,1)**，顏色全烤進 StyleBox。（已在 overrides 載明。）
- **skew 切到字**：靠 `content_margin_left` 加大緩衝；skew 落在 0.10~0.14，實機微調。
- **立繪蓋住文字/選項**：bust 靠左 anchor（right≈0.42）、文字框文字靠右起；選項層維持在最上不被蓋。實機確認。
- **層次序動到別層**：只動 `12` 的 scene＋新增 `17`，其餘層 id/scene 不變，降低回歸面。

## 文件/記憶同步（完成後）

- PROJECT_STATUS #8 標完成 + 「二、已完成」新增條目；註明「胸像化」翻案。
- 記憶：更新 [[project-build-status]]（胸像化→VN 式立繪在框外）；視需要新增 `project-dialogue-vn-style` 記憶（含 SPEAKER 模式免 join、self_modulate 乘色、StyleBox skew/shadow 做 P5 等雷）＋ MEMORY 索引。
- 本 spec 為真相源。
