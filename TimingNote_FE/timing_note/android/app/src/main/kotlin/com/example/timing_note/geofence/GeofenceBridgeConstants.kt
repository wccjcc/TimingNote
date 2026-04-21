package com.example.timing_note.geofence

/**
 * Flutter <-> Android geofence 브리지에서 공통으로 쓰는 상수 모음입니다.
 */
object GeofenceBridgeConstants {
    // Flutter 채널 이름(Flutter 코드와 반드시 동일해야 합니다)
    const val METHOD_CHANNEL = "timing_note/geofence_method"
    const val EVENT_CHANNEL = "timing_note/geofence_events"

    // 앱 내부 브로드캐스트 액션(네이티브 이벤트를 MainActivity로 전달)
    const val ACTION_GEOFENCE_EVENT = "com.example.timing_note.GEOFENCE_EVENT"
    const val EXTRA_EVENT_JSON = "extra_event_json"

    // SharedPreferences 키(백그라운드/종료 상태에서 수신된 이벤트 임시 저장)
    const val PREFS_NAME = "timing_note_geofence_prefs"
    const val PREFS_KEY_PENDING_EVENTS = "pending_events_json_array"
}
