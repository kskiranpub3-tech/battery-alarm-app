package com.example.battery_alarm_app

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// Adds a "battery_info" method channel that returns temperature, voltage and
/// instantaneous current — values that battery_plus does not expose. These are
/// read straight from the sticky ACTION_BATTERY_CHANGED broadcast and from
/// BatteryManager, so no extra plugin is needed.
class MainActivity : FlutterActivity() {
    private val channelName = "battery_info"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "getBatteryInfo") {
                    result.success(readBatteryInfo())
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun readBatteryInfo(): Map<String, Any?> {
        val bm = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        val status: Intent? =
            registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))

        val tempTenths = status?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, -1) ?: -1
        val voltageMv = status?.getIntExtra(BatteryManager.EXTRA_VOLTAGE, -1) ?: -1
        val batStatus = status?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
        val plugged = status?.getIntExtra(BatteryManager.EXTRA_PLUGGED, -1) ?: -1
        val health = status?.getIntExtra(BatteryManager.EXTRA_HEALTH, -1) ?: -1
        val technology = status?.getStringExtra(BatteryManager.EXTRA_TECHNOLOGY)

        // Instantaneous current in microamperes (sign varies by device).
        val currentNowUa = try {
            bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CURRENT_NOW)
        } catch (e: Exception) {
            Int.MIN_VALUE
        }

        val map = HashMap<String, Any?>()
        map["temperature"] = if (tempTenths > 0) tempTenths / 10.0 else null
        map["voltage"] = if (voltageMv > 0) voltageMv / 1000.0 else null
        map["currentMa"] =
            if (currentNowUa != Int.MIN_VALUE && currentNowUa != 0) currentNowUa / 1000.0 else null
        map["status"] = batStatus
        map["plugged"] = plugged
        map["health"] = health
        map["technology"] = technology
        return map
    }
}
