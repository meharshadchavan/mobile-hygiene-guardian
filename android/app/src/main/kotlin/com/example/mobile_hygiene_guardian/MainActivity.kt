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
import java.text.SimpleDateFormat
import java.util.Locale

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.mobile.hygiene.guardian/hygiene"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Request POST_NOTIFICATIONS on Android 13+ (API 33+) so install watchdog alerts work
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 101)
            }
        }

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

    private fun getActiveAccessibilityPackages(): Set<String> {
        val enabledServices = try {
            Settings.Secure.getString(
                contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            )
        } catch (e: Exception) {
            null
        } ?: return emptySet()

        val activePackages = mutableSetOf<String>()
        val colonSplitter = enabledServices.split(":")
        for (componentString in colonSplitter) {
            val component = android.content.ComponentName.unflattenFromString(componentString)
            if (component != null) {
                activePackages.add(component.packageName)
            }
        }
        return activePackages
    }

    private fun scanInstalledApps(): List<Map<String, Any>> {
        val pm = packageManager
        val packages = pm.getInstalledPackages(PackageManager.GET_PERMISSIONS)
        val suspiciousApps = mutableListOf<Map<String, Any>>()
        val activeAccessibilityPackages = getActiveAccessibilityPackages()

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

            // Allowlist of known legitimate installer package names.
            // Any installer NOT on this list (including null) is treated as sideloaded.
            val legitimateInstallers = setOf(
                "com.android.vending",          // Google Play Store
                "com.amazon.venezia",            // Amazon Appstore
                "com.sec.android.app.samsungapps", // Samsung Galaxy Store
                "com.huawei.appmarket",          // Huawei AppGallery
                "org.fdroid.fdroid",             // F-Droid
                "com.aurora.store"               // Aurora Store (FOSS Play client)
            )
            val isSideloaded = installer == null || installer !in legitimateInstallers

            val requestedPermissions = pkg.requestedPermissions?.toList() ?: emptyList()
            val hasAccessibility = requestedPermissions.contains("android.permission.BIND_ACCESSIBILITY_SERVICE") || activeAccessibilityPackages.contains(pkg.packageName)
            val hasOverlay = requestedPermissions.contains("android.permission.SYSTEM_ALERT_WINDOW")
            val hasSms = requestedPermissions.contains("android.permission.RECEIVE_SMS") || requestedPermissions.contains("android.permission.READ_SMS")
            val hasLocation = requestedPermissions.contains("android.permission.ACCESS_FINE_LOCATION")
            val hasBootCompleted = requestedPermissions.contains("android.permission.RECEIVE_BOOT_COMPLETED")
            val hasIgnoreBatteryOpt = requestedPermissions.contains("android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS")
            val hasForegroundService = requestedPermissions.any { it.startsWith("android.permission.FOREGROUND_SERVICE") }
            val hasBackgroundService = isSideloaded && (hasBootCompleted || hasIgnoreBatteryOpt || hasForegroundService)

            if (isSideloaded || hasAccessibility || hasOverlay || hasSms || hasBackgroundService) {
                val appMap = mapOf(
                    "packageName" to pkg.packageName,
                    "appName" to pm.getApplicationLabel(pkg.applicationInfo).toString(),
                    "isSideloaded" to isSideloaded,
                    "installerSource" to (installer ?: "Unknown/Sideloaded"),
                    "hasAccessibility" to hasAccessibility,
                    "hasOverlay" to hasOverlay,
                    "hasSms" to hasSms,
                    "hasLocation" to hasLocation,
                    "hasBackgroundService" to hasBackgroundService
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

        val securityPatch = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) Build.VERSION.SECURITY_PATCH else "Unknown"
        var isPatchOutdated = false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && securityPatch.length >= 7) {
            try {
                val sdf = SimpleDateFormat("yyyy-MM-dd", Locale.US)
                val patchDate = sdf.parse(securityPatch)
                if (patchDate != null) {
                    val daysSincePatch = (System.currentTimeMillis() - patchDate.time) / (1000 * 60 * 60 * 24)
                    if (daysSincePatch > 180) {
                        isPatchOutdated = true
                    }
                }
            } catch (e: Exception) { }
        }

        return mapOf(
            "devOptionsEnabled" to devOptionsOn,
            "usbDebuggingEnabled" to usbDebuggingOn,
            "isDeviceSecure" to isDeviceSecure,
            "isRooted" to isRooted,
            "securityPatch" to securityPatch,
            "isPatchOutdated" to isPatchOutdated
        )
    }

    private fun scanNetworkSecurity(): Map<String, Any> {
        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val activeNetwork = cm.activeNetwork
        val caps = cm.getNetworkCapabilities(activeNetwork)

        val isVpnActive = caps?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) ?: false
        val isWifi = caps?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ?: false

        val proxyInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            cm.getLinkProperties(activeNetwork)?.httpProxy
        } else {
            null
        }
        val isProxyActive = proxyInfo != null && !proxyInfo.host.isNullOrEmpty()

        var isOpenWifi = false
        if (isWifi && caps != null) {
            // If Wi-Fi capabilities lack TRUSTED or captive portal capabilities, flag open Wi-Fi
            val isCaptive = caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_CAPTIVE_PORTAL)
            val isNotTrusted = !caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_TRUSTED)
            if (isCaptive || isNotTrusted) {
                isOpenWifi = true
            }
        }

        return mapOf(
            "isWifi" to isWifi,
            "isVpnActive" to isVpnActive,
            "isProxyActive" to isProxyActive,
            "isOpenWifi" to isOpenWifi
        )
    }

    private fun checkRoot(): Boolean {
        // 1. File-system checks for su binary (bypassed by Magisk with DenyList,
        //    but catches basic/older root methods)
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

        // 2. Known root manager package detection (catches Magisk, SuperSU, KernelSU)
        val rootPackages = listOf(
            "com.topjohnwu.magisk",
            "eu.chainfire.supersu",
            "com.koushikdutta.superuser",
            "me.weishu.kernelsu",
            "com.noshufou.android.su"
        )
        for (pkg in rootPackages) {
            try {
                packageManager.getPackageInfo(pkg, 0)
                return true // Package found → rooted
            } catch (e: Exception) { /* not installed */ }
        }

        // 3. su execution attempt (catches Magisk without DenyList)
        return try {
            val process = Runtime.getRuntime().exec(arrayOf("which", "su"))
            process.waitFor() == 0
        } catch (e: Exception) {
            false
        }
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
