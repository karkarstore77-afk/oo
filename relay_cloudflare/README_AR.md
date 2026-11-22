# Relay مجاني على Cloudflare (بديل Render — من غير بطاقة ومن غير نوم)

بيشتغل على Cloudflare Workers + Durable Objects في الخطة المجانية. البروتوكول نفس `relay_server/server.py`
فمفيش أي تغيير في اللعبة غير رابط الـ `url`.

## الخطوات (ويندوز)
1. ثبّت Node.js (النسخة LTS) من https://nodejs.org ثم اقفل PowerShell وافتحه من جديد.
2. اعمل حساب مجاني على https://dash.cloudflare.com/sign-up (بالإيميل، مش لازم بطاقة).
3. افتح PowerShell جوه مجلد `relay_cloudflare` ونفّذ:
   ```
   npx wrangler login
   npx wrangler deploy
   ```
   الأمر الأول بيفتح المتصفح عشان تسمح. الأمر التاني بيرفع السيرفر ويطلعلك رابط زي
   `https://roofgroove-relay.اسمك.workers.dev`.
4. افتح `https://roofgroove-relay.اسمك.workers.dev/health` والمفروض يرد `ok`.
5. في Firebase: كولكشن `config` ثم مستند `relay` وحقل `url` (string) قيمته
   `wss://roofgroove-relay.اسمك.workers.dev` (لاحظ `wss://` بدل `https://`).
   لو كنت حاطط رابط Render قبل كده، بدّله بالرابط الجديد. وامسح خدمة Render عشان ما تتحاسبش.

## حدود الخطة المجانية
Cloudflare بتحسب كل 20 رسالة WebSocket كطلب واحد، والحد 100,000 طلب في اليوم. ده تقريباً يكفي
حوالي 6 إلى 7 ساعات يومياً من غرفة فيها 4 لاعبين (الأرقام تقديرية). لو الحد خلص السيرفر بيرفض لحد اليوم التالي،
واللعبة بتفضل تشتغل بالاتصال المباشر.
