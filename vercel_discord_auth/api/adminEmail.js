// Admin only: send an email from the game to any address (for example a player's account email).
// Protected by a secret that exists ONLY in Vercel (never inside the game):
//   ADMIN_MAIL_KEY            long random text you choose; send it in the header  x-admin-key
// Mail provider: same variables as feedback.js / sendAccountEmail.js (BREVO_API_KEY + MAIL_FROM, or RESEND_API_KEY + MAIL_FROM).
// Use the page  /admin_mail.html  or:  curl -X POST <url>/api/adminEmail -H "x-admin-key: KEY" -H "Content-Type: application/json" -d '{"to":"a@b.com","subject":"Hi","message":"Text"}'
const crypto = require("crypto");

function send(res, status, body) {
  res.setHeader("Cache-Control", "no-store");
  return res.status(status).json(body);
}
const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
const clean = (s, n) => String(s == null ? "" : s).replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/g, "").slice(0, n);

function sameKey(a, b) {
  const x = crypto.createHash("sha256").update(String(a)).digest();
  const y = crypto.createHash("sha256").update(String(b)).digest();
  return crypto.timingSafeEqual(x, y);
}

module.exports = async function adminEmail(req, res) {
  if (req.method !== "POST") return send(res, 405, { error: "POST only" });
  const secret = String(process.env.ADMIN_MAIL_KEY || "").trim();
  if (secret.length < 16) return send(res, 503, { error: "ADMIN_MAIL_KEY is not set on the server (min 16 characters)" });
  if (!sameKey(req.headers["x-admin-key"] || "", secret)) return send(res, 401, { error: "wrong admin key" });

  let body = req.body;
  if (typeof body === "string") { try { body = JSON.parse(body); } catch (_) { body = {}; } }
  body = body || {};
  const to = clean(body.to, 160).trim();
  const subject = clean(body.subject, 150).trim() || "Roof Groove";
  const message = clean(body.message, 5000).trim();
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(to)) return send(res, 400, { error: "invalid recipient email" });
  if (message.length < 1) return send(res, 400, { error: "empty message" });

  const brevoKey = String(process.env.BREVO_API_KEY || "").trim();
  const resendKey = String(process.env.RESEND_API_KEY || process.env.FEEDBACK_RESEND_API_KEY || "").trim();
  const from = String(process.env.MAIL_FROM || (process.env.FEEDBACK_RESEND_API_KEY ? "Roof Groove <onboarding@resend.dev>" : "")).trim();
  if ((!brevoKey && !resendKey) || !from) return send(res, 503, { error: "mail provider is not configured" });

  const html = `<div style="font-family:Arial,sans-serif;line-height:1.7;white-space:pre-wrap">${esc(message)}<hr><small>Roof Groove</small></div>`;
  try {
    let sent;
    if (brevoKey) {
      const m = from.match(/^\s*"?([^"<]*?)"?\s*<([^>]+)>\s*$/);
      const sender = m ? { name: m[1].trim() || "Roof Groove", email: m[2].trim() } : { name: "Roof Groove", email: from };
      sent = await fetch("https://api.brevo.com/v3/smtp/email", {
        method: "POST",
        headers: { "api-key": brevoKey, "Content-Type": "application/json", accept: "application/json" },
        body: JSON.stringify({ sender, to: [{ email: to }], subject, htmlContent: html, textContent: message }),
        signal: AbortSignal.timeout(10000),
      });
    } else {
      sent = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: { Authorization: `Bearer ${resendKey}`, "Content-Type": "application/json" },
        body: JSON.stringify({ from, to: [to], subject, html, text: message }),
        signal: AbortSignal.timeout(10000),
      });
    }
    if (!sent.ok) {
      const info = await sent.json().catch(() => ({}));
      return send(res, 502, { error: "mail provider rejected the email", provider_status: sent.status, detail: clean(info.message || info.error || info.code || "", 200) });
    }
    return send(res, 200, { ok: true });
  } catch (e) {
    return send(res, 502, { error: "could not reach the mail provider" });
  }
};
