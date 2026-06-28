import 'package:flutter/services.dart';

/// Battery details read from the native side (temperature, voltage, current),
/// plus charging status. Any field can be null if the device doesn't report it.
class BatteryInfo {
  final double? temperatureC;
  final double? voltageV;
  final double? currentMa; // signed; magnitude is what matters here
  final int status; // 1 unknown, 2 charging, 3 discharging, 4 not charging, 5 full
  final int plugged; // 0 none, 1 AC, 2 USB, 4 wireless
  final int health; // 2 good, 3 overheat, 4 dead, 5 over-voltage, 7 cold
  final String? technology;

  const BatteryInfo({
    this.temperatureC,
    this.voltageV,
    this.currentMa,
    this.status = 1,
    this.plugged = 0,
    this.health = 1,
    this.technology,
  });

  bool get isPlugged => plugged > 0;
  bool get isFull => status == 5;
  bool get isCharging => status == 2;

  /// Heuristic: plugged in, not full, but effectively no current flowing.
  /// Strong sign that a battery-protection / charge-limit feature (or a weak
  /// cable/charger) is holding charging back.
  bool get chargingLikelyCapped {
    if (!isPlugged || isFull) return false;
    final c = currentMa;
    if (c == null) {
      // No current reading: fall back to status. "Not charging" while plugged
      // and not full is the classic capped signature.
      return status == 4;
    }
    return c.abs() < 30; // ~0 mA while plugged and not full
  }

  String get healthText {
    switch (health) {
      case 2:
        return 'Good';
      case 3:
        return 'Overheating';
      case 4:
        return 'Dead';
      case 5:
        return 'Over-voltage';
      case 7:
        return 'Cold';
      default:
        return 'Unknown';
    }
  }
}

const MethodChannel _channel = MethodChannel('battery_info');

Future<BatteryInfo?> readBatteryInfo() async {
  try {
    final m = await _channel.invokeMapMethod<String, dynamic>('getBatteryInfo');
    if (m == null) return null;
    return BatteryInfo(
      temperatureC: (m['temperature'] as num?)?.toDouble(),
      voltageV: (m['voltage'] as num?)?.toDouble(),
      currentMa: (m['currentMa'] as num?)?.toDouble(),
      status: (m['status'] as num?)?.toInt() ?? 1,
      plugged: (m['plugged'] as num?)?.toInt() ?? 0,
      health: (m['health'] as num?)?.toInt() ?? 1,
      technology: m['technology'] as String?,
    );
  } catch (_) {
    return null; // channel unavailable (e.g., hot-reload before native ready)
  }
}
