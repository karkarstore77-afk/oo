const crypto = require("node:crypto");

const FIREBASE_TOKEN_AUDIENCE = "https://identitytoolkit.googleapis.com/google.identity.identitytoolkit.v1.IdentityToolkit";
let cachedServiceAccount;

// Public value (also in firebase_config.gd). Used when the DISCORD_CLIENT_ID variable was not set on Vercel.
const DEFAULT_DISCORD_CLIENT_ID = "1572027686455349371";
const USER_AGENT = "DiscordBot (https://roofgroove-discord-auth.vercel.app, 1.0)";

function send(res, status, body) {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");
  res.setHeader("Cache-Control", "no-store");
  return res.status(status).json(body);
}

function getServiceAccount() {
  if (cachedServiceAccount) return cachedServiceAccount;
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (!raw) throw new Error("Missing FIREBASE_SERVICE_ACCOUNT environment variable");
  const account = JSON.parse(raw);
  if (account.project_id !== "roof-groove" || !account.client_email || !account.private_key) {
    throw new Error("FIREBASE_SERVICE_ACCOUNT must be a valid key for project roof-groove");
  }
  cachedServiceAccount = account;
  return account;
}

function base64url(value) {
  return Buffer.from(value).toString("base64url");
}

function createFirebaseCustomToken(account, uid) {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: account.client_email,
    sub: account.client_email,
    aud: FIREBASE_TOKEN_AUDIENCE,
    iat: now,
    exp: now + 3600,
    uid,
    claims: { provider: "discord" },
  };
  const content = `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(payload))}`;
  const signature = crypto.sign("RSA-SHA256", Buffer.from(content), account.private_key);
  return `${content}.${signature.toString("base64url")}`;
}

module.exports = async function discordLogin(req, res) {
  if (req.method === "OPTIONS") return send(res, 204, {});
  if (req.method !== "POST") return send(res, 405, { error: "POST only" });

  let body = req.body;
  if (typeof body === "string") {
    try { body = JSON.parse(body); } catch (_) { body = {}; }
  }
  const accessToken = body && typeof body.access_token === "string" ? body.access_token : "";
  if (accessToken.length < 10 || accessToken.length > 8192) {
    return send(res, 400, { error: "missing or invalid token" });
  }
  const expectedApp = String(process.env.DISCORD_CLIENT_ID || DEFAULT_DISCORD_CLIENT_ID).trim();

  try {
    const response = await fetch("https://discord.com/api/oauth2/@me", {
      headers: { Authorization: `Bearer ${accessToken}`, "User-Agent": USER_AGENT },
      signal: AbortSignal.timeout(10000),
    });
    if (!response.ok) return send(res, 401, { error: `Discord rejected the token (HTTP ${response.status})` });

    const info = await response.json();
    if (!info.application || String(info.application.id) !== expectedApp) {
      return send(res, 403, { error: "token is for another Discord application (check DISCORD_CLIENT_ID on Vercel)" });
    }
    const user = info.user;
    if (!user || !user.id) return send(res, 401, { error: "no Discord user" });

    const uid = `discord_${user.id}`;
    const name = String(user.global_name || user.username || "Player").slice(0, 30);
    let account;
    try {
      account = getServiceAccount();
    } catch (configError) {
      console.error("Discord sign-in config error:", configError.message);
      return send(res, 500, { error: `server setup problem: ${configError.message}` });
    }
    const token = createFirebaseCustomToken(account, uid);
    return send(res, 200, { token, name, uid });
  } catch (error) {
    // Never log OAuth access tokens or the service-account key.
    console.error("Discord sign-in failed:", error.message);
    return send(res, 500, { error: `server error: ${String(error.message || error).slice(0, 120)}` });
  }
};
