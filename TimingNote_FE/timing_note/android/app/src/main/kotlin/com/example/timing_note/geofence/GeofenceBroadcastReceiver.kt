package com.example.timing_note.geofence

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/**
 * Android OS geofence 이벤트를 수신하는 BroadcastReceiver입니다.
 *
 * 이 리시버는 앱이 백그라운드에 있거나 화면이 꺼져 있어도 호출될 수 있습니다.
 */
class GeofenceBroadcastReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val geofencingEvent = GeofencingEvent.fromIntent(intent) ?: return
        if (geofencingEvent.hasError()) {
            return
        }

        val transition = when (geofencingEvent.geofenceTransition) {
            Geofence.GEOFENCE_TRANSITION_ENTER -> "ENTER"
            Geofence.GEOFENCE_TRANSITION_EXIT -> "EXIT"
            else -> return
        }

        val location = geofencingEvent.triggeringLocation
        val triggered = geofencingEvent.triggeringGeofences ?: emptyList()

        for (item in triggered) {
            val nowMillis = System.currentTimeMillis()
            val eventId = "${item.requestId}_${transition}_${nowMillis}"

            val payload = JSONObject()
                .put("eventId", eventId)
                .put("geofenceId", item.requestId)
                .put("transition", transition)
                .put("occurredAt", toUtcIsoString(nowMillis))
                .put("latitude", location?.latitude ?: 0.0)
                .put("longitude", location?.longitude ?: 0.0)
                .put("accuracyMeters", location?.accuracy?.toDouble() ?: 0.0)
                .toString()

            // 1) 우선 저장(Flutter 미연결 상황에서도 유실 최소화)
            GeofenceEventStore.appendEvent(context, payload)

            // 2) 앱이 살아있다면 즉시 브로드캐스트로 전달
            val forward = Intent(GeofenceBridgeConstants.ACTION_GEOFENCE_EVENT)
                .putExtra(GeofenceBridgeConstants.EXTRA_EVENT_JSON, payload)
            context.sendBroadcast(forward)
        }
    }

    private fun toUtcIsoString(timeMillis: Long): String {
        val format = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
        format.timeZone = TimeZone.getTimeZone("UTC")
        return format.format(Date(timeMillis))
    }
}
