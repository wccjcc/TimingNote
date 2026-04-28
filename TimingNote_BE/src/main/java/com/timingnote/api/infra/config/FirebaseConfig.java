package com.timingnote.api.infra.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.FirebaseMessaging;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.util.StringUtils;

@Slf4j
@Configuration
// Firebase Admin SDK를 애플리케이션 시작 시 1회 초기화하고,
// 이후 푸시 전송에 사용할 FirebaseMessaging Bean을 제공한다.
public class FirebaseConfig {

    @Value("${firebase.admin-sdk-path}")
    private String adminSdkPath;

    @Bean
    public FirebaseApp firebaseApp() throws IOException {
        // 환경변수(FIREBASE_ACCOUNT_PATH) 미설정 시 즉시 실패시켜 초기 설정 누락을 빠르게 감지한다.
        if (!StringUtils.hasText(adminSdkPath)) {
            throw new IllegalStateException("firebase.admin-sdk-path (FIREBASE_ACCOUNT_PATH) must be set.");
        }

        Path credentialPath = Path.of(adminSdkPath);
        // 경로가 잘못된 경우 런타임 중간 장애 대신 기동 시점에 명확히 실패하도록 한다.
        if (!Files.exists(credentialPath)) {
            throw new IllegalStateException("Firebase service account file not found: " + adminSdkPath);
        }

        // 테스트/재기동 환경에서 중복 초기화를 피하고 기존 App 인스턴스를 재사용한다.
        if (!FirebaseApp.getApps().isEmpty()) {
            log.info("FirebaseApp already initialized. appName={}",FirebaseApp.getApps().get(0).getName());
            return FirebaseApp.getApps().get(0);
        }

        try (InputStream credentialsStream = Files.newInputStream(credentialPath)) {
            FirebaseOptions options = FirebaseOptions.builder()
                    .setCredentials(GoogleCredentials.fromStream(credentialsStream))
                    .build();
            FirebaseApp app = FirebaseApp.initializeApp(options);
            log.info("FirebaseApp initialized successfully. appName={}",app.getName());
            return app;
        }
    }

    @Bean
    public FirebaseMessaging firebaseMessaging(FirebaseApp firebaseApp) {
        // 실제 메시지 전송 서비스에서 주입받아 사용하는 Firebase 메시징 클라이언트.
        return FirebaseMessaging.getInstance(firebaseApp);
    }
}
