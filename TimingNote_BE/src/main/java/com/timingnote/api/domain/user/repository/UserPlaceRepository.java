package com.timingnote.api.domain.user.repository;

import com.timingnote.api.domain.user.entity.UserPlace;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface UserPlaceRepository extends JpaRepository<UserPlace, Long> {

    List<UserPlace> findByUser_Id(Long userId);

    Optional<UserPlace> findByIdAndUser_Id(Long id, Long userId);

    Optional<UserPlace> findFirstByUser_IdAndPlace_IdOrderByIdAsc(Long userId, Long placeId);

    long countByUser_Id(Long userId);

    boolean existsByUser_IdAndAliasName(Long userId, String aliasName);

    boolean existsByUser_IdAndAliasNameAndIdNot(Long userId, String aliasName, Long id);

    @Query("""
            SELECT up
            FROM UserPlace up
            JOIN FETCH up.place p
            WHERE up.user.id = :userId
            """)
    List<UserPlace> findWithPlaceByUserId(@Param("userId") Long userId);

    /**
     * AI가 인식한 별칭명으로 user_place를 정확 동치 매칭 — TodoStructurePersister.linkPlace의
     * ALIAS 분기에서 사용. JOIN FETCH로 Place 함께 로드 (즉시 candidate 저장에 활용).
     */
    @Query("""
            SELECT up
            FROM UserPlace up
            JOIN FETCH up.place p
            WHERE up.user.id = :userId
              AND up.aliasName = :aliasName
            """)
    Optional<UserPlace> findWithPlaceByUserIdAndAliasName(
            @Param("userId") Long userId,
            @Param("aliasName") String aliasName);
}
