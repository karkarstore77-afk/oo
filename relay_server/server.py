"""RoofGroove relay server.

Both the room host and every joining player connect OUT to this server over WebSocket, so the game
works through any router, CGNAT or mobile network (no port forwarding needed). The server only
forwards opaque game packets; it never reads them.

  /host?room=<ROOM_ID>   the room host (one per room)
  /join?room=<ROOM_ID>   a joining player
  /health                plain HTTP 200 (used to wake the server and for host health checks)

Frames:
  joiner -> server        binary datagram                       -> forwarded to host as  [cid:4 bytes BE][datagram]
  host   -> server        binary  [cid:4 bytes BE][datagram]    -> forwarded to that joiner as [datagram]
  server -> host (text)   {"t":"open","cid":N} / {"t":"close","cid":N}
  host   -> server (text) {"t":"kick","cid":N}
"""
import asyncio
import json
import os
import re
import struct
from http import HTTPStatus
from urllib.parse import parse_qs, urlparse

from websockets.asyncio.server import serve

MAX_ROOMS = int(os.environ.get("MAX_ROOMS", "2000"))
MAX_CLIENTS_PER_ROOM = int(os.environ.get("MAX_CLIENTS_PER_ROOM", "32"))
MAX_FRAME = 4096
ROOM_RE = re.compile(r"^[A-Za-z0-9_\-]{6,64}$")

rooms: dict[str, dict] = {}


def _query(path: str):
    u = urlparse(path)
    return u.path, parse_qs(u.query)


async def health(connection, request):
    path, q = _query(request.path)
    if path == "/health":
        return connection.respond(HTTPStatus.OK, "ok\n")
    if path == "/join":
        # Reject at the HTTP handshake while the host has not connected yet, so the game simply retries.
        room = rooms.get((q.get("room") or [""])[0])
        if room is None or room["host"] is None:
            return connection.respond(HTTPStatus.SERVICE_UNAVAILABLE, "no host\n")
        if len(room["clients"]) >= MAX_CLIENTS_PER_ROOM:
            return connection.respond(HTTPStatus.SERVICE_UNAVAILABLE, "room full\n")
    return None


async def handler(ws):
    path, q = _query(ws.request.path)
    room_id = (q.get("room") or [""])[0]
    if not ROOM_RE.match(room_id):
        await ws.close(1008, "bad room")
        return
    if path == "/host":
        await host_session(ws, room_id)
    elif path == "/join":
        await join_session(ws, room_id)
    else:
        await ws.close(1008, "bad path")


async def host_session(ws, room_id):
    room = rooms.get(room_id)
    if room is not None and room["host"] is not None:
        await ws.close(1008, "room busy")
        return
    if room is None:
        if len(rooms) >= MAX_ROOMS:
            await ws.close(1013, "server full")
            return
        room = {"host": None, "clients": {}, "next": 1}
        rooms[room_id] = room
    room["host"] = ws
    try:
        async for msg in ws:
            if isinstance(msg, bytes):
                if len(msg) < 5 or len(msg) > MAX_FRAME + 4:
                    continue
                cid = struct.unpack(">I", msg[:4])[0]
                target = room["clients"].get(cid)
                if target is not None:
                    try:
                        await target.send(msg[4:])
                    except Exception:
                        pass
            else:
                try:
                    data = json.loads(msg)
                except ValueError:
                    continue
                if data.get("t") == "kick":
                    target = room["clients"].get(int(data.get("cid", 0)))
                    if target is not None:
                        await target.close(1000, "kicked")
    finally:
        room["host"] = None
        for client in list(room["clients"].values()):
            try:
                await client.close(1001, "host left")
            except Exception:
                pass
        room["clients"].clear()
        if rooms.get(room_id) is room:
            rooms.pop(room_id, None)


async def join_session(ws, room_id):
    room = rooms.get(room_id)
    host = room["host"] if room else None
    if host is None:
        await ws.close(1013, "no host")
        return
    if len(room["clients"]) >= MAX_CLIENTS_PER_ROOM:
        await ws.close(1013, "room full")
        return
    cid = room["next"]
    room["next"] += 1
    room["clients"][cid] = ws
    try:
        await host.send(json.dumps({"t": "open", "cid": cid}))
        async for msg in ws:
            if not isinstance(msg, bytes) or not 0 < len(msg) <= MAX_FRAME:
                continue
            host = room["host"]
            if host is None:
                break
            await host.send(struct.pack(">I", cid) + msg)
    finally:
        room["clients"].pop(cid, None)
        host = room["host"]
        if host is not None:
            try:
                await host.send(json.dumps({"t": "close", "cid": cid}))
            except Exception:
                pass


async def main():
    port = int(os.environ.get("PORT", "8080"))
    async with serve(handler, "0.0.0.0", port, process_request=health,
                     max_size=MAX_FRAME + 16, ping_interval=20, ping_timeout=30):
        print("relay listening on", port, flush=True)
        await asyncio.get_running_loop().create_future()


if __name__ == "__main__":
    asyncio.run(main())
