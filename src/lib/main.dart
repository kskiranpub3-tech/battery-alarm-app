import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'battery_info.dart';
import 'battery_monitor_service.dart';

final FlutterLocalNotificationsPlugin _uiNotifications =
    FlutterLocalNotificationsPlugin();

Future<void> _initUiNotifications() async {
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  await _uiNotifications
      .initialize(const InitializationSettings(android: androidInit));
  final android = _uiNotifications.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  await android?.createNotificationChannel(const AndroidNotificationChannel(
    'battery_alarm_channel',
    'Battery Alarms',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  ));
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeBackgroundService();
  await _initUiNotifications();
  runApp(const BatteryAlarmApp());
}

class BatteryAlarmApp extends StatelessWidget {
  const BatteryAlarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Battery Alarm',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double _charge = 80;
  double _discharge = 20;
  bool _monitoring = false;
  int _dischargeInterval = 30;
  bool _quietEnabled = false;
  TimeOfDay _quietStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _quietEnd = const TimeOfDay(hour: 7, minute: 0);
  bool _volumeOverride = true;
  double _alarmVolume = 0.8;
  bool _serviceRunning = false;
  bool _loaded = false;
  BatteryInfo? _info;
  Timer? _infoTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshServiceStatus();
    _pollInfo();
    _infoTimer =
        Timer.periodic(const Duration(seconds: 3), (_) => _pollInfo());
  }

  @override
  void dispose() {
    _infoTimer?.cancel();
    super.dispose();
  }

  Future<void> _pollInfo() async {
    final info = await readBatteryInfo();
    if (mounted) setState(() => _info = info);
  }

  Future<void> _refreshServiceStatus() async {
    final running = await FlutterBackgroundService().isRunning();
    if (mounted) setState(() => _serviceRunning = running);
  }

  Future<void> _restartService() async {
    final service = FlutterBackgroundService();
    try {
      if (await service.isRunning()) {
        service.invoke('stop_service');
        await Future.delayed(const Duration(milliseconds: 800));
      }
      await Permission.notification.request();
      await service.startService();
      await Future.delayed(const Duration(milliseconds: 800));
      _pushSettings();
      setState(() => _monitoring = true);
      await _save();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Restart failed: $e')));
      }
    }
    await _refreshServiceStatus();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_serviceRunning
              ? 'Service restarted and running'
              : 'Service did not start — check battery settings below'),
        ),
      );
    }
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _charge = p.getDouble(kChargeThresholdKey) ?? 80;
      _discharge = p.getDouble(kDischargeThresholdKey) ?? 20;
      _monitoring = p.getBool(kMonitoringEnabledKey) ?? false;
      _dischargeInterval = p.getInt(kDischargeIntervalKey) ?? 30;
      _quietEnabled = p.getBool(kQuietEnabledKey) ?? false;
      _quietStart = TimeOfDay(
        hour: p.getInt(kQuietStartHourKey) ?? 22,
        minute: p.getInt(kQuietStartMinKey) ?? 0,
      );
      _quietEnd = TimeOfDay(
        hour: p.getInt(kQuietEndHourKey) ?? 7,
        minute: p.getInt(kQuietEndMinKey) ?? 0,
      );
      _volumeOverride = p.getBool(kVolumeOverrideKey) ?? true;
      _alarmVolume = p.getDouble(kAlarmVolumeKey) ?? 0.8;
      _loaded = true;
    });
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble(kChargeThresholdKey, _charge);
    await p.setDouble(kDischargeThresholdKey, _discharge);
    await p.setBool(kMonitoringEnabledKey, _monitoring);
    await p.setInt(kDischargeIntervalKey, _dischargeInterval);
    await p.setBool(kQuietEnabledKey, _quietEnabled);
    await p.setInt(kQuietStartHourKey, _quietStart.hour);
    await p.setInt(kQuietStartMinKey, _quietStart.minute);
    await p.setInt(kQuietEndHourKey, _quietEnd.hour);
    await p.setInt(kQuietEndMinKey, _quietEnd.minute);
    await p.setBool(kVolumeOverrideKey, _volumeOverride);
    await p.setDouble(kAlarmVolumeKey, _alarmVolume);
  }

  void _pushSettings() {
    FlutterBackgroundService().invoke('update_settings', {
      'charge': _charge,
      'discharge': _discharge,
      'dischargeInterval': _dischargeInterval,
      'quietEnabled': _quietEnabled,
      'quietStartHour': _quietStart.hour,
      'quietStartMin': _quietStart.minute,
      'quietEndHour': _quietEnd.hour,
      'quietEndMin': _quietEnd.minute,
      'volumeOverride': _volumeOverride,
      'alarmVolume': _alarmVolume,
    });
  }

  Future<void> _commit() async {
    await _save();
    if (_monitoring) _pushSettings();
  }

  Future<void> _toggleMonitoring(bool value) async {
    // Persist intent FIRST, so the service (which reads this flag on start, and
    // self-stops if it's false on boot) sees the correct value.
    setState(() => _monitoring = value);
    await _save();
    if (value) {
      await Permission.notification.request();
    }
    final service = FlutterBackgroundService();
    try {
      if (value) {
        if (!await service.isRunning()) {
          await service.startService();
        }
        await Future.delayed(const Duration(milliseconds: 600));
        _pushSettings();
      } else {
        service.invoke('stop_service');
      }
      await _refreshServiceStatus();
    } catch (e) {
      setState(() => _monitoring = false);
      await _save();
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Could not start monitoring'),
            content: Text('$e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _sendTestAlarm() async {
    // Fire directly from the UI isolate so it works regardless of whether the
    // background service is running, and is always audible (not silenced by
    // quiet hours, which only applies to real monitoring alarms).
    await Permission.notification.request();
    await _uiNotifications.show(
      99,
      'Test alarm',
      'This is what a battery alarm sounds like.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'battery_alarm_channel',
          'Battery Alarms',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
          category: AndroidNotificationCategory.alarm,
          autoCancel: true,
        ),
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test alarm sent')),
      );
    }
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _quietStart : _quietEnd,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _quietStart = picked;
        } else {
          _quietEnd = picked;
        }
      });
      await _commit();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Battery Alarm')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card([
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable battery alarm'),
              subtitle: const Text('Runs as a background service'),
              value: _monitoring,
              onChanged: _toggleMonitoring,
            ),
          ]),
          _card([
            Text('Charge alarm: ${_charge.round()}%', style: _label),
            const Text('Alerts you to unplug at this level while charging',
                style: _hint),
            Slider(
              value: _charge,
              min: 50,
              max: 100,
              divisions: 50,
              label: '${_charge.round()}%',
              onChanged: (v) => setState(() => _charge = v),
              onChangeEnd: (_) => _commit(),
            ),
            const SizedBox(height: 8),
            Text('Discharge alarm: ${_discharge.round()}%', style: _label),
            const Text('Alerts you to plug in at this level while unplugged',
                style: _hint),
            Slider(
              value: _discharge,
              min: 5,
              max: 50,
              divisions: 45,
              label: '${_discharge.round()}%',
              onChanged: (v) => setState(() => _discharge = v),
              onChangeEnd: (_) => _commit(),
            ),
          ]),
          _buildStatusCard(),
          _card([
            const Text('Battery-saving check interval', style: _label),
            const Text(
              'While charging the phone is on wall power, so it always checks '
              'every 2 min to catch your cutoff. This sets how often it checks '
              'while running on battery.',
              style: _hint,
            ),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 15, label: Text('15 min')),
                ButtonSegment(value: 30, label: Text('30 min')),
                ButtonSegment(value: 60, label: Text('60 min')),
              ],
              selected: {_dischargeInterval},
              onSelectionChanged: (s) {
                setState(() => _dischargeInterval = s.first);
                _commit();
              },
            ),
          ]),
          _card([
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Quiet hours (silent at night)'),
              subtitle:
                  const Text('No sound during this window — silent alert only'),
              value: _quietEnabled,
              onChanged: (v) {
                setState(() => _quietEnabled = v);
                _commit();
              },
            ),
            if (_quietEnabled)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickTime(true),
                      child: Text('From ${_quietStart.format(context)}'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickTime(false),
                      child: Text('To ${_quietEnd.format(context)}'),
                    ),
                  ),
                ],
              ),
          ]),
          _card([
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Override volume'),
              subtitle: const Text(
                  'Play the alarm at a fixed level, heard even on silent'),
              value: _volumeOverride,
              onChanged: (v) {
                setState(() => _volumeOverride = v);
                _commit();
              },
            ),
            if (_volumeOverride) ...[
              Text('Alarm volume: ${(_alarmVolume * 100).round()}%',
                  style: _label),
              Slider(
                value: _alarmVolume,
                min: 0.1,
                max: 1.0,
                divisions: 9,
                label: '${(_alarmVolume * 100).round()}%',
                onChanged: (v) => setState(() => _alarmVolume = v),
                onChangeEnd: (_) => _commit(),
              ),
            ],
          ]),
          _card([
            Row(
              children: [
                Icon(
                  _serviceRunning ? Icons.check_circle : Icons.cancel,
                  color: _serviceRunning ? Colors.green : Colors.redAccent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _serviceRunning ? 'Service: running' : 'Service: stopped',
                  style: _label,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh status',
                  onPressed: _refreshServiceStatus,
                ),
              ],
            ),
            if (_monitoring && !_serviceRunning)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Monitoring is enabled but the background service is not '
                  'running — your phone may have stopped it. Restart it and '
                  'make sure battery optimization is disabled below.',
                  style: TextStyle(fontSize: 12, color: Colors.orangeAccent),
                ),
              ),
            const Text(
              'If alarms stop firing, restart the service and check the '
              'reliability settings below.',
              style: _hint,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _restartService,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Restart service'),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      Permission.ignoreBatteryOptimizations.request(),
                  icon: const Icon(Icons.battery_saver),
                  label: const Text('Allow background'),
                ),
                OutlinedButton.icon(
                  onPressed: openAppSettings,
                  icon: const Icon(Icons.settings),
                  label: const Text('App settings'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Some brands (Xiaomi, OnePlus, Samsung, Oppo, Vivo) need extra '
              'steps like enabling Autostart and locking the app in Recents. '
              'See dontkillmyapp.com for your exact phone.',
              style: _hint,
            ),
          ]),
          OutlinedButton(
            onPressed: _sendTestAlarm,
            child: const Text('Send test alarm'),
          ),
          const SizedBox(height: 12),
          const Text(
            'For reliable background operation, set this app to Unrestricted '
            'battery usage: Settings > Apps > Battery Alarm > Battery.',
            style: _hint,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final info = _info;
    String fmt(double? v, String unit, {int dp = 1}) =>
        v == null ? '—' : '${v.toStringAsFixed(dp)}$unit';

    final capped = info?.chargingLikelyCapped ?? false;

    return _card([
      Row(
        children: [
          const Text('Battery status', style: _label),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.info_outline, size: 20),
            tooltip: 'About native limits',
            onPressed: _showLimitsInfo,
          ),
        ],
      ),
      if (info == null)
        const Text(
          'Live readings are not available on this device.',
          style: _hint,
        )
      else
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _stat('Temp', fmt(info.temperatureC, '°C')),
            _stat('Voltage', fmt(info.voltageV, ' V', dp: 2)),
            _stat(
                'Current',
                info.currentMa == null
                    ? '—'
                    : '${info.currentMa!.abs().toStringAsFixed(0)} mA'),
            _stat('Health', info.healthText),
          ],
        ),
      if (capped) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            '⚠️ Charging looks paused while plugged in. A built-in battery '
            'protection / charge-limit feature, or a weak cable or charger, may '
            'be capping it. If your charge alarm is set above this level, it '
            'may not fire. Tap ⓘ to learn more.',
            style: TextStyle(fontSize: 12, color: Colors.orangeAccent),
          ),
        ),
      ],
    ]);
  }

  Widget _stat(String label, String value) => Column(
        children: [
          Text(value,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          Text(label, style: _hint),
        ],
      );

  void _showLimitsInfo() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Native features & cables'),
        content: const SingleChildScrollView(
          child: Text(
            'Your phone and accessories can limit what this app can do:\n\n'
            '• Built-in charge limits / battery protection (e.g. "limit to '
            '80%", adaptive charging) make the phone stop charging at a set '
            'level. If that cap is below your charge alarm, the alarm may '
            'never trigger — the phone simply won\'t reach your %.\n\n'
            '• These native caps can themselves be inconsistent (some phones '
            'still charge to 100% when warm, or periodically for calibration).\n\n'
            '• A weak or damaged cable/charger, or a dirty port, can slow or '
            'pause charging, which also affects when alarms fire.\n\n'
            'This app reads battery state but cannot turn these native features '
            'on or off. If alarms don\'t behave as expected, check your phone\'s '
            'battery/charging settings and try a different cable.',
            style: TextStyle(fontSize: 13),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _card(List<Widget> children) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: children),
        ),
      );

  static const _label = TextStyle(fontSize: 16, fontWeight: FontWeight.w600);
  static const _hint = TextStyle(fontSize: 12, color: Colors.grey);
}
