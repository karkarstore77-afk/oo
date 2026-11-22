# سيرفر Relay للأونلاين (يخلّي اللعب يشتغل من أي راوتر وأي دولة)

> **الأسهل والمجاني فعلاً:** استخدم `relay_cloudflare/` (Cloudflare Workers) بدل Render. الملف ده لمن يفضّل استضافة تانية.

السيرفر ده بيمرّر حزم اللعبة بين اللاعبين. كل لاعب (والمضيف) بيتصل **للخارج** بس، فمفيش Port Forwarding
ولا UPnP ولا مشكلة CGNAT. السيرفر مش بيقرأ بيانات اللعبة.

## تشغيله مجاناً على Render
1. ارفع مجلد `relay_server` على مستودع GitHub (ممكن نفس مستودع اللعبة).
2. على render.com: New + ثم Web Service، واختار المستودع.
3. Root Directory: `relay_server` — Runtime: `Docker` (فيه Dockerfile جاهز) — Plan: Free.
4. بعد ما يخلص النشر هتاخد رابط زي `https://roofgroove-relay.onrender.com`.
   افتح `https://.../health` والمفروض يرد `ok`.

> الخطة المجانية بتنام بعد 15 دقيقة من غير استخدام، والاتصال الأول بعدها ممكن ياخد حوالي دقيقة.
> اللعبة بتصحّي السيرفر تلقائياً أول ما تدخل أو تفتح غرفة، وبتحاول تتصل لحد 75 ثانية.

## ربطه باللعبة (من غير ما تبني اللعبة تاني)
1. Firebase Console ثم Firestore ثم `Start collection` باسم `config`.
2. Document ID: `relay`، وضيف حقل `url` نوعه string وقيمته `wss://roofgroove-relay.onrender.com`
   (لاحظ `wss://` بدل `https://`).
3. انشر `FIRESTORE_1_1_4_RULES.txt` من جديد (فيه قاعدة قراءة `config`).

بدل Render ممكن أي استضافة بتدعم WebSocket (Fly.io، Railway، VPS، ...):
`pip install -r requirements.txt && PORT=8080 python server.py`

## طريقة الشغل
- اللعبة بتجرّب الاتصال المباشر الأول (أسرع)، ولو فشل بتحوّل تلقائياً على السيرفر.
- لو مفيش رابط في `config/relay` اللعبة بتشتغل زي الأول (مباشر فقط).
