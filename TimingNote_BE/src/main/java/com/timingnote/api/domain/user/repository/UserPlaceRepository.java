package com.timingnote.api.domain.user.repository;

import com.timingnote.api.domain.user.entity.UserPlace;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface UserPlaceRepository extends JpaRepository<UserPlace, Long> {

    List<UserPlace> findByUser_Id(Long userId);

    @Query("""
            SELECT up
            FROM UserPlace up
            JOIN FETCH up.place p
            WHERE up.user.id = :userId
            """)
    List<UserPlace> findWithPlaceByUserId(@Param("userId") Long userId);
}
