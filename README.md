# ClipAlt

An open-source, on-device clipboard manager for iPhone/iPad (iOS 16+), built as a free alternative to Paste.
Text, links and images are saved locally — no account, no sync, no tracking.

**بديل مجاني ومفتوح المصدر لتطبيق Paste** يحفظ سجل النسخ (نصوص وروابط وصور) على جهازك فقط، بدون حساب ولا مزامنة.

---

## Features / المميزات

- Clipboard history for text, URLs and images / سجل للنصوص والروابط والصور
- Saves the clipboard automatically when you open the app (can be turned off) / يحفظ المنسوخ تلقائيًا لما تفتح التطبيق
- Paste button that saves without the iOS “Allow Paste” prompt / زر لصق يحفظ بدون رسالة السماح
- Search, pin, delete, share, tap to copy / بحث وتثبيت وحذف ومشاركة، واضغط للنسخ
- Custom keyboard: shows recent clips and types them on tap / كيبورد يعرض آخر القصاصات ويكتبها بضغطة
- **Optional background capture** (off by default) — keeps saving what you copy while ClipAlt is in the background / **حفظ بالخلفية اختياري** (مقفل افتراضيًا)
- Battery-friendly by default: nothing runs in the background unless you turn on background capture / ما يشتغل بالخلفية إلا إذا فعّلت الحفظ بالخلفية

## Install with Signulous / التثبيت عن طريق Signulous

1. Open the latest **Release** of this repo (or the latest *Build unsigned IPA* run → artifact `ClipAlt-unsigned-ipa`) and download `ClipAlt.ipa`.
   افتح آخر **Release** في المستودع ونزّل `ClipAlt.ipa` (أو من آخر تشغيل في Actions، الملف `ClipAlt-unsigned-ipa`).
2. In Signulous, go to **Upload App / My Apps**, upload `ClipAlt.ipa`, then tap **Sign** and **Install**.
   في Signulous ارفع الملف من **Upload App**، وبعدها **Sign** ثم **Install**.
3. If asked, keep the app extensions (the keyboard) and App Groups enabled.
   إذا سألك، خلّ الإضافات (الكيبورد) و App Groups مفعّلة.

## Enable the keyboard / تفعيل الكيبورد

1. **Settings › General › Keyboard › Keyboards › Add New Keyboard… › ClipAlt**
   **الإعدادات › عام › لوحة المفاتيح › لوحات المفاتيح › إضافة لوحة مفاتيح جديدة › ClipAlt**
2. Tap **ClipAlt** and turn on **Allow Full Access** (required so the keyboard can read the clips saved by the app).
   اضغط **ClipAlt** وفعّل **السماح بالوصول الكامل** (لازم عشان الكيبورد يقرأ القصاصات).
3. In any text field, long-press 🌐 and choose **ClipAlt**. Tap a clip to type it. Tap **Save clipboard** to add what you just copied.
   في أي خانة كتابة اضغط مطولًا على 🌐 واختر **ClipAlt**، واضغط على القصاصة عشان تنكتب. وزر **Save clipboard** يحفظ آخر شي نسخته.

To stop the “Allow Paste” prompt / لإيقاف رسالة «السماح باللصق»:
**Settings › ClipAlt › Paste from Other Apps › Allow** — **الإعدادات › ClipAlt › اللصق من التطبيقات الأخرى › السماح**

## Background capture / الحفظ بالخلفية

iOS normally doesn't let apps run (or read the clipboard) in the background. Like Riley Testut's *Clip*, ClipAlt can
keep itself alive with a low-accuracy location session (≈3 km, never stored or sent) and check
`UIPasteboard.changeCount` every ~1.5 s. It only reads the clipboard when the counter changes.

iOS عادةً ما يخلّي التطبيقات تشتغل بالخلفية. مثل تطبيق *Clip*، يقدر ClipAlt يظل شغال عن طريق جلسة موقع بدقة منخفضة جدًا
(تقريبًا ٣ كم، وما ينحفظ الموقع ولا ينرسل)، ويشيك على المنسوخ كل ثانية ونص تقريبًا، ويقرأه بس إذا تغيّر.

**Turn it on / التفعيل**
1. ClipAlt › ⚙︎ Settings › **Background capture** → On. Allow location when asked.
   افتح ClipAlt › الإعدادات › **الحفظ بالخلفية** وفعّله، ووافق على طلب الموقع.
2. iPhone Settings › ClipAlt › **Location › Always** (and turn **Precise Location** off).
   إعدادات الآيفون › ClipAlt › **الموقع › دائمًا** (وطفّي **الموقع الدقيق**).
3. iPhone Settings › ClipAlt › **Paste from Other Apps › Allow**.
   إعدادات الآيفون › ClipAlt › **اللصق من التطبيقات الأخرى › السماح**.
4. Open ClipAlt once after each restart of the phone (or after force-closing it), then you can leave it in the background.
   افتح التطبيق مرة بعد كل إعادة تشغيل للجوال أو بعد ما تقفله من قائمة التطبيقات، وبعدها خلّه بالخلفية.

The Settings screen shows the location permission and whether background capture is running.
شاشة الإعدادات توضح حالة إذن الموقع وهل الحفظ بالخلفية شغال.

**Limitations / القيود**
- ⚠️ Uses noticeably more battery. / يستهلك بطارية أكثر بشكل واضح.
- Stops if you swipe ClipAlt away, after a reboot, in Low Power Mode, or if iOS decides to suspend it. Open the app again to resume.
  يوقف إذا سكّرت التطبيق من قائمة التطبيقات، أو بعد إعادة التشغيل، أو بوضع توفير الطاقة، أو إذا iOS قرر يوقفه. افتح التطبيق ويرجع يشتغل.
- iOS may still show the “Allow Paste” prompt, or block clipboard reads in the background on some iOS versions. Setting *Paste from Other Apps* to *Allow* is required.
  iOS ممكن يظهر رسالة «السماح باللصق» أو يمنع قراءة المنسوخ بالخلفية في بعض الإصدارات، فلازم تخلي *اللصق من التطبيقات الأخرى* على *السماح*.
- With “While Using” instead of “Always”, iOS shows a blue location indicator while it runs in the background.
  إذا الموقع على «أثناء الاستخدام» بدل «دائمًا»، يظهر مؤشر الموقع الأزرق وهو بالخلفية.
- The re-signing service (Signulous) must keep the app's background modes (`UIBackgroundModes = location`). If it strips them, Settings shows a red warning and background capture won't run.
  لازم Signulous يحافظ على أوضاع الخلفية في التطبيق، وإذا حذفها تظهر ملاحظة حمراء في الإعدادات وما يشتغل الحفظ بالخلفية.
- This technique is not allowed on the App Store; it's meant for personal sideloaded installs.
  هالطريقة ما تقبلها App Store، وهي للتثبيت الشخصي بس.

## Limitations / القيود

- Without background capture, ClipAlt saves when you open it, when you tap Paste, or from the keyboard's *Save clipboard* button.
  بدون الحفظ بالخلفية، الحفظ يصير لما تفتح التطبيق أو من زر اللصق أو من الكيبورد.
- Keyboards can only type text. Tapping an image clip in the keyboard copies it so you can paste it.
  الكيبورد يكتب نصوص بس، والصور تنسخ عشان تلصقها.
- Keyboards are not available in password fields and some secure apps (iOS rule).
- If the re-signing service drops the App Group, the app and the keyboard keep separate histories (Settings in the app shows “Shared with keyboard: No”).

## Build it yourself / البناء

No Mac needed: every push to `main` runs **.github/workflows/build.yml** on a GitHub macOS runner, which
installs XcodeGen, generates the Xcode project from `project.yml`, builds without code signing, and packages
`Payload/ClipAlt.app` (with `PlugIns/ClipAltKeyboard.appex`) into `ClipAlt.ipa`. You can also run it manually from
**Actions › Build unsigned IPA › Run workflow**.

On a Mac: `brew install xcodegen && swift scripts/make_icon.swift ClipAlt/Assets.xcassets/AppIcon.appiconset/icon.png && xcodegen generate && open ClipAlt.xcodeproj`

| | |
|---|---|
| App bundle id | `com.bandar9994.clipalt` |
| Keyboard bundle id | `com.bandar9994.clipalt.keyboard` |
| App Group | `group.com.bandar9994.clipalt` |

License: MIT
