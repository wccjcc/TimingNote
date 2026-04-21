package com.example.timing_note.geofence

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * geofence 이벤트를 영속 저장/조회/삭제하는 저장소입니다.
 *
 * 왜 필요한가?
 * - geofence 이벤트는 앱이 백그라운드/종료 상태에서도 들어올 수 있습니다.
 * - 그 순간 Flutter EventSink가 없을 수 있으므로, 먼저 저장해두고
 *   다음에 Flutter가 연결되면 전달해야 이벤트 유실을 줄일 수 있습니다.
 */
object GeofenceEventStore {
    private fun prefs(context: Context) =
        context.getSharedPreferences(GeofenceBridgeConstants.PREFS_NAME, Context.MODE_PRIVATE)

    @Synchronized
    fun appendEvent(context: Context, eventJson: String) {
        val raw = prefs(context).getString(GeofenceBridgeConstants.PREFS_KEY_PENDING_EVENTS, "[]") ?: "[]"
        val array = JSONArray(raw)
        array.put(JSONObject(eventJson))
        prefs(context)
            .edit()
            .putString(GeofenceBridgeConstants.PREFS_KEY_PENDING_EVENTS, array.toString())
            .apply()
    }

    /**
     * 대기 이벤트를 모두 반환하고 저장소는 비웁니다.
     */
    @Synchronized
    fun loadAndClear(context: Context): List<String> {
        val raw = prefs(context).getString(GeofenceBridgeConstants.PREFS_KEY_PENDING_EVENTS, "[]") ?: "[]"
        val array = JSONArray(raw)
        val result = mutableListOf<String>()

        for (i in 0 until array.length()) {
            result.add(array.getJSONObject(i).toString())
        }

        prefs(context)
            .edit()
            .putString(GeofenceBridgeConstants.PREFS_KEY_PENDING_EVENTS, "[]")
            .apply()

        return result
    }

    /**
     * 특정 eventId를 대기열에서 제거합니다.
     *
     * 사용 시점:
     * - 브로드캐스트로 즉시 Flutter에 전달 성공한 이벤트를
     *   대기열에서도 제거해 중복 전송을 방지합니다.
     */
    @Synchronized
    fun removeByEventId(context: Context, eventId: String) {
        val raw = prefs(context).getString(GeofenceBridgeConstants.PREFS_KEY_PENDING_EVENTS, "[]") ?: "[]"
        val array = JSONArray(raw)
        val filtered = JSONArray()

        for (i in 0 until array.length()) {
            val obj = array.getJSONObject(i)
            if (obj.optString("eventId") != eventId) {
                filtered.put(obj)
            }
        }

        prefs(context)
            .edit()
            .putString(GeofenceBridgeConstants.PREFS_KEY_PENDING_EVENTS, filtered.toString())
            .apply()
    }

    fun jsonToMap(json: String): Map<String, Any?> {
        val obj = JSONObject(json)
        return mapOf(
            "eventId" to obj.optString("eventId"),
            "geofenceId" to obj.optString("geofenceId"),
            "transition" to obj.optString("transition"),
            "occurredAt" to obj.optString("occurredAt"),
            "latitude" to obj.optDouble("latitude"),
            "longitude" to obj.optDouble("longitude"),
            "accuracyMeters" to if (obj.has("accuracyMeters")) obj.optDouble("accuracyMeters") else null,
        )
    }
}
