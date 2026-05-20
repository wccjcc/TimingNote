package com.example.timing_note

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import com.example.timing_note.geofence.GeofenceBridgeConstants
import com.example.timing_note.geofence.GeofenceEventStore
import com.example.timing_note.geofence.NativeGeofenceManager
import com.example.timing_note.map.TimingNoteNativeKakaoMapFactory
import com.example.timing_note.notification.PushActionBridgeConstants
import com.example.timing_note.notification.PushActionStore
import com.example.timing_note.notification.TimingNoteAppState
import com.kakao.vectormap.KakaoMapSdk
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
    private var pushActionChannel: MethodChannel? = null
    private var pushActionReceiver: BroadcastReceiver? = null
    private var pendingLaunchPushActionJson: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        capturePushActionIntent(intent)
    }

    override fun onStart() {
        super.onStart()
        TimingNoteAppState.isForeground = true
    }

    override fun onStop() {
        TimingNoteAppState.isForeground = false
        super.onStop()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        initializeKakaoMapSdk()

        geofenceManager = NativeGeofenceManager(applicationContext)

        flutterEngine.platformViewsController.registry.registerViewFactory(
            "timing_note/native_kakao_map",
            TimingNoteNativeKakaoMapFactory(flutterEngine.dartExecutor.binaryMessenger),
        )

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

        pushActionChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PushActionBridgeConstants.CHANNEL,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "drainPendingActions" -> {
                        flushPendingPushActionPayloads()
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
        }

        registerRuntimeReceiver()
        registerPushActionRuntimeReceiver()
    }

    private fun initializeKakaoMapSdk() {
        val appKey = resolveKakaoNativeAppKey()
        if (appKey.isBlank()) {
            return
        }
        KakaoMapSdk.init(applicationContext, appKey)
    }

    private fun resolveKakaoNativeAppKey(): String {
        return try {
            val flags = PackageManager.GET_META_DATA
            val applicationInfo = packageManager.getApplicationInfo(packageName, flags)
            applicationInfo.metaData?.getString("com.kakao.sdk.AppKey") ?: ""
        } catch (_: Exception) {
            ""
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        runtimeReceiver?.let { unregisterReceiver(it) }
        pushActionReceiver?.let { unregisterReceiver(it) }
        runtimeReceiver = null
        pushActionReceiver = null
        pushActionChannel?.setMethodCallHandler(null)
        pushActionChannel = null
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        capturePushActionIntent(intent)
        flushPendingPushActionPayloads()
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

        val filter = IntentFilter(GeofenceBridgeConstants.ACTION_GEOFENCE_EVENT)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(receiver, filter)
        }
        runtimeReceiver = receiver
    }

    private fun registerPushActionRuntimeReceiver() {
        if (pushActionReceiver != null) return

        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                val raw = intent?.getStringExtra(PushActionBridgeConstants.EXTRA_ACTION_JSON) ?: return
                val eventId = org.json.JSONObject(raw).optString("eventId")
                pushActionChannel?.invokeMethod(
                    "onPushAction",
                    PushActionStore.jsonToMap(raw),
                    object : MethodChannel.Result {
                        override fun success(result: Any?) {
                            if (eventId.isNotEmpty()) {
                                PushActionStore.removeByEventId(applicationContext, eventId)
                            }
                        }

                        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) = Unit

                        override fun notImplemented() = Unit
                    },
                )
            }
        }

        val filter = IntentFilter(PushActionBridgeConstants.ACTION_PUSH_ACTION)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(receiver, filter)
        }
        pushActionReceiver = receiver
    }

    private fun capturePushActionIntent(intent: Intent?) {
        val raw = intent?.getStringExtra(PushActionBridgeConstants.EXTRA_ACTION_JSON) ?: return
        pendingLaunchPushActionJson = raw
        intent.removeExtra(PushActionBridgeConstants.EXTRA_ACTION_JSON)
    }

    private fun flushPendingPushActionPayloads() {
        val channel = pushActionChannel ?: return

        pendingLaunchPushActionJson?.let { raw ->
            channel.invokeMethod("onPushAction", PushActionStore.jsonToMap(raw))
            pendingLaunchPushActionJson = null
        }

        for (raw in PushActionStore.loadAndClear(applicationContext)) {
            channel.invokeMethod("onPushAction", PushActionStore.jsonToMap(raw))
        }
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
