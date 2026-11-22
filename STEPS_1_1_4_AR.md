# خطوات تشغيل RoofGroove 1.1.4 (الأونلاين وكل حاجة)

## 1) جرّب المشروع في Godot
افتح مجلد `RoofGroove` في Godot 4.7 وشغّل اللعبة. لو ظهر أي خطأ أحمر في تبويب Output ابعتلي نصه.

## 2) Firebase (من المتصفح، مش محتاج سكربت ولا gcloud)
1. Firestore Database ثم Rules: الصق محتوى `FIRESTORE_1_1_4_RULES.txt` واضغط Publish.
2. الجواهر: في `players/<uid>` ضيف حقل `gems` (number).
3. رسائل البريد: كولكشن `inbox_messages` (تفاصيله في `INBOX_AND_IDS_AR.md`).
4. رابط الـ relay (الخطوة 3): كولكشن `config` ثم مستند `relay` وحقل `url`.

## 3) سيرفر الـ Relay المجاني (يخلّي الأونلاين يشتغل من أي راوتر وأي دولة)
1. ثبّت Node.js LTS من nodejs.org، واعمل حساب مجاني على Cloudflare بالإيميل.
2. افتح PowerShell جوه مجلد `relay_cloudflare` ونفّذ:
   `npx wrangler login` ثم `npx wrangler deploy`
3. هتاخد رابط `https://roofgroove-relay.اسمك.workers.dev`. افتحه على `/health` والمفروض يرد `ok`.
4. في Firebase: `config/relay` ثم `url` = `wss://roofgroove-relay.اسمك.workers.dev` (`wss` مش `https`).
5. لو كان عندك خدمة Render امسحها.

## 4) ابنِ الإصدار من GitHub
رقم الإصدار اتغيّر لـ 1.1.4 (Android كود 15). من مجلد المشروع:
```
git add .
git commit -m "RoofGroove 1.1.4"
git tag v1.1.4
git push origin main --tags
```
بعد ما يخلص Actions نزّل ملفات Windows وAndroid من Artifacts أو Releases.
لازم البناء يتم من GitHub (مش تصدير محلي)، لأن ملف بصمات الملفات بيتولّد هناك بس.

## 5) نشر التحديث للاعبين
اللعبة بتشوف التحديث من مستند `app/latest` في Firestore. **بعد ما ترفع الملفات وتجهّز روابط التحميل** غيّر فيه:
`version` = `1.1.4`، و`notes` بالتغييرات، و`url_windows` و`url_android` بروابط التحميل.
ما تغيّرش `version` قبل ما الروابط تكون جاهزة، وإلا اللاعبين هيشوفوا تحديث مالوش تحميل.

## 6) جرّب الأونلاين فعلياً
1. جهاز أول (Wi-Fi) يعمل غرفة أونلاين ويطلع الكود.
2. جهاز تاني على داتا الموبايل أو شبكة تانية يدخل بالكود.
3. لو الاتصال المباشر فشل هتظهر رسالة "Connecting through the relay server" وتدخل بعدها.
4. لو ما دخلش: اتأكد من `/health`، ومن `config/relay`، ومن نشر القواعد.

## 7) حاجات تانية مهمة
- لو كراش أندرويد لسه بيحصل: شغّل `adb logcat -s godot AndroidRuntime DEBUG` وابعتلي الناتج.
- دوّر الـ Google client secret من Google Cloud Console لو المستودع اتشارك قبل كده.
- حدود Cloudflare المجانية تقريبية (حوالي 6 إلى 7 ساعات يومياً لغرفة 4 لاعبين). لو الحد خلص اللعبة بتكمّل بالاتصال المباشر.
- فحص ملفات الكود اتعمل قراءة ثابتة بس (مفيش Godot هنا)، فالتجربة الفعلية في الخطوة 1 و6 هي اللي بتأكد.
