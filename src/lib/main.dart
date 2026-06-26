import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'battery_monitor_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeBackgroundService();
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
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
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
    if (value) {
      await Permission.notification.request();
    }
    setState(() => _monitoring = value);
    await _save();
    final service = FlutterBackgroundService();
    if (value) {
      if (!await service.isRunning()) {
        await service.startService();
      }
      await Future.delayed(const Duration(milliseconds: 600));
      _pushSettings();
    } else {
      service.invoke('stop_service');
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
          OutlinedButton(
            onPressed: () => FlutterBackgroundService().invoke('test_alarm'),
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


