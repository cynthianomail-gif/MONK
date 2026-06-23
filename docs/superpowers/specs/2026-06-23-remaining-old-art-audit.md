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

## 🟡 P2：過場 cutscene 幀序列（全舊，量大）
逐幀序列（cutscene 播放器用，每段一個資料夾 `frame_XXXX.png`）。要 okami 重生。落點＝`assets/cutscenes/<段>/`：
| 段 | 幀數 | 內容 | 優先 |
|---|---|---|---|
| `opening_temple_falls` | 74 | 開場神社被強拆＝玩家第一印象 | ⭐ 最高（先做這段） |
| `ares_phase2` | 61 | 阿瑞斯二階變身 | 高（ch1 boss） |
| `break_food` / `break_greed` / `break_lust` | 49/49/61 | 三破戒獨白 | 中 |
| `heat_diamond` / `heat_tathagata` / `heat_thousand` | 73/73/61 | 技能奧義演出 | 中 |
| `ch1_aftermath_wake` / `ch1_ares` | 0/0（空） | 雨夜遇了塵／超渡阿瑞斯 | ⚠ 本來就缺，要新做或改定格+配音 |

> 量很大（~500 幀）。建議先只做 `opening_temple_falls`（開場），其餘分批。

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
