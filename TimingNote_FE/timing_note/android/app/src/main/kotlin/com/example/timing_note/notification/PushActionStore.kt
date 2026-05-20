package com.example.timing_note.notification

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

object PushActionStore {
    private fun prefs(context: Context) =
        context.getSharedPreferences(PushActionBridgeConstants.PREFS_NAME, Context.MODE_PRIVATE)

    @Synchronized
    fun appendAction(context: Context, actionJson: String) {
        val raw = prefs(context)
            .getString(PushActionBridgeConstants.PREFS_KEY_PENDING_ACTIONS, "[]") ?: "[]"
        val array = JSONArray(raw)
        array.put(JSONObject(actionJson))
        prefs(context)
            .edit()
            .putString(PushActionBridgeConstants.PREFS_KEY_PENDING_ACTIONS, array.toString())
            .apply()
    }

    @Synchronized
    fun loadAndClear(context: Context): List<String> {
        val raw = prefs(context)
            .getString(PushActionBridgeConstants.PREFS_KEY_PENDING_ACTIONS, "[]") ?: "[]"
        val array = JSONArray(raw)
        val result = mutableListOf<String>()

        for (i in 0 until array.length()) {
            result.add(array.getJSONObject(i).toString())
        }

        prefs(context)
            .edit()
            .putString(PushActionBridgeConstants.PREFS_KEY_PENDING_ACTIONS, "[]")
            .apply()

        return result
    }

    @Synchronized
    fun removeByEventId(context: Context, eventId: String) {
        val raw = prefs(context)
            .getString(PushActionBridgeConstants.PREFS_KEY_PENDING_ACTIONS, "[]") ?: "[]"
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
            .putString(PushActionBridgeConstants.PREFS_KEY_PENDING_ACTIONS, filtered.toString())
            .apply()
    }

    fun jsonToMap(json: String): Map<String, String> {
        val obj = JSONObject(json)
        return mapOf(
            "actionId" to obj.optString("actionId"),
            "notificationId" to obj.optString("notificationId"),
            "todoId" to obj.optString("todoId"),
            "slotId" to obj.optString("slotId"),
        )
    }
}
