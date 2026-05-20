package com.example.timing_note.notification

object PushActionBridgeConstants {
    const val CHANNEL = "timing_note/push_actions"
    const val ACTION_PUSH_ACTION = "com.example.timing_note.PUSH_ACTION"
    const val EXTRA_ACTION_JSON = "push_action_json"
    const val EXTRA_SYSTEM_NOTIFICATION_ID = "system_notification_id"
    const val PREFS_NAME = "timing_note_push_action_prefs"
    const val PREFS_KEY_PENDING_ACTIONS = "pending_push_actions"

    const val ACTION_OPEN = "OPEN"
    const val ACTION_COMPLETE = "COMPLETE"
    const val ACTION_SNOOZE_60 = "SNOOZE_60"
}
