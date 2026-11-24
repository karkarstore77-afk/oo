# إيميلات Pixel Account وصفحة التعديل

## 1) صفحة التعديل بتاعتنا (بدل صفحة Firebase الافتراضية)
الملف `vercel_discord_auth/public/account.html` هو صفحة بشكل اللعبة (ألوان وخط ونجوم وعنوان اللعبة)، بتفتح من الرابط اللي في الإيميل وبتعمل حاجتين:
- **تأكيد الإيميل:** بتأكده وتقول للاعب يرجع للعبة.
- **استعادة كلمة السر:** بتفتح له خانتين لكلمة السر الجديدة وتحفظها.
وفيها أزرار لغة (عربي / English / Français)، وبتفتح باللغة اللي اتبعت بيها الإيميل.

**التفعيل (مرة واحدة):**
1. من داخل مجلد `vercel_discord_auth` شغّل `vercel --prod` (نفس طريقة Discord). بعدها الصفحة هتبقى على: `https://roofgroove-discord-auth.vercel.app/account.html`
2. Firebase Console > **Authentication** > **Templates** > اضغط القلم على أي قالب > **Customize action URL**، وحط الرابط اللي فوق، واحفظ. ده بيطبّق على كل القوالب.
3. جرّب: اعمل حساب بإيميل حقيقي، افتح الرابط من الإيميل وشوف الصفحة.

## 2) نص الإيميلات
من **Authentication > Templates** اختار **Email address verification** ثم **Password reset**. فوق على اليمين فيه قايمة **اللغة**: اختار كل لغة وعدّل نصها لوحدها (اللعبة بتبعت لـ Firebase لغة اللاعب فبيختار القالب المناسب).
- **Sender name:** `Roof Groove`
- ممكن تحط عنوان Reply-to خاص بيك.
- المتغيرات المسموحة: `%LINK%` (الرابط) و`%EMAIL%` و`%APP_NAME%` (اسم التطبيق). لازم `%LINK%` يكون موجود.

### تأكيد الإيميل (Email address verification)
**العربي** — الموضوع: `أكّد إيميلك في Roof Groove`
```
أهلاً بيك في Roof Groove!

اضغط على الرابط ده عشان تأكد إيميلك (%EMAIL%) وتبدأ تلعب:

%LINK%

لو ما عملتش حساب في اللعبة تجاهل الرسالة دي.

فريق Pixel Studio
```
**English** — Subject: `Confirm your email for Roof Groove`
```
Welcome to Roof Groove!

Tap the link below to confirm your email (%EMAIL%) and start playing:

%LINK%

If you did not create an account in the game, just ignore this message.

Pixel Studio
```
**Français** — Objet : `Confirme ton e-mail pour Roof Groove`
```
Bienvenue dans Roof Groove !

Clique sur le lien ci-dessous pour confirmer ton e-mail (%EMAIL%) et commencer à jouer :

%LINK%

Si tu n'as pas créé de compte dans le jeu, ignore ce message.

Pixel Studio
```

### استعادة كلمة السر (Password reset)
**العربي** — الموضوع: `استعادة كلمة السر في Roof Groove`
```
وصلنا طلب لتغيير كلمة السر للحساب %EMAIL%.

اضغط على الرابط ده عشان تختار كلمة سر جديدة:

%LINK%

لو ما طلبتش ده تجاهل الرسالة وكلمة السر هتفضل زي ما هي.

فريق Pixel Studio
```
**English** — Subject: `Reset your Roof Groove password`
```
We received a request to change the password of %EMAIL%.

Tap the link below to choose a new password:

%LINK%

If you did not ask for this, ignore this message and your password stays the same.

Pixel Studio
```
**Français** — Objet : `Réinitialise ton mot de passe Roof Groove`
```
Nous avons reçu une demande de changement de mot de passe pour %EMAIL%.

Clique sur le lien ci-dessous pour choisir un nouveau mot de passe :

%LINK%

Si tu n'es pas à l'origine de cette demande, ignore ce message : ton mot de passe ne change pas.

Pixel Studio
```

## 3) إيميل بتصميم اللعبة (HTML) بدل النص العادي
Firebase بيبعت نص بس، فعملنا سيرفر صغير بيبعت إيميل بتصميم اللعبة: شعار **Pixel Studio** فوق، وعنوان **Roof Groove**، وكارت بنفسجي، وزرار دهبي كبير، وبالعربي (من اليمين لليسار) والإنجليزي والفرنسي، حسب لغة اللاعب.
شوف الشكل قبل ما تفعّل أي حاجة: افتح الملفات في المتصفح من `vercel_discord_auth/email_previews/` (`verify_ar.html` و`reset_en.html` وهكذا).

**الملفات:** `vercel_discord_auth/api/sendAccountEmail.js` (السيرفر) و`vercel_discord_auth/lib/emailTemplates.js` (التصميم والنصوص، تعدّلها من هنا).

**التفعيل (مرة واحدة):**
1. اعمل حساب في **resend.com** (مجاني للبداية).
2. **Domains > Add domain**: ضيف دومين ليك وحط سجلات الـ DNS اللي بتديهالك (SPF وDKIM) واستنى لحد ما يبقى Verified. من غير دومين تقدر تبعت **لإيميلك أنت بس** (للتجربة) من `onboarding@resend.dev`.
3. **API Keys > Create API Key** وانسخ المفتاح.
4. في Vercel > المشروع > **Settings > Environment Variables** ضيف:
   - `RESEND_API_KEY` = المفتاح
   - `MAIL_FROM` = `Roof Groove <noreply@دومينك.com>`
   (و`FIREBASE_SERVICE_ACCOUNT` موجود من قبل عشان Discord.)
5. شغّل `vercel --prod` من داخل `vercel_discord_auth`.
6. جرّب: اعمل حساب جديد. الإيميل المفروض يوصل بالتصميم الجديد، والرابط بيفتح صفحة `account.html`.

**مهم:**
- لو أي حاجة من اللي فوق ناقصة، السيرفر بيرد بخطأ واللعبة **بترجع تلقائياً لإيميل Firebase العادي**. يعني مفيش حاجة هتوقف.
- السيرفر بيبعت إيميل واحد لكل عنوان كل دقيقة (حماية من الإزعاج)، وبيرد "تمام" حتى لو الإيميل مالوش حساب في استعادة كلمة السر (عشان محدش يعرف مين مسجل).
- ما جرّبتش الإرسال الفعلي لأن مفيش نت ولا مفتاح عندي. التصميم اتفحص في المتصفح بس، والسيرفر اتفحص syntax بس.

## ملاحظات
- الإيميلات بتوصل من العنوان اللي في `MAIL_FROM`. لو الدومين لسه جديد ممكن تروح Spam في الأول.
- بدون سيرفر الإيميل (القسم 3) الإيميلات بتفضل نص Firebase العادي بالنصوص اللي في القسم 2.

## 4) إرسال مجاني من غير دومين (Brevo) — جديد
Resend مش بيبعت لأي حد غير إيميلك إلا لو عندك دومين. عشان كده السيرفر بقى يدعم **Brevo** كمان (مجاني، لحد 300 إيميل في اليوم، من غير دومين):
1. اعمل حساب في **brevo.com**.
2. **Senders & IP > Senders > Add a sender**: حط إيميلك (مثلاً Gmail) وأكّده من الرسالة اللي توصلك.
3. **SMTP & API > API Keys > Generate a new API key** وانسخه.
4. في Vercel > Settings > Environment Variables ضيف:
   - `BREVO_API_KEY` = المفتاح
   - `MAIL_FROM` = `Roof Groove <إيميلك-المؤكد@gmail.com>`
5. شغّل `vercel --prod` من داخل `vercel_discord_auth`.
لو `BREVO_API_KEY` موجود السيرفر بيستخدمه، وإلا بيرجع لـ Resend. الإيميل ممكن يروح Spam في الأول لأن المرسل Gmail؛ اطلب من اللاعبين يدوّروا في Spam.
**ما اتجرّبش فعلياً** (مفيش نت هنا).

## 5) اللي اتعدل في شكل الإيميل
- كل النص في النص (سنتر) بالعربي والإنجليزي والفرنسي.
- الرابط الطويل (oobCode) ما بقاش ظاهر كله؛ بيظهر مختصر والضغط عليه بيفتح الرابط الكامل.
- سطر معاينة مخفي (Preheader) بيظهر جنب العنوان في صندوق الوارد.
