# تسجيل Discord على Firebase Spark باستخدام Vercel

الخدمة دي بديل لـ Firebase Cloud Functions؛ لا تنشر `firebase_functions` على Spark. خدمة Vercel المجانية Hobby مخصصة للمشاريع الشخصية غير التجارية، ولها حدود استخدام شهرية.

## 1. انشر الـ API

المشروع اتعمل بالفعل على Vercel واتربط بالمجلد المحلي. لو بتبدأ على جهاز جديد، شغّل `vercel login` ثم `vercel link` واختار المشروع الموجود `roofgroove-discord-auth`. لو Vercel سأل عن إنشاء مشروع جديد، اختار الموجود بدل إنشاء واحد إضافي. استخدم Node.js 26 كما يتطلب إصدار Vercel الحالي.

```powershell
npm install
```

في إعدادات مشروع Vercel > **Settings > Environment Variables** أضف:

- `DISCORD_CLIENT_ID`: رقم تطبيق Discord نفسه الموجود في `RoofGroove/scripts/firebase_config.gd`.
- `FIREBASE_SERVICE_ACCOUNT`: محتوى ملف مفتاح خدمة Firebase بصيغة JSON. الخادم يستخدم مفتاح RSA لبناء Firebase custom token ولا يحتاج مكتبة Firebase Admin.

أنشئ مفتاح الخدمة من Firebase Console > Project settings > Service accounts > Generate new private key. ألصق محتواه مباشرة في متغير Vercel السري. لا تضع المفتاح داخل مجلد اللعبة أو GitHub أو ترسله في المحادثة. المفتاح يستطيع توقيع رموز Firebase للمشروع؛ احتفظ به سرًا واحذفه/دوّره إذا انكشف.

استخدم مشروع Firebase `roof-groove` عند إعداد مفتاح الخدمة، ثم انشر نسخة Production من Vercel:

```powershell
vercel --prod
```

عنوان الـ API سيكون بالشكل التالي:

```text
https://اسم-مشروعك.vercel.app/api/discordLogin
```

## 2. اربط اللعبة بالـ API

افتح `RoofGroove/scripts/firebase_config.gd`، وتأكد أن `DISCORD_LOGIN_URL` يساوي عنوان الـ API الفعلي من Vercel. الرابط المضبوط حاليًا هو `https://roofgroove-discord-auth.vercel.app/api/discordLogin`. اترك `DISCORD_CLIENT_ID` مطابقًا للتطبيق نفسه.

في Discord Developer Portal > OAuth2 فعّل **Public Client**، وأضف روابط التحويل التالية كما هي:

```text
http://127.0.0.1:53682/callback
http://127.0.0.1:53683/callback
http://127.0.0.1:53684/callback
http://127.0.0.1:53685/callback
```

بعدها افتح اللعبة في Godot وسجّل الدخول من زر Discord.

## ملاحظات

- لا حاجة لترقية Firebase أو نشر Cloud Function. `firebase_functions` وملف `.env` فيها لا يستخدمهما هذا المسار.
- لا حاجة لتفعيل Billing على Firebase لتسجيل الدخول المخصص؛ Firebase Auth يستقبل الرمز المخصص الصادر من الخادم.
- أول تسجيل دخول قد يرجع خطأ صلاحية توقيع. راجع رسالة الخطأ في سجلات Vercel وتأكد أن مفتاح الخدمة يعود لمشروع `roof-groove` وأن Firebase Authentication مفعّل.
- لا تضع ملف المفتاح أو قيمته في `vercel_discord_auth`، أو داخل ZIP بعد إدخالها، أو في GitHub.

## تسجيل Google عن طريق نفس السيرفر (اختياري)

الملف `api/googleLogin.js` بيبدّل كود Google بـ id_token على السيرفر، فالسر مبيبقاش داخل اللعبة. أضف في Vercel > Environment Variables:

- `GOOGLE_DESKTOP_CLIENT_ID`
- `GOOGLE_DESKTOP_CLIENT_SECRET`

وحط نفس الـ Client ID في `GOOGLE_DESKTOP_CLIENT_ID` داخل `RoofGroove/scripts/firebase_config.gd` (اترك السر هناك `PUT_...`). بعدين `vercel --prod`.

## لو Discord لسه فيه مشكلة

الرسالة في اللعبة دلوقتي بتقول السبب. الشائع:

- `invalid_client` ← فعّل **Public Client** في Discord Developer Portal > OAuth2.
- رسالة فيها `redirect` ← ضيف الأربع روابط `http://127.0.0.1:5368x/callback` في Redirects.
- `server setup problem` ← `FIREBASE_SERVICE_ACCOUNT` ناقص أو لمشروع غير `roof-groove`.
- `another Discord application` ← `DISCORD_CLIENT_ID` على Vercel غلط.
