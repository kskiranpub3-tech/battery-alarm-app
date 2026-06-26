import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the user has unlocked Pro (which removes ads).
const String kProTierKey = 'pro_tier';

/// Google's official TEST banner unit ID. Replace with your real AdMob unit
/// ID before publishing — but NEVER ship while still pointing at a real unit
/// in debug/testing, as that violates AdMob policy. Test IDs are safe to ship
/// during development and always return test ads.
const String _testBannerUnitId = 'ca-app-pub-3940256099942544/6300978111';

/// Call once at startup. Safe to call even if you later disable ads.
Future<void> initAds() async {
  // NOTE FOR PRODUCTION: before this runs in the EEA/UK/Switzerland you must
  // gather consent via the UMP SDK (google's User Messaging Platform) and only
  // then initialize ads. See SPEC_ASSESSMENT.md section 4.5.
  try {
    await MobileAds.instance.initialize();
  } catch (_) {
    // If init fails, the app still works fully; ads just won't show.
  }
}

Future<bool> isProUser() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(kProTierKey) ?? false;
}

Future<void> setProUser(bool value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(kProTierKey, value);
}

/// A self-contained banner that loads a test ad. Renders nothing until the ad
/// loads, and renders nothing at all for Pro users (handled by the caller).
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    try {
      final ad = BannerAd(
        adUnitId: _testBannerUnitId,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (_) {
            if (mounted) setState(() => _loaded = true);
          },
          onAdFailedToLoad: (ad, error) {
            ad.dispose();
          },
        ),
      );
      ad.load();
      _ad = ad;
    } catch (_) {
      // Ignore — banner simply won't appear.
    }
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _ad == null) return const SizedBox.shrink();
    return Container(
      alignment: Alignment.center,
      width: _ad!.size.width.toDouble(),
      height: _ad!.size.height.toDouble(),
      child: AdWidget(ad: _ad!),
    );
  }
}
