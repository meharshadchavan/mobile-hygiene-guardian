package com.example.mobile_hygiene_guardian

import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.kanad.shield/hygiene"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "scanDeviceHygiene" -> {
                    val report = runFullHygieneAudit()
                    result.success(report)
                }
                "openRemediationIntent" -> {
                    val target = call.argument<String>("target")
                    val packageName = call.argument<String>("packageName")
                    val status = launchRemediation(target, packageName)
                    result.success(status)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun runFullHygieneAudit(): Map<String, Any> {
        val appList = scanInstalledApps()
        val osSecurity = scanOSSecurity()
        val networkSecurity = scanNetworkSecurity()

        return mapOf(
            "apps" to appList,
            "osSecurity" to osSecurity,
            "network" to networkSecurity,
            "timestamp" to System.currentTimeMillis()
        )
    }

    private fun scanInstalledApps(): List<Map<String, Any>> {
        val pm = packageManager
        val packages = pm.getInstalledPackages(PackageManager.GET_PERMISSIONS)
        val suspiciousApps = mutableListOf<Map<String, Any>>()

        for (pkg in packages) {
            val isSystemApp = (pkg.applicationInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0
            if (isSystemApp) continue

            val installer = try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    pm.getInstallSourceInfo(pkg.packageName).installingPackageName
                } else {
                    @Suppress("DEPRECATION")
                    pm.getInstallerPackageName(pkg.packageName)
                }
            } catch (e: Exception) { null }

            val isSideloaded = installer == null || installer != "com.android.vending"

            val requestedPermissions = pkg.requestedPermissions?.toList() ?: emptyList()
            val hasAccessibility = requestedPermissions.contains("android.permission.BIND_ACCESSIBILITY_SERVICE")
            val hasOverlay = requestedPermissions.contains("android.permission.SYSTEM_ALERT_WINDOW")
            val hasSms = requestedPermissions.contains("android.permission.RECEIVE_SMS") || requestedPermissions.contains("android.permission.READ_SMS")
            val hasLocation = requestedPermissions.contains("android.permission.ACCESS_FINE_LOCATION")

            if (isSideloaded || hasAccessibility || hasOverlay || hasSms) {
                val appMap = mapOf(
                    "packageName" to pkg.packageName,
                    "appName" to pm.getApplicationLabel(pkg.applicationInfo).toString(),
                    "isSideloaded" to isSideloaded,
                    "installerSource" to (installer ?: "Unknown/Sideloaded"),
                    "hasAccessibility" to hasAccessibility,
                    "hasOverlay" to hasOverlay,
                    "hasSms" to hasSms,
                    "hasLocation" to hasLocation
                )
                suspiciousApps.add(appMap)
            }
        }
        return suspiciousApps
    }

    private fun scanOSSecurity(): Map<String, Any> {
        val contentResolver = context.contentResolver

        val devOptionsOn = Settings.Global.getInt(contentResolver, Settings.Global.DEVELOPMENT_SETTINGS_ENABLED, 0) == 1
        val usbDebuggingOn = Settings.Global.getInt(contentResolver, Settings.Global.ADB_ENABLED, 0) == 1

        val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        val isDeviceSecure = keyguardManager.isDeviceSecure

        val isRooted = checkRoot()

        return mapOf(
            "devOptionsEnabled" to devOptionsOn,
            "usbDebuggingEnabled" to usbDebuggingOn,
            "isDeviceSecure" to isDeviceSecure,
            "isRooted" to isRooted
        )
    }

    private fun scanNetworkSecurity(): Map<String, Any> {
        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val activeNetwork = cm.activeNetwork
        val caps = cm.getNetworkCapabilities(activeNetwork)

        val isVpnActive = caps?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) ?: false
        val isWifi = caps?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ?: false

        val proxyHost = System.getProperty("http.proxyHost")
        val isProxyActive = !proxyHost.isNullOrEmpty()

        return mapOf(
            "isWifi" to isWifi,
            "isVpnActive" to isVpnActive,
            "isProxyActive" to isProxyActive
        )
    }

    private fun checkRoot(): Boolean {
        val buildTags = Build.TAGS
        if (buildTags != null && buildTags.contains("test-keys")) return true

        val paths = arrayOf(
            "/system/app/Superuser.apk",
            "/sbin/su",
            "/system/bin/su",
            "/system/xbin/su",
            "/data/local/xbin/su",
            "/data/local/bin/su",
            "/system/sd/xbin/su",
            "/system/bin/failsafe/su",
            "/data/local/su"
        )
        for (path in paths) {
            if (File(path).exists()) return true
        }
        return false
    }

    private fun launchRemediation(target: String?, packageName: String?): Boolean {
        return try {
            val intent = when (target) {
                "DEVELOPMENT_SETTINGS" -> Intent(Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS)
                "SECURITY_SETTINGS" -> Intent(Settings.ACTION_SECURITY_SETTINGS)
                "ACCESSIBILITY_SETTINGS" -> Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                "APP_DETAILS" -> {
                    Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                        data = Uri.fromParts("package", packageName ?: "", null)
                    }
                }
                else -> Intent(Settings.ACTION_SETTINGS)
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }
}
