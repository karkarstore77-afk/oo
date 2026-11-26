// Optional in-game feedback. The game POSTs JSON here; we email it to the developer.
// No secret is shipped in the game: the mail key lives only in Vercel environment variables.
// Simplest setup (free, no domain): a Resend account created with the developer's own email.
//   FEEDBACK_RESEND_API_KEY   Resend API key used ONLY for feedback (preferred, checked first)
//   FEEDBACK_MAIL_FROM        (optional) default "Roof Groove <onboarding@resend.dev>" (Resend's test sender)
//   FEEDBACK_TO               (optional) where feedback goes; default below. With a free Resend account
//                             without a domain this MUST be the email the Resend account was made with.
// Fallback when FEEDBACK_RESEND_API_KEY is not set: BREVO_API_KEY or RESEND_API_KEY with MAIL_FROM
// (same as sendAccountEmail.js).
const DEFAULT_TO = "rayyanelnahas10@gmail.com";
const COOLDOWN_MS = 30 * 1000;
const DAILY_LIMIT_PER_IP = 20;
const lastByIp = new Map(); // best effort, per server instance
const dayCount = new Map();

function send(res, status, body) {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");
  res.setHeader("Cache-Control", "no-store");
  return res.status(status).json(body);
}

const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
const clean = (s, n) => String(s == null ? "" : s).replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/g, "").slice(0, n);

module.exports = async function feedback(req, res) {
  if (req.method === "OPTIONS") return send(res, 204, {});
  if (req.method !== "POST") return send(res, 405, { error: "POST only" });

  const ownResend = String(process.env.FEEDBACK_RESEND_API_KEY || "").trim();
  const brevoKey = ownResend ? "" : String(process.env.BREVO_API_KEY || "").trim();
  const resendKey = ownResend || String(process.env.RESEND_API_KEY || "").trim();
  const from = ownResend
    ? String(process.env.FEEDBACK_MAIL_FROM || "Roof Groove <onboarding@resend.dev>").trim()
    : String(process.env.MAIL_FROM || "").trim();
  const to = String(process.env.FEEDBACK_TO || DEFAULT_TO).trim();
  if ((!brevoKey && !resendKey) || !from) return send(res, 503, { error: "mail is not configured" });

  let body = req.body;
  if (typeof body === "string") { try { body = JSON.parse(body); } catch (_) { body = {}; } }
  body = body || {};

  const message = clean(body.message, 1000).trim();
  if (message.length < 5) return send(res, 400, { error: "message too short" });
  const category = ["idea", "bug", "other"].includes(body.category) ? body.category : "other";
  const contact = clean(body.contact, 120).trim();
  if (contact && !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(contact)) return send(res, 400, { error: "invalid email" });
  const version = clean(body.version, 20), platform = clean(body.platform, 30), lang = clean(body.lang, 5);
  const build = Number.isFinite(Number(body.build)) ? Number(body.build) : "";

  const ip = String(req.headers["x-forwarded-for"] || "").split(",")[0].trim() || "unknown";
  const now = Date.now();
  if (now - (lastByIp.get(ip) || 0) < COOLDOWN_MS) return send(res, 429, { error: "slow down" });
  const dayKey = `${ip}:${new Date().toISOString().slice(0, 10)}`;
  if ((dayCount.get(dayKey) || 0) >= DAILY_LIMIT_PER_IP) return send(res, 429, { error: "limit reached" });

  const subject = `[Roof Groove feedback] ${category}${version ? " v" + version : ""}`;
  const lines = [
    `Type: ${category}`,
    version ? `Game version: ${version}${build !== "" ? " (build " + build + ")" : ""}` : "Game version: not shared",
    `Device: ${platform || "not shared"}`,
    `Language: ${lang || "unknown"}`,
    `Reply to: ${contact || "not provided"}`,
    "",
    message,
  ];
  const text = lines.join("\n");
  const html = `<div style="font-family:Arial,sans-serif;line-height:1.6"><h3>Roof Groove feedback</h3><p>${esc(lines.slice(0, 5).join("\n")).replace(/\n/g, "<br>")}</p><hr><p style="white-space:pre-wrap">${esc(message)}</p></div>`;

  try {
    let sent;
    if (brevoKey) {
      const m = from.match(/^\s*"?([^"<]*?)"?\s*<([^>]+)>\s*$/);
      const sender = m ? { name: m[1].trim() || "Roof Groove", email: m[2].trim() } : { name: "Roof Groove", email: from };
      const payload = { sender, to: [{ email: to }], subject, htmlContent: html, textContent: text };
      if (contact) payload.replyTo = { email: contact };
      sent = await fetch("https://api.brevo.com/v3/smtp/email", {
        method: "POST",
        headers: { "api-key": brevoKey, "Content-Type": "application/json", accept: "application/json" },
        body: JSON.stringify(payload),
        signal: AbortSignal.timeout(10000),
      });
    } else {
      const payload = { from, to: [to], subject, html, text };
      if (contact) payload.reply_to = contact;
      sent = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: { Authorization: `Bearer ${resendKey}`, "Content-Type": "application/json" },
        body: JSON.stringify(payload),
        signal: AbortSignal.timeout(10000),
      });
    }
    if (!sent.ok) {
      const info = await sent.json().catch(() => ({}));
      const detail = clean(info.message || info.error || info.code || info.name || "", 160);
      console.error("Mail provider rejected feedback:", sent.status, detail);
      return send(res, 502, { error: "mail provider rejected the email", provider: brevoKey ? "brevo" : "resend", provider_status: sent.status, detail });
    }
    lastByIp.set(ip, now);
    dayCount.set(dayKey, (dayCount.get(dayKey) || 0) + 1);
    return send(res, 200, { ok: true });
  } catch (error) {
    console.error("feedback failed:", error.message);
    return send(res, 500, { error: "server error" });
  }
};
