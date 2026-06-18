#!/usr/bin/env python3
"""Meshy AI Text-to-3D 批次生成工具（GDD Step 2）

用法：
    set MESHY_API_KEY=msy_xxxx          # 先設定環境變數（金鑰勿寫進程式碼）
    python tools/meshy_generate.py environments   # 生成 5 個場景
    python tools/meshy_generate.py characters     # 生成無戒角色
    python tools/meshy_generate.py --list         # 只列出將生成的項目（不花費額度）

流程：Preview（產生形狀）→ Refine（上材質）→ 下載 .glb 至 GDD 指定路徑。
每個模型約消耗 Preview+Refine 額度，生成耗時數分鐘，請耐心等待。
"""

import json
import os
import sys
import time
import urllib.request

API_BASE = "https://api.meshy.ai/openapi/v2/text-to-3d"
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROMPT_DIR = os.path.join(PROJECT_ROOT, "data", "meshy_prompts")
POLL_INTERVAL = 20  # 秒


def api_key() -> str:
    key = os.environ.get("MESHY_API_KEY", "")
    if not key:
        sys.exit("錯誤：請先設定環境變數 MESHY_API_KEY（建議到 meshy.ai 重新生成金鑰）")
    return key


def request_json(url: str, payload: dict | None = None) -> dict:
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(url, data=data, method="POST" if data else "GET")
    req.add_header("Authorization", f"Bearer {api_key()}")
    req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req) as resp:
        return json.load(resp)


def create_task(mode: str, prompt: str, art_style: str, topology: str,
                preview_task_id: str | None = None) -> str:
    payload = {"mode": mode}
    if mode == "preview":
        payload.update({
            "prompt": prompt,
            "art_style": art_style,
            "topology": topology,
            "should_remesh": True,
        })
    else:  # refine
        payload["preview_task_id"] = preview_task_id
    result = request_json(API_BASE, payload)
    return result["result"]


def wait_for(task_id: str, label: str) -> dict:
    while True:
        info = request_json(f"{API_BASE}/{task_id}")
        status = info.get("status", "UNKNOWN")
        progress = info.get("progress", 0)
        print(f"  [{label}] {status} {progress}%", flush=True)
        if status == "SUCCEEDED":
            return info
        if status in ("FAILED", "CANCELED"):
            sys.exit(f"  [{label}] 生成失敗：{info.get('task_error', info)}")
        time.sleep(POLL_INTERVAL)


def download(url: str, dest: str) -> None:
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    urllib.request.urlretrieve(url, dest)
    size_mb = os.path.getsize(dest) / 1024 / 1024
    print(f"  已下載 {dest}（{size_mb:.1f} MB）")


def generate(name: str, spec: dict) -> None:
    dest = os.path.join(PROJECT_ROOT, spec["output"].replace("/", os.sep))
    if os.path.exists(dest):
        print(f"[{name}] 已存在，跳過：{dest}")
        return
    print(f"[{name}] Preview 生成中……")
    preview_id = create_task("preview", spec["prompt"],
                             spec.get("art_style", "cartoon"),
                             spec.get("topology", "quad"))
    wait_for(preview_id, f"{name}/preview")
    print(f"[{name}] Refine 上材質中……")
    refine_id = create_task("refine", "", "", "", preview_task_id=preview_id)
    info = wait_for(refine_id, f"{name}/refine")
    glb_url = info.get("model_urls", {}).get("glb", "")
    if not glb_url:
        sys.exit(f"[{name}] 找不到 glb 下載連結：{info}")
    download(glb_url, dest)


def main() -> None:
    args = sys.argv[1:]
    list_only = "--list" in args
    targets = [a for a in args if not a.startswith("--")] or ["environments", "characters"]
    for target in targets:
        path = os.path.join(PROMPT_DIR, f"{target}.json")
        if not os.path.exists(path):
            sys.exit(f"找不到 prompt 檔：{path}")
        with open(path, encoding="utf-8") as f:
            specs = json.load(f)
        print(f"=== {target}：共 {len(specs)} 個模型 ===")
        for name, spec in specs.items():
            if list_only:
                print(f"[{name}] → {spec['output']}")
            else:
                generate(name, spec)
    if list_only:
        print("（--list 模式：未呼叫 API，未消耗額度）")


if __name__ == "__main__":
    main()
