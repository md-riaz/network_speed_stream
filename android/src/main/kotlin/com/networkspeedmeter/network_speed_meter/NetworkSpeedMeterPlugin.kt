package com.networkspeedmeter.network_speed_meter

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Context.RECEIVER_NOT_EXPORTED
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob

class NetworkSpeedMeterPlugin : FlutterPlugin, MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {

    private lateinit var context: Context
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null
    private var monitor: TrafficStatsMonitor? = null
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private var latest: SpeedReading? = null
    private var serviceReceiver: BroadcastReceiver? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL)
        methodChannel?.setMethodCallHandler(this)
        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL)
        eventChannel?.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        stopMonitoringInternal()
        methodChannel?.setMethodCallHandler(null)
        eventChannel?.setStreamHandler(null)
        eventSink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startMonitoring" -> {
                val args = call.arguments as? Map<*, *>
                val interval = (args?.get("intervalMs") as? Number)?.toLong() ?: 1000L
                val foreground = args?.get("enableForegroundService") == true
                val showNotification = args?.get("showNotification") as? Boolean ?: true
                val title = args?.get("notificationTitle") as? String
                    ?: "Network speed monitor"
                val content = args?.get("notificationContent") as? String
                    ?: "Monitoring traffic..."
                startMonitoringInternal(
                    intervalMs = interval,
                    foreground = foreground,
                    showNotification = showNotification,
                    notificationTitle = title,
                    notificationContent = content,
                )
                result.success(null)
            }
            "stopMonitoring" -> {
                stopMonitoringInternal()
                result.success(null)
            }
            "isMonitoring" -> {
                result.success(isMonitoring())
            }
            "latestSnapshot" -> {
                result.success(latest?.toMap())
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        latest?.let { eventSink?.success(it.toMap()) }
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    private fun startMonitoringInternal(
        intervalMs: Long,
        foreground: Boolean,
        showNotification: Boolean,
        notificationTitle: String,
        notificationContent: String,
    ) {
        stopMonitoringInternal()
        if (foreground) {
            registerServiceReceiver()
            val intent = Intent(context, NetworkSpeedForegroundService::class.java).apply {
                action = NetworkSpeedForegroundService.ACTION_START
                putExtra(NetworkSpeedForegroundService.EXTRA_INTERVAL_MS, intervalMs)
                putExtra(
                    NetworkSpeedForegroundService.EXTRA_SHOW_NOTIFICATION,
                    showNotification,
                )
                putExtra(
                    NetworkSpeedForegroundService.EXTRA_NOTIFICATION_TITLE,
                    notificationTitle,
                )
                putExtra(
                    NetworkSpeedForegroundService.EXTRA_NOTIFICATION_CONTENT,
                    notificationContent,
                )
            }
            ContextCompat.startForegroundService(context, intent)
        } else {
            monitor = TrafficStatsMonitor(scope, fromForeground = false).also { m ->
                m.start(
                    intervalMs = intervalMs,
                    onUpdate = { reading ->
                        latest = reading
                        eventSink?.success(reading.toMap())
                    },
                    onError = { throwable ->
                        eventSink?.error(
                            "traffic_stats_error",
                            throwable.message,
                            null,
                        )
                    },
                )
            }
        }
    }

    private fun stopMonitoringInternal() {
        monitor?.stop()
        monitor = null

        if (NetworkSpeedForegroundService.isRunning) {
            context.stopService(
                Intent(context, NetworkSpeedForegroundService::class.java).apply {
                    action = NetworkSpeedForegroundService.ACTION_STOP
                },
            )
        }
        unregisterServiceReceiver()
    }

    private fun isMonitoring(): Boolean {
        return (monitor?.isRunning == true) || NetworkSpeedForegroundService.isRunning
    }

    private fun registerServiceReceiver() {
        if (serviceReceiver != null) return
        serviceReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                when (intent?.action) {
                    NetworkSpeedForegroundService.ACTION_BROADCAST -> {
                        val reading = SpeedReading(
                            downloadBps =
                            intent.getLongExtra(
                                NetworkSpeedForegroundService.EXTRA_DOWNLOAD_BPS,
                                0,
                            ),
                            uploadBps =
                            intent.getLongExtra(
                                NetworkSpeedForegroundService.EXTRA_UPLOAD_BPS,
                                0,
                            ),
                            totalBps =
                            intent.getLongExtra(
                                NetworkSpeedForegroundService.EXTRA_TOTAL_BPS,
                                0,
                            ),
                            timestamp =
                            intent.getLongExtra(
                                NetworkSpeedForegroundService.EXTRA_TIMESTAMP,
                                System.currentTimeMillis(),
                            ),
                            fromForeground = intent.getBooleanExtra(
                                NetworkSpeedForegroundService.EXTRA_FROM_FOREGROUND,
                                true,
                            ),
                        )
                        latest = reading
                        eventSink?.success(reading.toMap())
                    }
                    NetworkSpeedForegroundService.ACTION_ERROR -> {
                        val message = intent.getStringExtra(
                            NetworkSpeedForegroundService.EXTRA_ERROR_MESSAGE,
                        ) ?: "Unknown error"
                        eventSink?.error("traffic_stats_error", message, null)
                    }
                }
            }
        }
        val filter = IntentFilter().apply {
            addAction(NetworkSpeedForegroundService.ACTION_BROADCAST)
            addAction(NetworkSpeedForegroundService.ACTION_ERROR)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(serviceReceiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(serviceReceiver, filter)
        }
    }

    private fun unregisterServiceReceiver() {
        serviceReceiver?.let {
            context.unregisterReceiver(it)
        }
        serviceReceiver = null
    }

    companion object {
        private const val METHOD_CHANNEL = "network_speed_meter/methods"
        private const val EVENT_CHANNEL = "network_speed_meter/events"
    }
}

private fun SpeedReading.toMap(): Map<String, Any> = mapOf(
    "downloadBps" to downloadBps,
    "uploadBps" to uploadBps,
    "totalBps" to totalBps,
    "timestamp" to timestamp,
    "fromForeground" to fromForeground,
)
