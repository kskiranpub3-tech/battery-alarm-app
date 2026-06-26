import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ads.dart';
import 'battery_monitor_service.dart';
import 'purchase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeBackgroundService();
  await initAds();
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
  bool _isPro = false;
  bool _loaded = false;
  final PurchaseService _purchases = PurchaseService();

  @override
  void initState() {
    super.initState();
    _load();
    _initPurchases();
  }

  Future<void> _initPurchases() async {
    // When a purchase/restore completes, reflect it in the UI immediately.
    _purchases.isPro.addListener(() {
      if (_purchases.isPro.value && mounted) {
        setState(() => _isPro = true);
      }
    });
    _purchases.status.addListener(() {
      if (mounted) setState(() {});
    });
    await _purchases.init();
  }

  @override
  void dispose() {
    _purchases.dispose();
    super.dispose();
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
      _isPro = p.getBool(kProTierKey) ?? false;
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
      // Give the isolate a moment to spin up before pushing settings.
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
      bottomNavigationBar: _isPro
          ? null
          : const SafeArea(
              child: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: AdBanner(),
              ),
            ),
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
            Text('Charge alarm: ${_charge.round()}%',
                style: _label),
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
              subtitle: const Text('No sound during this window — silent alert only'),
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
                  _isPro ? Icons.workspace_premium : Icons.volunteer_activism,
                  color: _isPro ? Colors.amber : Colors.teal,
                ),
                const SizedBox(width: 8),
                Text(_isPro ? 'Pro (ad-free)' : 'Free (ad-supported)',
                    style: _label),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _isPro
                  ? 'Thanks for going Pro. Ads are disabled.'
                  : 'The free version is supported by a single banner ad on this '
                      'screen. Go Pro to remove it (and, in the full product, '
                      'unlock history graphs, widgets and custom alarms).',
              style: _hint,
            ),
            const SizedBox(height: 8),
            if (!_isPro) ..._buyControls() else _proControls(),
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

  List<Widget> _buyControls() {
    final status = _purchases.status.value;
    final product = _purchases.product.value;
    final busy = status == PurchaseStatusUi.pending ||
        status == PurchaseStatusUi.loading;

    final priceLabel = product != null
        ? 'Go Pro — ${product.price}'
        : 'Go Pro — remove ads';

    return [
      FilledButton.icon(
        onPressed: busy ? null : () => _purchases.buyPro(),
        icon: busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.lock_open),
        label: Text(status == PurchaseStatusUi.pending
            ? 'Processing...'
            : priceLabel),
      ),
      TextButton(
        onPressed: busy ? null : () => _purchases.restore(),
        child: const Text('Restore purchase'),
      ),
      if (status == PurchaseStatusUi.unavailable)
        const Text(
          'In-app billing isn\'t available on this build yet. It works once '
          'the app is signed and uploaded to a Play testing track with the '
          'product configured. See README.',
          style: _hint,
        ),
      if (status == PurchaseStatusUi.error &&
          _purchases.lastError.value != null)
        Text('Error: ${_purchases.lastError.value}', style: _hint),
    ];
  }

  Widget _proControls() {
    return TextButton(
      onPressed: () => _purchases.restore(),
      child: const Text('Restore / re-check purchase'),
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
