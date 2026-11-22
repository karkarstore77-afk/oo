// RoofGroove relay on Cloudflare Workers + Durable Objects (free plan, no sleeping, no credit card).
// Same protocol as relay_server/server.py:
//   /host?room=ID  the room host (one per room)
//   /join?room=ID  a joining player
//   /health        plain 200
// joiner -> host: binary datagram is forwarded as [cid:4 bytes BE][datagram]
// host -> joiner: binary [cid:4 bytes BE][datagram] is forwarded as [datagram]
// server -> host (text): {"t":"open","cid":N} / {"t":"close","cid":N}; host -> server (text): {"t":"kick","cid":N}

const ROOM_RE = /^[A-Za-z0-9_-]{6,64}$/;
const MAX_FRAME = 4096;
const MAX_CLIENTS = 32;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === "/health") return new Response("ok\n");
    if (url.pathname !== "/host" && url.pathname !== "/join") {
      return new Response("not found", { status: 404 });
    }
    const room = url.searchParams.get("room") || "";
    if (!ROOM_RE.test(room)) return new Response("bad room", { status: 400 });
    if (request.headers.get("Upgrade") !== "websocket") {
      return new Response("expected websocket", { status: 426 });
    }
    return env.ROOM.get(env.ROOM.idFromName(room)).fetch(request);
  },
};

export class Room {
  constructor(ctx, env) {
    this.ctx = ctx;
    this.env = env;
  }

  async fetch(request) {
    const isHost = new URL(request.url).pathname === "/host";
    const hosts = this.ctx.getWebSockets("host");
    if (isHost) {
      if (hosts.length > 0) return new Response("room busy", { status: 409 });
    } else {
      // Rejected at the HTTP handshake while the host is not there yet, so the game just retries.
      if (hosts.length === 0) return new Response("no host", { status: 503 });
      if (this.ctx.getWebSockets("client").length >= MAX_CLIENTS) {
        return new Response("room full", { status: 503 });
      }
    }
    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);
    if (isHost) {
      this.ctx.acceptWebSocket(server, ["host"]);
      server.serializeAttachment({ role: "host" });
    } else {
      const cid = ((await this.ctx.storage.get("next")) || 1);
      await this.ctx.storage.put("next", cid + 1);
      this.ctx.acceptWebSocket(server, ["client", "c" + cid]);
      server.serializeAttachment({ role: "client", cid });
      try {
        hosts[0].send(JSON.stringify({ t: "open", cid }));
      } catch (e) {}
    }
    return new Response(null, { status: 101, webSocket: client });
  }

  async webSocketMessage(ws, message) {
    const att = ws.deserializeAttachment() || {};
    if (att.role === "host") {
      if (typeof message === "string") {
        try {
          const data = JSON.parse(message);
          if (data.t === "kick") {
            const target = this.ctx.getWebSockets("c" + data.cid)[0];
            if (target) target.close(1000, "kicked");
          }
        } catch (e) {}
        return;
      }
      if (message.byteLength < 5 || message.byteLength > MAX_FRAME + 4) return;
      const cid = new DataView(message).getUint32(0);
      const target = this.ctx.getWebSockets("c" + cid)[0];
      if (target) {
        try {
          target.send(message.slice(4));
        } catch (e) {}
      }
    } else if (att.role === "client") {
      if (typeof message === "string" || message.byteLength === 0 || message.byteLength > MAX_FRAME) return;
      const host = this.ctx.getWebSockets("host")[0];
      if (!host) return;
      const out = new Uint8Array(4 + message.byteLength);
      new DataView(out.buffer).setUint32(0, att.cid);
      out.set(new Uint8Array(message), 4);
      try {
        host.send(out);
      } catch (e) {}
    }
  }

  async webSocketClose(ws, code) {
    const att = ws.deserializeAttachment() || {};
    if (att.role === "host") {
      for (const client of this.ctx.getWebSockets("client")) {
        try {
          client.close(1001, "host left");
        } catch (e) {}
      }
    } else if (att.role === "client") {
      const host = this.ctx.getWebSockets("host")[0];
      if (host) {
        try {
          host.send(JSON.stringify({ t: "close", cid: att.cid }));
        } catch (e) {}
      }
    }
    const safe = code >= 1000 && code < 5000 && ![1004, 1005, 1006, 1015].includes(code) ? code : 1000;
    try {
      ws.close(safe, "closed");
    } catch (e) {}
  }

  async webSocketError(ws) {
    await this.webSocketClose(ws, 1011);
  }
}
