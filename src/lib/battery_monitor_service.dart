import 'dart:async';
import 'dart:ui';

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
const String kAlarmSoundKey = 'alarm_sound';

/// A selectable alarm sound. Each option uses its OWN notification channel,
/// because Android locks a channel's sound at the moment it is first created —
/// you cannot change it afterwards. So to offer several sounds we pre-create one
/// channel per option and simply post the alarm on whichever channel the user
/// picked. The sounds are the phone's own built-in system sounds (no bundled
/// audio), played on the ALARM stream so they are loud and audible even when the
/// ringer is on silent/vibrate.
class AlarmSoundOption {
  final String id;
  final String label;
  final String channelId;
  final AndroidNotificationSound? sound; // null => channel default beep

  const AlarmSoundOption({
    required this.id,
    required this.label,
    required this.channelId,
    this.sound,
  });

  String get channelName => 'Battery Alarms — $label';
}

/// The standard Android system-sound content URIs (Settings.System defaults).
const List<AlarmSoundOption> kAlarmSounds = [
  AlarmSoundOption(
    id: 'alarm',
    label: 'Alarm (loudest)',
    channelId: 'battery_alarm_snd_alarm',
    sound: UriAndroidNotificationSound('content://settings/system/alarm_alert'),
  ),
  AlarmSoundOption(
    id: 'ringtone',
    label: 'Ringtone',
    channelId: 'battery_alarm_snd_ringtone',
    sound: UriAndroidNotificationSound('content://settings/system/ringtone'),
  ),
  AlarmSoundOption(
    id: 'notification',
    label: 'Notification tone',
    channelId: 'battery_alarm_snd_notif',
    sound: UriAndroidNotificationSound(
        'content://settings/system/notification_sound'),
  ),
  AlarmSoundOption(
    id: 'default',
    label: 'Default beep',
    channelId: _alarmChannelId, // back-compat: reuse battery_alarm_v2
  ),
];

/// Out of the box, use the (loud) alarm tone — that is what users expect from a
/// "battery alarm" and what they have been asking for.
const String kDefaultAlarmSoundId = 'alarm';

AlarmSoundOption alarmSoundById(String? id) => kAlarmSounds.firstWhere(
      (o) => o.id == id,
      orElse: () =>
          kAlarmSounds.firstWhere((o) => o.id == kDefaultAlarmSoundId),
    );

/// Creates every notification channel the app uses. MUST run in the UI isolate
/// BEFORE the background service is ever started: flutter_background_service
/// posts its foreground notification on [_monitorChannelId] natively the moment
/// the service starts, and if that channel doesn't exist yet Android kills the
/// whole app with "Bad notification for startForeground" (RemoteServiceException).
/// Safe to call repeatedly; re-creating an existing channel is a no-op.
Future<void> createAllNotificationChannels(
    FlutterLocalNotificationsPlugin plugin) async {
  final android = plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  await android?.createNotificationChannel(const AndroidNotificationChannel(
    _monitorChannelId,
    _monitorChannelName,
    description: 'Persistent notification while monitoring battery',
    importance: Importance.low,
  ));
  await createAlarmSoundChannels(android);
  await android?.createNotificationChannel(const AndroidNotificationChannel(
    _silentChannelId,
    _silentChannelName,
    description: 'Charge/discharge alarms during quiet hours',
    importance: Importance.low,
    playSound: false,
    enableVibration: false,
  ));
}

/// Creates one max-importance, alarm-stream channel per selectable sound. Safe
/// to call repeatedly; re-creating an existing channel id is a no-op on Android.
Future<void> createAlarmSoundChannels(
    AndroidFlutterLocalNotificationsPlugin? android) async {
  for (final o in kAlarmSounds) {
    await android?.createNotificationChannel(AndroidNotificationChannel(
      o.channelId,
      o.channelName,
      description: 'Charge/discharge alarms (${o.label})',
      importance: Importance.max,
      playSound: true,
      sound: o.sound,
      enableVibration: true,
      // Play on the ALARM stream so it's audible even on vibrate/silent and
      // uses the alarm volume rather than the (often low) notification volume.
      audioAttributesUsage: AudioAttributesUsage.alarm,
    ));
  }
}

const String _monitorChannelId = 'battery_monitor_channel';
const String _monitorChannelName = 'Battery Monitor';
// v2: new id so the alarm-stream audio setting takes effect on updated installs
// (channel settings are locked once a channel id is first created).
const String _alarmChannelId = 'battery_alarm_v2';
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
  String alarmSoundId = kDefaultAlarmSoundId;

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
    alarmSoundId = p.getString(kAlarmSoundKey) ?? alarmSoundId;
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
    alarmSoundId = e['alarmSound'] as String? ?? alarmSoundId;
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

  final battery = Battery();
  final settings = _Settings();

  final prefs = await SharedPreferences.getInstance();
  settings.loadFrom(prefs);

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
        await _alert(notifications, settings,
            title: 'Unplug your charger',
            body: 'Battery is at $level%. Unplugging now helps battery health.');
      } else if (level < settings.charge - 3) {
        chargeAlertFired = false;
      }
    } else {
      chargeAlertFired = false;
      if (level <= settings.discharge && !dischargeAlertFired) {
        dischargeAlertFired = true;
        await _alert(notifications, settings,
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
    await _alert(notifications, settings,
        title: 'Test alarm',
        body: 'This is what a battery alarm looks and sounds like.');
  });

  service.on('stop_service').listen((event) async {
    nextCheck?.cancel();
    await stateSub.cancel();
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
  // Channels are created in the UI isolate before the service can start; this
  // re-create is a harmless no-op that covers boot-time starts too.
  await createAllNotificationChannels(plugin);
}

/// Fires an alert respecting quiet hours. The system alarm-channel notification
/// is the sound source (reliable from a background isolate).
Future<void> _alert(
  FlutterLocalNotificationsPlugin plugin,
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

  // Non-quiet: ring through the user-selected alarm-sound channel (max
  // importance reliably plays sound + vibrates from a background isolate).
  final opt = alarmSoundById(s.alarmSoundId);
  await plugin.show(
    id,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        opt.channelId,
        opt.channelName,
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        sound: opt.sound,
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        autoCancel: true,
        visibility: NotificationVisibility.public,
      ),
    ),
  );
}
