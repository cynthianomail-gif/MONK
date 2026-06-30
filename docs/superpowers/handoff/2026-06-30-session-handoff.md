# 交接文件 — 2026-06-30(過場 okami 化 + 影片化)

> 給下一個 session / 切帳號接手用。先讀這篇，再讀 `docs/superpowers/specs/2026-06-23-remaining-old-art-audit.md`（art 盤點，已標完成狀態）與記憶 [[project-cutscene-system]]。

## 一、這輪做了什麼(2026-06-29 ~ 06-30)

**全 8 段過場 okami 化 + 影片化完成**，遊戲內再無 pivot 前舊過場。

| 段 | 做法 | 狀態 |
|---|---|---|
| `opening_temple_falls` | 6 okami 靜幀 + 揮拳 KO 剪接 v2 影片幀 | ✅ |
| `ares_phase2` | Seedance i2v 影片 → 拆 61 幀(對 audio.ogg) | ✅ |
| `break_food/greed/lust` | Seedance i2v → 拆回 49/49/61 幀 | ✅ |
| `heat_diamond/tathagata/thousand` | Seedance i2v → 拆回 73/73/61 幀 | ✅ |
| `ch1_aftermath_wake` / `ares_intro` | StoryCutscene okami 單幀 | ✅ |

- **兩階段管線**：① Magnific `imagen-nano-banana-2` 生定格關鍵幀(使用者逐張核可，style ref=`bg_battle_ximen`/`ares_forge`，identity ref=game_ready 立繪/12神 contact sheet)；② 把原本是動態的段用核可幀當 keyframe 以 **Seedance 2.0 image-to-video** 生真影片 → ffmpeg 拆回原幀數(對齊 SFX cue/audio)。
- **wiring 零改碼**：CutsceneScreen(逐幀+SFX_CUES) / StoryCutscene(資料驅動) 都沿用，只換圖/幀。
- **日本反皮**：破戒=屋台/座敷/koban；奧義=如来掌/金剛曼荼羅/千手観音；主角鎖 game_ready `wujie_ascetic`。
- **了塵修正**：ch1 茶屋的了塵改成正確的**戴菅笠斷臂浪人**(先前誤畫老和尚)。
- **開場揮拳 KO**(試 6 版)：最終=剪 `vid_opening_ko_v2.mp4` 的幀，只留 POV 拳頭+白閃(frame 33–43)+變暗(44–51)+純黑，剪掉阿瑞斯第三人稱入鏡段(16–32)；收黑後第 7 拍 eye_open 接靜態群神。詳見 audit spec。
- **驗證**：`TestCutscene` + `TestStoryCutscene` ALL PASS；GPU 實機錄製整段開場 = `_art_review/cutscene_okami/opening_play.mp4`(含聲音)。
- **源圖/源影片**全留在 repo 外的 `D:/monk/_art_review/cutscene_okami/`(vid_*.mp4 / *.png)。

## 二、目前整體進度(DEMO = 只做第 1 章阿瑞斯)

**系統/內容**：autoloads/戰鬥/地圖(3D 水墨 2 區)/過場/對話(全 26 dtl)/小遊戲×3/選單+手機 5 app/主線引擎+ch1 九段/成就/神祇情報/技能習得/戰鬥美術——**全部已實作 + headless ALL PASS**(詳見 [[project-build-status]])。

**美術 okami 化**：戰鬥背景 8 張 ✅、VN 胸像/戰鬥站姿 ✅、3D 探索 ✅、game_ready 全卡司(含鐵叔 2 態) ✅、全 8 過場 ✅(這輪)。

## 三、還沒做(缺口，依優先序)

1. **⚠ ch1 開場「了塵介紹 12 神」背景還是舊圖** — `main_ch1_aftermath.dtl` 用 `assets/2d/gods/*.jpg`(06-14 舊半寫實)當 12 神 CG；新 okami 概念圖 `art_direction/.../gods/concepts/*_16x9.png` 已生但沒換上。= demo 開場唯一還露舊風格的地方。換 12 個 .dtl 背景路徑即可(**改 .dtl 要先關 Godot**，見 build_status .dtl 陷阱)。
2. **無戒 chanter/beggar 的 `calm` 正面表情** — ascetic 有 calm/angry/happy/surprised；chanter/beggar 缺 calm(誦經/行腳職時戰鬥/VN 預設臉 fallback)。丟 Codex 補 2 張。
3. **實機 GPU 完整跑一次 ch1 demo** — 幾乎每個系統都標「headless ALL PASS、仍待實機 GPU 抽驗」；戰鬥+選單+支線那一大塊沒在真視窗從頭跑過。
4. **DEMO 之後(ch2-12)**：11 神 in-game 立繪整合、各章 boss 數值/迷宮/過場/對話/敵兵(boss.json 目前只有阿瑞斯)。

## 四、雷 / 注意

- **改 .dtl 一律先完全關閉 Godot**(Dialogic 會把快取空的 .dtl 存成 0 bytes)。
- **新 png/jpg/ogg 要 `Godot --headless --path MONK --import`** 才會生 .import、runtime 才載得到。
- **StoryCutscene 要掛 CanvasLayer 下**才正常渲染(直接掛 root 會 _frame Nil 灰屏)。
- **GPU 截圖 harness**(`test/CaptureOpening.tscn`/`CaptureAresPhase2.tscn`/`PlayOpening.tscn`)**只能用視窗版 Godot 跑**(headless 卡 frame_post_draw)；`PlayOpening` + `--write-movie` 可錄整段含音軌。
- **AI i2v 揮拳很難維持 POV** → 開場 KO 是手剪 v2 影片幀，別再盲生(詳 audit spec「揮拳 POV 雷」)。

## 五、git 狀態(交接重點)

分支 `hd2d-exploration`。⚠**working tree 有大量前幾輪未提交的工作**(okami 戰鬥背景/3D/對話日本反皮/data json/整個 `art_direction` 源樹)+本輪過場——**676 檔變更**，大半非本輪。dev 產物 `_cap_opening/`、`_cap_ares_phase2/`(截圖)不該進版。
