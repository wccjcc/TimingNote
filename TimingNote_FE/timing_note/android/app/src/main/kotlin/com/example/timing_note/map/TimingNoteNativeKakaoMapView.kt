package com.example.timing_note.map

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.view.View
import com.kakao.vectormap.GestureType
import com.kakao.vectormap.KakaoMap
import com.kakao.vectormap.KakaoMapReadyCallback
import com.kakao.vectormap.LatLng
import com.kakao.vectormap.MapLifeCycleCallback
import com.kakao.vectormap.MapView
import com.kakao.vectormap.camera.CameraPosition
import com.kakao.vectormap.camera.CameraUpdateFactory
import com.kakao.vectormap.label.CompetitionType
import com.kakao.vectormap.label.Label
import com.kakao.vectormap.label.LabelLayer
import com.kakao.vectormap.label.LabelLayerOptions
import com.kakao.vectormap.label.LabelOptions
import com.kakao.vectormap.label.LabelStyle
import com.kakao.vectormap.label.OrderingType
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import kotlin.math.ceil
import kotlin.math.max

class TimingNoteNativeKakaoMapView(
    context: Context,
    messenger: BinaryMessenger,
    viewId: Int,
    params: Map<*, *>?,
) : PlatformView {
    private val appContext = context.applicationContext
    private val density = appContext.resources.displayMetrics.density
    private val mapView = MapView(context)
    private val channel = MethodChannel(messenger, "timing_note/native_kakao_map_$viewId")

    private val initialLatitude = (params?.get("latitude") as? Number)?.toDouble() ?: 37.5665
    private val initialLongitude = (params?.get("longitude") as? Number)?.toDouble() ?: 126.9780
    private val initialLevel = (params?.get("level") as? Number)?.toInt() ?: 15
    private val mapViewName = "timing_note_map_$viewId"

    private var kakaoMap: KakaoMap? = null
    private var lastNativeState = "created"
    private var pendingCameraTarget: LatLng? = null
    private var pendingMarkerPayload: List<Map<String, Any?>>? = null
    private var pendingUserLocation: Pair<Double, Double>? = null
    private var currentUserLocation: Pair<Double, Double>? = null
    private var candidateLayer: LabelLayer? = null
    private var bubbleLayer: LabelLayer? = null
    private var userLocationLayer: LabelLayer? = null
    private var activeBubbleMarkerId: String? = null
    private val markerStates = mutableMapOf<String, MarkerState>()

    init {
        channel.setMethodCallHandler(::handleMethodCall)
        mapView.setFinishManually(true)
        startMap()
    }

    override fun getView(): View = mapView

    override fun dispose() {
        channel.setMethodCallHandler(null)
        candidateLayer?.removeAll()
        bubbleLayer?.removeAll()
        userLocationLayer?.removeAll()
        mapView.pause()
        mapView.finish()
    }

    private fun startMap() {
        mapView.start(
            object : MapLifeCycleCallback() {
                override fun onMapDestroy() {
                    lastNativeState = "mapDestroy"
                }

                override fun onMapError(error: Exception) {
                    lastNativeState = "mapError:${error.message.orEmpty()}"
                    channel.invokeMethod(
                        "onMapError",
                        mapOf("message" to error.message.orEmpty()),
                    )
                }
            },
            object : KakaoMapReadyCallback() {
                override fun onMapReady(map: KakaoMap) {
                    lastNativeState = "mapReady"
                    kakaoMap = map
                    attachMapListeners(map)

                    pendingCameraTarget?.let {
                        pendingCameraTarget = null
                        moveCamera(it)
                    } ?: map.getCameraPosition()?.let(::notifyCameraIdle)

                    pendingMarkerPayload?.let {
                        pendingMarkerPayload = null
                        applyCandidateMarkers(it)
                    }

                    pendingUserLocation?.let {
                        pendingUserLocation = null
                        applyUserLocation(it.first, it.second)
                    }
                }

                override fun getPosition(): LatLng {
                    return LatLng.from(initialLatitude, initialLongitude)
                }

                override fun getZoomLevel(): Int = initialLevel

                override fun getViewName(): String = mapViewName
            },
        )
        mapView.resume()
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "debugState" -> result.success(
                mapOf(
                    "lastNativeState" to lastNativeState,
                    "mapReady" to (kakaoMap != null),
                    "engineState" to mapView.getEngineState(),
                ),
            )

            "panTo" -> {
                val args = call.arguments as? Map<*, *>
                val latitude = (args?.get("latitude") as? Number)?.toDouble()
                val longitude = (args?.get("longitude") as? Number)?.toDouble()
                if (latitude == null || longitude == null) {
                    result.error("INVALID_ARGUMENT", "latitude/longitude is required", null)
                    return
                }
                moveCamera(LatLng.from(latitude, longitude))
                result.success(null)
            }

            "setMarkers" -> {
                val args = call.arguments as? Map<*, *>
                val markers = (args?.get("markers") as? List<*>)
                    ?.mapNotNull { it as? Map<*, *> }
                    ?.map { raw -> raw.entries.associate { it.key.toString() to it.value } }
                    ?: run {
                        result.error("INVALID_ARGUMENT", "markers list is required", null)
                        return
                    }

                if (kakaoMap == null) {
                    pendingMarkerPayload = markers
                } else {
                    applyCandidateMarkers(markers)
                }
                result.success(null)
            }

            "setUserLocation" -> {
                val args = call.arguments as? Map<*, *>
                val latitude = (args?.get("latitude") as? Number)?.toDouble()
                val longitude = (args?.get("longitude") as? Number)?.toDouble()
                if (latitude == null || longitude == null) {
                    result.error("INVALID_ARGUMENT", "latitude/longitude is required", null)
                    return
                }
                if (kakaoMap == null) {
                    pendingUserLocation = latitude to longitude
                } else {
                    applyUserLocation(latitude, longitude)
                }
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private fun attachMapListeners(map: KakaoMap) {
        map.setOnCameraMoveStartListener(
            object : KakaoMap.OnCameraMoveStartListener {
                override fun onCameraMoveStart(kakaoMap: KakaoMap, gestureType: GestureType) {
                    dismissBubble()
                    channel.invokeMethod("onCameraMoveStarted", null)
                }
            },
        )

        map.setOnCameraMoveEndListener(
            object : KakaoMap.OnCameraMoveEndListener {
                override fun onCameraMoveEnd(
                    kakaoMap: KakaoMap,
                    cameraPosition: CameraPosition,
                    gestureType: GestureType,
                ) {
                    notifyCameraIdle(cameraPosition)
                }
            },
        )

        map.setOnLabelClickListener(
            object : KakaoMap.OnLabelClickListener {
                override fun onLabelClicked(
                    kakaoMap: KakaoMap,
                    layer: LabelLayer,
                    label: Label,
                ): Boolean {
                    val markerId = label.getTag() as? String ?: return false
                    toggleBubble(markerId)
                    channel.invokeMethod("onPoiTapped", mapOf("id" to markerId))
                    return true
                }
            },
        )
    }

    private fun moveCamera(target: LatLng) {
        val map = kakaoMap
        if (map == null) {
            pendingCameraTarget = target
            return
        }
        map.moveCamera(CameraUpdateFactory.newCenterPosition(target))
    }

    private fun notifyCameraIdle(cameraPosition: CameraPosition) {
        val position = cameraPosition.getPosition()
        channel.invokeMethod(
            "onCameraIdle",
            mapOf(
                "latitude" to position.getLatitude(),
                "longitude" to position.getLongitude(),
                "level" to cameraPosition.getZoomLevel(),
            ),
        )
    }

    private fun applyCandidateMarkers(markers: List<Map<String, Any?>>) {
        val map = kakaoMap ?: return
        val layer = ensureCandidateLayer(map) ?: return
        layer.removeAll()
        dismissBubble()
        markerStates.clear()

        markers.forEachIndexed { index, marker ->
            val id = marker["id"]?.toString() ?: return@forEachIndexed
            val latitude = (marker["latitude"] as? Number)?.toDouble() ?: return@forEachIndexed
            val longitude = (marker["longitude"] as? Number)?.toDouble() ?: return@forEachIndexed
            val active = (marker["active"] as? Boolean) ?: false
            val name = marker["name"]?.toString()?.takeIf { it.isNotBlank() }
            val placeType = marker["placeType"]?.toString()
            val badgeText = marker["badgeText"]?.toString()?.takeIf { it.isNotBlank() }
            val compact = (marker["compact"] as? Boolean) ?: false
            markerStates[id] = MarkerState(
                id = id,
                latitude = latitude,
                longitude = longitude,
                name = name,
                compact = compact,
            )
            val icon = makeMarkerBitmap(
                color = pinColorFor(placeType, active),
                active = active,
                compact = compact,
                badgeText = badgeText,
            )
            val style = LabelStyle.from(icon.bitmap)
                .setApplyDpScale(false)
                .setAnchorPoint(icon.anchorX, icon.anchorY)
            val options = LabelOptions.from(id, LatLng.from(latitude, longitude))
                .setStyles(style)
                .setClickable(true)
                .setRank(if (active) 10_000L - index else 1_000L - index)
                .setTag(id)
            layer.addLabel(options)
        }

        currentUserLocation?.let { applyUserLocation(it.first, it.second) }
    }

    private data class MarkerState(
        val id: String,
        val latitude: Double,
        val longitude: Double,
        val name: String?,
        val compact: Boolean,
    )

    private fun toggleBubble(markerId: String) {
        val state = markerStates[markerId] ?: return
        if (state.name.isNullOrBlank()) return

        if (activeBubbleMarkerId == markerId) {
            dismissBubble()
            return
        }

        val map = kakaoMap ?: return
        val layer = ensureBubbleLayer(map) ?: return
        layer.removeAll()

        val bubble = makeBubbleBitmap(state.name)
        val style = LabelStyle.from(bubble)
            .setApplyDpScale(false)
            .setAnchorPoint(0.5f, 1.0f)
        val options = LabelOptions.from(
            "tn_bubble_${state.id}",
            LatLng.from(state.latitude, state.longitude),
        )
            .setStyles(style)
            .setClickable(false)
            .setRank(20_000L)
        val label = layer.addLabel(options)
        val offsetY = if (state.compact) -dp(28f) else -dp(36f)
        label.changePixelOffset(0f, offsetY, false)
        activeBubbleMarkerId = markerId
    }

    private fun dismissBubble() {
        bubbleLayer?.removeAll()
        activeBubbleMarkerId = null
    }

    private fun applyUserLocation(latitude: Double, longitude: Double) {
        val map = kakaoMap ?: return
        currentUserLocation = latitude to longitude
        val layer = ensureUserLocationLayer(map) ?: return
        layer.removeAll()

        val style = LabelStyle.from(makeUserLocationBitmap())
            .setApplyDpScale(false)
            .setAnchorPoint(0.5f, 0.5f)
        val options = LabelOptions.from("tn_user_location_poi", LatLng.from(latitude, longitude))
            .setStyles(style)
            .setClickable(false)
            .setRank(10_000L)
        layer.addLabel(options)
    }

    private fun ensureCandidateLayer(map: KakaoMap): LabelLayer? {
        val existing = candidateLayer
        if (existing != null) return existing
        val layer = map.getLabelManager()?.addLayer(
            LabelLayerOptions.from("timing_note_candidates")
                .setCompetitionType(CompetitionType.None)
                .setOrderingType(OrderingType.Rank)
                .setZOrder(5000)
                .setClickable(true),
        )
        candidateLayer = layer
        return layer
    }

    private fun ensureBubbleLayer(map: KakaoMap): LabelLayer? {
        val existing = bubbleLayer
        if (existing != null) return existing
        val layer = map.getLabelManager()?.addLayer(
            LabelLayerOptions.from("timing_note_bubbles")
                .setCompetitionType(CompetitionType.None)
                .setOrderingType(OrderingType.Rank)
                .setZOrder(7000)
                .setClickable(false),
        )
        bubbleLayer = layer
        return layer
    }

    private fun ensureUserLocationLayer(map: KakaoMap): LabelLayer? {
        val existing = userLocationLayer
        if (existing != null) return existing
        val layer = map.getLabelManager()?.addLayer(
            LabelLayerOptions.from("timing_note_user_location")
                .setCompetitionType(CompetitionType.None)
                .setOrderingType(OrderingType.Rank)
                .setZOrder(6000)
                .setClickable(false),
        )
        userLocationLayer = layer
        return layer
    }

    private fun pinColorFor(placeType: String?, active: Boolean): Int {
        val base = when (placeType) {
            "SPECIFIC" -> Color.rgb(167, 139, 250)
            "ALIAS" -> Color.rgb(253, 230, 138)
            "GENERIC" -> Color.rgb(34, 211, 238)
            else -> if (active) Color.rgb(15, 186, 130) else Color.rgb(66, 66, 66)
        }
        return if (active || placeType == null) base else Color.argb(77, Color.red(base), Color.green(base), Color.blue(base))
    }

    private data class MarkerBitmap(
        val bitmap: Bitmap,
        val anchorX: Float,
        val anchorY: Float,
    )

    private fun makeMarkerBitmap(
        color: Int,
        active: Boolean,
        compact: Boolean,
        badgeText: String?,
    ): MarkerBitmap {
        val pinWidthDp = if (compact) {
            if (active) 20f else 14f
        } else {
            if (active) 26f else 18f
        }
        val pinHeightDp = if (compact) {
            if (active) 30f else 22f
        } else {
            if (active) 36f else 28f
        }
        val badgeDisplay = badgeText?.let { if (it.length > 2) "99+" else it }
        val badgeWidthDp = badgeDisplay?.let {
            val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                textSize = 11f * density
                typeface = android.graphics.Typeface.DEFAULT_BOLD
            }
            max(20f, (textPaint.measureText(it) / density) + 10f)
        } ?: 0f
        val badgeHeightDp = if (badgeDisplay == null) 0f else 20f
        val extraLeftDp = if (badgeDisplay == null) 0f else badgeWidthDp * 0.18f
        val extraRightDp = if (badgeDisplay == null) 0f else badgeWidthDp * 0.55f
        val extraTopDp = if (badgeDisplay == null) 0f else badgeHeightDp * 0.5f

        val width = dp(pinWidthDp + extraLeftDp + extraRightDp).toInt()
        val height = dp(pinHeightDp + extraTopDp).toInt()
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        val pinLeft = dp(extraLeftDp)
        val pinTop = dp(extraTopDp)
        drawPin(
            canvas = canvas,
            left = pinLeft,
            top = pinTop,
            width = dp(pinWidthDp),
            height = dp(pinHeightDp),
            color = color,
            glow = active,
            compact = compact,
        )

        if (badgeDisplay != null) {
            drawCountBadge(
                canvas = canvas,
                text = badgeDisplay,
                left = pinLeft + dp(pinWidthDp * 0.55f),
                top = dp(1f),
                width = dp(badgeWidthDp),
                height = dp(badgeHeightDp),
            )
        }

        val tipX = pinLeft + dp(pinWidthDp / 2f)
        val tipY = pinTop + dp(pinHeightDp)
        return MarkerBitmap(
            bitmap = bitmap,
            anchorX = (tipX / width).coerceIn(0f, 1f),
            anchorY = (tipY / height).coerceIn(0f, 1f),
        )
    }

    private fun drawPin(
        canvas: Canvas,
        left: Float,
        top: Float,
        width: Float,
        height: Float,
        color: Int,
        glow: Boolean,
        compact: Boolean,
    ) {
        val centerX = left + width / 2f
        val headRadius = width / 2f
        val headCenterY = top + headRadius
        val tailTipY = top + height - if (glow) dp(4f) else dp(2f)
        val shadowBlur = if (compact) dp(2f) else dp(4f)
        val strokeWidth = if (compact) dp(0.7f) else dp(0.9f)

        val path = Path().apply {
            moveTo(centerX, tailTipY)
            cubicTo(
                centerX - headRadius * 0.05f,
                tailTipY - headRadius * 0.6f,
                centerX - headRadius,
                headCenterY + headRadius * 0.7f,
                centerX - headRadius,
                headCenterY,
            )
            arcTo(
                RectF(
                    centerX - headRadius,
                    headCenterY - headRadius,
                    centerX + headRadius,
                    headCenterY + headRadius,
                ),
                180f,
                180f,
            )
            cubicTo(
                centerX + headRadius,
                headCenterY + headRadius * 0.7f,
                centerX + headRadius * 0.05f,
                tailTipY - headRadius * 0.6f,
                centerX,
                tailTipY,
            )
            close()
        }

        if (glow) {
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                this.color = Color.argb(230, 255, 255, 255)
                setShadowLayer(shadowBlur, 0f, 0f, Color.WHITE)
            }.also { canvas.drawPath(path, it) }
        }

        Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            this.color = color
        }.also { canvas.drawPath(path, it) }

        Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            this.color = Color.WHITE
            this.strokeWidth = strokeWidth
        }.also { canvas.drawPath(path, it) }

        val innerRadius = if (compact) dp(1.8f) else dp(2.5f)
        Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            this.color = Color.WHITE
        }.also {
            canvas.drawOval(
                RectF(
                    centerX - innerRadius,
                    headCenterY - innerRadius,
                    centerX + innerRadius,
                    headCenterY + innerRadius,
                ),
                it,
            )
        }
    }

    private fun drawCountBadge(
        canvas: Canvas,
        text: String,
        left: Float,
        top: Float,
        width: Float,
        height: Float,
    ) {
        val rect = RectF(left, top, left + width, top + height)
        Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            color = Color.argb(245, 248, 244, 255)
        }.also { canvas.drawRoundRect(rect, height / 2f, height / 2f, it) }

        Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = dp(1f)
            color = Color.argb(199, 167, 139, 250)
        }.also {
            val inset = dp(0.5f)
            canvas.drawRoundRect(
                RectF(left + inset, top + inset, left + width - inset, top + height - inset),
                height / 2f,
                height / 2f,
                it,
            )
        }

        val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(14, 13, 24)
            textSize = dp(11f)
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            textAlign = Paint.Align.CENTER
        }
        val y = rect.centerY() - (textPaint.descent() + textPaint.ascent()) / 2f
        canvas.drawText(text, rect.centerX(), y, textPaint)
    }

    private fun makeBubbleBitmap(text: String): Bitmap {
        val display = if (text.length > 16) "${text.take(15)}..." else text
        val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(38, 38, 38)
            textSize = dp(12f)
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            textAlign = Paint.Align.LEFT
        }
        val textWidth = textPaint.measureText(display)
        val textHeight = textPaint.descent() - textPaint.ascent()
        val hPad = dp(10f)
        val vPad = dp(6f)
        val tailHeight = dp(6f)
        val tailHalfWidth = dp(6f)
        val cornerRadius = dp(8f)
        val boxWidth = textWidth + hPad * 2f
        val boxHeight = textHeight + vPad * 2f
        val width = ceil(boxWidth).toInt()
        val height = ceil(boxHeight + tailHeight).toInt()
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        val path = Path().apply {
            addRoundRect(
                RectF(0f, 0f, boxWidth, boxHeight),
                cornerRadius,
                cornerRadius,
                Path.Direction.CW,
            )
            moveTo(boxWidth / 2f - tailHalfWidth, boxHeight)
            lineTo(boxWidth / 2f, boxHeight + tailHeight)
            lineTo(boxWidth / 2f + tailHalfWidth, boxHeight)
            close()
        }

        Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            color = Color.argb(235, 255, 255, 255)
        }.also { canvas.drawPath(path, it) }

        Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = dp(0.5f)
            color = Color.argb(179, 140, 140, 140)
        }.also { canvas.drawPath(path, it) }

        val baseline = vPad - textPaint.ascent()
        canvas.drawText(display, hPad, baseline, textPaint)
        return bitmap
    }

    private fun makeUserLocationBitmap(): Bitmap {
        val size = dp(16f).toInt()
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val center = size / 2f
        val purple = Color.rgb(167, 139, 250)

        Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            color = Color.argb(46, Color.red(purple), Color.green(purple), Color.blue(purple))
        }.also {
            canvas.drawCircle(center, center, size / 2f, it)
        }

        Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            color = purple
            strokeWidth = dp(1.5f)
        }.also {
            canvas.drawCircle(center, center, dp(5f), it)
        }

        Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            color = Color.WHITE
        }.also {
            canvas.drawCircle(center, center, dp(3f), it)
        }

        return bitmap
    }

    private fun dp(value: Float): Float = ceil(value * density)
}
