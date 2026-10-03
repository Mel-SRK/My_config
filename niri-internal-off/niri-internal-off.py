#!/usr/bin/env python3
"""外接显示器接入时自动熄灭内屏 eDP-1；拔掉后自动恢复；顺带把外接屏钉在指定刷新率。

判断依据：内核 sysfs 的连接状态（热插拔立刻可见，不依赖合成器状态）
  /sys/class/drm/card*-DP-1/status == "connected"
下发动作：niri IPC   niri msg output <name> {off,on} | mode <WxH@R>

用法：
  niri-internal-off.py                     常驻守护（systemd user service 调用）
  niri-internal-off.py --status            打印当前判断依据
  niri-internal-off.py --once              只判断一次并纠正，然后退出
  niri-internal-off.py --once --dry-run    只说要做什么，不动硬件（自测用）
  niri-internal-off.py --once --assume-external=no   假定外接不在（测"拔掉后恢复"分支）
环境变量：
  NIRI_PIN_MODE   覆盖钉住的刷新率，例：NIRI_PIN_MODE=2560x1440@144（设空字符串=不钉）
"""

import argparse
import glob
import json
import os
import subprocess
import sys
import time

EXTERNAL = "DP-1"
INTERNAL = "eDP-1"

# 把外接屏钉在这个模式上。原因：config 里的 mode 并不保证对已启用的 output 生效
# （实测启动后仍是 EDID 给的模式，跟这里钉的不一致时以这里为准）。
# 置空字符串则不管刷新率。
PIN_MODES = {EXTERNAL: "2560x1440@200"}

POLL_SECONDS = 2.0
LOG_PATH = os.path.expanduser("~/.local/state/niri-internal-off.log")


def log(msg):
    line = f"{time.strftime('%F %T')} {msg}"
    print(line, flush=True)
    try:
        with open(LOG_PATH, "a") as fh:
            fh.write(line + "\n")
    except OSError:
        pass


def find_niri_socket():
    """niri msg 只认 NIRI_SOCKET，而 systemd user service 的环境里往往没有它。

    socket 名形如 /run/user/1000/niri.wayland-1.141034.sock，末尾 PID 可用来配对活着的 niri。
    """
    env = os.environ.get("NIRI_SOCKET")
    if env and os.path.exists(env):
        return env
    runtime = os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}"
    try:
        out = subprocess.run(["pgrep", "-x", "niri"], capture_output=True, text=True, timeout=5).stdout
        pids = out.split()
    except (OSError, subprocess.TimeoutExpired):
        pids = []
    candidates = []
    for pid in pids:
        candidates += glob.glob(f"{runtime}/niri.wayland-*.{pid}.sock")
    if not candidates:
        candidates = glob.glob(f"{runtime}/niri.wayland-*.sock")
    if not candidates:
        return None
    candidates.sort(key=lambda p: os.path.getmtime(p), reverse=True)
    os.environ["NIRI_SOCKET"] = candidates[0]
    return candidates[0]


def niri(*args):
    return subprocess.run(["niri", "msg", *args], capture_output=True, text=True, timeout=15)


def snapshot():
    """一次 IPC 拿到所有输出信息，读不到返回 None。"""
    try:
        res = niri("--json", "outputs")
    except (OSError, subprocess.TimeoutExpired):
        return None
    if res.returncode != 0:
        return None
    try:
        return json.loads(res.stdout)
    except json.JSONDecodeError:
        return None


def external_connected():
    """sysfs 里找不到对应连接器时按"没接"处理。"""
    for path in glob.glob(f"/sys/class/drm/card*-{EXTERNAL}/status"):
        try:
            with open(path) as fh:
                if fh.read().strip() == "connected":
                    return True
        except OSError:
            continue
    return False


def is_on(outs, name):
    """True=亮，False=熄，None=这块输出不在列表里。"""
    info = outs.get(name)
    if info is None:
        return None
    return info.get("logical") is not None


def current_mode(outs, name):
    """返回 (宽, 高, 刷新率Hz)，读不到返回 None。"""
    info = outs.get(name)
    if not info:
        return None
    modes = info.get("modes") or []
    idx = info.get("current_mode")
    if idx is None or not isinstance(idx, int) or idx >= len(modes):
        return None
    m = modes[idx]
    return (m.get("width"), m.get("height"), (m.get("refresh_rate") or 0) / 1000.0)


def parse_mode(text):
    """'2560x1440@144' -> (2560, 1440, 144.0)；解析不了返回 None。"""
    try:
        size, _, rate = text.partition("@")
        w, _, h = size.partition("x")
        return (int(w), int(h), float(rate))
    except (ValueError, AttributeError):
        return None


def sync(assume_external=None, dry_run=False, pin_modes=None):
    outs = snapshot()
    if outs is None:
        return {"error": "读不到 niri 输出信息"}
    ext = external_connected() if assume_external is None else assume_external
    want_on = not ext
    result = {"external": ext, "want_internal_on": want_on, "actions": []}

    cur = is_on(outs, INTERNAL)
    if cur is None:
        result["actions"].append(f"{INTERNAL} 不在输出列表里，跳过")
    elif cur != want_on:
        action = "on" if want_on else "off"
        verb = "打开" if want_on else "熄灭"
        line = f"{EXTERNAL} {'已接入' if ext else '未接入'} → 内屏{verb}"
        if dry_run:
            result["actions"].append(f"[dry-run] 会执行: {line}")
        else:
            res = niri("output", INTERNAL, action)
            if res.returncode != 0:
                line += f" 失败 rc={res.returncode} {res.stderr.strip()}"
            log(line)
            result["actions"].append(line)

    pins = PIN_MODES if pin_modes is None else pin_modes
    for name, target in (pins or {}).items():
        if not target:
            continue
        want = parse_mode(target)
        have = current_mode(outs, name)
        if want is None:
            result["actions"].append(f"{name} 的目标模式 {target!r} 解析失败")
            continue
        if have is None:
            result["actions"].append(f"{name} 当前模式读不到，跳过刷新率检查")
            continue
        if abs(have[2] - want[2]) < 0.5 and have[0] == want[0] and have[1] == want[1]:
            continue
        line = f"{name} 刷新率 {have[0]}x{have[1]}@{have[2]:g} → 钉到 {target}"
        if dry_run:
            result["actions"].append(f"[dry-run] 会执行: {line}")
        else:
            res = niri("output", name, "mode", target)
            if res.returncode != 0:
                line += f" 失败 rc={res.returncode} {res.stderr.strip()}"
            log(line)
            result["actions"].append(line)

    return result


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--status", action="store_true", help="打印判断依据后退出")
    ap.add_argument("--once", action="store_true", help="只同步一次后退出")
    ap.add_argument("--dry-run", action="store_true", help="只报告要做什么，不动硬件")
    ap.add_argument("--assume-external", choices=["yes", "no"], default=None,
                    help="自测用：强制假定外接是否接入")
    ap.add_argument("--no-pin", action="store_true", help="本次不检查/不修改刷新率")
    args = ap.parse_args()

    if find_niri_socket() is None:
        log("找不到 niri 的 IPC socket")

    pins = {} if (args.no_pin or os.environ.get("NIRI_PIN_MODE") == "") else None
    if pins is None and os.environ.get("NIRI_PIN_MODE"):
        pins = {EXTERNAL: os.environ["NIRI_PIN_MODE"]}

    if args.status:
        outs = snapshot() or {}
        print(f"niri socket   : {os.environ.get('NIRI_SOCKET')}")
        print(f"{EXTERNAL} 连接   : {external_connected()}")
        print(f"{EXTERNAL} 亮着   : {is_on(outs, EXTERNAL)}  模式: {current_mode(outs, EXTERNAL)}")
        print(f"{INTERNAL} 亮着   : {is_on(outs, INTERNAL)}  模式: {current_mode(outs, INTERNAL)}")
        print(f"刷新率目标    : {pins if pins is not None else PIN_MODES}")
        return 0

    if args.once:
        assume = None if args.assume_external is None else (args.assume_external == "yes")
        res = sync(assume_external=assume, dry_run=args.dry_run, pin_modes=pins)
        if "error" in res:
            print(f"出错：{res['error']}")
            return 1
        print(f"外接接入: {res['external']}  期望内屏亮: {res['want_internal_on']}")
        for a in res["actions"]:
            print(f"  - {a}")
        if not res["actions"]:
            print("  - 无需改动")
        return 0

    log(f"守护启动：{EXTERNAL} 接入则熄灭 {INTERNAL}，拔掉则恢复"
        + (f"；并把 {', '.join(f'{k}→{v}' for k, v in (pins or {}).items())}" if pins else ""))
    while True:
        try:
            sync(pin_modes=pins)
        except Exception as exc:  # 守护进程不能因为一次异常退出
            log(f"异常：{exc!r}")
        time.sleep(POLL_SECONDS)


if __name__ == "__main__":
    sys.exit(main())
