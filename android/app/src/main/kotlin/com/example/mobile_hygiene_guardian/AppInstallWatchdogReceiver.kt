package com.example.mobile_hygiene_guardian

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat

class AppInstallWatchdogReceiver : BroadcastReceiver() {

    private val CHANNEL_ID = "hygiene_security_alerts"
    private val CHANNEL_NAME = "Mobile Hygiene Security Alerts"

    private val legitimateInstallers = setOf(
        "com.android.vending",
        "com.amazon.venezia",
        "com.sec.android.app.samsungapps",
        "com.huawei.appmarket",
        "org.fdroid.fdroid",
        "com.aurora.store"
    )

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_PACKAGE_ADDED) return

        // Ignore package replacement / update events
        val isReplacing = intent.getBooleanExtra(Intent.EXTRA_REPLACING, false)
        if (isReplacing) return

        val packageName = intent.data?.schemeSpecificPart ?: return
        if (packageName.isBlank()) return
        val pm = context.packageManager

        try {
            val pkgInfo = pm.getPackageInfo(packageName, PackageManager.GET_PERMISSIONS)
            val appLabel = pm.getApplicationLabel(pkgInfo.applicationInfo).toString()

            val installer = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                try {
                    pm.getInstallSourceInfo(packageName).installingPackageName
                } catch (e: Exception) { null }
            } else {
                @Suppress("DEPRECATION")
                try {
                    pm.getInstallerPackageName(packageName)
                } catch (e: Exception) { null }
            }

            val isSideloaded = installer == null || installer !in legitimateInstallers
            val requestedPerms = pkgInfo.requestedPermissions?.toList() ?: emptyList()

            val hasAccessibility = requestedPerms.contains("android.permission.BIND_ACCESSIBILITY_SERVICE")
            val hasSms = requestedPerms.contains("android.permission.RECEIVE_SMS") || requestedPerms.contains("android.permission.READ_SMS")
            val hasOverlay = requestedPerms.contains("android.permission.SYSTEM_ALERT_WINDOW")

            if (isSideloaded && (hasAccessibility || hasSms || hasOverlay)) {
                val riskDescription = when {
                    hasAccessibility -> "Requests Screen Reading & Accessibility permissions (OTP theft risk)!"
                    hasSms -> "Requests SMS interception permissions (Banking OTP risk)!"
                    hasOverlay -> "Requests Display Overlay permissions (Phishing risk)!"
                    else -> "Installed from unknown source outside Google Play Store."
                }
                triggerUrgentAlertNotification(context, appLabel, packageName, riskDescription)
            }
        } catch (e: Exception) {
            // Package uninstalled or error querying info
        }
    }

    private fun triggerUrgentAlertNotification(
        context: Context,
        appName: String,
        packageName: String,
        threatDescription: String
    ) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Urgent real-time security alerts for unverified/malicious APKs"
                enableVibration(true)
            }
            notificationManager.createNotificationChannel(channel)
        }

        val launchIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            packageName.hashCode(),
            launchIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT else PendingIntent.FLAG_UPDATE_CURRENT
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("⚠️ Security Alert: $appName")
            .setContentText(threatDescription)
            .setStyle(NotificationCompat.BigTextStyle().bigText("Sideloaded app '$appName' ($packageName) was installed.\n$threatDescription\nTap to open Mobile Hygiene Guardian and audit threat."))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        notificationManager.notify(packageName.hashCode(), notification)
    }
}
