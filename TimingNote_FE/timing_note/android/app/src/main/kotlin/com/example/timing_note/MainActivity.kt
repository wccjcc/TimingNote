package com.example.timing_note

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import com.example.timing_note.geofence.GeofenceBridgeConstants
import com.example.timing_note.geofence.GeofenceEventStore
import com.example.timing_note.geofence.NativeGeofenceManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter 진입 액티비티이면서,
 * 네이티브 geofence 이벤트를 Flutter EventChannel로 전달하는 브리지 역할을 합니다.
 */
class MainActivity : FlutterActivity() {
    private var geofenceManager: NativeGeofenceManager? = null
    private var eventSink: EventChannel.EventSink? = null
    private var runtimeReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        geofenceManager = NativeGeofenceManager(applicationContext)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            GeofenceBridgeConstants.METHOD_CHANNEL,
        ).setMethodCallHandler(::handleMethodCall)

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            GeofenceBridgeConstants.EVENT_CHANNEL,
        ).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    eventSink = events
                    // Flutter가 구독을 시작한 순간, 백그라운드에 쌓여 있던 이벤트를 먼저 밀어줍니다.
                    emitPendingEvents()
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            },
        )

        registerRuntimeReceiver()
    }

    override fun onDestroy() {
        super.onDestroy()
        runtimeReceiver?.let { unregisterReceiver(it) }
        runtimeReceiver = null
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "registerGeofences" -> {
                val regions = call.argument<List<Map<String, Any?>>>("regions") ?: emptyList()
                geofenceManager?.registerGeofences(regions, result)
                    ?: result.error("GEOFENCE_MANAGER_NULL", "NativeGeofenceManager가 초기화되지 않았습니다.", null)
            }

            "clearGeofences" -> {
                geofenceManager?.clearGeofences(result)
                    ?: result.error("GEOFENCE_MANAGER_NULL", "NativeGeofenceManager가 초기화되지 않았습니다.", null)
            }

            else -> result.notImplemented()
        }
    }

    /**
     * BroadcastReceiver에서 올라온 즉시 이벤트를 EventSink로 전달합니다.
     */
    private fun registerRuntimeReceiver() {
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                val raw = intent?.getStringExtra(GeofenceBridgeConstants.EXTRA_EVENT_JSON) ?: return
                val map = GeofenceEventStore.jsonToMap(raw)
                eventSink?.success(map)

                // 즉시 전달 성공한 이벤트는 대기열에서 제거해 중복을 줄입니다.
                val eventId = map["eventId"]?.toString()
                if (!eventId.isNullOrEmpty()) {
                    GeofenceEventStore.removeByEventId(applicationContext, eventId)
                }
            }
        }

        registerReceiver(receiver, IntentFilter(GeofenceBridgeConstants.ACTION_GEOFENCE_EVENT))
        runtimeReceiver = receiver
    }

    /**
     * 앱이 다시 살아났을 때(혹은 EventChannel 재구독 시점)에
     * 보관된 백그라운드 이벤트를 Flutter로 전달합니다.
     */
    private fun emitPendingEvents() {
        val pending = GeofenceEventStore.loadAndClear(applicationContext)
        for (raw in pending) {
            eventSink?.success(GeofenceEventStore.jsonToMap(raw))
        }
    }
}
