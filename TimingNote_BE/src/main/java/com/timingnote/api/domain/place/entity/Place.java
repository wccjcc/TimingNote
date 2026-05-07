package com.timingnote.api.domain.place.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.annotations.UpdateTimestamp;
import org.hibernate.type.SqlTypes;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.PrecisionModel;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;

@Entity
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@AllArgsConstructor
@Builder
@Table(name = "places")
public class Place {

    private static final GeometryFactory GEO_FACTORY =
            new GeometryFactory(new PrecisionModel(), 4326);

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // 카카오 장소 ID (지도 마커로 등록한 사용자 정의 장소는 null)
    @Column(name = "external_place_id", nullable = true, length = 128)
    private String externalPlaceId;

    // Google Places ID (영업시간 연동, nullable)
    @Column(name = "google_place_id", length = 128)
    private String googlePlaceId;

    @Column(name = "name", nullable = false)
    private String name;

    // 카카오 category_name 전체 경로 (예: "의료,건강 > 약국")
    @Column(name = "category_name")
    private String categoryName;

    // 카카오 대분류 코드 (예: "PM9", "CE7")
    @Column(name = "category_group_code", length = 10)
    private String categoryGroupCode;

    // 카카오 대분류 이름 (예: "약국, 병원", "카페")
    @Column(name = "category_group_name", length = 50)
    private String categoryGroupName;

    // 지번 주소
    @Column(name = "address", columnDefinition = "TEXT")
    private String address;

    // 도로명 주소
    @Column(name = "road_address", columnDefinition = "TEXT")
    private String roadAddress;

    // PostGIS 좌표 — x=경도(longitude), y=위도(latitude)
    @Column(name = "location", columnDefinition = "geography(Point,4326)", nullable = false)
    private Point location;

    @Column(name = "phone", length = 50)
    private String phone;

    @Column(name = "place_url", columnDefinition = "TEXT")
    private String placeUrl;

    @Column(name = "business_status", length = 32)
    private String businessStatus;

    // Google Places regularOpeningHours JSON (raw)
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "regular_hours_raw", columnDefinition = "jsonb")
    private String regularHoursRaw;

    // Google 영업시간 마지막 조회 시각
    @Column(name = "hours_fetched_at")
    private OffsetDateTime hoursFetchedAt;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false, nullable = false)
    private OffsetDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;

    // ── 좌표 편의 메서드 ──────────────────────────────────────────────────────

    public double getLatitude() {
        return location != null ? location.getY() : 0;
    }

    public double getLongitude() {
        return location != null ? location.getX() : 0;
    }

    // ── 팩토리 ───────────────────────────────────────────────────────────────

    public static Point toPoint(double longitude, double latitude) {
        return GEO_FACTORY.createPoint(new Coordinate(longitude, latitude));
    }

    // ── 도메인 메서드 ─────────────────────────────────────────────────────────

    public void enrichGoogleData(String googlePlaceId, String regularHoursRaw, String businessStatus) {
        this.googlePlaceId = googlePlaceId;
        this.regularHoursRaw = regularHoursRaw;
        this.businessStatus = businessStatus;
        this.hoursFetchedAt = OffsetDateTime.now(ZoneOffset.UTC);
    }
}
