# الاستخراج التلقائي من GitHub

الملف: `.github/workflows/build.yml` — لازم يكون في أول الريبو (جنب فولدر RoofGroove).

## التشغيل
- اعمل tag: `git tag v1.1.2 && git push --tags` ← يبني كل المنصات ويعمل Release فيه الملفات.
- أو من GitHub: تبويب Actions > Build RoofGroove > Run workflow (الملفات بتتحمّل من Artifacts).

## اللي بيطلع
| المنصة | الملف | ملاحظة |
|---|---|---|
| Windows | zip فيه RoofGroove.exe | الأيقونة بتتحط بـ rcedit + wine |
| Linux | zip فيه RoofGroove.x86_64 | |
| macOS | zip فيه RoofGroove.app (universal) | غير موقّع؛ على الماك: كليك يمين > Open |
| Android | APK | Release لو حطيت الـ Secrets، وإلا Debug |
| iOS | zip فيه مشروع Xcode | محتاج APPLE_TEAM_ID، وبعدها تبني IPA من Xcode |

## الـ Secrets (Settings > Secrets and variables > Actions)
- `ANDROID_KEYSTORE_BASE64` : ملف الـ keystore متحوّل base64 (`base64 -w0 release.keystore`)
- `ANDROID_KEY_ALIAS` و `ANDROID_KEYSTORE_PASSWORD`
- `APPLE_TEAM_ID` : للـ iOS بس (حساب Apple Developer)

## قبل أول تشغيل
- `GODOT_VERSION` و `PROJECT_DIR` فوق في build.yml.
- لو رفعت مشروع Godot لوحده من غير الفولدرات التانية خلي `PROJECT_DIR: "."`.
- إضافة الإشعارات (ملفات `.aar`) لازم تتحط في `addons/NotificationSchedulerPlugin/bin` وتترفع على GitHub، لأن `.gitignore` مش بيستبعدها.
- لم يتم تشغيل الـ workflow فعلياً. أول تشغيل ممكن يحتاج تعديل نسخ أدوات أندرويد.
