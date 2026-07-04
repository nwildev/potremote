# -*- coding: utf-8 -*-
"""
PotPlayer Bridge — HTTP-мост для удалённого управления DAUM PotPlayer.

Запускается на том же ПК с Windows, где работает PotPlayer.
Поднимает HTTP-сервер и транслирует запросы в Win32-сообщения окну плеера
(WM_USER API PotPlayer + эмуляция клавиш + WM_COMMAND).

Запуск:  python potplayer_bridge.py
Требования: Python 3.9+, Windows. Сторонние библиотеки не нужны (только stdlib).
"""

import ctypes
import json
import os
import re
import subprocess
import threading
from ctypes import wintypes
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse

# ============================ НАСТРОЙКИ ============================

CONFIG = {
    "host": "0.0.0.0",
    "port": 9911,
    # Необязательный токен. Если задан — клиент должен слать заголовок X-Auth-Token.
    "token": "",
    # Путь к exe PotPlayer (нужен для запуска элементов плейлиста).
    "potplayer_exe": r"C:\Program Files\DAUM\PotPlayer\PotPlayerMini64.exe",
    # Классы окна PotPlayer (64- и 32-битная версии).
    "window_classes": ["PotPlayer64", "PotPlayer"],
}

# WM_COMMAND ID для пунктов меню (соотношение сторон и т.п.).
# ВНИМАНИЕ: эти ID могут отличаться между версиями PotPlayer.
# Если команда не срабатывает — проверьте ID в PotPlayer:
# ПКМ -> Настройки -> Клавиши (в списке команд виден их номер),
# и поправьте значения здесь. Для отладки есть эндпоинт POST /command {"id": N}.
WM_COMMAND_IDS = {
    "aspect_default": 10201,
    "aspect_fit_window": 10202,
    "aspect_4_3": 10203,
    "aspect_16_9": 10204,
    "aspect_1_85": 10205,
    "aspect_2_35": 10206,
}

# ============================ WIN32 ============================

user32 = ctypes.windll.user32 if os.name == "nt" else None

WM_USER = 0x0400
WM_COMMAND = 0x0111
WM_KEYDOWN = 0x0100
WM_KEYUP = 0x0101

# Документированный "PotPlayer API" (WM_USER, wParam):
POT_GET_VOLUME = 0x5002
POT_SET_VOLUME = 0x5003
POT_GET_TOTAL_TIME = 0x5004
POT_GET_PROGRESS_TIME = 0x5005
POT_GET_CURRENT_TIME = 0x5006
POT_SET_CURRENT_TIME = 0x5007
POT_GET_PLAY_STATUS = 0x5008   # -1 нет файла, 0 стоп, 1 пауза, 2 воспроизведение
POT_SET_PLAY_STATUS = 0x5009

VK = {
    "SPACE": 0x20, "ENTER": 0x0D, "ESC": 0x1B,
    "PGUP": 0x21, "PGDN": 0x22,
    "LEFT": 0x25, "RIGHT": 0x27, "UP": 0x26, "DOWN": 0x28,
    "C": 0x43, "X": 0x58, "Z": 0x5A, "M": 0x4D,
}

STATE_NAMES = {-1: "no_media", 0: "stopped", 1: "paused", 2: "playing"}


def find_potplayer():
    if user32 is None:
        return None
    for cls in CONFIG["window_classes"]:
        hwnd = user32.FindWindowW(cls, None)
        if hwnd:
            return hwnd
    return None


def pot_send(wparam, lparam=0):
    hwnd = find_potplayer()
    if not hwnd:
        raise RuntimeError("PotPlayer window not found")
    return user32.SendMessageW(hwnd, WM_USER, wparam, lparam)


def pot_command(cmd_id):
    hwnd = find_potplayer()
    if not hwnd:
        raise RuntimeError("PotPlayer window not found")
    user32.PostMessageW(hwnd, WM_COMMAND, cmd_id, 0)


def pot_key(vk_code):
    """Эмуляция нажатия клавиши прямо в окно плеера (фокус не требуется)."""
    hwnd = find_potplayer()
    if not hwnd:
        raise RuntimeError("PotPlayer window not found")
    user32.PostMessageW(hwnd, WM_KEYDOWN, vk_code, 0)
    user32.PostMessageW(hwnd, WM_KEYUP, vk_code, 0)


def window_title():
    hwnd = find_potplayer()
    if not hwnd:
        return ""
    buf = ctypes.create_unicode_buffer(512)
    user32.GetWindowTextW(hwnd, buf, 512)
    title = buf.value
    # Обычно заголовок: "имя_файла - PotPlayer"
    return re.sub(r"\s*-\s*PotPlayer.*$", "", title)


# ============================ ПЛЕЙЛИСТ ============================

def playlist_path():
    appdata = os.environ.get("APPDATA", "")
    candidates = [
        os.path.join(appdata, "PotPlayerMini64", "Playlist", "PotPlayerMini64.dpl"),
        os.path.join(appdata, "PotPlayerMini", "Playlist", "PotPlayerMini.dpl"),
    ]
    for p in candidates:
        if os.path.isfile(p):
            return p
    return None


def read_playlist():
    """Парсит текущий .dpl плейлист PotPlayer."""
    path = playlist_path()
    if not path:
        return []
    items = {}
    with open(path, "r", encoding="utf-8-sig", errors="replace") as f:
        for line in f:
            m = re.match(r"^(\d+)\*file\*(.+)$", line.strip())
            if m:
                idx = int(m.group(1))
                fp = m.group(2)
                items[idx] = {
                    "index": idx,
                    "path": fp,
                    "name": os.path.basename(fp),
                }
    return [items[k] for k in sorted(items)]


def play_playlist_item(index):
    items = read_playlist()
    match = next((i for i in items if i["index"] == index), None)
    if not match:
        raise RuntimeError(f"Playlist item {index} not found")
    exe = CONFIG["potplayer_exe"]
    if not os.path.isfile(exe):
        raise RuntimeError(f"PotPlayer exe not found: {exe}")
    # При включённом режиме "одно окно" файл откроется в текущем экземпляре.
    subprocess.Popen([exe, match["path"], "/current"])
    return match


# ============================ ДЕЙСТВИЯ ============================

def get_status():
    hwnd = find_potplayer()
    if not hwnd:
        return {"connected": False}
    state = ctypes.c_long(user32.SendMessageW(hwnd, WM_USER, POT_GET_PLAY_STATUS, 0)).value
    return {
        "connected": True,
        "state": STATE_NAMES.get(state, str(state)),
        "position_ms": user32.SendMessageW(hwnd, WM_USER, POT_GET_CURRENT_TIME, 0),
        "duration_ms": user32.SendMessageW(hwnd, WM_USER, POT_GET_TOTAL_TIME, 0),
        "volume": user32.SendMessageW(hwnd, WM_USER, POT_GET_VOLUME, 0),
        "title": window_title(),
    }


ACTIONS = {
    "toggle":     lambda body: pot_key(VK["SPACE"]),
    "play":       lambda body: pot_send(POT_SET_PLAY_STATUS, 2),
    "pause":      lambda body: pot_send(POT_SET_PLAY_STATUS, 1),
    "stop":       lambda body: pot_send(POT_SET_PLAY_STATUS, 0),
    "next":       lambda body: pot_key(VK["PGDN"]),
    "prev":       lambda body: pot_key(VK["PGUP"]),
    "fullscreen": lambda body: pot_key(VK["ENTER"]),
    "mute":       lambda body: pot_key(VK["M"]),
    "speed_up":   lambda body: pot_key(VK["C"]),
    "speed_down": lambda body: pot_key(VK["X"]),
    "speed_reset":lambda body: pot_key(VK["Z"]),
}


def do_seek(body):
    if "position_ms" in body:
        pot_send(POT_SET_CURRENT_TIME, int(body["position_ms"]))
    elif "relative_ms" in body:
        cur = pot_send(POT_GET_CURRENT_TIME)
        pot_send(POT_SET_CURRENT_TIME, max(0, cur + int(body["relative_ms"])))
    else:
        raise ValueError("position_ms or relative_ms required")


def do_volume(body):
    level = max(0, min(100, int(body["level"])))
    pot_send(POT_SET_VOLUME, level)


def do_aspect(body):
    key = "aspect_" + str(body["name"])
    if key not in WM_COMMAND_IDS:
        raise ValueError(f"unknown aspect: {body['name']}")
    pot_command(WM_COMMAND_IDS[key])


def do_raw_command(body):
    pot_command(int(body["id"]))


# ============================ HTTP ============================

class Handler(BaseHTTPRequestHandler):
    server_version = "PotPlayerBridge/1.0"

    def _reply(self, code, payload):
        data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _auth_ok(self):
        token = CONFIG.get("token") or ""
        return not token or self.headers.get("X-Auth-Token") == token

    def _body(self):
        length = int(self.headers.get("Content-Length") or 0)
        if not length:
            return {}
        return json.loads(self.rfile.read(length).decode("utf-8"))

    def do_GET(self):
        if not self._auth_ok():
            return self._reply(401, {"error": "unauthorized"})
        path = urlparse(self.path).path
        try:
            if path == "/status":
                return self._reply(200, get_status())
            if path == "/playlist":
                return self._reply(200, {"items": read_playlist()})
            if path == "/ping":
                return self._reply(200, {"ok": True})
            return self._reply(404, {"error": "not found"})
        except Exception as e:
            return self._reply(500, {"error": str(e)})

    def do_POST(self):
        if not self._auth_ok():
            return self._reply(401, {"error": "unauthorized"})
        path = urlparse(self.path).path
        try:
            body = self._body()
            name = path.lstrip("/")
            if name in ACTIONS:
                ACTIONS[name](body)
                return self._reply(200, {"ok": True})
            if path == "/seek":
                do_seek(body); return self._reply(200, {"ok": True})
            if path == "/volume":
                do_volume(body); return self._reply(200, {"ok": True})
            if path == "/aspect":
                do_aspect(body); return self._reply(200, {"ok": True})
            if path == "/command":
                do_raw_command(body); return self._reply(200, {"ok": True})
            if path == "/playlist/play":
                item = play_playlist_item(int(body["index"]))
                return self._reply(200, {"ok": True, "item": item})
            return self._reply(404, {"error": "not found"})
        except Exception as e:
            return self._reply(500, {"error": str(e)})

    def log_message(self, fmt, *args):
        print("[HTTP]", fmt % args)


def main():
    if os.name != "nt":
        print("Этот сервер должен запускаться на Windows рядом с PotPlayer.")
        return
    addr = (CONFIG["host"], CONFIG["port"])
    print(f"PotPlayer Bridge запущен на http://{addr[0]}:{addr[1]}")
    print("Окно PotPlayer:", "найдено" if find_potplayer() else "НЕ найдено (запустите плеер)")
    ThreadingHTTPServer(addr, Handler).serve_forever()


if __name__ == "__main__":
    main()
