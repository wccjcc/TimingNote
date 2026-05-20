package com.example.timing_note.notification

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import org.json.JSONObject

class PushActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val payload = buildPayload(intent)
        val payloadJson = payload.toString()

        PushActionStore.appendAction(context, payloadJson)
        cancelNotification(context, intent)

        val forward = Intent(PushActionBridgeConstants.ACTION_PUSH_ACTION)
            .setPackage(context.packageName)
            .putExtra(PushActionBridgeConstants.EXTRA_ACTION_JSON, payloadJson)
        context.sendBroadcast(forward)
    }

    private fun buildPayload(intent: Intent): JSONObject {
        return JSONObject()
            .put("eventId", "${System.currentTimeMillis()}_${intent.getStringExtra("actionId").orEmpty()}")
            .put("actionId", intent.getStringExtra("actionId").orEmpty())
            .put("notificationId", intent.getStringExtra("notificationId").orEmpty())
            .put("todoId", intent.getStringExtra("todoId").orEmpty())
            .put("slotId", intent.getStringExtra("slotId").orEmpty())
    }

    private fun cancelNotification(context: Context, intent: Intent) {
        val systemNotificationId = intent.getIntExtra(
            PushActionBridgeConstants.EXTRA_SYSTEM_NOTIFICATION_ID,
            0,
        )
        if (systemNotificationId == 0) return

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.cancel(systemNotificationId)
    }
}
