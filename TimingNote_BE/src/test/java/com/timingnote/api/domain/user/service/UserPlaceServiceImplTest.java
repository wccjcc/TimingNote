package com.timingnote.api.domain.user.service;

import com.timingnote.api.common.exception.BusinessException;
import com.timingnote.api.common.exception.ErrorCode;
import com.timingnote.api.domain.place.service.PlaceService;
import com.timingnote.api.domain.user.dto.request.UserPlaceCreateRequest;
import com.timingnote.api.domain.user.repository.UserPlaceRepository;
import com.timingnote.api.domain.user.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class UserPlaceServiceImplTest {

    @Mock
    private UserPlaceRepository userPlaceRepository;
    @Mock
    private UserRepository userRepository;
    @Mock
    private PlaceService placeService;

    @Test
    void createUserPlace_rejectsWhenUserAlreadyHasFivePlaces() {
        UserPlaceServiceImpl service = new UserPlaceServiceImpl(
                userPlaceRepository,
                userRepository,
                placeService
        );
        UserPlaceCreateRequest request = new UserPlaceCreateRequest();

        when(userPlaceRepository.countByUser_Id(1L)).thenReturn(5L);

        assertThatThrownBy(() -> service.createUserPlace(1L, request))
                .isInstanceOfSatisfying(BusinessException.class, e -> {
                    assertThat(e.getErrorCode()).isEqualTo(ErrorCode.USER_PLACE_LIMIT_EXCEEDED);
                    assertThat(e.getMessage()).isEqualTo("내 장소는 최대 5개까지 등록할 수 있어요");
                });
        verifyNoInteractions(placeService);
    }
}
