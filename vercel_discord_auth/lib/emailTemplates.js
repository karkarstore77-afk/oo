// Designed HTML emails for Pixel Account (verification + password reset) in Arabic, English and French.
// Pure function: buildEmail({ type, lang, link, email, baseUrl }) -> { subject, html, text }

const TEXTS = {
  en: {
    dir: "ltr",
    verify: {
      subject: "Confirm your email for Roof Groove",
      heading: "Welcome to Roof Groove!",
      body: "Tap the button below to confirm your email address and start playing.",
      button: "Confirm my email",
      note: "This link works once and expires soon. If you did not create an account, you can ignore this message.",
    },
    reset: {
      subject: "Reset your Roof Groove password",
      heading: "Forgot your password?",
      body: "We received a request to change the password for {email}. Tap the button below to choose a new one.",
      button: "Choose a new password",
      note: "If you did not ask for this, ignore this message — your password stays the same.",
    },
    fallback: "If the button does not work, tap this link instead:",
    footer: "Pixel Studio • Roof Groove",
  },
  ar: {
    dir: "rtl",
    verify: {
      subject: "أكّد إيميلك في Roof Groove",
      heading: "أهلاً بيك في Roof Groove!",
      body: "اضغط على الزرار عشان تأكد إيميلك وتبدأ تلعب.",
      button: "تأكيد الإيميل",
      note: "الرابط بيشتغل مرة واحدة وبيخلص بعد وقت قصير. لو ما عملتش حساب تجاهل الرسالة دي.",
    },
    reset: {
      subject: "استعادة كلمة السر في Roof Groove",
      heading: "نسيت كلمة السر؟",
      body: "وصلنا طلب لتغيير كلمة السر للحساب {email}. اضغط على الزرار عشان تختار كلمة سر جديدة.",
      button: "اختيار كلمة سر جديدة",
      note: "لو ما طلبتش ده تجاهل الرسالة وكلمة السر هتفضل زي ما هي.",
    },
    fallback: "لو الزرار ما اشتغلش اضغط على الرابط ده:",
    footer: "Pixel Studio • Roof Groove",
  },
  fr: {
    dir: "ltr",
    verify: {
      subject: "Confirme ton e-mail pour Roof Groove",
      heading: "Bienvenue dans Roof Groove !",
      body: "Clique sur le bouton ci-dessous pour confirmer ton adresse e-mail et commencer à jouer.",
      button: "Confirmer mon e-mail",
      note: "Ce lien ne fonctionne qu'une fois et expire bientôt. Si tu n'as pas créé de compte, ignore ce message.",
    },
    reset: {
      subject: "Réinitialise ton mot de passe Roof Groove",
      heading: "Mot de passe oublié ?",
      body: "Nous avons reçu une demande de changement de mot de passe pour {email}. Clique sur le bouton ci-dessous pour en choisir un nouveau.",
      button: "Choisir un nouveau mot de passe",
      note: "Si tu n'es pas à l'origine de cette demande, ignore ce message : ton mot de passe ne change pas.",
    },
    fallback: "Si le bouton ne fonctionne pas, clique sur ce lien :",
    footer: "Pixel Studio • Roof Groove",
  },
};

function esc(value) {
  return String(value).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
}

function normalizeLang(lang) {
  const code = String(lang || "en").slice(0, 2).toLowerCase();
  return TEXTS[code] ? code : "en";
}

function buildEmail({ type, lang, link, email, baseUrl }) {
  const code = normalizeLang(lang);
  const L = TEXTS[code];
  const T = type === "reset" ? L.reset : L.verify;
  const base = String(baseUrl || "").replace(/\/$/, "");
  const align = "center";
  const body = esc(T.body).replace("{email}", `<span dir="ltr" style="color:#ffd666;">${esc(email || "")}</span>`);
  const font = "Tahoma, 'Segoe UI', Arial, sans-serif";
  // Show a short, tidy address instead of the very long one-time link (the href still holds the full link).
  let shortLink = String(link);
  try { const u = new URL(link); shortLink = u.host + u.pathname.replace(/\/$/, "") + "/…"; } catch (_) {}
  const preheader = esc(T.heading);

  const html = `<!DOCTYPE html>
<html lang="${code}" dir="${L.dir}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="dark">
<title>${esc(T.subject)}</title>
</head>
<body style="margin:0;padding:0;background:#0b0719;" bgcolor="#0b0719">
<div style="display:none;max-height:0;overflow:hidden;opacity:0;font-size:1px;line-height:1px;color:#0b0719;">${preheader}</div>
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background:#0b0719;">
 <tr><td align="center" style="padding:28px 12px;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="max-width:520px;">
   <tr><td align="center" style="padding:0 0 18px;">
     <img src="${base}/studio-logo.png" width="170" alt="Pixel Studio" style="display:block;border:0;outline:none;height:auto;">
   </td></tr>
   <tr><td style="background:#130d29;border:2px solid #6b4bb0;border-radius:16px;padding:30px 26px;font-family:${font};text-align:${align};" dir="${L.dir}">
     <div style="text-align:center;padding:0 0 18px;">
       <img src="${base}/title.png" width="230" alt="Roof Groove" style="border:0;outline:none;height:auto;">
     </div>
     <h1 style="margin:0 0 12px;font-size:22px;line-height:1.5;color:#ffd666;font-family:${font};text-align:center;">${esc(T.heading)}</h1>
     <p style="margin:0 0 24px;font-size:15px;line-height:1.9;color:#d9d2f0;font-family:${font};text-align:center;">${body}</p>
     <table role="presentation" align="center" cellspacing="0" cellpadding="0" border="0" style="margin:0 auto 24px;">
       <tr><td align="center" bgcolor="#ffb83d" style="border-radius:12px;border-bottom:4px solid #8a5a10;">
         <a href="${esc(link)}" target="_blank" style="display:inline-block;padding:15px 34px;font-family:${font};font-size:17px;font-weight:bold;color:#2a1442;text-decoration:none;border-radius:12px;">${esc(T.button)}</a>
       </td></tr>
     </table>
     <p style="margin:0 0 14px;font-size:12px;line-height:1.8;color:#9d93c4;font-family:${font};text-align:center;">${esc(T.note)}</p>
     <p style="margin:0;font-size:11px;line-height:1.7;color:#7d72a8;font-family:${font};text-align:center;">${esc(L.fallback)}<br><a href="${esc(link)}" target="_blank" style="color:#ffd666;" dir="ltr">${esc(shortLink)}</a></p>
   </td></tr>
   <tr><td align="center" style="padding:18px 0 0;font-family:${font};font-size:11px;color:#7d72a8;">${esc(L.footer)}</td></tr>
  </table>
 </td></tr>
</table>
</body>
</html>`;

  const text = [T.heading, "", T.body.replace("{email}", email || ""), "", link, "", T.note, "", L.footer].join("\n");
  return { subject: T.subject, html, text };
}

module.exports = { buildEmail, normalizeLang };
