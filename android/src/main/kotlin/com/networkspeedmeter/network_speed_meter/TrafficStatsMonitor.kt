package com.networkspeedmeter.network_speed_meter

import android.net.TrafficStats
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

data class SpeedReading(
    val downloadBps: Long,
    val uploadBps: Long,
    val totalBps: Long,
    val timestamp: Long,
    val fromForeground: Boolean,
)

class TrafficStatsMonitor(
    private val scope: CoroutineScope,
    private val fromForeground: Boolean = false,
) {
    private var job: Job? = null
    private var lastRxBytes: Long = 0
    private var lastTxBytes: Long = 0

    fun start(
        intervalMs: Long,
        onUpdate: (SpeedReading) -> Unit,
        onError: (Throwable) -> Unit,
    ) {
        if (job?.isActive == true) return

        val baselineRx = TrafficStats.getTotalRxBytes()
        val baselineTx = TrafficStats.getTotalTxBytes()
        if (baselineRx == TrafficStats.UNSUPPORTED.toLong() ||
            baselineTx == TrafficStats.UNSUPPORTED.toLong()
        ) {
            onError(IllegalStateException("TrafficStats unsupported on this device."))
            return
        }

        lastRxBytes = baselineRx
        lastTxBytes = baselineTx

        job = scope.launch(Dispatchers.Default) {
            var initialized = false
            while (isActive) {
                delay(intervalMs)
                val currentRx = TrafficStats.getTotalRxBytes()
                val currentTx = TrafficStats.getTotalTxBytes()

                val downloadDelta = (currentRx - lastRxBytes).coerceAtLeast(0)
                val uploadDelta = (currentTx - lastTxBytes).coerceAtLeast(0)

                lastRxBytes = currentRx
                lastTxBytes = currentTx

                if (!initialized) {
                    initialized = true
                    continue
                }

                val downloadBps = downloadDelta * 1000 / intervalMs
                val uploadBps = uploadDelta * 1000 / intervalMs
                val totalBps = downloadBps + uploadBps

                onUpdate(
                    SpeedReading(
                        downloadBps = downloadBps,
                        uploadBps = uploadBps,
                        totalBps = totalBps,
                        timestamp = System.currentTimeMillis(),
                        fromForeground = fromForeground,
                    ),
                )
            }
        }
    }

    fun stop() {
        job?.cancel()
        job = null
    }

    val isRunning: Boolean
        get() = job?.isActive == true
}
