import 'dart:async';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kChargeThresholdKey = 'charge_threshold';
const String kDischargeThresholdKey = 'discharge_threshold';
const String kMonitoringEnabledKey = 'monitoring_enabled';
const String kDischargeIntervalKey = 'discharge_interval_min';
const String kQuietEnabledKey = 'quiet_enabled';
const String kQuietStartHourKey = 'quiet_start_hour';
const String kQuietStartMinKey = 'quiet_start_min';
const String kQuietEndHourKey = 'quiet_end_hour';
const String kQuietEndMinKey = 'quiet_end_min';
const String kVolumeOverrideKey = 'volume_override';
const String kAlarmVolumeKey = 'alarm_volume';

const String _monitorChannelId = 'battery_monitor_channel';
const String _monitorChannelName = 'Battery Monitor';
const String _alarmChannelId = 'battery_alarm_channel';
const String _alarmChannelName = 'Battery Alarms';
const String _silentChannelId = 'battery_silent_channel';
const String _silentChannelName = 'Battery Alarms (silent)';

// While charging the phone is on external power, so polling costs ~no battery.
// We poll fast enough to catch the high threshold during fast charging.
const Duration _chargingInterval = Duration(minutes: 2);

/// Holds the user's settings inside the background isolate.
class _Settings {
  double charge = 80;
  double discharge = 20;
  int dischargeIntervalMin = 30;
  bool quietEnabled = false;
  int quietStartHour = 22;
  int quietStartMin = 0;
  int quietEndHour = 7;
  int quietEndMin = 0;
  bool volumeOverride = true;
  double alarmVolume = 0.8;

  void loadFrom(SharedPreferences p) {
    charge = p.getDouble(kChargeThresholdKey) ?? charge;
    discharge = p.getDouble(kDischargeThresholdKey) ?? discharge;
    dischargeIntervalMin = p.getInt(kDischargeIntervalKey) ?? dischargeIntervalMin;
    quietEnabled = p.getBool(kQuietEnabledKey) ?? quietEnabled;
    quietStartHour = p.getInt(kQuietStartHourKey) ?? quietStartHour;
    quietStartMin = p.getInt(kQuietStartMinKey) ?? quietStartMin;
    quietEndHour = p.getInt(kQuietEndHourKey) ?? quietEndHour;
    quietEndMin = p.getInt(kQuietEndMinKey) ?? quietEndMin;
    volumeOverride = p.getBool(kVolumeOverrideKey) ?? volumeOverride;
    alarmVolume = p.getDouble(kAlarmVolumeKey) ?? alarmVolume;
  }

  void applyEvent(Map<String, dynamic> e) {
    charge = (e['charge'] as num?)?.toDouble() ?? charge;
    discharge = (e['discharge'] as num?)?.toDouble() ?? discharge;
    dischargeIntervalMin = (e['dischargeInterval'] as num?)?.toInt() ?? dischargeIntervalMin;
    quietEnabled = e['quietEnabled'] as bool? ?? quietEnabled;
    quietStartHour = (e['quietStartHour'] as num?)?.toInt() ?? quietStartHour;
    quietStartMin = (e['quietStartMin'] as num?)?.toInt() ?? quietStartMin;
    quietEndHour = (e['quietEndHour'] as num?)?.toInt() ?? quietEndHour;
    quietEndMin = (e['quietEndMin'] as num?)?.toInt() ?? quietEndMin;
    volumeOverride = e['volumeOverride'] as bool? ?? volumeOverride;
    alarmVolume = (e['alarmVolume'] as num?)?.toDouble() ?? alarmVolume;
  }

  bool get inQuietHours {
    if (!quietEnabled) return false;
    final now = DateTime.now();
    final cur = now.hour * 60 + now.minute;
    final start = quietStartHour * 60 + quietStartMin;
    final end = quietEndHour * 60 + quietEndMin;
    if (start == end) return false;
    if (start < end) return cur >= start && cur < end;
    return cur >= start || cur < end; // window wraps past midnight
  }
}

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onServiceStart,
      autoStart: false,
      // Restart monitoring after a device reboot (the service itself stops
      // again on boot if the user had monitoring turned off — see onServiceStart).
      autoStartOnBoot: true,
      isForegroundMode: true,
      notificationChannelId: _monitorChannelId,
      initialNotificationTitle: 'Battery Alarm',
      initialNotificationContent: 'Monitoring battery level...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(),
  );
}

@pragma('vm:entry-point')
void onServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final notifications = FlutterLocalNotificationsPlugin();
  await _initNotifications(notifications);

  final player = AudioPlayer();
  final battery = Battery();
  final settings = _Settings();

  final prefs = await SharedPreferences.getInstance();
  settings.loadFrom(prefs);

  // If the service was started by the boot receiver but the user had monitoring
  // turned off, stop immediately so we don't run uninvited. (When the user
  // enables monitoring, the flag is saved BEFORE the service starts, so this
  // check passes for a deliberate start.)
  final monitoringEnabled = prefs.getBool(kMonitoringEnabledKey) ?? false;
  if (!monitoringEnabled) {
    service.stopSelf();
    return;
  }
  // Hysteresis flags so we alert once per crossing, not every poll.
  bool chargeAlertFired = false;
  bool dischargeAlertFired = false;
  Timer? nextCheck;

  Future<void> runCheck() async {
    final level = await battery.batteryLevel;
    final state = await battery.batteryState;
    final isCharging =
        state == BatteryState.charging || state == BatteryState.full;

    if (service is AndroidServiceInstance) {
      final mode = isCharging ? 'Charging' : 'On battery';
      service.setForegroundNotificationInfo(
        title: 'Battery Alarm',
        content:
            '$level% • $mode (unplug ${settings.charge.round()}%, charge ${settings.discharge.round()}%)',
      );
    }

    if (isCharging) {
      dischargeAlertFired = false;
      if (level >= settings.charge && !chargeAlertFired) {
        chargeAlertFired = true;
        await _alert(notifications, player, settings,
            title: 'Unplug your charger',
            body: 'Battery is at $level%. Unplugging now helps battery health.');
      } else if (level < settings.charge - 3) {
        chargeAlertFired = false;
      }
    } else {
      chargeAlertFired = false;
      if (level <= settings.discharge && !dischargeAlertFired) {
        dischargeAlertFired = true;
        await _alert(notifications, player, settings,
            title: 'Plug in your charger',
            body: 'Battery is at $level%. Time to charge.');
      } else if (level > settings.discharge + 3) {
        dischargeAlertFired = false;
      }
    }

    // Reschedule adaptively: fast while charging (free, on wall power),
    // slow while on battery (saves power).
    nextCheck?.cancel();
    final delay = isCharging
        ? _chargingInterval
        : Duration(minutes: settings.dischargeIntervalMin);
    nextCheck = Timer(delay, runCheck);
  }

  // Plug/unplug events trigger an immediate re-check so cadence switches at once.
  final stateSub = battery.onBatteryStateChanged.listen((_) {
    nextCheck?.cancel();
    runCheck();
  });

  service.on('update_settings').listen((event) {
    if (event == null) return;
    settings.applyEvent(Map<String, dynamic>.from(event));
    chargeAlertFired = false;
    dischargeAlertFired = false;
    nextCheck?.cancel();
    runCheck();
  });

  service.on('test_alarm').listen((event) async {
    await _alert(notifications, player, settings,
        title: 'Test alarm',
        body: 'This is what a battery alarm looks and sounds like.');
  });

  service.on('stop_service').listen((event) async {
    nextCheck?.cancel();
    await stateSub.cancel();
    await player.dispose();
    service.stopSelf();
  });

  if (service is AndroidServiceInstance) {
    service.setForegroundNotificationInfo(
      title: 'Battery Alarm',
      content: 'Monitoring battery level...',
    );
  }

  runCheck();
}

Future<void> _initNotifications(FlutterLocalNotificationsPlugin plugin) async {
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  await plugin.initialize(const InitializationSettings(android: androidInit));

  final android = plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();

  await android?.createNotificationChannel(const AndroidNotificationChannel(
    _monitorChannelId,
    _monitorChannelName,
    description: 'Persistent notification while monitoring battery',
    importance: Importance.low,
  ));
  await android?.createNotificationChannel(const AndroidNotificationChannel(
    _alarmChannelId,
    _alarmChannelName,
    description: 'Charge/discharge alarms',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  ));
  await android?.createNotificationChannel(const AndroidNotificationChannel(
    _silentChannelId,
    _silentChannelName,
    description: 'Charge/discharge alarms during quiet hours',
    importance: Importance.low,
    playSound: false,
    enableVibration: false,
  ));
}

/// Fires an alert respecting quiet hours and the volume-override setting.
Future<void> _alert(
  FlutterLocalNotificationsPlugin plugin,
  AudioPlayer player,
  _Settings s, {
  required String title,
  required String body,
}) async {
  final quiet = s.inQuietHours;
  final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

  if (quiet) {
    // Silent visual-only notification during night hours.
    await plugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _silentChannelId,
          _silentChannelName,
          importance: Importance.low,
          priority: Priority.low,
          playSound: false,
          enableVibration: false,
          autoCancel: true,
        ),
      ),
    );
    return;
  }

  // Non-quiet: ALWAYS ring through the system alarm channel. A max-importance
  // notification reliably plays sound + vibrates from a background isolate,
  // which a background AudioPlayer often does NOT. This is the guaranteed
  // sound path.
  await plugin.show(
    id,
    title,
    body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        _alarmChannelId,
        _alarmChannelName,
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        autoCancel: true,
        visibility: NotificationVisibility.public,
      ),
    ),
  );

  // Best-effort extra: if the user wants a louder/volume-controlled tone, also
  // try the audio player. If it stays silent in the background (common), the
  // alarm-channel notification above has already made noise, so we're covered.
  if (s.volumeOverride) {
    try {
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setVolume(s.alarmVolume.clamp(0.0, 1.0));
      await player.play(AssetSource('alarm.wav'));
    } catch (_) {
      // Ignore — notification sound already fired.
    }
  }
}
