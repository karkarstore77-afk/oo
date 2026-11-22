// Discord -> Firebase sign in.  Deploy once:  firebase deploy --only functions
// The game sends the Discord access token; this function checks with Discord that the token really
// belongs to YOUR Discord application, then returns a Firebase custom token for that Discord user.
const { onRequest } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

admin.initializeApp();

exports.discordLogin = onRequest({ cors: true, region: "us-central1", maxInstances: 10 }, async (req, res) => {
  if (req.method !== "POST") return res.status(405).json({ error: "POST only" });
  try {
    const accessToken = String((req.body && req.body.access_token) || "");
    if (accessToken.length < 10) return res.status(400).json({ error: "missing token" });

    const me = await fetch("https://discord.com/api/oauth2/@me", {
      headers: { Authorization: "Bearer " + accessToken },
    });
    if (!me.ok) return res.status(401).json({ error: "invalid Discord token" });
    const info = await me.json();

    // the token must have been issued to OUR Discord application
    if (!info.application || String(info.application.id) !== String(process.env.DISCORD_CLIENT_ID)) {
      return res.status(403).json({ error: "token is for another application" });
    }
    const user = info.user;
    if (!user || !user.id) return res.status(401).json({ error: "no Discord user" });

    const uid = "discord_" + user.id;
    const name = String(user.global_name || user.username || "Player").slice(0, 30);
    try {
      await admin.auth().updateUser(uid, { displayName: name });
    } catch (e) {
      if (e.code === "auth/user-not-found") await admin.auth().createUser({ uid, displayName: name });
      else throw e;
    }
    const token = await admin.auth().createCustomToken(uid, { provider: "discord" });
    return res.json({ token, name });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: "server error" });
  }
});
