package com.ultraforge.license_logger

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import android.os.Looper
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Cheap idle wake while the high-accuracy GPS stream is off.
 * Network provider, ~400 m / 60 s — not a navigation stream.
 */
class IdleWakeHandler(
    private val context: Context,
) : EventChannel.StreamHandler, LocationListener {
    private val methodChannelName = "com.ultraforge.licenselogger/idle_wake"
    private val eventChannelName = "com.ultraforge.licenselogger/idle_wake_events"

    private var eventSink: EventChannel.EventSink? = null
    private var running = false

    private val locationManager: LocationManager?
        get() = context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager

    fun register(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> result.success(start())
                    "stop" -> {
                        stop()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName)
            .setStreamHandler(this)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    private fun start(): Boolean {
        if (running) return true
        val fine = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_FINE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
        val coarse = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_COARSE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
        if (!fine && !coarse) return false
        val mgr = locationManager ?: return false
        val provider = when {
            mgr.isProviderEnabled(LocationManager.NETWORK_PROVIDER) ->
                LocationManager.NETWORK_PROVIDER
            mgr.isProviderEnabled(LocationManager.PASSIVE_PROVIDER) ->
                LocationManager.PASSIVE_PROVIDER
            else -> return false
        }
        return try {
            mgr.requestLocationUpdates(
                provider,
                60_000L,
                400f,
                this,
                Looper.getMainLooper(),
            )
            running = true
            true
        } catch (_: SecurityException) {
            false
        }
    }

    private fun stop() {
        if (!running) return
        try {
            locationManager?.removeUpdates(this)
        } catch (_: SecurityException) {
        }
        running = false
    }

    override fun onLocationChanged(location: Location) {
        eventSink?.success(mapOf("reason" to "significant_change"))
    }

    @Deprecated("Deprecated in Java")
    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}

    override fun onProviderEnabled(provider: String) {}

    override fun onProviderDisabled(provider: String) {}
}
