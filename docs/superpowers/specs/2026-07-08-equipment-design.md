# 佛具裝備位設計規格（2026-07-08，使用者拍板「你決定就好」＝全推薦選項）

## 概要

三欄護符裝備：**念珠**（攻）／**袈裟**（防+HP）／**缽**（經濟被動）。
一次購買永久持有、隨時免費換裝、無耐久度。共 9 件（每欄 3 階）。
換裝 UI＝經書 device 新「佛具」頁；販售＝水野佛具店（ShopScreen）加「消耗品／佛具」分頁；
進貨門檻＝1 階開店即有、2 階 armory_unlocked、3 階擊敗 ares（用既有旗標，實作時查證正名）。

## 道具表

| id 建議 | 名稱 | 欄 | 階 | 效果 | 價格 | 進貨 |
|---|---|---|---|---|---|---|
| beads_bodhi | 菩提子念珠 | beads | 1 | atk+8 | 400 | 開店 |
| beads_vajra | 金剛杵念珠 | beads | 2 | atk+15 | 900 | armory_unlocked |
| beads_agarwood | 沉水香念珠 | beads | 3 | atk+22 | 1500 | ares 後 |
| kasaya_rough | 粗布袈裟 | kasaya | 1 | def+1, hp+20 | 350 | 開店 |
| kasaya_brocade | 錦斕袈裟 | kasaya | 2 | def+2, hp+90 | 800 | armory_unlocked |
| kasaya_gold | 金襴袈裟 | kasaya | 3 | def+3, hp+180 | 1400 | ares 後 |
| bowl_pine | 松木缽 | bowl | 1 | 戰勝金幣+10% | 300 | 開店 |
| bowl_iron | 鐵缽 | bowl | 2 | 戰勝金幣+20%, hp+40 | 700 | armory_unlocked |
| bowl_zijin | 紫金缽 | bowl | 3 | 戰勝金幣+25%, 每勝功德+1 | 1200 | ares 後 |

平衡護欄（2026-07-08 實作時依實測修訂）：原案 def+4/+8/+12 經 TTK probe 用雜魚**真實招式**
實測，總防 22 會讓 7/7 招觸「只打 1」地板（裸裝基準本身已 4/7 觸底＝既有特性）；
修訂為 def+1/+2/+3＋HP 上調補償（+20/+90/+180），總防 13 時地板率回到 4/7 與裸裝一致
＝「裝備不使地板化惡化」。atk+22≈傷害+22%，低於修行盤整條路線幅度，維持原案。

## 系統設計（全部沿用既有慣例）

- **資料**：`data/equipment.json`，schema 仿 items.json：
  `{id: {name, slot: "beads|kasaya|bowl", tier, price, bonus: {atk?, def?, hp?}, passive?: {gold_pct?, merit_per_win?}, desc}}`
- **存檔**：`player.equipment = {"beads":"","kasaya":"","bowl":""}` ＋ `player.equipment_owned: Array[String]`；
  照 enemies_seen 慣例：_ready 與 new_game 兩份預設**同步加**、guard 函式處理舊檔缺鍵與 float 型別、
  SaveManager 逐 key 覆蓋天然相容不用改。
- **數值掛點**：新 `EquipmentSystem`（仿 CultivationBoard 模式）`compute_bonus() -> {atk, def, hp, gold_pct, merit_per_win}`；
  在 `Combatant.from_player()`（Combatant.gd:64-78，全案唯一公式接觸點）與修行盤 bonus 同點加總。
- **缽被動**：掛 `BattleManager._victory()` 的金幣結算（與 gold_multiplier_active 疊乘）＋功德發放。
  **勝利限定**——flee 路徑（_apply_battle_victory_hooks）零獎勵原則不變。
- **商店**：ShopScreen 加「消耗品／佛具」分頁；佛具購買＝spend_gold→入 equipment_owned；
  已持有顯示「已購入」灰置（每件限購一次）；未達進貨門檻的不顯示（不劇透）。
- **佛具頁**：MenuShell 經書 device 加第三頁「佛具」（EquipPage）：三欄位現況＋該欄持有清單＋
  裝上/卸下＋三圍加成即時預覽。
- **說明 app**：HelpApp 戰鬥系統區補一條佛具說明。
- **不動**：傷害公式本體、修行盤、消耗品道具、戰鬥道具選單（裝備不進 inventory，不會混入戰鬥道具清單）。

## 驗證

- 新 TestEquipment：json schema 載入、compute_bonus、裝/卸、舊檔 guard、商店購買（扣錢/入庫/限購）、
  勝利被動（金幣%/功德）、flee 不觸發被動、裝備不出現在戰鬥道具選單。
- 回歸：TestMenuSystem（經書頁數斷言同步）、TestShop、TestBattleFlow、TestBattleOverhaul 除外（髒存檔雷）。
- **TTK probe**：裸裝 vs 全 3 階，打代表雜魚與 ares，改前改後對照落在合理帶（雜魚不得出現「只能打 1」化）。

## 偵察依據（E0，2026-07-08）

玩家 atk/def/spd＝Combatant.from_player() 寫死 100/10/15（player dict 無此欄位）；
傷害＝power×atk/100→乘區→−defense（減法 min 1）；雜魚 HP120-200/atk12-40/金50-400；
ares HP2000/atk80/def40/金5000；現行消耗品 220-500 金；初始金 1000。
⚠CultivationBoard 的 guard_boost/one_more_edge passive 只有定義端無消費端——裝備被動要自己接線。
