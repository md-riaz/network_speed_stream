package com.networkspeedmeter.network_speed_meter

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob

class NetworkSpeedForegroundService : Service() {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private var monitor: TrafficStatsMonitor? = null
    private var shouldUpdateNotification: Boolean = true

    private val notificationManager by lazy {
        getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopSelf()
                return START_NOT_STICKY
            }
        }

        val intervalMs = intent?.getLongExtra(EXTRA_INTERVAL_MS, 1000L) ?: 1000L
        val showNotification = intent?.getBooleanExtra(EXTRA_SHOW_NOTIFICATION, true) ?: true
        val title = intent?.getStringExtra(EXTRA_NOTIFICATION_TITLE)
            ?: "Network speed monitor"
        val content = intent?.getStringExtra(EXTRA_NOTIFICATION_CONTENT)
            ?: "Monitoring traffic..."

        shouldUpdateNotification = showNotification
        startMonitor(intervalMs)

        val notification = buildNotification(title = title, content = content)
        if (ServiceInfoTypeHelper.supportsServiceType()) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfoTypeHelper.serviceTypeDataSync(),
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        isRunning = true
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        stopMonitor()
        stopForeground(STOP_FOREGROUND_REMOVE)
        isRunning = false
    }

    private fun startMonitor(intervalMs: Long) {
        if (monitor?.isRunning == true) return
        monitor = TrafficStatsMonitor(scope, fromForeground = true).also { m ->
            m.start(
                intervalMs = intervalMs,
                onUpdate = { reading ->
                    sendBroadcast(Intent(ACTION_BROADCAST).apply {
                        putExtra(EXTRA_DOWNLOAD_BPS, reading.downloadBps)
                        putExtra(EXTRA_UPLOAD_BPS, reading.uploadBps)
                        putExtra(EXTRA_TOTAL_BPS, reading.totalBps)
                        putExtra(EXTRA_TIMESTAMP, reading.timestamp)
                        putExtra(EXTRA_FROM_FOREGROUND, true)
                    })
                    updateNotification(reading)
                },
                onError = {
                    sendBroadcast(
                        Intent(ACTION_ERROR).apply {
                            putExtra(EXTRA_ERROR_MESSAGE, it.message ?: "Unknown error")
                        },
                    )
                    stopSelf()
                },
            )
        }
    }

    private fun stopMonitor() {
        monitor?.stop()
        monitor = null
    }

    private fun updateNotification(reading: SpeedReading) {
        if (!shouldUpdateNotification) return
        val formattedDownload = SpeedFormatter.format(reading.downloadBps)
        val formattedUpload = SpeedFormatter.format(reading.uploadBps)
        val body = "Down: $formattedDownload | Up: $formattedUpload"
        notificationManager.notify(
            NOTIFICATION_ID,
            buildNotification(title = "Network speed monitor", content = body),
        )
    }

    private fun buildNotification(title: String, content: String): Notification {
        createChannel()
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setOngoing(true)
            .setContentTitle(title)
            .setContentText(content)
            .setSmallIcon(android.R.drawable.stat_sys_download_done)
            .setOnlyAlertOnce(true)
            .build()
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Network speed monitor",
                NotificationManager.IMPORTANCE_LOW,
            )
            notificationManager.createNotificationChannel(channel)
        }
    }

    companion object {
        const val ACTION_START = "com.networkspeedmeter.network_speed_meter.action.START"
        const val ACTION_STOP = "com.networkspeedmeter.network_speed_meter.action.STOP"
        const val ACTION_BROADCAST = "com.networkspeedmeter.network_speed_meter.action.BROADCAST"
        const val ACTION_ERROR = "com.networkspeedmeter.network_speed_meter.action.ERROR"

        const val EXTRA_INTERVAL_MS = "intervalMs"
        const val EXTRA_SHOW_NOTIFICATION = "showNotification"
        const val EXTRA_NOTIFICATION_TITLE = "notificationTitle"
        const val EXTRA_NOTIFICATION_CONTENT = "notificationContent"
        const val EXTRA_DOWNLOAD_BPS = "downloadBps"
        const val EXTRA_UPLOAD_BPS = "uploadBps"
        const val EXTRA_TOTAL_BPS = "totalBps"
        const val EXTRA_TIMESTAMP = "timestamp"
        const val EXTRA_FROM_FOREGROUND = "fromForeground"
        const val EXTRA_ERROR_MESSAGE = "errorMessage"

        const val CHANNEL_ID = "network_speed_meter_channel"
        const val NOTIFICATION_ID = 2110

        @Volatile
        var isRunning: Boolean = false
            private set
    }
}

private object ServiceInfoTypeHelper {
    fun supportsServiceType(): Boolean = Build.VERSION.SDK_INT >= 29

    fun serviceTypeDataSync(): Int {
        return if (Build.VERSION.SDK_INT >= 34) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
        } else {
            0
        }
    }
}

private object SpeedFormatter {
    fun format(bytesPerSecond: Long): String {
        if (bytesPerSecond >= 1024 * 1024 * 1024) {
            return "%.1f GB/s".format(bytesPerSecond / (1024.0 * 1024 * 1024))
        }
        if (bytesPerSecond >= 1024 * 1024) {
            return "%.1f MB/s".format(bytesPerSecond / (1024.0 * 1024))
        }
        if (bytesPerSecond >= 1024) {
            return "%.1f KB/s".format(bytesPerSecond / 1024.0)
        }
        return "$bytesPerSecond B/s"
    }
}
