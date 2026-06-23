#!/usr/bin/env python
"""從 game_ready 全身立繪裁 VN 對話胸像（頭+上半身），縮到目標 bust 檔的尺寸（不跑版）。

用法: python tools/crop_bust.py            # 跑內建 Phase 1 manifest（18 張）
裁法: alpha bbox 取人物範圍 → 從頭頂往下 TOP_FRAC×身高、寬=高×目標長寬比、水平置中 → resize 到目標尺寸。
覆蓋現有 bust 路徑（.dch 已指向，零改碼）。已驗證(lao_wang 702×740 框準)。
"""
import sys
from PIL import Image

TOP_FRAC = 0.50  # 從頭頂往下取身高的比例當胸像高（含頭+上半身）

GR = "assets/art_direction/new_ink_shrine_style/characters/game_ready"

# src(在 GR 下) -> dst(專案相對路徑，沿用現有檔名=零改碼)
MANIFEST = {
    # 無戒 ascetic 4 表情 -> wujie/bust
    "wujie_ascetic_emote_calm_front_game_ready.png":      "assets/2d/portraits/wujie/bust/wujie_ascetic_calm.png",
    "wujie_ascetic_emote_angry_front_game_ready.png":     "assets/2d/portraits/wujie/bust/wujie_ascetic_angry.png",
    "wujie_ascetic_emote_happy_front_game_ready.png":     "assets/2d/portraits/wujie/bust/wujie_ascetic_happy.png",
    "wujie_ascetic_emote_surprised_front_game_ready.png": "assets/2d/portraits/wujie/bust/wujie_ascetic_surprised.png",
    # Cherry(藝伎) 4 表情 -> cherry/bust
    "cherry_geisha_emote_neutral_front_game_ready.png":   "assets/2d/portraits/cherry/bust/cherry_neutral.png",
    "cherry_geisha_emote_smile_front_game_ready.png":     "assets/2d/portraits/cherry/bust/cherry_smile.png",
    "cherry_geisha_emote_angry_front_game_ready.png":     "assets/2d/portraits/cherry/bust/cherry_angry.png",
    "cherry_geisha_emote_sorrow_front_game_ready.png":    "assets/2d/portraits/cherry/bust/cherry_sorrow.png",
    # NPC 10 -> npcs/bust
    "ah_ming_front_ares_red_game_ready.png":  "assets/2d/portraits/npcs/bust/npc_ah_ming.png",
    "ah_zhong_front_ares_red_game_ready.png": "assets/2d/portraits/npcs/bust/npc_ah_zhong.png",
    "cai_ma_front_ares_red_game_ready.png":   "assets/2d/portraits/npcs/bust/npc_cai_ma.png",
    "david_front_ares_red_game_ready.png":    "assets/2d/portraits/npcs/bust/npc_david.png",
    "grandma_front_ares_red_game_ready.png":  "assets/2d/portraits/npcs/bust/npc_grandma.png",
    "jie_front_ares_red_game_ready.png":      "assets/2d/portraits/npcs/bust/npc_jie.png",
    "lao_wang_front_ares_red_game_ready.png": "assets/2d/portraits/npcs/bust/npc_lao_wang.png",
    "liaochen_front_game_ready.png":          "assets/2d/portraits/npcs/bust/npc_liaochen.png",
    "rei_front_ares_red_game_ready.png":      "assets/2d/portraits/npcs/bust/npc_rei.png",
    "zheng_ma_front_ares_red_game_ready.png": "assets/2d/portraits/npcs/bust/npc_zheng_ma.png",
}


def crop_bust(src_path: str, dst_path: str) -> tuple:
    src = Image.open(src_path).convert("RGBA")
    # 目標尺寸：沿用現有 dst（不跑版）；缺則預設方形 512。
    try:
        dst_w, dst_h = Image.open(dst_path).size
    except FileNotFoundError:
        dst_w, dst_h = 512, 540
    l, t, r, b = src.getbbox()           # 人物（非透明）範圍
    fh = b - t
    cx = (l + r) // 2
    aspect = dst_w / dst_h
    crop_h = int(TOP_FRAC * fh)
    crop_w = int(crop_h * aspect)
    x0 = max(0, cx - crop_w // 2)
    x1 = min(src.width, x0 + crop_w)
    y0 = t
    y1 = min(src.height, y0 + crop_h)
    bust = src.crop((x0, y0, x1, y1)).resize((dst_w, dst_h), Image.LANCZOS)
    bust.save(dst_path)
    return (dst_w, dst_h)


def main():
    ok = 0
    for src_rel, dst in MANIFEST.items():
        src = f"{GR}/{src_rel}"
        try:
            size = crop_bust(src, dst)
            print(f"OK  {dst.split('portraits/')[1]:<40} {size}")
            ok += 1
        except Exception as e:
            print(f"ERR {src_rel}: {e}")
    print(f"--- {ok}/{len(MANIFEST)} busts ---")


if __name__ == "__main__":
    main()
