# Battery Alarm App — Setup

## What it does
A background service watches your battery and fires an alarm when:
- Battery reaches your **charge threshold** (default 80%) while charging → "Unplug"
- Battery drops to your **discharge threshold** (default 20%) while unplugged → "Plug in"

All thresholds and behaviours are adjustable in the app.

## The three things you asked for

### 1. Doesn't drain the battery (adaptive, not hourly)
A flat "once an hour" check would miss your 80% cutoff during fast charging,
so instead the app is **adaptive**:
- **While charging:** checks every 2 minutes. The phone is on wall power, so
  this costs effectively zero battery — and it reliably catches the cutoff.
- **While on battery:** checks every 15 / 30 / 60 minutes (your choice,
  default 30). Battery drops slowly, so infrequent checks are plenty.
- It also reacts instantly when you plug in or unplug (event-driven), so the
  cadence switches over immediately rather than waiting for the next tick.

Reading the battery level is a very cheap system call; the only real cost is
keeping the service alive, which is unavoidable for any reliable background
monitor.

### 2. Quiet hours (silent at night)
Toggle **Quiet hours** and set a start/end time (e.g. 22:00–07:00, wraps past
midnight). During that window the app still detects thresholds but posts a
**silent, visual-only** notification — no sound, no vibration.

### 3. Alarm sound selection (louder than a notification beep)
Pick the alarm sound under **Alarm sound**:
- **Alarm (loudest)** – your phone's own alarm tone (default)
- **Ringtone** – your phone's ringtone
- **Notification tone** – your phone's notification sound
- **Default beep** – the plain system notification beep

All choices play on the **alarm stream**, so they're **heard even when the
ringer is on silent or vibrate**, and at the alarm volume rather than the (often
quiet) notification volume. "Default beep" is the short tone older builds used —
the new default is the much louder Alarm tone. Use **Test this sound** to hear
the current choice. To use a specific tone, set it as your phone's Alarm or
Ringtone sound (Settings → Sound), then select it here.

## How to build it (from your phone)
1. Create a GitHub repo and upload this whole folder, keeping the layout:
   - `src/pubspec.yaml`
   - `src/lib/main.dart`
   - `src/lib/battery_monitor_service.dart`
   - `src/assets/alarm.wav`
   - `scripts/patch_manifest.py`
   - `.github/workflows/build-apk.yml`
2. On push to `main`, GitHub **Actions** builds automatically. Open the latest
   run → download the **battery-alarm-apk** artifact (a zip with `app-debug.apk`).
3. Unzip on your phone and open the APK to install (allow "install unknown
   apps" if prompted).

## After installing
- Open the app, set thresholds, interval, quiet hours and volume, then turn on
  **Enable battery alarm**.
- **Important:** Settings → Apps → Battery Alarm → Battery → **Unrestricted**.
  Without this, Android may kill the service and stop the checks.

## Monetization / ads (built in)
The app ships with an **ad-supported free tier** and a **Pro (ad-free) tier**:
- Free users see a single banner pinned to the bottom of the settings screen
  (no ads in the alarm or in notifications — that would violate policy).
- A **"Go Pro — remove ads"** button removes the banner. It's a local demo
  unlock; in production it would trigger a real one-time purchase via the
  `in_app_purchase` / Play Billing flow.

The build uses **Google's official TEST ad unit IDs**, so it works with no
AdMob account and always shows test ads. Before publishing:
1. Create an AdMob account, register the app, and make a banner ad unit.
2. Replace the test app id in `scripts/patch_manifest.py` (`ADMOB_APP_ID`) and
   the test banner id in `src/lib/ads.dart` (`_testBannerUnitId`).
3. **Required for EEA/UK/Switzerland:** integrate the UMP consent SDK and
   gather consent *before* ads initialize, add a privacy policy, and complete
   the Play Data Safety form. See `SPEC_ASSESSMENT.md` §4.5.

See **`SPEC_ASSESSMENT.md`** for the full product, monetization and
go-to-market analysis (recommended model: freemium + one-time Pro unlock).

## Pro unlock (real in-app purchase)
The "Go Pro" button now uses the real **`in_app_purchase`** plugin (Google
Play Billing), not a demo toggle. It's a **one-time, non-consumable** purchase
that permanently unlocks ad-free mode. Code lives in
`src/lib/purchase_service.dart`.

Important: in-app billing **cannot be tested from a debug APK installed by
sideloading**. To make the purchase flow live you must:
1. In **Play Console → Monetize → Products → In-app products**, create a
   product with ID **`pro_unlock`** (must match `kProProductId` in
   `purchase_service.dart`), set a price, and **activate** it.
2. Build a **signed release** APK/AAB (the CI here builds an unsigned debug
   APK — you'll need to add signing for release; see Flutter app-signing docs).
3. Upload it to at least an **internal testing** track and add your Google
   account as a **licensed tester** (Play Console → Setup → License testing).
   Install the app *from the Play test link*, not by sideloading.
4. The "Restore purchase" button is required by Play policy and is wired up.

Until those steps are done the app shows "billing isn't available" — that's
expected for a sideloaded debug build, and the rest of the app still works.

**Verify entitlements server-side for real revenue protection:** the scaffold
grants Pro on a completed purchase, but a production app should validate the
purchase token against the Google Play Developer API on a backend before
granting, to resist tampering. See the comment in `_onPurchaseUpdates`.

### If the ad SDK breaks the build
The ad code is isolated. To get back to a clean build without ads, remove the
`google_mobile_ads` line from `src/pubspec.yaml`, delete `src/lib/ads.dart`,
and remove the three `ads.dart` references in `src/lib/main.dart` (the import,
the `initAds()` call, and the `AdBanner` / Pro card).

## Android constraints worth knowing
- Builds a **debug** APK (no signing needed — fine for your own device).
- Volume override works by playing the app's own tone; Android does not let an
  app set the volume of a *system notification's* sound directly, which is why
  the app plays its own audio for the override feature.
- "Heard on silent" relies on the media stream, which keeps playing when the
  ringer is silenced. If you put the whole phone in Do Not Disturb with media
  muted, that still takes precedence.
