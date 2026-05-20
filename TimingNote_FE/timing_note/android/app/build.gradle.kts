import java.util.Base64

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// --dart-define-from-file=.env 로 주입된 값을 Gradle에서 읽는 유틸
fun dartDefines(): Map<String, String> {
    val raw = project.findProperty("dart-defines") as? String ?: return emptyMap()
    return raw.split(",").associate { entry ->
        val decoded = String(Base64.getDecoder().decode(entry))
        val idx = decoded.indexOf('=')
        if (idx < 0) decoded to "" else decoded.substring(0, idx) to decoded.substring(idx + 1)
    }
}

fun envFileValue(key: String): String? {
    val candidates = listOf(
        rootProject.file("../.env"),
        rootProject.file("../../../.env"),
    )
    return candidates
        .firstOrNull { it.isFile }
        ?.readLines()
        ?.firstNotNullOfOrNull { line ->
            val trimmed = line.trim()
            if (trimmed.startsWith("#") || !trimmed.startsWith("$key=")) {
                null
            } else {
                trimmed.substringAfter("=")
                    .trim()
                    .trim('"')
                    .trim('\'')
                    .takeIf { it.isNotBlank() }
            }
        }
}

android {
    namespace = "com.example.timing_note"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.timing_note"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Kakao Maps SDK 네이티브 앱 키 → AndroidManifest.xml의 ${kakaoNativeAppKey}에 주입
        manifestPlaceholders["kakaoNativeAppKey"] =
            dartDefines()["KAKAO_NATIVE_APP_KEY"]
                ?: envFileValue("KAKAO_NATIVE_APP_KEY")
                ?: ""
    }

    buildTypes {
        release {
            // 소나큐브 권고: 릴리즈 빌드에서 코드 난독화 활성화
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("com.kakao.maps.open:android:2.13.1")
    implementation("com.google.android.gms:play-services-location:21.3.0")
}

flutter {
    source = "../.."
}
