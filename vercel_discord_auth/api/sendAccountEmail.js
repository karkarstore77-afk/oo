// Sends the Pixel Account emails (verify email / reset password) with our own designed HTML,
// instead of Firebase's plain-text emails. Setup in EMAIL_TEMPLATES_AR.md. Environment variables on Vercel:
//   BREVO_API_KEY             (free, no domain needed) API key from brevo.com; MAIL_FROM must be a sender verified in Brevo
//   RESEND_API_KEY            (alternative) API key from resend.com; needs a verified domain to email other people
//   MAIL_FROM                 e.g.  Roof Groove <you@gmail.com>  (Brevo)  or  Roof Groove <noreply@yourdomain.com>  (Resend)
//   FIREBASE_SERVICE_ACCOUNT  already set for the Discord login
//   PUBLIC_BASE_URL           (optional) default https://roofgroove-discord-auth.vercel.app
// If something is missing the function answers 503 and the game falls back to Firebase's own emails.
const crypto = require("crypto");
const { buildEmail, normalizeLang } = require("../lib/emailTemplates");

const PROJECT_ID = "roof-groove";
const API_KEY = process.env.FIREBASE_API_KEY || "AIzaSyAgMmES7FDnz10lWrYZCUDvTX8ZhjbUGmg";
const BASE_URL = String(process.env.PUBLIC_BASE_URL || "https://roofgroove-discord-auth.vercel.app").replace(/\/$/, "");
const COOLDOWN_MS = 60 * 1000;
const lastSent = new Map(); // best effort (per server instance): at most one email per address and type each minute

function send(res, status, body) {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");
  res.setHeader("Cache-Control", "no-store");
  return res.status(status).json(body);
}

function b64url(input) {
  return Buffer.from(input).toString("base64").replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}

function getServiceAccount() {
  const account = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT || "{}");
  if (!account.client_email || !account.private_key || account.project_id !== PROJECT_ID) {
    throw new Error("FIREBASE_SERVICE_ACCOUNT is missing or belongs to another project");
  }
  return account;
}

async function getAccessToken(account) {
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claim = b64url(JSON.stringify({
    iss: account.client_email,
    scope: "https://www.googleapis.com/auth/identitytoolkit",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const signature = crypto.sign("RSA-SHA256", Buffer.from(`${header}.${claim}`), account.private_key);
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${header}.${claim}.${b64url(signature)}`,
    }),
    signal: AbortSignal.timeout(10000),
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok || !data.access_token) throw new Error("could not get a Google access token");
  return data.access_token;
}

async function adminCall(token, path, body) {
  const response = await fetch(`https://identitytoolkit.googleapis.com/v1/projects/${PROJECT_ID}/${path}`, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(10000),
  });
  const data = await response.json().catch(() => ({}));
  return { ok: response.ok, data };
}

module.exports = async function sendAccountEmail(req, res) {
  if (req.method === "OPTIONS") return send(res, 204, {});
  if (req.method !== "POST") return send(res, 405, { error: "POST only" });

  const brevoKey = String(process.env.BREVO_API_KEY || "").trim();
  const resendKey = String(process.env.RESEND_API_KEY || "").trim();
  const from = String(process.env.MAIL_FROM || "").trim();
  if ((!brevoKey && !resendKey) || !from) return send(res, 503, { error: "mail is not configured" });

  let body = req.body;
  if (typeof body === "string") {
    try { body = JSON.parse(body); } catch (_) { body = {}; }
  }
  body = body || {};
  const type = body.type === "reset" ? "reset" : body.type === "verify" ? "verify" : "";
  if (!type) return send(res, 400, { error: "invalid type" });
  const lang = normalizeLang(body.lang);

  try {
    let email = "";
    if (type === "verify") {
      // The player just created the account: the idToken proves it and tells us the address.
      const idToken = typeof body.idToken === "string" ? body.idToken : "";
      if (idToken.length < 20 || idToken.length > 4096) return send(res, 400, { error: "missing token" });
      const lookup = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${API_KEY}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ idToken }),
        signal: AbortSignal.timeout(10000),
      });
      const info = await lookup.json().catch(() => ({}));
      const user = lookup.ok && Array.isArray(info.users) ? info.users[0] : null;
      if (!user || !user.email) return send(res, 401, { error: "invalid token" });
      if (user.emailVerified) return send(res, 200, { ok: true, skipped: true });
      email = String(user.email).toLowerCase();
    } else {
      email = String(body.email || "").trim().toLowerCase();
      if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email) || email.length > 254) return send(res, 400, { error: "invalid email" });
    }

    const key = `${type}:${email}`;
    if (Date.now() - (lastSent.get(key) || 0) < COOLDOWN_MS) return send(res, 200, { ok: true, skipped: true });

    const token = await getAccessToken(getServiceAccount());
    if (type === "reset") {
      // Never reveal whether an address has an account: unknown address -> answer "ok" but send nothing.
      const exists = await adminCall(token, "accounts:lookup", { email: [email] });
      if (!exists.ok || !Array.isArray(exists.data.users) || exists.data.users.length === 0) return send(res, 200, { ok: true });
    }
    const oob = await adminCall(token, "accounts:sendOobCode", {
      requestType: type === "reset" ? "PASSWORD_RESET" : "VERIFY_EMAIL",
      email,
      returnOobLink: true,
    });
    if (!oob.ok) return send(res, 502, { error: "could not create the link" });
    let oobCode = oob.data.oobCode;
    if (!oobCode && oob.data.oobLink) oobCode = new URL(oob.data.oobLink).searchParams.get("oobCode");
    if (!oobCode) return send(res, 502, { error: "could not create the link" });

    const mode = type === "reset" ? "resetPassword" : "verifyEmail";
    const link = `${BASE_URL}/account.html?mode=${mode}&oobCode=${encodeURIComponent(oobCode)}&lang=${lang}`;
    const mail = buildEmail({ type, lang, link, email, baseUrl: BASE_URL });

    let sent;
    if (brevoKey) {
      const m = from.match(/^\s*"?([^"<]*?)"?\s*<([^>]+)>\s*$/);
      const sender = m ? { name: m[1].trim() || "Roof Groove", email: m[2].trim() } : { name: "Roof Groove", email: from };
      sent = await fetch("https://api.brevo.com/v3/smtp/email", {
        method: "POST",
        headers: { "api-key": brevoKey, "Content-Type": "application/json", accept: "application/json" },
        body: JSON.stringify({ sender, to: [{ email }], subject: mail.subject, htmlContent: mail.html, textContent: mail.text }),
        signal: AbortSignal.timeout(10000),
      });
    } else {
      sent = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: { Authorization: `Bearer ${resendKey}`, "Content-Type": "application/json" },
        body: JSON.stringify({ from, to: [email], subject: mail.subject, html: mail.html, text: mail.text }),
        signal: AbortSignal.timeout(10000),
      });
    }
    if (!sent.ok) {
      console.error("Mail provider rejected the email:", sent.status);
      return send(res, 502, { error: `mail provider rejected the email (HTTP ${sent.status})` });
    }
    lastSent.set(key, Date.now());
    return send(res, 200, { ok: true });
  } catch (error) {
    console.error("sendAccountEmail failed:", error.message);
    return send(res, 500, { error: "server error" });
  }
};
