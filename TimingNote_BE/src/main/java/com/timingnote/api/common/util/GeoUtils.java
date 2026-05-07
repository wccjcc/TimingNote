package com.timingnote.api.common.util;

/**
 * 지구 좌표계 기반 거리 계산 유틸리티.
 * Haversine 공식 사용 (구면 삼각법, 오차 ≤ 0.5%).
 *
 * <p>기존에 PlaceServiceImpl, TodoServiceImpl에 각각 복사된 동일 공식을 통합.
 * double 반환 — int(m) 필요 시 호출부에서 {@code (int) Math.round(GeoUtils.distanceMeters(...))} 사용.
 */
public final class GeoUtils {

    private static final double EARTH_RADIUS_M = 6_371_000.0;

    private GeoUtils() {}

    /**
     * 두 WGS-84 좌표 간 직선 거리(미터, double) 반환.
     *
     * @param lat1 출발 위도
     * @param lon1 출발 경도
     * @param lat2 도착 위도
     * @param lon2 도착 경도
     */
    public static double distanceMeters(double lat1, double lon1, double lat2, double lon2) {
        double dLat = Math.toRadians(lat2 - lat1);
        double dLon = Math.toRadians(lon2 - lon1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                * Math.sin(dLon / 2) * Math.sin(dLon / 2);
        return EARTH_RADIUS_M * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    }
}
