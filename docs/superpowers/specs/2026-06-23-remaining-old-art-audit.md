# 還是舊圖的盤點 → Codex 生圖清單

日期：2026-06-23
背景：game_ready 新水墨全卡司已接（VN 胸像 18／戰鬥站姿 無戒3職背面+敵人5）。本文盤點**遊戲實際會用、但還是舊圖（pivot 前）的部分**，給 Codex 生新水墨版。

## 🔴 P1：戰鬥背景（最顯眼，每場戰鬥都看到，跟新角色嚴重打架）
現況＝舊賽博龐克霓虹城。要 **okami 水墨環境（16:9 橫幅）**。落點＝覆蓋 `assets/2d/backgrounds/<同名>.png`：
| 檔 | 用途 | DEMO 優先 |
|---|---|---|
| `bg_battle_ximen.png` | 街區/神社區遭遇戰（收區後 shrine 戰鬥 fallback 用它） | ⭐ 高 |
| `bg_battle_pantheon.png` | 萬神殿總部/軍火庫（ch1 主線雜兵戰） | ⭐ 高 |
| `bg_battle_wanhua.png` / `bg_battle_linsen.png` | 舊分區戰鬥（收區後少用，仍留） | 中 |
| `bg_battle_temple.png` / `bg_battle_boss.png` / `bg_battle_ares_rooftop.png` | 特殊/Boss 場 | 中 |
| ~~`bg_battle_ares_forge.png`~~ | ✅ 已是新水墨（阿瑞斯 boss），不用動 | — |

**戰鬥背景生圖規格（Codex 還沒做過環境圖，這段給它對齊）**：16:9 橫幅、**okami 水墨環境**（同 3D 探索場景＋已完成的 `bg_battle_ares_forge.png` 風格）；**純環境、無角色**；構圖**中下景留空/壓低細節**（戰鬥時玩家背面在左下、敵人站中右，背景太滿會打架）；墨黑/土黃/硃紅/米白低彩、和紙肌理、墨筆描邊。各場：ximen＝櫻木町夜街/神社參道；pantheon＝萬神殿總部/軍火庫廠房內景；wanhua＝門前町老街；linsen＝歌舞坂花街；temple＝荒廢神社；rooftop＝高樓頂。

## 🟡 P2：過場 cutscene（全舊，量大）
要 okami 重生。落點＝`assets/cutscenes/<段>/`：
| 段 | 內容 | 狀態 |
|---|---|---|
| `opening_temple_falls` | 開場神社被強拆＝玩家第一印象 | ✅ **2026-06-27 完成（定格+配音路線，見下）** |
| `ares_phase2` | 阿瑞斯二階變身（61 幀舊） | ✅ **2026-06-27 完成（4 okami 定格幀填 61 幀，見下）** |
| `break_food` / `break_greed` / `break_lust` | 三破戒獨白（49/49/61 幀） | ✅ **2026-06-29 完成（各 3 okami 定格幀填回原幀數，日本反皮）** |
| `heat_diamond` / `heat_tathagata` / `heat_thousand` | 技能奧義演出（73/73/61 幀） | ✅ **2026-06-29 完成（各 3 okami 定格幀，佛教法相）** |
| `ch1_aftermath_wake` / `ch1_ares` | 雨夜遇了塵／超渡阿瑞斯（本來就空） | ✅ **2026-06-29 完成（StoryCutscene 換 okami 單幀）** |

> 🎉 **P2 全部 8 段過場已完成 okami 化（2026-06-29）。** 兩階段：先定格分鏡鎖風格/身份/構圖（使用者逐張核可），**再把原本是動態的段用核可幀當關鍵幀以 Seedance 2.0 生成真影片**（image-to-video），拆幀塞回，保留所有 wiring/音軌/字幕/cue。
>
> ### ✅ 影片化升級（2026-06-29，Seedance 2.0 image-to-video）
> 原本是逐幀動畫的段已從定格升級為**真影片**：ares_phase2 / break×3 / heat×3 各一次 Seedance（起=首核可幀、訖=末核可幀、prompt 帶轉場+cameraMotion，720p）→ffmpeg 拆回**原幀數**（精準取 N 幀對齊 SFX cue/audio）。開場揮拳 KO＝720p 影片→拆 97 幀進 `opening_temple_falls/punch_okami/`，cutscenes.json 開場 shot 6 由 image 改回 `frames_dir`（fps24），cue t=1.3（對齊影片撞擊白閃）只留 SFX+flash、**拿掉程式 knockout**（翻倒改由影片演）。**全程第一人稱 POV**，**最終＝剪接 `vid_opening_ko_v2.mp4`（抓領→揮拳那支 Seedance 影片）的幀**：抽 121 幀後 **只保留 POV 拳頭段＋變暗段、剪掉第三人稱錯視角段**＝frame **33–43**（POV 拳頭直轟鏡頭+白色衝擊放射，無阿瑞斯頭）＋frame **44–51**（變暗廢墟/倒地仰視）＋ **6 純黑幀**（暈倒），共 25 幀進 `punch_okami/`。**剪掉 frame 16–32**（阿瑞斯第三人稱頭+身入鏡的揮拳段＝使用者明確不要）。**影片內不接群神**，收黑後由第 7 拍 `ok_06_lineup` 的 `eye_open` 睜眼揭示**靜態**群神。cue `t=0.2`（白閃在開頭，impact_heavy+monk_grunt+補閃 strength0.85），**拿掉程式 knockout**。
>   - ⚠ **揮拳 POV 雷（試了 6 版才定，全記下）**：AI image-to-video 的揮拳**很難維持第一人稱**——起手幀用抓握姿勢(`ok_04_collar`)會動成「扯衣料怪手」；用拳頭特寫(`ok_05_fist`)起手雖拳乾淨但翻覆鏡頭會把阿瑞斯帶進畫面=像「阿瑞斯自己被打」；自製靜圖 push-in 使用者也不要。**最終解＝直接剪 v2 影片的幀**，只挑「拳頭填滿鏡頭+白閃」那 ~10 幀(33–43)當 POV 撞擊、接「變暗」幀(44–51)、補純黑，把所有「阿瑞斯入鏡」的幀剪掉。**收全黑**：餵純黑圖當 video end keyframe，或拆幀後補純黑幀（本版用後者）。其餘段（ares_phase2/break×3/heat×3）的 Seedance image-to-video 都 OK，只有開場 POV 揮拳要這樣手剪。源影片＝`_art_review/cutscene_okami/vid_opening_ko_v2.mp4`、實機錄製＝`opening_play.mp4`。驗證 `TestCutscene`+`TestStoryCutscene` ALL PASS。

### ✅ 破戒×3 + 奧義×3 + ch1×2 okami 重做（2026-06-29，日本反皮）
- **逐幀段（破戒×3 / 奧義×3，用 `CutsceneScreen` 固定 12fps + `SFX_CUES`）**：每段生 **3 張 okami 關鍵幀**，PIL **重複填回原幀數**（1280×720），**cue 幀落點對齊高潮拍**（破戒：setup→破戒act(vow_break)→魔相；奧義：架式→蓄能(heat_buildup)→法相現身）。`SFX_CUES` 完全不動＝零改碼。
- **日本反皮（主線不變只反皮）**：破戒·食＝日式**屋台**吃肉→紅面鬼煞；破戒·財＝日式廳堂貪 **koban** 金光→金煞；破戒·色＝日式**座敷/花街**藝伎環繞→慾煞。奧義＝佛教法相（如来巨掌／金剛界曼荼羅光柱／**千手観音 Senju Kannon** 現身），通用於日本佛教，配日式和尚。
- **身份鎖**：主角全用 game_ready `wujie_ascetic_front`；魔相＝同一和尚變紅鬼。ch1：**了塵＝`liaochen_front`＝戴菅笠的斷臂浪人 rōnin（非老和尚！生圖要描述成戴帽浪人，否則 prompt 會蓋掉參考圖）**、阿瑞斯＝`ares_front`。style/tone 鎖 `bg_battle_ximen`（夜街暗金）／奧義金光／ch1_ares 用 `bg_battle_ares_forge`（軍火庫）。
- **ch1 兩段（StoryCutscene 單幀）**：`ch1_aftermath_wake/ok_tea_stall.png`（雨夜日式茶屋，戴帽浪人了塵在攤前）、`ch1_ares/ok_ares_reveal.png`（阿瑞斯軍火庫現身）；cutscenes.json 的 `ch1_aftermath_wake`/`ares_intro` 圖路徑已改 .jpg→新 .png（舊 jpg 留著未引用）。
- **驗證**：`test/TestCutscene.tscn`（逐幀）+ `test/TestStoryCutscene.tscn`（已加 ares_intro/ch1_aftermath_wake 圖載入斷言）皆 ALL PASS。渲染路徑兩套播放器已分別 GPU 驗證（CaptureOpening / CaptureAresPhase2）。源圖全留 `_art_review/cutscene_okami/`。

### ✅ opening_temple_falls okami 重做（2026-06-27）＝後續過場的範本
- **方法**：保留原 shot 結構/字幕時間軸/配音/cue（duration 全不動＝字幕同步），只把 8 個 shot 的圖換成 6 張新 okami 靜幀；揮拳那拍由 `frames_dir`(punch_anim 74 幀) 改成 `image`(ok_05_fist)＋保留程式 KO cue（flash/knockout 不靠幀）；定場/群神加緩慢 `zoom_in` 免靜幀死板。
- **6 張新圖**（`assets/cutscenes/opening_temple_falls/ok_0[1-6]_*.png`，2752×1536）：ok_01_pov 定場 / ok_02_taunt 嘲諷 / ok_03_laugh 狂笑 / ok_04_collar 抓領 / ok_05_fist 揮拳 / ok_06_lineup 群神背影。源檔留 `_art_review/cutscene_okami/`。
- **風格定案（重要，推翻原「對齊北極星 washi」）**：使用者實際要的 okami＝**對齊已上線戰鬥背景 `bg_battle_ximen` 的暗厚塗渲染 tone**（深黑/暖燈/硃紅鳥居/濕反光/雨霧），**不是**平塗浮世繪和紙北極星 `_style1b_okami_b`（生過、被否）。
- **POV 鐵則**：開場全程**第一人稱**，畫面不出現主角（原 `01_pov_temple` 就是 POV）；憑空畫和尚被否。要角色身份時餵 game_ready 立繪鎖（阿瑞斯＝`ares_front_black_red_game_ready.png`）。
- **十二神背影**：餵 12 神概念圖（`art_direction/new_ink_shrine_style/gods/concepts/*_16x9.png`）拼成的 contact sheet 當單一 image 參考，確保背影是正確的 12 神（生成式泛畫的神被否）。
- **管線**：Magnific `images_generate` mode `imagen-nano-banana-2`（Nano Banana Pro），16:9 / 2k；reference＝`style`(ximen 戰鬥背景) ＋ `image`(角色/神 sheet)。
- **驗證**：headless `test/TestStoryCutscene.tscn` ALL PASS（已順手把過時斷言 6→8 shots、11→10 captions、t=5 阿瑞斯→無戒 校正）；GPU 視窗 `test/CaptureOpening.tscn` 截圖確認實際渲染（截圖 `MONK/_cap_opening/`）。⚠CaptureOpening 只能用視窗版 Godot 跑（headless 卡 frame_post_draw）；StoryCutscene 要掛在 CanvasLayer 下才正常渲染（直接掛 `get_tree().root` 會 _frame Nil/灰屏）。
- **舊賽博龐克素材**（`01_pov_temple.png`/`02_ares_cup.png`/`02b`/`02c`/`03_ares_fist.png`/`05_lineup.jpg`/`punch_anim/`74 幀）✅ **2026-06-27 已刪**（127M→40M）。

### ✅ ares_phase2 okami 重做（2026-06-27）＝逐幀播放器（CutsceneScreen）定格化範本
- **不同於開場**：ares_phase2 是戰鬥疊播（`SceneRouter.play_battle_cutscene`→`CutsceneScreen` 固定 12fps 逐幀＋整段 `audio.ogg` 5.06s），由 boss.json phase 觸發。**保留這套 wiring 零改碼**。
- **方法**：生 **4 張 okami 變身關鍵幀**（受擊/蓄能/爆發/戰神），用 PIL **重複填成 61 幀**（1280×720，同原始尺寸）對齊 audio：受擊1–14｜蓄能15–30｜爆發31–40（峰值~36 對音檔高潮）｜戰神41–61。`audio.ogg` 原封不動。源圖 `_art_review/cutscene_okami/p2_*.png`。
- **設計修正**：game_ready 的 phase2＝**黑西裝阿瑞斯「覺醒」態（全身紅熔岩裂紋＋背後鍛造齒輪/刀刃翼＋雙手紅焰）**，**不是**舊版橘色熔岩巨人。身份鎖 `ares_phase2_front_black_red_game_ready.png`，前段受擊/蓄能鎖 `ares_front_black_red_game_ready.png`，style/tone 鎖戰鬥背景 `bg_battle_ares_forge.png`。
- **驗證**：headless `test/TestCutscene.tscn` ALL PASS（61 幀＋audio 播放/停止/finished）；GPU 視窗 `test/CaptureAresPhase2.tscn` 截圖確認四拍實際渲染對位（`MONK/_cap_ares_phase2/`）。
- **footprint**：89M（4 唯一圖×61 複本 @1280×720），與破戒/奧義各段同量級；可日後若要省再降析度。

## 🟢 P3：補完角色（game_ready 漏掉的，小量）
全身透明底、同 game_ready 風格，落 `art_direction/.../game_ready/`（我再裁/接）：
- **無戒 chanter（誦經僧）/ beggar（行腳僧）正面＋4 表情**：現只有 ascetic 正面＋chanter/beggar 背面。分職時 VN/戰鬥正面會缺。
- **無戒 chanter/beggar 受傷背面**：現只有 `ascetic_hurt_back`。
- **鐵叔 2 態**（locked/freed）：已出 handoff `2026-06-22-tieshu-portrait-handoff.md`，待生。

## ⚪ P4：DEMO 後再說（ch2-12）
- **11 神立繪**（阿瑞斯外）：Codex 已生 `gods/concepts/*_16x9.png` 新版，待 ch2+ 接遊戲時換掉舊 `assets/2d/gods/*.jpg`。DEMO 只 ch1 用不到。
- 其他章節專屬場景/敵人。

## ✅ 不用 Codex 生（已新 / 已有待整合 / 根本無圖 / 已退役）
- **已換新**：VN 胸像 18、戰鬥站姿（無戒3職背面+敵人5）、3D 探索 okami 場景、阿瑞斯戰鬥背景。
- **已有新圖、只待「整合」非生圖**：阿瑞斯 boss 全套（idle/attack/phase2/emote）+10 FX——game_ready 已有，等我做 Phase 3 VFX 系統。
- **本來就無點陣圖**：UI/選單/道具/技能/成就/圖示＝純程式暗金×黑 StyleBox + 文字/emoji。標題/logo 同。
- **已退役不用**：2D 地圖（`map/scenes`、`map/interiors`）、2D 無戒走路 sprite（`characters/wujie/sprite`）、`_backup_1k`/`_nobg`/`_source`/`3d_ref`（備份/中間檔）。

## 一句總結給 Codex
**最該先生：① 戰鬥背景 okami 化（先 ximen+pantheon）② 開場 cutscene `opening_temple_falls` okami 化。** 其餘按上表分批。
