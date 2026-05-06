package com.timingnote.api;

import org.junit.jupiter.api.Disabled;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

@Disabled("로컬 DB 없는 환경에서 context 로드 불가 — 통합 테스트 환경에서만 실행")
@SpringBootTest
class TimingNoteApplicationTests {

    @Test
    void contextLoads() {
    }

}
