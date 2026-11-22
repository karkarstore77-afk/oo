extends RefCounted

const API_KEY: = "AIzaSyAgMmES7FDnz10lWrYZCUDvTX8ZhjbUGmg"

const PROJECT_ID: = "roof-groove"

const GOOGLE_CLIENT_ID: = "830392345927-0sm273r42cvbekh6s0n6ceq6g4lufadj.apps.googleusercontent.com"
const GOOGLE_CLIENT_SECRET: = "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"
# ---- Google sign in that returns to the game by itself (recommended) --------------------------
# Google Cloud Console > APIs & Services > Credentials > Create credentials > OAuth client ID
# > Application type "Desktop app" (same Google Cloud project as Firebase). Paste its values here.
# While these two are empty, the game falls back to the old "enter the code on google.com/device" flow.
const GOOGLE_DESKTOP_CLIENT_ID: = "830392345927-2p08q95m053g8tbipjmi8b1m76bbam7f.apps.googleusercontent.com"
const GOOGLE_DESKTOP_CLIENT_SECRET: = "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"
# ---- Discord sign in ----------------------------------------------------------------------------
# discord.com/developers/applications > your app > OAuth2: copy the Client ID, turn on "Public Client",
# and add these Redirects:  http://127.0.0.1:53682/callback  ..53683  ..53684  ..53685
# DISCORD_LOGIN_URL is the URL of the Vercel function in vercel_discord_auth/ (see its README_AR.md).
const DISCORD_CLIENT_ID: = "1572027686455349371"
const DISCORD_LOGIN_URL: = "https://roofgroove-discord-auth.vercel.app/api/discordLogin"
