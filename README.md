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
- Save from anywhere with a Shortcut, Back Tap, the Action Button or Siri / احفظ من أي مكان بالاختصارات أو النقر على الظهر أو زر الإجراء
- Share extension: Share › ClipAlt saves text, links and images / إضافة مشاركة تحفظ النصوص والروابط والصور
- Capture log for troubleshooting / سجل للحفظ يساعد في حل المشاكل
- Battery-friendly: nothing runs in the background, no location use / ما يشتغل بالخلفية ولا يستخدم الموقع

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

## Save without opening the app / حفظ بدون فتح التطبيق

**Shortcuts, Back Tap & Action Button / الاختصارات والنقر على الظهر وزر الإجراء**
1. Shortcuts app › **+** › add **Get Clipboard**, then **Save Clipboard to ClipAlt**, and pass *Clipboard* as Text (or Image).
   Shortcuts reads the clipboard with its own permission, so ClipAlt shows no “Allow Paste” prompt.
   تطبيق الاختصارات › **+** › أضف **الحصول على الحافظة** ثم **Save Clipboard to ClipAlt**، ومرّر الحافظة كنص أو صورة. بهالطريقة ما تطلع رسالة السماح.
   (The action also works alone — then ClipAlt reads the clipboard itself. / ويشتغل لحاله بعد، بس ممكن تطلع رسالة السماح.)
2. **Back Tap:** Settings › Accessibility › Touch › Back Tap › Double/Triple Tap › choose the shortcut.
   **النقر على الظهر:** الإعدادات › تسهيلات الاستخدام › اللمس › النقر على الظهر › نقرتان أو ثلاث › اختر الاختصار.
3. **Action Button** (iPhone 15 Pro and later): Settings › Action Button › Shortcut › choose it.
   **زر الإجراء** (آيفون ١٥ برو وأحدث): الإعدادات › زر الإجراء › اختصار › اختره.
4. Siri: “Save clipboard in ClipAlt”.

**Share sheet / قائمة المشاركة** — in any app tap **Share › ClipAlt** to save text, links or images (up to 10) directly.
No clipboard access, so no prompt. If ClipAlt isn't listed, tap *More* / *Edit Actions* and enable it.
من أي تطبيق اضغط **مشاركة › ClipAlt** عشان تحفظ نص أو رابط أو صور. إذا ما ظهر، اضغط *المزيد* وفعّله.

**Capture log / سجل الحفظ** — ClipAlt › Settings › Diagnostics › *Capture log*: the last 200 save events (from opening
the app, Paste button, keyboard, Share and Shortcuts) with what was on the clipboard and whether it was saved, a
duplicate moved to top, or the read failed. Share it with the button at the top.
من الإعدادات › Diagnostics › *سجل الحفظ*: آخر ٢٠٠ عملية حفظ، وتقدر تشاركه.

## Limitations / القيود

- iOS doesn't let apps watch the clipboard in the background, and ClipAlt deliberately doesn't use battery-draining workarounds. It saves when you open it, tap Paste, use the keyboard's *Save clipboard*, Share › ClipAlt, or run the Shortcut (Back Tap / Action Button).
  iOS ما يسمح بمراقبة النسخ بالخلفية، وClipAlt ما يستخدم حيل تستهلك البطارية. الحفظ يصير لما تفتحه، أو من زر اللصق، أو الكيبورد، أو المشاركة، أو الاختصار.
- If you copy several things before saving, only the last one is on the clipboard — iOS keeps no history.
  إذا نسخت أكثر من شي قبل الحفظ، الأخير بس هو اللي ينحفظ.
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
