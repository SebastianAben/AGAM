package site.agam

import android.content.Context
import android.content.Intent
import android.os.PowerManager
import android.provider.Settings
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Activity utama. Turunan AudioServiceActivity agar narasi dapat dikendalikan
 * dari notifikasi dan lock screen (audio_service).
 *
 * Channel `site.agam/battery` dipakai PermissionService (PB02) untuk membaca
 * status optimasi baterai dan membuka daftar pengaturannya. Tidak meminta izin
 * REQUEST_IGNORE_BATTERY_OPTIMIZATIONS; pengguna memilih sendiri di pengaturan.
 */
class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "site.agam/battery")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isIgnoringBatteryOptimizations" -> {
                        val power = getSystemService(Context.POWER_SERVICE) as PowerManager
                        result.success(power.isIgnoringBatteryOptimizations(packageName))
                    }
                    "openBatteryOptimizationSettings" -> {
                        try {
                            startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
