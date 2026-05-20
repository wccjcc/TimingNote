package com.example.timing_note.notification

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import com.example.timing_note.MainActivity
import com.example.timing_note.R
import org.json.JSONObject
import kotlin.math.absoluteValue

class TimingNoteFirebaseMessagingReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (TimingNoteAppState.isForeground) {
            return
        }

        val data = intent.extras ?: return
        val type = data.getString("type").orEmpty()
        if (type != PUSH_TYPE_GEOFENCE) {
            return
        }

        if (!canPostNotifications(context)) {
            return
        }

        val payload = PushPayload(
            title = data.getString("title").orEmpty().ifBlank { TITLE_FALLBACK },
            body = data.getString("body").orEmpty().ifBlank { BODY_FALLBACK },
            notificationId = data.getString("notificationId").orEmpty(),
            todoId = data.getString("todoId").orEmpty(),
            slotId = data.getString("slotId").orEmpty(),
        )
        val systemNotificationId = payload.systemNotificationId()

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        ensureChannel(manager)
        manager.notify(systemNotificationId, buildNotification(context, payload, systemNotificationId))
    }

    private fun buildNotification(
        context: Context,
        payload: PushPayload,
        systemNotificationId: Int,
    ): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }

        builder
            .setSmallIcon(R.drawable.ic_stat_timing_note)
            .setContentTitle(payload.title)
            .setContentText(payload.body)
            .setStyle(Notification.BigTextStyle().bigText(payload.body))
            .setAutoCancel(true)
            .setShowWhen(true)
            .setContentIntent(contentIntent(context, payload, systemNotificationId))
            .addAction(
                action(
                    context,
                    payload,
                    systemNotificationId,
                    PushActionBridgeConstants.ACTION_COMPLETE,
                    "완료",
                    android.R.drawable.ic_menu_save,
                ),
            )
            .addAction(
                action(
                    context,
                    payload,
                    systemNotificationId,
                    PushActionBridgeConstants.ACTION_SNOOZE_60,
                    "1시간 후 알림해제",
                    android.R.drawable.ic_menu_recent_history,
                ),
            )

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            @Suppress("DEPRECATION")
            builder.setPriority(Notification.PRIORITY_HIGH)
        }

        return builder.build()
    }

    private fun contentIntent(
        context: Context,
        payload: PushPayload,
        systemNotificationId: Int,
    ): PendingIntent {
        val actionJson = payload.toActionJson(PushActionBridgeConstants.ACTION_OPEN)
        val intent = Intent(context, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            .putExtra(PushActionBridgeConstants.EXTRA_ACTION_JSON, actionJson)
            .putExtra(PushActionBridgeConstants.EXTRA_SYSTEM_NOTIFICATION_ID, systemNotificationId)
        return PendingIntent.getActivity(
            context,
            systemNotificationId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun action(
        context: Context,
        payload: PushPayload,
        systemNotificationId: Int,
        actionId: String,
        title: String,
        iconResId: Int,
    ): Notification.Action {
        val intent = Intent(context, PushActionReceiver::class.java)
            .putExtra("actionId", actionId)
            .putExtra("notificationId", payload.notificationId)
            .putExtra("todoId", payload.todoId)
            .putExtra("slotId", payload.slotId)
            .putExtra(PushActionBridgeConstants.EXTRA_SYSTEM_NOTIFICATION_ID, systemNotificationId)
        val requestCode = "$systemNotificationId:$actionId".hashCode().absoluteValue
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return Notification.Action.Builder(iconResId, title, pendingIntent).build()
    }

    private fun canPostNotifications(context: Context): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
    }

    private fun ensureChannel(manager: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val existing = manager.getNotificationChannel(CHANNEL_ID)
        if (existing != null) {
            return
        }

        val channel = NotificationChannel(
            CHANNEL_ID,
            "위치 알림",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "할 일 위치 알림"
        }
        manager.createNotificationChannel(channel)
    }

    private data class PushPayload(
        val title: String,
        val body: String,
        val notificationId: String,
        val todoId: String,
        val slotId: String,
    ) {
        fun systemNotificationId(): Int {
            val numeric = notificationId.toIntOrNull()
            if (numeric != null && numeric != 0) {
                return numeric
            }
            return "$todoId:$slotId:${System.currentTimeMillis()}".hashCode().absoluteValue
        }

        fun toActionJson(actionId: String): String {
            return JSONObject()
                .put("eventId", "${System.currentTimeMillis()}_$actionId")
                .put("actionId", actionId)
                .put("notificationId", notificationId)
                .put("todoId", todoId)
                .put("slotId", slotId)
                .toString()
        }
    }

    private companion object {
        const val PUSH_TYPE_GEOFENCE = "GEOFENCE"
        const val CHANNEL_ID = "timing_note_geofence"
        const val TITLE_FALLBACK = "타이밍노트 알림"
        const val BODY_FALLBACK = "위치 기반 알림이 도착했습니다."
    }
}
