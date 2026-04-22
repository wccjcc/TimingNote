package com.example.timing_note.geofence

import android.Manifest
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices
import io.flutter.plugin.common.MethodChannel

/**
 * Android 네이티브 geofence 등록/해제를 담당합니다.
 */
class NativeGeofenceManager(
    private val context: Context,
) {
    private val geofencingClient = LocationServices.getGeofencingClient(context)

    private val geofencePendingIntent: PendingIntent by lazy {
        val intent = Intent(context, GeofenceBroadcastReceiver::class.java)
        PendingIntent.getBroadcast(
            context,
            12001,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
        )
    }

    fun registerGeofences(
        rawRegions: List<Map<String, Any?>>,
        result: MethodChannel.Result,
    ) {
        if (rawRegions.isEmpty()) {
            result.error("GEOFENCE_EMPTY", "등록할 geofence 목록이 비어 있습니다.", null)
            return
        }

        if (!hasLocationPermission()) {
            result.error("LOCATION_PERMISSION_DENIED", "위치 권한이 없어 geofence를 등록할 수 없습니다.", null)
            return
        }

        val geofences = rawRegions.mapNotNull { map ->
            val id = map["id"]?.toString() ?: return@mapNotNull null
            val lat = (map["latitude"] as? Number)?.toDouble() ?: return@mapNotNull null
            val lng = (map["longitude"] as? Number)?.toDouble() ?: return@mapNotNull null
            val radius = (map["radius"] as? Number)?.toFloat() ?: return@mapNotNull null

            Geofence.Builder()
                .setRequestId(id)
                .setCircularRegion(lat, lng, radius)
                .setTransitionTypes(
                    Geofence.GEOFENCE_TRANSITION_ENTER or Geofence.GEOFENCE_TRANSITION_EXIT,
                )
                .setLoiteringDelay(0)
                .setExpirationDuration(Geofence.NEVER_EXPIRE)
                .build()
        }

        if (geofences.isEmpty()) {
            result.error("GEOFENCE_INVALID", "geofence 파라미터 파싱에 실패했습니다.", null)
            return
        }

        val request = GeofencingRequest.Builder()
            .setInitialTrigger(
                GeofencingRequest.INITIAL_TRIGGER_ENTER or GeofencingRequest.INITIAL_TRIGGER_EXIT,
            )
            .addGeofences(geofences)
            .build()

        // 기존 등록 제거 후 재등록하면 중복 등록 위험이 줄어듭니다.
        geofencingClient.removeGeofences(geofencePendingIntent)
            .addOnCompleteListener {
                @Suppress("MissingPermission")
                geofencingClient.addGeofences(request, geofencePendingIntent)
                    .addOnSuccessListener { result.success(null) }
                    .addOnFailureListener { e ->
                        result.error("GEOFENCE_REGISTER_FAILED", e.message, null)
                    }
            }
    }

    fun clearGeofences(result: MethodChannel.Result) {
        geofencingClient.removeGeofences(geofencePendingIntent)
            .addOnSuccessListener { result.success(null) }
            .addOnFailureListener { e ->
                result.error("GEOFENCE_CLEAR_FAILED", e.message, null)
            }
    }

    private fun hasLocationPermission(): Boolean {
        val fine = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_FINE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED

        // Android 10+(API 29)에서는 백그라운드 geofence 안정성을 위해
        // ACCESS_BACKGROUND_LOCATION 권한도 함께 확인합니다.
        val background = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.ACCESS_BACKGROUND_LOCATION,
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }

        return fine && background
    }
}
