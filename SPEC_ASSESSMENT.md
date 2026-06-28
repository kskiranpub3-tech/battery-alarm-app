# Battery Alarm — Spec Assessment v2

*v2 adds: a best-in-class teardown (AccuBattery + OS-native features), the OS as the
key competitive threat, prioritized feature recommendations, explicit key
assumptions, critical questions with answers, a risk register, and a concrete
gaps-to-close checklist.*

---

## 0. The verdict (unchanged, reinforced by research)

Ship a **freemium app with a one-time "Pro" unlock (~$2.99–$3.99)**, light ads only
on the settings screen as a backstop. Research confirms this is exactly how the
category leader monetizes (AccuBattery: free core, cheap one-time/low-cost Pro,
ads in free, ad-free in Pro). But the bigger strategic finding is this: **alarms
alone are no longer enough to be best-in-class, and the OS is eating the "stop at
80%" use case.** To win you must (a) be *more reliable* than incumbents (their #1
weakness right now), (b) own the **discharge/low-battery alarm**, which the OS does
**not** address, and (c) add a **battery-data layer** (charge sessions, current,
temperature, wear, history) that becomes both the moat and the Pro upsell.

---

## 1. Best-in-class teardown

### 1.1 AccuBattery — the reference product
The market leader (10M+ installs, ~4.8★, independent dev Digibites). What makes it
best-in-class:
- **Real capacity measurement in mAh** (not a vague "Good/Fair" label) by integrating
  charge current over full cycles — this is its signature credibility feature.
- **Per-charge-session wear**: tells you how much battery health each charge cost.
- **A charge alarm to unplug** — note: *our core concept is validated*; the leader
  treats the unplug alarm as a core feature, not a gimmick.
- **Charge current in mA**: lets users find their fastest charger/cable — high
  perceived value, trivial to read from the OS.
- **Per-app discharge / consumption**, **remaining charge time** and **remaining use
  time**, **deep-sleep %**, and an **ongoing stats notification**.
- **Pro tier** unlocks: history older than 1 day, detailed notification stats, AMOLED
  themes, **no ads**. One-time / low-cost, not an expensive subscription.
- **Positioning**: privacy-light ("doesn't access privacy-sensitive info, makes no
  false claims"). This trust posture is a real asset in a category full of sketchy
  "booster" apps.

### 1.2 Where even the leader is weak — your openings
- **Background reliability is collapsing under modern Android.** Users report it works
  on older Android but gets killed on the newest versions "to save power." This is the
  single biggest, most-repeated complaint — and it's your wedge: **nail background
  reliability and you beat the leader on its worst problem.**
- **Accuracy varies by OEM** (poor on some Redmi/dual-battery devices) and needs
  several full cycles to calibrate. Experts warn that single smoothed "health scores"
  are misleading — capacity + cycle data is the honest metric.
- **EU ads-consent backlash**: recent forced GDPR consent screens drew 1-star reviews.
  A clean consent UX (and keeping Pro fully ad-free) is a differentiator.
- **iOS version is poorly received** — iOS sandboxing makes this category weak there.

### 1.3 Pricing comps (from the 2026 landscape)
- AccuBattery: free core + cheap one-time/low-cost Pro, ad-free in Pro.
- "Battery Life" (iOS): ~$2.99 one-time, no subscription, no ads.
- OEM tools: free but device-specific and shallow on history.
- **Takeaway: one-time ~$2.99–$3.99 is the category norm. Avoid subscriptions** unless
  you add genuine ongoing cloud value.

---

## 2. The competitive threat that actually matters: the OS

The most important strategic fact: **charge-limit features are now built into the OS.**
- **Android 15 (QPR1)** added a "Charging optimization" menu on Pixel with **Limit to
  80%** and Adaptive Charging. Samsung ("Protect battery") and iPhone (Optimized
  Charging) have had equivalents.
- This commoditizes the *charge cap*. If a user's phone can already cap at 80%, why
  install your app?

**But the native features are beatable, and here's exactly why:**
1. **They don't do the discharge side at all.** There is **no OS feature** that alarms
   you to *plug in* at 20%. Your discharge alarm is uncontested.
2. **They're inconsistent and partly broken.** Pixel's 80% cap is overridden to 100% by
   PMIC firmware above ~34°C (navigation, fast charging, warm rooms trigger it), and
   Android 16 deliberately charges to 100% every 1–2 weeks for calibration. A Sept 2025
   Pixel update broke the feature for some users entirely. An **alarm gives the user
   awareness and control** even when the silent native cap misbehaves.
3. **Fixed threshold.** Pixel's limit is a hard 80% with no adjustment; your app lets
   users pick any threshold (50–100%).
4. **Device coverage.** Hundreds of millions of mid-range/older devices have **no**
   native cap. That's your core market.
5. **Cross-device consistency.** One predictable behavior across brands.

**Strategic conclusion:** reposition from "stop charging at 80%" (losing to the OS) to
**"battery health awareness + alarms + data"** (the OS doesn't do this end-to-end).

### 2.1 Tailwinds worth riding
- **EU Right-to-Repair** now mandates battery-health disclosure for devices sold after
  2025, and the **secondhand market** prices phones on state-of-health. A credible
  **"battery health / resale SOH report"** is a timely, novel feature.
- Search interest in battery health is surging; sustainability ("keep your phone
  longer, reduce e-waste") is now common marketing language and resonates in Europe.

---

## 3. Recommended features & improvements (prioritized)

### NOW — reach parity on reliability + the cheap, high-value data wins
- **Battery-optimization / autostart onboarding** (deep-link per OEM) + **boot
  restart** + a **WorkManager watchdog**. This is the #1 success factor and the
  incumbent's weakness. *Highest priority.*
- **Charge current (mA) display** — easy from `BatteryManager`, lets users compare
  chargers/cables; high perceived value for near-zero effort.
- **Battery temperature** read + **overheat warning** (heat is the top degradation
  driver; this is genuinely protective and differentiated).
- **Charge-session logging**: per session, % gained, duration, average current, and an
  **estimated wear** figure — AccuBattery's signature, and the basis of stickiness.
- **Remaining charge-time / use-time** estimates.

### NEXT — Pro differentiators (the things people pay for)
- **Charging history + graphs** (the sticky, screenshot-worthy feature).
- **Capacity / wear estimate over cycles** — shown **honestly as an estimate**, never a
  single smoothed "health %". Calibrates over several full cycles.
- **Per-app battery usage** (needs usage-access permission; higher effort).
- **Multiple profiles**, **custom alarm sounds + escalation** ("repeat until
  unplugged"), **smart charge target** ("be at 80% by 7am").
- **Home-screen widget + Quick Settings tile** (keeps the app visible despite low
  session frequency — directly addresses the monetization problem).
- **Battery-health / resale SOH report export** — rides EU Right-to-Repair + secondhand
  resale; a fresh angle incumbents under-serve.

### LATER
- Wear OS companion, cloud history (only if you justify a subscription), broad
  localization (huge non-English Android markets), themes/AMOLED.

---

## 4. Reliability & platform constraints (the make-or-break)

- **Background execution is the hard problem**, not a detail. Aggressive OEM battery
  managers (Xiaomi/Samsung/Huawei/Oppo/Vivo) kill services. Mitigate with a foreground
  service (done), a guided battery-optimization exemption (to add), `RECEIVE_BOOT_COMPLETED`
  restart, and a WorkManager backup. This is *also* your competitive wedge (§1.2).
- **Foreground-service policy (verified June 2026):** Android 14+ requires declaring a
  `foregroundServiceType` in the manifest **and** filing a Play Console declaration
  (Policy → App content) with a **demo video**. A battery monitor falls under the
  reviewed **`specialUse`** type. De-risk this early.
- **Avoid `SCHEDULE_EXACT_ALARM`** (you poll state, not schedule exact alarms — keep it
  that way). Only request `USE_FULL_SCREEN_INTENT` if the loud alarm truly needs it; it
  now requires a Play declaration.
- **Don't overstate health claims.** Frame 80/20 as battery-health best practice, not a
  lifespan guarantee; show capacity as an estimate.

---

### 4.1 Reliability gaps to close (from methodology review)

A reviewed implementation sketch reinforced that the current build's biggest hole is
**service survival**, not features. Concrete items to implement when we return to this:

- **WorkManager watchdog.** A periodic background task (e.g. every 15 min, the platform
  minimum) that checks whether the foreground service is alive and restarts it if an
  OEM killed it. This is the real meaning of "watchdog" — the polling loop inside the
  service is *not* a watchdog, because if the service dies the loop dies with it.
- **Boot restart, done safely.** Restart monitoring after reboot via
  `RECEIVE_BOOT_COMPLETED`, but **only if** the user had monitoring enabled, and respect
  Android 15 limits on launching `specialUse` FGS from boot. Avoid blanket
  `autoStart: true` — starting the service before notification permission is granted
  (Android 13+) or before the user opts in is fragile and can crash.
- **Permission/exemption ordering.** Always request `POST_NOTIFICATIONS` and guide the
  battery-optimization exemption *before* relying on the service, not after autostart.
- **Keep release builds signed.** CI must stay on `--debug` until signing is configured;
  a `flutter build apk --release` without a keystore will fail the pipeline. (Tracked in
  §10 monetization gaps.)
- **Pin known-good toolchain.** Keep Flutter and `flutter_background_service` on the
  versions we've stabilized (current major, not older majors); downgrading the plugin or
  Flutter reintroduces API and Kotlin-version mismatches.

## 5. Monetization (reaffirmed)

- **Free tier**: full alarm functionality + basic stats. Single non-intrusive banner on
  the settings screen only. Never ads in the alarm or in notifications.
- **Pro (one-time ~$2.99–$3.99)**: history graphs, wear/capacity estimates, widgets,
  custom alarms, SOH export — and removes ads.
- **Why not subscription**: category norm is one-time; subscriptions convert poorly and
  draw resentment for a simple utility.
- **Why not pure ads**: set-and-forget = near-zero session time = negligible ad revenue;
  ads also erode the privacy story and add EEA consent burden.
- **Ad compliance**: serving personalized ads in EEA/UK/Switzerland legally requires a
  Google-certified CMP (UMP SDK), consent **before** ad init, a privacy policy, and an
  accurate Data Safety form. Keep Pro 100% ad-SDK-free.

---

## 6. Go-to-market

- **ASO**: target "battery alarm," "charge alarm," "full battery alarm," "80 20
  charging," "battery health." Lead screenshots with the alarm + the 80/20 benefit.
- **Reviews drive ranking**: trigger the in-app review prompt *after* a successful alarm,
  never on first launch.
- **Channels**: r/Android, r/batterylife, device subreddits; a simple SEO post on the
  80/20 rule and battery degradation; short-form video demos; an XDA/Android-blog launch.
- **Virality**: the charging-history graph and a shareable "battery health / resale"
  card are the natural "show a friend" moments.

---

## 7. Key assumptions (explicit & testable)

| # | Assumption | Confidence | How to validate |
|---|------------|-----------|-----------------|
| A1 | A reliable **discharge/low alarm** is a real unmet need the OS doesn't cover | High | Keyword demand, review mining, A/B onboarding emphasis |
| A2 | **Reliability** (alarm always fires) is the top driver of ratings | High | Review-sentiment analysis; correlate kills→ratings |
| A3 | Users keep the app **despite** OS-native caps (because caps are partial/broken) | Medium | Retention split by device OS-feature availability |
| A4 | A **one-time ~$3** unlock beats a subscription here | High | Category comps; price-test Pro |
| A5 | Free users yield **negligible ad revenue but high review/WoM value** | Med-High | Cohort ARPU vs review/referral lift |
| A6 | We can **pass Play's specialUse FGS review** with a clear justification + video | Medium | Submit early to a test track; iterate |
| A7 | Battery telemetry (mAh, current, temp) is **accessible enough** across mainstream devices | Medium | Device-matrix testing; known OEM gaps |
| A8 | "Charge to 80%" stays marketable **even as OEMs adopt it** (inconsistent execution) | Medium | Track OS rollout; monitor demand |

---

## 8. Critical questions — with answers

**Q: Is the OS killing this category?**
A: It's commoditizing the *charge cap*, not the category. Discharge alarms, adjustable
thresholds, history/wear data, cross-device consistency, and reliability when native
caps misbehave all remain. Reposition as "battery health + awareness," not "stop at 80%."

**Q: Ads or paid — final answer?**
A: Freemium + one-time Pro (~$2.99–$3.99). Ads are a minor settings-screen backstop. This
matches the proven category leader and the pricing of every credible comp.

**Q: What's the biggest technical risk?**
A: Background-service reliability across OEMs — the exact thing degrading the incumbent on
Android 15. Invest here first; it's both the top success factor and your wedge.

**Q: Will Play approve a `specialUse` foreground-service battery monitor?**
A: Likely, with a proper declaration + demo video, but it's reviewed case-by-case.
De-risk early and design a fallback (periodic WorkManager checks / user-initiated flows)
in case of denial.

**Q: Can we show "battery health" accurately?**
A: Capacity/wear estimates need several full cycles and vary by OEM. Show them honestly as
estimates; never a single smoothed "health score" (experts consider those misleading).

**Q: Should we build iOS?**
A: Android-first. iOS sandboxing blocks background battery polling and custom alarms, and
even the leader's iOS app is poorly received. Don't split focus early.

**Q: What's the actual moat?**
A: Reliability + honest data + privacy + the uncontested discharge alarm + breadth across
devices. Not the 80% cap alone.

---

## 9. Risk register & mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| OS-native charge limits erode demand | Medium | High | Lead with discharge alarm + data layer; target devices without the feature; reframe value as health/awareness |
| Background service killed by OEMs | High | High | Battery-opt exemption onboarding, boot restart, WorkManager watchdog, per-OEM guidance |
| Play rejects `specialUse` FGS | Medium | High | Clean declaration + demo video; submit early; fallback architecture |
| Battery data inaccurate on some OEMs | Medium | Medium | Label as estimate; calibrate over cycles; known-issues list; under-promise |
| Ad SDK harms privacy story / EEA consent friction | Medium | Medium | Keep Pro ad-free; implement UMP cleanly; minimal data; honest Data Safety form |
| Low monetization (set-and-forget) | Medium | Medium | Pro data features that drive opens; widget/QS tile keep app visible |
| Battery-health overclaims (credibility/policy) | Low | High | Chemistry-based framing, no lifespan guarantees |
| Crowded category / poor discovery | Medium | Medium | Long-tail ASO, content/SEO, reliability-led reviews, niche wedges (discharge alarm, SOH export) |
| Thermal firmware override confuses dual-feature users | Low | Medium | In-app education explaining native-cap overrides |
| IAP entitlement spoofing | Low | Medium | Server-side purchase validation before granting Pro |

---

## 10. Gaps to close (current build → best-in-class)

The current app has: charge/discharge alarms, adaptive polling, quiet hours, volume
override, an ad-supported tier, and an `in_app_purchase` Pro scaffold. To reach
best-in-class, close these:

**Reliability (critical)**
- [ ] Battery-optimization / autostart onboarding flow
- [ ] `RECEIVE_BOOT_COMPLETED` restart + WorkManager watchdog
- [ ] Per-OEM "keep alive" guidance

**Data layer (the whole best-in-class differentiator — currently absent)**
- [ ] Charge-session logging (% gained, duration, avg current)
- [ ] Charge current (mA) + temperature read
- [ ] Estimated per-session wear
- [ ] Capacity / health estimate over cycles (honest, calibrated)
- [ ] History + graphs (Pro)

**Engagement**
- [ ] Home-screen widget + Quick Settings tile
- [ ] Richer persistent stats notification

**Trust & compliance**
- [ ] Privacy policy + accurate Data Safety form
- [ ] UMP consent flow (before ads init) for EEA/UK/Switzerland
- [ ] FGS type declared on the service + Play Console declaration (with video)
- [ ] Full-screen-intent justification (or drop it)

**Monetization**
- [ ] Real Play Console product config (`pro_unlock`) + release signing
- [ ] Server-side purchase validation

**Polish**
- [ ] Onboarding, app icon/branding, accessibility pass (TalkBack/large text)
- [ ] Localization for top non-English Android markets

**iOS**
- [ ] None — Android-first is the correct call

### 10.1 Additional gaps (from PRD cross-check)
- [ ] **Privacy policy + Play Data Safety form** treated as hard launch gates for *any*
  submission (not just when ads are present) — the persistent notification and battery
  data still require disclosure.
- [ ] **Privacy-respecting analytics/telemetry layer.** Without it, the KPIs in §11
  (service-kill rate by OEM, permission/exemption grant rates) can't be measured. Pick a
  lightweight, consent-aware solution; keep Pro data minimal.
- [ ] **Battery-data permission reality.** Charge current (mA) and temperature are simple
  reads, but **per-app usage needs `PACKAGE_USAGE_STATS`** (a special-access permission
  with a system-settings handoff). Plan the UX cost before scheduling that feature.
- [ ] **Support & calibration cadence.** The incumbent's moat is years of OEM-specific
  accuracy fixes. Define a realistic process for device-specific bug reports and
  per-OEM calibration, or the "honest data" promise erodes on long-tail devices.

---

## 11. KPIs to instrument
- Notification-permission grant rate; **battery-optimization-exemption grant rate**.
- **Alarm fire success rate** (did the service survive to fire?) — the north-star.
- D1 / D7 / D30 retention; service-kill rate **by OEM**.
- Free→Pro conversion; ARPU; ad eCPM by geo.
- Crash-free rate; store-rating trend and review-keyword sentiment.

---

## 12. Phased plan
1. **Phase 1 (ship):** harden reliability + onboarding; free tier; charge current + temp
   + session logging as the early data hook. Earn reviews.
2. **Phase 2:** Pro unlock — history graphs, wear/capacity estimate, widgets, custom
   alarms — via the one-time IAP (already scaffolded).
3. **Phase 3:** optional settings-screen ads + UMP consent; SOH/resale export; keep Pro
   ad-free.
4. **Phase 4:** Wear OS, localization, smart charge target; iterate ASO + content.

> Bottom line: the OS is taking the "stop at 80%" feature, so don't compete there. Win on
> **reliability the incumbents have lost, the discharge alarm the OS ignores, and an
> honest battery-data layer** — give the core away, sell a small one-time Pro for the
> data and delight, and keep ads a quiet floor under the free tier.

---

## 13. Failure scenarios & known bugs to watch

Concrete ways the current build can misbehave, beyond the OEM-kill problem:

1. **UI says "enabled" but service is dead.** `_monitoring` is restored from saved
   prefs, but after a reboot or an OEM kill the actual service may be stopped. The user
   thinks they're protected and isn't. *Mitigated now* by a live "Service: running/
   stopped" indicator + a warning + a Restart button (§ service-health card).
2. **No restart after reboot.** `autoStart` is off, so monitoring silently stops after a
   restart. Needs `RECEIVE_BOOT_COMPLETED` to relaunch *only if* the user had it on.
3. **Doze mode defers the polling timer.** Without a battery-optimization exemption, the
   periodic check can be delayed for long stretches, so a charge alarm can fire late or
   not until the screen wakes. The "Allow background" button now requests the exemption.
4. **Late low-battery alarm.** On battery, checks run every 15–60 min; a fast drain can
   pass the threshold and only alert at the next tick (e.g. at 14% instead of 20%).
   Acceptable, but consider a tighter interval when already near the threshold.
5. **Background audio is unreliable.** The custom-tone path often stays silent in the
   service isolate. *Fixed* by making the max-priority notification the guaranteed sound
   and treating the tone as a best-effort extra.
6. **Quiet-hours test confusion.** A test alarm during quiet hours is silent by design —
   a user testing at night hears nothing and assumes it's broken. Consider making the
   test always audible.
7. **Notification stacking.** Each alarm uses a unique ID, so repeated alerts pile up.
   Consider a fixed ID per alarm type so a new one replaces the old.
8. **Full-screen intent may not trigger.** Android 14+ gates `USE_FULL_SCREEN_INTENT`;
   without declaring/justifying it, the lock-screen full-screen alarm silently degrades
   to a normal notification. Add the permission or stop relying on full-screen.
9. **Rapid charge/discharge events** can overlap async checks (the state-change listener
   plus the self-rescheduling timer). Add a re-entrancy guard so two checks can't run at
   once.
10. **Permission denial.** If the user denies notifications, the FGS notification and
    alarms won't show. Detect denial and explain, rather than failing silently.

## 14. OEM power-saving reality (top 5 brands)

The biggest functional risk is **vendor battery managers**, which are stricter than
stock Android's Doze and can kill a foreground service even when it's "exempt." Per
dontkillmyapp.com and field guides, ranked roughly worst-to-mildest among major brands:

- **Xiaomi (MIUI/HyperOS):** among the most aggressive; background work "simply does not
  work right" by default. Needs a separate **Autostart** toggle (in the Security app),
  plus battery-saver exemption; settings can reset after system updates.
- **OnePlus (OxygenOS):** historically one of the most severe limiters — "deep
  optimization," "sleep standby optimization," and adaptive battery all restrict the
  service; settings can reset on firmware updates, and locking the app in Recents helps
  but isn't 100%.
- **Oppo/Realme (ColorOS):** kills background processes aggressively; needs Autostart +
  manual background-activity allowance.
- **Vivo (Funtouch/OriginOS):** similar aggressive limits; Autostart is a separate,
  easy-to-miss toggle.
- **Samsung (One UI):** milder than the above but still puts unused apps to "sleep";
  needs the app marked as **not** sleeping/deep-sleeping and exempt from battery
  optimization; settings may need redoing after major updates.
- *(Honorable mention: Huawei/HMD are extreme but smaller share in many markets.)*

**Implication for the app:** an in-app reliability flow is essential — request the
battery-optimization exemption (done), link out to dontkillmyapp.com per device (done in
the card), and tell users plainly that on these brands they must also enable Autostart
and lock the app in Recents. Even then, expect occasional kills and surface a Restart
control (done). A WorkManager watchdog is still the missing automated backstop.

## 15. Competitor gap analysis — "Battery Charge Limit & Alarm" (org.gouz.batterycharge)

A close competitor (on Play since Feb 2025, ~13.9 MB, written in native code). Mapping
its advertised features against the current app:

| Competitor feature | Status in our app | Gap to close |
|---|---|---|
| Customizable charge-limit alarm | ✅ Have | — |
| Low-battery alert **without manually starting** | ⚠️ Partial — ours needs monitoring toggled on | Add opt-in auto-start so the discharge alarm works out of the box |
| Continuous background monitoring | ✅ Have (reliability WIP) | Watchdog + boot restart |
| **Full battery status: level, temperature, voltage, current** | ❌ Missing | Add a real-time status screen (temp/voltage/current are simple reads) |
| **Charging statistics + health score** | ❌ Missing | Session logging + history; show **calibrated estimates**, not a single smoothed "health score" |
| **Snooze** the alarm | ❌ Missing | Add snooze action on the alarm notification |
| Customizable sound & vibration per alarm | ⚠️ Partial (volume, quiet hours) | Add sound picker + vibration pattern choice |

**Net new gaps surfaced** (add to §10): real-time battery status view (temperature,
voltage, current), **snooze**, custom alarm-sound selection, and an opt-in auto-monitor
mode. Temperature/voltage/current are quick wins with high perceived value.

**Permissions the competitor uses that are worth selectively adopting:**
- **Access Do Not Disturb** — lets alarms sound through DND (genuinely useful for a
  wake-me alarm; weigh against the consent/permission friction).
- **Full-screen intent on locked device** — for a true alarm screen (needs the
  `USE_FULL_SCREEN_INTENT` declaration we currently lack).
- **Schedule exact alarms** — only needed if we add snooze/scheduled re-alerts.
- It also ships **ads (Advertising ID, AdServices APIs)** and **Play Billing** — i.e. the
  same freemium+ads model the spec recommends.

## 16. App size & how to stay compact

The competitor is **~13.9 MB, native**. A Flutter app carries a baseline engine cost
(~5–7 MB) that native avoids, so matching it exactly is hard — but a well-built release
gets competitive. Our current artifact is a **universal debug APK**, which is the
*largest* possible form. To shrink:

1. **Ship release, not debug** — debug bundles extra tooling; release is much smaller.
2. **Split per ABI** (`flutter build apk --split-per-abi`) — produces ~per-architecture
   APKs (arm64 ~8–11 MB) instead of one fat universal (~20 MB+). Or ship an **app bundle
   (.aab)** so Play delivers a per-device slice automatically.
3. **Obfuscate + split debug info** (`--obfuscate --split-debug-info=...`) — strips
   symbols from the binary.
4. **Enable R8 + resource shrinking** in release (`minifyEnabled`, `shrinkResources`).
5. **Drop unused weight:** removing `audioplayers` + `alarm.wav` (now that the
   notification is the sound source) removes an audio engine and an asset — a real,
   easy size win, at the cost of the programmatic-volume feature.
6. **Avoid heavy plugins** where a platform channel would do; each native plugin adds
   size.

Realistic target: a per-ABI **release** build in the ~9–12 MB range — close to the
competitor, without giving up Flutter's development speed.

> Note: items in §13–16 are analysis for later. The shipped change this round is the
> in-app **service-health / restart card** plus battery-optimization shortcuts.
