package com.timingnote.api.domain.place.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;

import java.time.LocalTime;
import java.time.OffsetDateTime;

@Entity
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@AllArgsConstructor
@Builder
@Table(name = "place_opening_periods")
public class PlaceOpeningPeriod {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "place_id", nullable = false)
    private Long placeId;

    // 0=일, 1=월, ..., 6=토
    @Column(name = "open_day", nullable = false)
    private Short openDay;

    @Column(name = "open_time", nullable = false)
    private LocalTime openTime;

    // 24/7일 때 null
    @Column(name = "close_day")
    private Short closeDay;

    // 24/7일 때 null
    @Column(name = "close_time")
    private LocalTime closeTime;

    // 연중무휴 24시간 (close 없는 단일 period) 여부
    @Column(name = "is_24h", nullable = false)
    private boolean is24h;

    @Column(name = "source_refreshed_at", nullable = false)
    private OffsetDateTime sourceRefreshedAt;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false, nullable = false)
    private OffsetDateTime createdAt;
}
