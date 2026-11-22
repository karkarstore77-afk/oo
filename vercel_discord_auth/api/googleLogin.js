// Exchanges a Google OAuth "authorization code" for an id_token on the server, so the Google
// client secret never has to live inside the game. Set these on Vercel (Settings > Environment Variables):
//   GOOGLE_DESKTOP_CLIENT_ID      the Desktop-app OAuth client ID (same one as in firebase_config.gd)
//   GOOGLE_DESKTOP_CLIENT_SECRET  its secret
function send(res, status, body) {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");
  res.setHeader("Cache-Control", "no-store");
  return res.status(status).json(body);
}

module.exports = async function googleLogin(req, res) {
  if (req.method === "OPTIONS") return send(res, 204, {});
  if (req.method !== "POST") return send(res, 405, { error: "POST only" });

  let body = req.body;
  if (typeof body === "string") {
    try { body = JSON.parse(body); } catch (_) { body = {}; }
  }
  body = body || {};
  const code = typeof body.code === "string" ? body.code : "";
  const verifier = typeof body.code_verifier === "string" ? body.code_verifier : "";
  const redirectUri = typeof body.redirect_uri === "string" ? body.redirect_uri : "";
  if (code.length < 10 || code.length > 4096 || verifier.length < 20 || verifier.length > 256) {
    return send(res, 400, { error: "missing or invalid code" });
  }
  // Only the game's own loopback redirect is allowed.
  if (!/^http:\/\/127\.0\.0\.1:\d{2,5}\/callback$/.test(redirectUri)) {
    return send(res, 400, { error: "invalid redirect_uri" });
  }
  const clientId = String(process.env.GOOGLE_DESKTOP_CLIENT_ID || "").trim();
  const clientSecret = String(process.env.GOOGLE_DESKTOP_CLIENT_SECRET || "").trim();
  if (!clientId || !clientSecret) {
    return send(res, 500, { error: "server setup problem: GOOGLE_DESKTOP_CLIENT_ID / GOOGLE_DESKTOP_CLIENT_SECRET are missing on Vercel" });
  }

  try {
    const response = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        client_id: clientId,
        client_secret: clientSecret,
        code,
        code_verifier: verifier,
        redirect_uri: redirectUri,
        grant_type: "authorization_code",
      }),
      signal: AbortSignal.timeout(10000),
    });
    const data = await response.json().catch(() => ({}));
    if (!response.ok || typeof data.id_token !== "string") {
      const why = data.error_description || data.error || `HTTP ${response.status}`;
      return send(res, 401, { error: `Google rejected the sign in: ${String(why).slice(0, 120)}` });
    }
    // Only the id_token goes back to the game (never the access or refresh token).
    return send(res, 200, { id_token: data.id_token });
  } catch (error) {
    console.error("Google sign-in failed:", error.message);
    return send(res, 500, { error: `server error: ${String(error.message || error).slice(0, 120)}` });
  }
};
